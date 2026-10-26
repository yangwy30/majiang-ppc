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
const BODY = JSON.stringify({ contents: [{ role: "user", parts: [{ text: "hi" }] }] });

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
    DEVICE_PER_MINUTE: "3",
    DEVICE_DAILY_LIMIT: "5",
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
  assert.equal(last.body, BODY);
});

test("Google 出错不扣每天的次数，每分钟限额生效", async () => {
  nextStatus = 500;
  assert.equal((await post()).status, 500);
  nextStatus = 200;
  // 每分钟上限 3：上一个测试 1 次 + 500 那次（每天的退回了，每分钟的不退）+ 这一次
  assert.equal((await post()).status, 200);
  const blocked = await post();
  assert.equal(blocked.status, 429);
  const err = (await blocked.json()).error;
  assert.equal(err.majiang, true);
  assert.match(err.message, /一分钟/);
});
