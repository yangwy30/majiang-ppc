import { DurableObject } from "cloudflare:workers";
import { isAllowedModel } from "./models.js";

// 认牌请求的中转站。App 把 Gemini generateContent 的请求体原样 POST 到 /recognize，
// 这里检查、计数，再带上 Key 转发给 Google，把回答原样还回去。
// Key 只存在 Worker 密钥 GEMINI_API_KEY 里，不进代码、不进仓库。

const DEVICE_RE = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const BODY_KEYS = new Set(["contents", "generationConfig"]);


/// 出错时的回答。majiang: true 让 App 知道这是中转站自己的话，直接显示 message。
function fail(status, message) {
  return Response.json({ error: { code: status, message, majiang: true } }, { status });
}

function limit(env, name, fallback) {
  const n = Number.parseInt(env[name] ?? "", 10);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health" && request.method === "GET") return new Response("ok");
    if (url.pathname !== "/recognize") return fail(404, "地址不对");
    if (request.method !== "POST") return fail(405, "只收 POST");

    const device = request.headers.get("X-Majiang-Device") ?? "";
    if (!DEVICE_RE.test(device)) return fail(400, "缺少设备标识，请更新 App");

    // 模型由服务器决定（改 wrangler.toml 的 MODEL 再部署），App 发来的 X-Majiang-Model 只做参考
    const model = env.MODEL;
    if (!isAllowedModel(model)) return fail(500, "服务器配置的模型不对");

    const maxBytes = limit(env, "MAX_BODY_BYTES", 8_000_000);
    if (Number(request.headers.get("Content-Length") ?? 0) > maxBytes) return fail(413, "照片太大了");
    const body = await request.arrayBuffer();
    if (body.byteLength > maxBytes) return fail(413, "照片太大了");

    // 只转发认牌用得到的请求：第一轮要有照片，不许带工具、系统提示词之类，防止被当成免费的通用 Gemini
    let json;
    try {
      json = JSON.parse(new TextDecoder().decode(body));
    } catch {
      return fail(400, "请求不是 JSON");
    }
    if (json === null || typeof json !== "object" || Array.isArray(json)
        || !Object.keys(json).every((k) => BODY_KEYS.has(k))
        || !Array.isArray(json.contents) || json.contents.length < 1 || json.contents.length > 3
        || !json.contents[0]?.parts?.some?.((p) => p?.inline_data?.data || p?.inlineData?.data)) {
      return fail(400, "请求格式不对");
    }

    // 计数和转发都在一个 Durable Object 里做：计数不会被并发请求挤乱，
    // 而且它放在北美（LOCATION_HINT），从那里调 Google 不会碰上「所在地区不支持」。
    const stub = env.RELAY.get(env.RELAY.idFromName("relay"), { locationHint: env.LOCATION_HINT || "wnam" });
    return stub.fetch("https://relay/recognize", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Majiang-Device": device.toLowerCase(),
        "X-Majiang-IP": request.headers.get("CF-Connecting-IP") ?? "unknown",
        "X-Majiang-Model": model,
      },
      body,
    });
  },
};

/// 计数 + 转发。每个 key 一行：今天（UTC）或这一分钟的次数，换了时间窗就从头数。
export class Relay extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec("CREATE TABLE IF NOT EXISTS hits (key TEXT PRIMARY KEY, win TEXT NOT NULL, n INTEGER NOT NULL)");
  }

  count(key, win) {
    const row = this.sql.exec("SELECT win, n FROM hits WHERE key = ?", key).toArray()[0];
    return row && row.win === win ? row.n : 0;
  }

  bump(key, win) {
    this.sql.exec(
      `INSERT INTO hits (key, win, n) VALUES (?, ?, 1)
       ON CONFLICT(key) DO UPDATE SET n = CASE WHEN win = excluded.win THEN n + 1 ELSE 1 END, win = excluded.win`,
      key, win);
  }

  refund(key, win) {
    this.sql.exec("UPDATE hits SET n = n - 1 WHERE key = ? AND win = ? AND n > 0", key, win);
  }

  async fetch(request) {
    const env = this.env;
    const device = request.headers.get("X-Majiang-Device");
    const ip = request.headers.get("X-Majiang-IP");
    const model = request.headers.get("X-Majiang-Model");
    const now = new Date().toISOString();
    const day = now.slice(0, 10);
    const minute = now.slice(0, 16);

    // 一天清一次过期的行
    if (this.count("_cleanup", day) === 0) {
      this.sql.exec("DELETE FROM hits WHERE win < ?", day);
      this.bump("_cleanup", day);
    }

    // 从窄到宽检查；SQL 是同步的，查和加之间不会插进别的请求
    const checks = [
      [`min:dev:${device}`, minute, limit(env, "DEVICE_PER_MINUTE", 10), "拍得太快了，等一分钟再试"],
      [`day:dev:${device}`, day, limit(env, "DEVICE_DAILY_LIMIT", 150), "这台手机今天的识别次数用完了，明天再来，或者先手动选牌"],
      [`day:ip:${ip}`, day, limit(env, "IP_DAILY_LIMIT", 500), "这个网络今天的识别次数用完了，换个网络或者先手动选牌"],
      ["day:all", day, limit(env, "GLOBAL_DAILY_LIMIT", 3000), "识别服务今天太忙了，先手动选牌"],
    ];
    for (const [key, win, max, message] of checks) {
      if (this.count(key, win) >= max) return fail(429, message);
    }
    for (const [key, win] of checks) this.bump(key, win);

    const base = env.GEMINI_BASE || "https://generativelanguage.googleapis.com/v1beta";
    let upstream;
    try {
      upstream = await fetch(`${base}/models/${model}:generateContent`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
        body: request.body,
      });
    } catch {
      upstream = null;
    }
    // Google 那边出错不算用户的次数
    if (!upstream || upstream.status >= 500 || upstream.status === 429) {
      for (const [key, win] of checks.slice(1)) this.refund(key, win);
      if (!upstream) return fail(502, "连不上 Gemini，再试一次");
      if (upstream.status === 429) return fail(503, "Gemini 现在太忙了，过一会儿再试");
    }

    const left = Math.max(0, checks[1][2] - this.count(checks[1][0], day));
    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "Content-Type": upstream.headers.get("Content-Type") ?? "application/json",
        "X-Majiang-Remaining": String(left),
      },
    });
  }
}
