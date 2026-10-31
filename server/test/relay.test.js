// 本地跑一遍中转站：起一个假的 Gemini，再用 wrangler dev 起 Worker（计数用本地的 Durable Object）。
// npm test
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { isAllowedModel } from "../src/models.js";

const WORKER_PORT = 8787 + Math.floor(Math.random() * 1000);
const BASE = `http://127.0.0.1:${WORKER_PORT}`;
const DEVICE = "8f14e45f-ceea-467f-a0e6-4d2b1c9a0b11";
const BODY = JSON.stringify({ contents: [{ role: "user", parts: [{ inline_data: { mime_type: "image/jpeg", data: "AAAA" } }, { text: "hi" }] }] });

let fake, worker, received = [], nextStatus = 200;

before(async () => {
  fake = createServer((req, res) => {
    let data = "";
    req.on("data", (c) => (data += c));
    req.on("end", () => {
      received.push({ url: req.url, key: req.headers["x-goog-api-key"], body: data });
      res.writeHead(nextStatus, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ candidates: [{ content: { parts: [{ text: "{}" }] } }] }));
    });
  });
  await new Promise((r) => fake.listen(0, "127.0.0.1", r));
  const vars = {
    GEMINI_BASE: `http://127.0.0.1:${fake.address().port}`,
    GEMINI_API_KEY: "fake-key",
    DEVICE_PER_MINUTE: "4",
    DEVICE_DAILY_LIMIT: "5",
    ADMIN_TOKEN: "admin-secret",
    INVITE_TRIES_PER_DAY: "3",
  };
  worker = spawn("npx", ["wrangler", "dev", "--port", String(WORKER_PORT), "--persist-to", `.wrangler/test-${WORKER_PORT}`,
    ...Object.entries(vars).flatMap(([k, v]) => ["--var", `${k}:${v}`])], { stdio: "ignore" });
  for (let i = 0; i < 120; i++) {
    try {
      if ((await fetch(`${BASE}/health`)).ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error("wrangler dev 没起来");
});

after(() => {
  worker?.kill();
  fake?.close();
});

const post = (headers = {}, body = BODY) => fetch(`${BASE}/recognize`, {
  method: "POST", body, headers: { "Content-Type": "application/json", "X-Majiang-Device": DEVICE, ...headers },
});

test("只放行 Flash 和 Flash-Lite", () => {
  for (const m of ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-2.5-flash-preview-09-2025"]) assert.ok(isAllowedModel(m), m);
  for (const m of ["gemini-3.8-pro", "gemini-2.5-pro-flash", "gemini-3.8-flash/../pro", "", undefined]) assert.ok(!isAllowedModel(m), m);
});

test("没有设备标识、格式不对的请求不转发", async () => {
  assert.equal((await post({ "X-Majiang-Device": "" })).status, 400);
  assert.equal((await post({}, "not json")).status, 400);
  assert.equal((await post({}, JSON.stringify({ contents: [], tools: [] }))).status, 400);
  assert.equal((await post({}, JSON.stringify({ ...JSON.parse(BODY), systemInstruction: {} }))).status, 400);
  assert.equal((await post({}, JSON.stringify({ contents: [{ role: "user", parts: [{ text: "写首诗" }] }] }))).status, 400);
  assert.equal((await fetch(`${BASE}/recognize`)).status, 405);
  assert.equal(received.length, 0);
});

test("带上 Key 转发给服务器配置的模型，App 指定的模型不算", async () => {
  const res = await post({ "X-Majiang-Model": "gemini-3.8-pro" });
  assert.equal(res.status, 200);
  assert.ok((await res.json()).candidates);
  const last = received.at(-1);
  assert.equal(last.url, "/models/gemini-3.8-flash:generateContent");
  assert.equal(last.key, "fake-key");
  const sent = JSON.parse(last.body);
  assert.deepEqual(sent.contents, JSON.parse(BODY).contents);
  assert.deepEqual(sent.generationConfig.thinkingConfig, { thinkingLevel: "low" });
});

test("思考深度用服务器的设置，App 发来的会被覆盖，其他生成参数保留", async () => {
  const body = JSON.stringify({ ...JSON.parse(BODY),
    generationConfig: { responseMimeType: "application/json", thinkingConfig: { thinkingLevel: "high" } } });
  assert.equal((await post({}, body)).status, 200);
  const sent = JSON.parse(received.at(-1).body);
  assert.equal(sent.generationConfig.responseMimeType, "application/json");
  assert.deepEqual(sent.generationConfig.thinkingConfig, { thinkingLevel: "low" });
});

test("Google 出错不扣每天的次数，每分钟限额生效", async () => {
  nextStatus = 500;
  assert.equal((await post()).status, 500);
  nextStatus = 200;
  // 每分钟上限 4：前面两个测试 2 次 + 500 那次（每天的退回了，每分钟的不退）+ 这一次
  assert.equal((await post()).status, 200);
  const blocked = await post();
  assert.equal(blocked.status, 429);
  const err = (await blocked.json()).error;
  assert.equal(err.majiang, true);
  assert.match(err.message, /一分钟/);
});

// MARK: 邀请码

const device = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const adminApi = (path, body, token = "admin-secret") => fetch(`${BASE}/admin/api/${path}`, {
  method: body ? "POST" : "GET",
  headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
  body: body ? JSON.stringify(body) : undefined,
});
const redeem = (code, dev) => fetch(`${BASE}/invite`, {
  method: "POST", headers: { "Content-Type": "application/json", "X-Majiang-Device": dev }, body: JSON.stringify({ code }),
});
const newInvite = async (body = {}) => {
  const res = await adminApi("codes", body);
  assert.equal(res.status, 200);
  return res.json();
};

test("管理接口要管理密码，网页本身能打开", async () => {
  assert.equal((await adminApi("codes", undefined, "")).status, 401);
  assert.equal((await adminApi("codes", undefined, "wrong")).status, 401);
  const page = await fetch(`${BASE}/admin`);
  assert.equal(page.status, 200);
  assert.match(await page.text(), /邀请码/);
  const list = await (await adminApi("codes")).json();
  assert.equal(list.inviteRequired, false);
  assert.deepEqual(list.defaults, { deviceLimit: 2, dailyLimit: 50 });
});

test("生成的码：6 位、不含容易看错的字，填码时不分大小写，绑满手机就不让再绑", async () => {
  const c = await newInvite({ note: "  老张  ", deviceLimit: 2 });
  assert.match(c.code, /^[2-9A-HJ-NP-Z]{6}$/);
  assert.equal(c.note, "老张");
  assert.equal(c.deviceLimit, 2);
  assert.equal(c.dailyLimit, 50);

  const ok = await redeem(` ${c.code.slice(0, 3).toLowerCase()}-${c.code.slice(3)} `, device(1));
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), { ok: true, code: c.code, dailyLimit: 50, remaining: 50 });
  assert.equal((await redeem(c.code, device(1))).status, 200, "同一台手机再填不算新手机");
  assert.equal((await redeem(c.code, device(2))).status, 200);
  const full = await redeem(c.code, device(3));
  assert.equal(full.status, 403);
  const err = (await full.json()).error;
  assert.equal(err.invite, true);
  assert.match(err.message, /2 台手机/);

  // 清掉绑定的手机以后，第三台能绑上
  assert.equal((await adminApi(`codes/${c.code}`, { action: "unbind" })).status, 200);
  assert.equal((await redeem(c.code, device(3))).status, 200);
  const listed = (await (await adminApi("codes")).json()).codes.find((x) => x.code === c.code);
  assert.equal(listed.devices, 1);
});

test("带码识别：按码计每天的次数，码不对、停用了都不转发", async () => {
  const c = await newInvite({ note: "限两次", dailyLimit: 2 });
  const dev = device(10);
  const before = received.length;

  const first = await post({ "X-Majiang-Device": dev, "X-Majiang-Invite": c.code });
  assert.equal(first.status, 200);
  assert.equal(first.headers.get("X-Majiang-Remaining"), "1");
  assert.equal((await post({ "X-Majiang-Device": dev, "X-Majiang-Invite": c.code })).status, 200);
  const used = await post({ "X-Majiang-Device": dev, "X-Majiang-Invite": c.code });
  assert.equal(used.status, 429);
  const usedErr = (await used.json()).error;
  assert.match(usedErr.message, /邀请码今天的次数用完了/);
  assert.equal(usedErr.invite, undefined, "次数用完不是码的问题，App 不该清掉码");

  const listed = (await (await adminApi("codes")).json()).codes.find((x) => x.code === c.code);
  assert.equal(listed.uses, 2);
  assert.equal(listed.today, 2);
  assert.ok(listed.lastUsed);

  const wrong = await post({ "X-Majiang-Device": device(11), "X-Majiang-Invite": "ZZZZZZ" });
  assert.equal(wrong.status, 403);
  assert.equal((await wrong.json()).error.invite, true);

  const d = await newInvite({ note: "要停用" });
  assert.equal((await post({ "X-Majiang-Device": device(12), "X-Majiang-Invite": d.code })).status, 200);
  assert.equal((await adminApi(`codes/${d.code}`, { action: "disable" })).status, 200);
  const off = await post({ "X-Majiang-Device": device(12), "X-Majiang-Invite": d.code });
  assert.equal(off.status, 403);
  assert.match((await off.json()).error.message, /停用/);
  assert.equal((await adminApi(`codes/${d.code}`, { action: "enable" })).status, 200);
  assert.equal((await post({ "X-Majiang-Device": device(12), "X-Majiang-Invite": d.code })).status, 200);

  assert.equal(received.length, before + 4);
});

test("「必须有邀请码」打开后，没码的请求（旧版 App）被拒，有码的照常", async () => {
  assert.equal((await post({ "X-Majiang-Device": device(20) })).status, 200, "默认没码也能用");
  const on = await adminApi("settings", { inviteRequired: true });
  assert.equal((await on.json()).inviteRequired, true);

  const blocked = await post({ "X-Majiang-Device": device(20) });
  assert.equal(blocked.status, 403);
  const err = (await blocked.json()).error;
  assert.equal(err.invite, true);
  assert.equal(err.majiang, true);

  const c = await newInvite();
  assert.equal((await post({ "X-Majiang-Device": device(21), "X-Majiang-Invite": c.code })).status, 200);

  await adminApi("settings", { inviteRequired: false });
  assert.equal((await post({ "X-Majiang-Device": device(20) })).status, 200);
});

// 放最后：本地所有请求都是同一个 IP，输错满了以后别的新手机也绑不上
test("输错太多次以后不让再试，已经绑好的手机不受影响", async () => {
  const c = await newInvite();
  assert.equal((await redeem(c.code, device(30))).status, 200);
  // 上限 3 次（前面的测试已经输错过 1 次，同一个 IP 一起算）
  let status = 0, tries = 0;
  while (tries < 10 && (status = (await redeem("AAAAAA", device(31))).status) === 403) tries++;
  assert.equal(status, 429);
  assert.ok(tries >= 1 && tries <= 3, `输错 ${tries} 次后被挡`);
  const locked = await redeem(c.code, device(31));
  assert.equal(locked.status, 429, "猜中了也不认");
  assert.equal((await locked.json()).error.invite, undefined);
  assert.equal((await redeem(c.code, device(30))).status, 200);
  assert.equal((await post({ "X-Majiang-Device": device(30), "X-Majiang-Invite": c.code })).status, 200);
});
