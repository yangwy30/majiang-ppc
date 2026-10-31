// 设置邀请码管理网页的密码：生成一个随机密码，存进 Worker 密钥 ADMIN_TOKEN
// 和这台电脑的 ~/.config/majiang/admin_token，然后打印带密码的管理网页地址。
// npm run admin-setup        （再跑一次就是换密码，旧密码立刻失效）
import { randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const BASE = process.env.MAJIANG_RELAY_URL || "https://majiang-relay.yangwang9710.workers.dev";
const token = randomBytes(24).toString("base64url");

const put = spawnSync("npx", ["wrangler", "secret", "put", "ADMIN_TOKEN"], { input: token, stdio: ["pipe", "inherit", "inherit"] });
if (put.status !== 0) {
  console.error("\n没设置上。先确认 `npx wrangler whoami` 登录的是 Yang 的 Cloudflare 账号。");
  process.exit(1);
}

const dir = join(homedir(), ".config", "majiang");
mkdirSync(dir, { recursive: true });
writeFileSync(join(dir, "admin_token"), token + "\n", { mode: 0o600 });

console.log(`\n管理密码已设置，也存在了 ${join(dir, "admin_token")}。`);
console.log("打开下面这个地址（密码会存进浏览器，以后直接开 /admin 就行）：\n");
console.log(`${BASE}/admin#token=${token}\n`);
