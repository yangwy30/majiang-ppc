# 认牌中转站（Cloudflare Worker）

App 正式版不带 Gemini Key，认牌请求发到这里，由中转站带上 Key 转发给 Google。

- 地址：`https://majiang.acrossus.app`（1.0.1 起 App 用这个，域名 acrossus.app 是 Yang 在 Cloudflare 上已有的）
  - 旧地址 `https://majiang-relay.yangwang9710.workers.dev` 是同一个 Worker，留给 1.0 和旧的 TestFlight 版本；中国大陆大多连不上 workers.dev，所以换了域名
  - `/recognize` 认牌，`/invite` 填码（见下面）
  - `/privacy` 隐私说明（`src/privacy.js`），`/support` 帮助页（`src/support.js`），App Store 产品页链的就是这两页
  - `/admin` 邀请码管理网页，`/health` 回 `ok`
- 账号：Yang 的 Cloudflare（免费套餐够用）
- Key：Worker 密钥 `GEMINI_API_KEY`，不进代码、不进仓库

## 它做什么

1. App 把 Gemini `generateContent` 的请求体原样 POST 到 `/recognize`，带 `X-Majiang-Device`（手机的随机编号，存钥匙串）和 `X-Majiang-Invite`（邀请码，见下面）。
2. 检查：必须有设备编号；邀请码要对（「必须有邀请码」关着时可以不带）；请求体只能有 `contents`（1 到 3 轮，第一轮要有照片）和 `generationConfig`，不许带工具、系统提示词，最大 8 MB。这样别人拿到地址也没法当免费的通用 Gemini 用。
3. 计数（UTC 日期，一个 Durable Object 里的 SQLite）：每台手机每分钟 10 次、每天 150 次；每个 IP 每天 500 次；所有人加起来每天 3000 次。超了回 429。Google 出错（5xx、429）不扣每天的次数。
4. 转发给 `wrangler.toml` 里 `MODEL` 指定的模型，回答原样返回，响应头 `X-Majiang-Remaining` 是这台手机今天还剩几次。App 发来的 `X-Majiang-Model` 不算数。
5. 只放行 Flash / Flash-Lite（`src/models.js`），配置里写成 Pro 会直接报错，不会用。

## 邀请码

AI 认牌是邀请制：App 在请求头 `X-Majiang-Invite` 带上用户填的码，中转站查码，App 里的输入框只是入口，挡人靠这里。

- **码**：6 位，只用 `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`（没有 0 O 1 I），不分大小写，空格和横线忽略。
- **填码**：App 先 POST `/invite`（`{"code":"…"}` + `X-Majiang-Device`），码对就把这台手机绑上，回 `{ok, code, dailyLimit, remaining}`。
- **限制**：每个码默认最多绑 2 台手机（`CODE_DEVICE_LIMIT`）、每天 50 次（`CODE_DAILY_LIMIT`），生成时可以单独改。原来按手机、IP、全站的限额照旧。同一个 IP 或手机每天输错 20 次（`INVITE_TRIES_PER_DAY`）以后，只认已经绑在这台手机上的码。
- **没码的请求**：「必须有邀请码」关着时照常转发（给还没更新的旧版 App 留的过渡期），打开后回 403。这个开关在管理网页上拨，不用重新部署；没拨过时按 `wrangler.toml` 的 `INVITE_REQUIRED`。**线上现在是开着的**（2026-10-31 起），旧版 App 没码就用不了 AI 认牌。
- **码的问题**（没有、不对、停用了、手机绑满了）回 403，`error.invite` 是 `true`，App 收到就把存着的码清掉。次数用完回 429，不带 `invite`。

### 管理网页

`https://majiang.acrossus.app/admin`（旧地址下的 `/admin` 也能用）：生成码（可写「给谁」）、看每个码绑了几台手机、今天和一共用了几次、停用 / 重新启用、换手机时清掉绑定、拨「必须有邀请码」。

网页要管理密码，存在 Worker 密钥 `ADMIN_TOKEN` 里。第一次设置（之后换密码也一样）：

```sh
npm run admin-setup   # 生成随机密码，存进 Worker 密钥和这台 Mac 的 ~/.config/majiang/admin_token，打印带密码的管理网页地址
```

打开打印出来的地址（`/admin#token=…`），密码会存进这个浏览器，以后直接开 `/admin` 就行。

上架审核：1.0 送审时已生成一个「审核专用」码（10 台手机、每天 200 次），写在 App Store Connect 的审核备注里。**上架以后在网页上停用它**；以后再送审就再生成一个。

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
- **发邀请码、停用**：管理网页 `/admin`，不用部署。
- **换 Key**：`tr -d '\n\r ' < ~/.config/gemini/api_key | npx wrangler secret put GEMINI_API_KEY`

## 以后可以加

现在靠邀请码挡人：没码的请求直接拒，每个码限手机数和每天次数，再加全局每天 3000 次兜底。码一旦给出去，拿到的人每天能用满这个码的次数，发现被滥用就在管理网页停用。用户多了，再加 Apple App Attest 验证请求确实来自我们的 App。
