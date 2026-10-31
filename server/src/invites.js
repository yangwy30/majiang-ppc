// 邀请码：有码的手机才能用 AI 认牌。码存在 Durable Object 的 SQLite 里，在 /admin 网页上生成、停用。

/// 去掉 0 O 1 I 这种容易看错的字，32 个字符，6 位约 10 亿种。
export const ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
export const CODE_LENGTH = 6;
const CODE_RE = new RegExp(`^[${ALPHABET}]{${CODE_LENGTH}}$`);

/// 用户输入的码：不分大小写，空格、横线忽略。格式不对返回 null。
export function normalizeCode(input) {
  if (typeof input !== "string") return null;
  const code = input.toUpperCase().replace(/[\s-]/g, "");
  return CODE_RE.test(code) ? code : null;
}

/// 随机生成一个码。256 能被 32 整除，取模不会偏向某些字。
export function newCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

/// 比较管理密码：先各自算 SHA-256 再定长比较，不会因为比较快慢泄露密码。
export async function sameSecret(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || !a || !b) return false;
  const enc = new TextEncoder();
  const [ha, hb] = await Promise.all([a, b].map((s) => crypto.subtle.digest("SHA-256", enc.encode(s))));
  return crypto.subtle.timingSafeEqual(ha, hb);
}
