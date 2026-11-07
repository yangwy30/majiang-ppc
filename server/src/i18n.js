// 给用户看的话按 App 的语言换成繁体、英文或日文。
// App 每个请求都带 X-Majiang-Lang（App 用的语言：zh-Hans / zh-Hant / en / ja）；网页按浏览器的 Accept-Language。
// 代码里还是写简体中文，出门前在 localizeError 里换掉；没有翻译的话照原样（简体）发出去。

export const LANGS = ["zh-Hans", "zh-Hant", "en", "ja"];

/// App 接口的语言：只认 App 自己带的 X-Majiang-Lang。
/// 旧版 App 只有简体界面，不带这个头；它的 Accept-Language 是系统加的，可能是英文，所以不看。
export function apiLang(request) {
  const lang = request.headers.get("X-Majiang-Lang");
  return LANGS.includes(lang) ? lang : "zh-Hans";
}

/// 网页的语言：从 ?lang= 或 Accept-Language 里挑一个我们有的语言，挑不出来就用简体。
export function pickLang(request) {
  const url = new URL(request.url);
  const forced = url.searchParams.get("lang");
  if (LANGS.includes(forced)) return forced;
  const header = request.headers.get("Accept-Language") ?? "";
  const tags = header.split(",")
    .map((part) => {
      const [tag, q] = part.trim().split(";q=");
      return { tag: tag.trim().toLowerCase(), q: q === undefined ? 1 : Number(q) || 0 };
    })
    .filter((t) => t.tag && t.tag !== "*" && t.q > 0)
    .sort((a, b) => b.q - a.q);
  for (const { tag } of tags) {
    if (tag.startsWith("zh")) {
      return /hant|-tw|-hk|-mo/.test(tag) ? "zh-Hant" : "zh-Hans";
    }
    if (tag.startsWith("ja")) return "ja";
    if (tag.startsWith("en")) return "en";
  }
  // 别的语言（法文、韩文……）App 界面是英文，网页也给英文；什么都没带就是简体
  return tags.length ? "en" : "zh-Hans";
}

// 简体原文 → [繁体, 英文, 日文]
const MESSAGES = {
  "地址不对": ["地址不對", "Not found", "見つかりません"],
  "只收 POST": ["只收 POST", "Only POST is accepted", "POST のみ受け付けます"],
  "缺少设备标识，请更新 App": ["缺少裝置標識，請更新 App", "Missing device ID. Please update the app.", "端末 ID がありません。アプリを更新してください。"],
  "请求不是 JSON": ["請求不是 JSON", "The request isn't JSON", "リクエストが JSON ではありません"],
  "太大了": ["太大了", "Too large", "サイズが大きすぎます"],
  "服务器配置的模型不对": ["伺服器設定的模型不對", "The server's model setting is wrong", "サーバーのモデル設定に誤りがあります"],
  "照片太大了": ["照片太大了", "The photo is too large", "写真のサイズが大きすぎます"],
  "请求格式不对": ["請求格式不對", "The request format is wrong", "リクエストの形式が正しくありません"],
  "服务器配置的思考深度不对": ["伺服器設定的思考深度不對", "The server's thinking setting is wrong", "サーバーの思考設定に誤りがあります"],
  "邀请码输错太多次了，明天再试": ["邀請碼輸錯太多次了，明天再試", "Too many wrong invite codes. Try again tomorrow.", "招待コードの入力ミスが多すぎます。明日またお試しください。"],
  "邀请码不对，核对一下再输": ["邀請碼不對，核對一下再輸", "That invite code isn't right. Check it and try again.", "招待コードが違います。確認してもう一度入力してください。"],
  "这个邀请码已经停用了": ["這個邀請碼已經停用了", "This invite code has been turned off.", "この招待コードは無効になっています。"],
  "AI 认牌现在要邀请码：更新到最新版，在首页右上角「更多」里填。没有码也可以先手动选牌": [
    "AI 認牌現在要邀請碼：更新到最新版，在首頁右上角「更多」裡填。沒有碼也可以先手動選牌",
    "AI tile reading now needs an invite code: update to the latest version and enter it under “More” at the top right of the home screen. Without a code you can still pick tiles by hand.",
    "AI 読み取りには招待コードが必要です。最新版に更新し、ホーム右上の「その他」から入力してください。コードがなくても手で牌を選べます。",
  ],
  "拍得太快了，等一分钟再试": ["拍得太快了，等一分鐘再試", "That's too many photos too fast. Wait a minute and try again.", "撮影が速すぎます。1 分ほど待ってからお試しください。"],
  "这台手机今天的识别次数用完了，明天再来，或者先手动选牌": ["這台手機今天的辨識次數用完了，明天再來，或者先手動選牌", "This phone has used up today's AI readings. Come back tomorrow, or pick tiles by hand for now.", "この端末の今日の読み取り回数を使い切りました。明日またお試しいただくか、手で牌を選んでください。"],
  "这个网络今天的识别次数用完了，换个网络或者先手动选牌": ["這個網路今天的辨識次數用完了，換個網路或者先手動選牌", "This network has used up today's AI readings. Try another network, or pick tiles by hand for now.", "このネットワークの今日の読み取り回数を使い切りました。別のネットワークを使うか、手で牌を選んでください。"],
  "识别服务今天太忙了，先手动选牌": ["辨識服務今天太忙了，先手動選牌", "AI reading is too busy today. Pick tiles by hand for now.", "今日は読み取りが混み合っています。手で牌を選んでください。"],
  "这个邀请码今天的次数用完了，明天再来，或者先手动选牌": ["這個邀請碼今天的次數用完了，明天再來，或者先手動選牌", "This invite code has used up today's readings. Come back tomorrow, or pick tiles by hand for now.", "この招待コードの今日の回数を使い切りました。明日またお試しいただくか、手で牌を選んでください。"],
  "连不上 Gemini，再试一次": ["連不上 Gemini，再試一次", "Couldn't reach Gemini. Try again.", "Gemini に接続できません。もう一度お試しください。"],
  "Gemini 现在太忙了，过一会儿再试": ["Gemini 現在太忙了，過一會兒再試", "Gemini is busy right now. Try again in a little while.", "Gemini が混み合っています。しばらくしてからお試しください。"],
  "今天发得太多了，明天再来": ["今天發得太多了，明天再來", "You've sent a lot today. Come back tomorrow.", "今日は送信が多すぎます。明日またお試しください。"],
  "这个网络今天发得太多了，明天再来": ["這個網路今天發得太多了，明天再來", "This network has sent a lot today. Come back tomorrow.", "このネットワークからの今日の送信が多すぎます。明日またお試しください。"],
  "今天收到的太多了，明天再来": ["今天收到的太多了，明天再來", "We've received a lot today. Come back tomorrow.", "今日は受信が多すぎます。明日またお試しください。"],
  "没写内容": ["沒寫內容", "Nothing was written", "内容が空です"],
  "照片不对": ["照片不對", "The photo isn't valid", "写真が正しくありません"],
  "牌不对": ["牌不對", "The tiles aren't valid", "牌のデータが正しくありません"],
};

// 带数字的话：正则 → 每种语言一个函数
const PATTERNS = [
  [/^这个邀请码已经在 (\d+) 台手机上用了，找给你码的人再要一个$/, [
    (n) => `這個邀請碼已經在 ${n} 台手機上用了，找給你碼的人再要一個`,
    (n) => `This invite code is already in use on ${n} ${n === "1" ? "phone" : "phones"}. Ask whoever gave it to you for another one.`,
    (n) => `この招待コードはすでに ${n} 台の端末で使われています。コードをくれた人に別のコードをもらってください。`,
  ]],
];

/// 一句简体的话换成 lang。没有翻译就原样返回。
export function translate(message, lang) {
  const i = ["zh-Hant", "en", "ja"].indexOf(lang);
  if (i < 0 || typeof message !== "string") return message;
  if (MESSAGES[message]) return MESSAGES[message][i];
  for (const [re, fns] of PATTERNS) {
    const m = message.match(re);
    if (m) return fns[i](...m.slice(1));
  }
  return message;
}

/// 中转站自己的出错回答（majiang: true）把 message 换成 lang。别的回答（包括 Google 的）原样返回。
export async function localizeError(response, lang) {
  if (lang === "zh-Hans" || response.status < 400) return response;
  if (!(response.headers.get("Content-Type") ?? "").includes("application/json")) return response;
  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = null; }
  if (!body?.error?.majiang || typeof body.error.message !== "string") {
    return new Response(text, { status: response.status, headers: response.headers });
  }
  body.error.message = translate(body.error.message, lang);
  return Response.json(body, { status: response.status });
}
