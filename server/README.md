# 认牌中转站（Cloudflare Worker）

App 正式版不带 Gemini Key，认牌请求发到这里，由中转站带上 Key 转发给 Google。

- 地址：`https://majiang-relay.yangwang9710.workers.dev/recognize`（`/health` 回 `ok`）
- 账号：Yang 的 Cloudflare（免费套餐够用）
- Key：Worker 密钥 `GEMINI_API_KEY`，不进代码、不进仓库

## 它做什么

1. App 把 Gemini `generateContent` 的请求体原样 POST 到 `/recognize`，带 `X-Majiang-Device`（手机的随机编号，存钥匙串）。
2. 检查：必须有设备编号；请求体只能有 `contents`（1 到 3 轮，第一轮要有照片）和 `generationConfig`，不许带工具、系统提示词，最大 8 MB。这样别人拿到地址也没法当免费的通用 Gemini 用。
3. 计数（UTC 日期，一个 Durable Object 里的 SQLite）：每台手机每分钟 10 次、每天 150 次；每个 IP 每天 500 次；所有人加起来每天 3000 次。超了回 429。Google 出错（5xx、429）不扣每天的次数。
4. 转发给 `wrangler.toml` 里 `MODEL` 指定的模型，回答原样返回，响应头 `X-Majiang-Remaining` 是这台手机今天还剩几次。App 发来的 `X-Majiang-Model` 不算数。
5. 只放行 Flash / Flash-Lite（`src/models.js`），配置里写成 Pro 会直接报错，不会用。

中转站自己拒绝的请求回 `{"error":{"message":"…","majiang":true}}`，App 把 `message` 直接显示给用户。

计数和转发放在北美西部的 Durable Object 里（`LOCATION_HINT`），从那里调 Google，避开 Gemini 不支持的地区（比如香港机房）。

## 常用操作

都在 `server/` 目录里运行，第一次先 `npm install`。

```sh
npm test                 # 本地测试：假的 Gemini + wrangler dev
npm run deploy           # 部署（改了代码或 wrangler.toml 之后）
npx wrangler tail        # 看线上实时日志
```

- **换模型**：改 `wrangler.toml` 里的 `MODEL`（比如 `gemini-3.5-flash-lite`），`npm run deploy`。App 不用更新。
- **改限额**：改 `wrangler.toml` 的 `[vars]`，`npm run deploy`。
- **换 Key**：`tr -d '\n\r ' < ~/.config/gemini/api_key | npx wrangler secret put GEMINI_API_KEY`

## 以后可以加

现在的防护挡得住随手乱用，挡不住有人专门改设备编号刷次数（全局每天 3000 次兜底，账单有上限）。真要上架、用户多了，再加 Apple App Attest 验证请求确实来自我们的 App。
