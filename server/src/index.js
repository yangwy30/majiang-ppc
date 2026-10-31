import { DurableObject } from "cloudflare:workers";
import { isAllowedModel } from "./models.js";
import { PRIVACY_HTML } from "./privacy.js";
import { ADMIN_HTML } from "./admin.js";
import { normalizeCode, newCode, sameSecret } from "./invites.js";

// 认牌请求的中转站。App 把 Gemini generateContent 的请求体原样 POST 到 /recognize，
// 这里检查、计数，再带上 Key 转发给 Google，把回答原样还回去。
// Key 只存在 Worker 密钥 GEMINI_API_KEY 里，不进代码、不进仓库。
// 邀请码（X-Majiang-Invite）也在这里查：有码才转发，App 里的输入框只是个入口，挡人靠服务器。
// /admin 是 Yang 管邀请码的网页，接口要管理密码（Worker 密钥 ADMIN_TOKEN）。

const DEVICE_RE = /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;
const BODY_KEYS = new Set(["contents", "generationConfig"]);
const THINKING_LEVELS = new Set(["minimal", "low", "medium", "high"]);


/// 出错时的回答。majiang: true 让 App 知道这是中转站自己的话，直接显示 message。
/// invite: true 表示是邀请码的问题（没有、不对、停用了、手机满了），App 收到就把存着的码清掉。
function fail(status, message, extra = {}) {
  return Response.json({ error: { code: status, message, majiang: true, ...extra } }, { status });
}

function relay(env) {
  return env.RELAY.get(env.RELAY.idFromName("relay"), { locationHint: env.LOCATION_HINT || "wnam" });
}

function limit(env, name, fallback) {
  const n = Number.parseInt(env[name] ?? "", 10);
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health" && request.method === "GET") return new Response("ok");
    if (url.pathname === "/privacy" && request.method === "GET") {
      return new Response(PRIVACY_HTML, { headers: { "Content-Type": "text/html; charset=utf-8" } });
    }
    if (url.pathname === "/admin" && request.method === "GET") {
      return new Response(ADMIN_HTML, { headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "Content-Security-Policy": "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'",
        "Referrer-Policy": "no-referrer",
      } });
    }
    if (url.pathname.startsWith("/admin/api/")) return admin(request, env, url);
    if (url.pathname !== "/recognize" && url.pathname !== "/invite") return fail(404, "地址不对");
    if (request.method !== "POST") return fail(405, "只收 POST");

    const device = request.headers.get("X-Majiang-Device") ?? "";
    if (!DEVICE_RE.test(device)) return fail(400, "缺少设备标识，请更新 App");
    const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";

    // 填邀请码时先来这里查一下：码对就把这台手机绑上，App 存下码
    if (url.pathname === "/invite") {
      let code = "";
      try {
        code = String((await request.json())?.code ?? "");
      } catch {
        return fail(400, "请求不是 JSON");
      }
      return relay(env).fetch("https://relay/invite", {
        method: "POST",
        headers: { "X-Majiang-Device": device.toLowerCase(), "X-Majiang-IP": ip, "X-Majiang-Invite": code.slice(0, 32) },
      });
    }

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

    // 思考深度也由服务器决定，覆盖 App 发来的。研究里 3.8 Flash 调成 low 快了约 3 倍，准确率只少一点。
    // 设成空就用模型默认；换成 2.5 系列模型时要设成空（它们不认 thinkingLevel）。
    let forward = body;
    const thinking = env.THINKING_LEVEL ?? "";
    if (thinking) {
      if (!THINKING_LEVELS.has(thinking)) return fail(500, "服务器配置的思考深度不对");
      json.generationConfig = { ...json.generationConfig, thinkingConfig: { thinkingLevel: thinking } };
      forward = JSON.stringify(json);
    }

    // 计数和转发都在一个 Durable Object 里做：计数不会被并发请求挤乱，
    // 而且它放在北美（LOCATION_HINT），从那里调 Google 不会碰上「所在地区不支持」。
    return relay(env).fetch("https://relay/recognize", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Majiang-Device": device.toLowerCase(),
        "X-Majiang-IP": ip,
        "X-Majiang-Model": model,
        "X-Majiang-Invite": (request.headers.get("X-Majiang-Invite") ?? "").slice(0, 32),
      },
      body: forward,
    });
  },
};

/// 管理接口：先对管理密码，再交给 Durable Object。
async function admin(request, env, url) {
  if (!env.ADMIN_TOKEN) return fail(503, "还没设置管理密码（Worker 密钥 ADMIN_TOKEN），见 server/README.md");
  const auth = request.headers.get("Authorization") ?? "";
  if (!(await sameSecret(auth.replace(/^Bearer\s+/i, ""), env.ADMIN_TOKEN))) return fail(401, "管理密码不对");
  if (request.method !== "GET" && request.method !== "POST") return fail(405, "只收 GET 和 POST");
  return relay(env).fetch(`https://relay${url.pathname.replace("/admin/api/", "/admin/")}`, {
    method: request.method,
    headers: { "Content-Type": "application/json" },
    body: request.method === "POST" ? await request.text() : undefined,
  });
}

/// 计数 + 转发 + 邀请码。每个计数 key 一行：今天（UTC）或这一分钟的次数，换了时间窗就从头数。
export class Relay extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec("CREATE TABLE IF NOT EXISTS hits (key TEXT PRIMARY KEY, win TEXT NOT NULL, n INTEGER NOT NULL)");
    // 邀请码。device_limit / daily_limit 为空时用 wrangler.toml 里的默认值。
    this.sql.exec(`CREATE TABLE IF NOT EXISTS invites (
      code TEXT PRIMARY KEY, note TEXT NOT NULL DEFAULT '', created TEXT NOT NULL,
      disabled INTEGER NOT NULL DEFAULT 0, device_limit INTEGER, daily_limit INTEGER,
      uses INTEGER NOT NULL DEFAULT 0, last_used TEXT)`);
    this.sql.exec(`CREATE TABLE IF NOT EXISTS invite_devices (
      code TEXT NOT NULL, device TEXT NOT NULL, first_seen TEXT NOT NULL, PRIMARY KEY (code, device))`);
    // 在管理网页上改的开关（现在只有「必须有邀请码」）
    this.sql.exec("CREATE TABLE IF NOT EXISTS settings (name TEXT PRIMARY KEY, value TEXT NOT NULL)");
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

  // MARK: 邀请码

  /// 没码能不能用 AI 认牌。管理网页上拨过就按网页的，没拨过按 wrangler.toml 的 INVITE_REQUIRED。
  inviteRequired() {
    const row = this.sql.exec("SELECT value FROM settings WHERE name = 'invite_required'").toArray()[0];
    return (row ? row.value : this.env.INVITE_REQUIRED) === "true";
  }

  limitsOf(row) {
    return {
      deviceLimit: row?.device_limit ?? limit(this.env, "CODE_DEVICE_LIMIT", 2),
      dailyLimit: row?.daily_limit ?? limit(this.env, "CODE_DAILY_LIMIT", 50),
    };
  }

  /// 查码，第一次用的手机顺手绑上。成功返回 { code, dailyLimit }，失败返回 { status, error, invite }。
  /// 防猜码：同一个 IP 或同一台手机每天输错几次（INVITE_TRIES_PER_DAY）以后，只认已经绑在这台手机上的码。
  useInvite(input, device, ip, day) {
    const code = normalizeCode(input);
    const row = code ? this.sql.exec("SELECT * FROM invites WHERE code = ?", code).toArray()[0] : undefined;
    const bound = row ? this.sql.exec("SELECT 1 FROM invite_devices WHERE code = ? AND device = ?", code, device).toArray().length > 0 : false;
    if (!bound) {
      const tries = limit(this.env, "INVITE_TRIES_PER_DAY", 20);
      if (this.count(`day:bad:ip:${ip}`, day) >= tries || this.count(`day:bad:dev:${device}`, day) >= tries) {
        return { status: 429, error: "邀请码输错太多次了，明天再试" };
      }
    }
    if (!row) {
      this.bump(`day:bad:ip:${ip}`, day);
      this.bump(`day:bad:dev:${device}`, day);
      return { status: 403, error: "邀请码不对，核对一下再输", invite: true };
    }
    if (row.disabled) return { status: 403, error: "这个邀请码已经停用了", invite: true };
    const { deviceLimit, dailyLimit } = this.limitsOf(row);
    if (!bound) {
      const n = this.sql.exec("SELECT COUNT(*) AS n FROM invite_devices WHERE code = ?", code).one().n;
      if (n >= deviceLimit) {
        return { status: 403, error: `这个邀请码已经在 ${deviceLimit} 台手机上用了，找给你码的人再要一个`, invite: true };
      }
      this.sql.exec("INSERT INTO invite_devices (code, device, first_seen) VALUES (?, ?, ?)", code, device, new Date().toISOString());
    }
    return { code, dailyLimit };
  }

  async fetch(request) {
    const path = new URL(request.url).pathname;
    const now = new Date().toISOString();
    const day = now.slice(0, 10);

    // 一天清一次过期的行
    if (this.count("_cleanup", day) === 0) {
      this.sql.exec("DELETE FROM hits WHERE win < ?", day);
      this.bump("_cleanup", day);
    }

    if (path === "/recognize") return this.recognize(request, now);
    if (path === "/invite") return this.checkInvite(request, day);
    if (path.startsWith("/admin/")) return this.admin(request, path, day);
    return fail(404, "地址不对");
  }

  checkInvite(request, day) {
    const device = request.headers.get("X-Majiang-Device");
    const used = this.useInvite(request.headers.get("X-Majiang-Invite"), device, request.headers.get("X-Majiang-IP"), day);
    if (used.error) return fail(used.status, used.error, used.invite ? { invite: true } : {});
    return Response.json({
      ok: true,
      code: used.code,
      dailyLimit: used.dailyLimit,
      remaining: Math.max(0, used.dailyLimit - this.count(`day:code:${used.code}`, day)),
    });
  }

  async recognize(request, now) {
    const env = this.env;
    const device = request.headers.get("X-Majiang-Device");
    const ip = request.headers.get("X-Majiang-IP");
    const model = request.headers.get("X-Majiang-Model");
    const inviteInput = request.headers.get("X-Majiang-Invite") ?? "";
    const day = now.slice(0, 10);
    const minute = now.slice(0, 16);

    // 带了码就查码（码不对直接拒绝，哪怕现在没码也能用）；没带码就看是不是必须要码
    let invite = null;
    if (inviteInput) {
      invite = this.useInvite(inviteInput, device, ip, day);
      if (invite.error) return fail(invite.status, invite.error, invite.invite ? { invite: true } : {});
    } else if (this.inviteRequired()) {
      return fail(403, "AI 认牌现在要邀请码，请更新 App 后在拍照页输入。没有码也可以先手动选牌", { invite: true });
    }

    // 从窄到宽检查；SQL 是同步的，查和加之间不会插进别的请求
    const checks = [
      [`min:dev:${device}`, minute, limit(env, "DEVICE_PER_MINUTE", 10), "拍得太快了，等一分钟再试"],
      [`day:dev:${device}`, day, limit(env, "DEVICE_DAILY_LIMIT", 150), "这台手机今天的识别次数用完了，明天再来，或者先手动选牌"],
      [`day:ip:${ip}`, day, limit(env, "IP_DAILY_LIMIT", 500), "这个网络今天的识别次数用完了，换个网络或者先手动选牌"],
      ["day:all", day, limit(env, "GLOBAL_DAILY_LIMIT", 3000), "识别服务今天太忙了，先手动选牌"],
    ];
    if (invite) {
      checks.push([`day:code:${invite.code}`, day, invite.dailyLimit, "这个邀请码今天的次数用完了，明天再来，或者先手动选牌"]);
    }
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
    if (invite && upstream.status === 200) {
      this.sql.exec("UPDATE invites SET uses = uses + 1, last_used = ? WHERE code = ?", now, invite.code);
    }

    // 还剩几次：这台手机今天的，有码时再和这个码今天的取小
    let left = checks[1][2] - this.count(checks[1][0], day);
    if (invite) left = Math.min(left, invite.dailyLimit - this.count(`day:code:${invite.code}`, day));
    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "Content-Type": upstream.headers.get("Content-Type") ?? "application/json",
        "X-Majiang-Remaining": String(Math.max(0, left)),
      },
    });
  }

  // MARK: 管理（Worker 那边已经对过管理密码）

  async admin(request, path, day) {
    let body = {};
    if (request.method === "POST") {
      try {
        body = (await request.json()) ?? {};
      } catch {
        return fail(400, "请求不是 JSON");
      }
    }

    if (path === "/admin/codes" && request.method === "GET") return Response.json(this.listCodes(day));

    if (path === "/admin/codes" && request.method === "POST") {
      const note = typeof body.note === "string" ? body.note.trim().slice(0, 40) : "";
      const deviceLimit = optionalCount(body.deviceLimit, 100);
      const dailyLimit = optionalCount(body.dailyLimit, 1000);
      if (deviceLimit === undefined || dailyLimit === undefined) return fail(400, "手机数要在 1 到 100，每天次数要在 1 到 1000");
      let code;
      do code = newCode(); while (this.sql.exec("SELECT 1 FROM invites WHERE code = ?", code).toArray().length);
      this.sql.exec("INSERT INTO invites (code, note, created, device_limit, daily_limit) VALUES (?, ?, ?, ?, ?)",
        code, note, new Date().toISOString(), deviceLimit, dailyLimit);
      return Response.json(this.listCodes(day).codes.find((c) => c.code === code));
    }

    if (path === "/admin/settings" && request.method === "POST") {
      if (typeof body.inviteRequired !== "boolean") return fail(400, "inviteRequired 要是 true 或 false");
      this.sql.exec(`INSERT INTO settings (name, value) VALUES ('invite_required', ?)
        ON CONFLICT(name) DO UPDATE SET value = excluded.value`, String(body.inviteRequired));
      return Response.json(this.listCodes(day));
    }

    const match = path.match(/^\/admin\/codes\/([^/]+)$/);
    if (match && request.method === "POST") {
      const code = normalizeCode(decodeURIComponent(match[1]));
      if (!code || !this.sql.exec("SELECT 1 FROM invites WHERE code = ?", code).toArray().length) return fail(404, "没有这个邀请码");
      switch (body.action) {
        case "disable": this.sql.exec("UPDATE invites SET disabled = 1 WHERE code = ?", code); break;
        case "enable": this.sql.exec("UPDATE invites SET disabled = 0 WHERE code = ?", code); break;
        // 换了手机：把绑过的手机都清掉，码可以重新绑
        case "unbind": this.sql.exec("DELETE FROM invite_devices WHERE code = ?", code); break;
        case "note": {
          const note = typeof body.note === "string" ? body.note.trim().slice(0, 40) : "";
          this.sql.exec("UPDATE invites SET note = ? WHERE code = ?", note, code);
          break;
        }
        default: return fail(400, "不认识的操作");
      }
      return Response.json(this.listCodes(day).codes.find((c) => c.code === code));
    }

    return fail(404, "地址不对");
  }

  listCodes(day) {
    const rows = this.sql.exec(`SELECT i.*, (SELECT COUNT(*) FROM invite_devices d WHERE d.code = i.code) AS devices
      FROM invites i ORDER BY i.created DESC`).toArray();
    const defaults = this.limitsOf(null);
    return {
      inviteRequired: this.inviteRequired(),
      defaults,
      codes: rows.map((r) => {
        const { deviceLimit, dailyLimit } = this.limitsOf(r);
        return {
          code: r.code, note: r.note, created: r.created, disabled: !!r.disabled,
          devices: r.devices, deviceLimit, dailyLimit,
          today: this.count(`day:code:${r.code}`, day), uses: r.uses, lastUsed: r.last_used,
        };
      }),
    };
  }
}

/// 管理网页填的数：空 = 用默认（null），1..max 的整数，其他返回 undefined 表示不对。
function optionalCount(value, max) {
  if (value === undefined || value === null || value === "") return null;
  const n = Number(value);
  return Number.isInteger(n) && n >= 1 && n <= max ? n : undefined;
}
