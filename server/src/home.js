// /：有人在浏览器里直接打开 majiang.acrossus.app 时看到的一页。一句话说这是什么，App Store 下载，帮助和隐私。
// 样式跟 /support、/privacy 一样。按浏览器语言给简体、繁体、英文、日文。

const TEXT = {
  "zh-Hans": {
    tagline: "国标麻将 AI 助手",
    description: "国标麻将算番记账。和了拍一下，自动认牌、算番、记账。完全免费，没有广告，不用注册。",
    lead: "国标麻将算番记账。和了拍一下，自动认牌、算番，四个人的账一局一局记好，打完算出最少几笔转账。",
    free: "完全免费，没有广告，不用注册。iPhone 上用。",
    download: "在 App Store 下载", help: "帮助", privacy: "隐私说明",
    sans: `-apple-system, "PingFang SC", "Noto Sans SC", sans-serif`,
  },
  "zh-Hant": {
    tagline: "國標麻將 AI 助手",
    description: "國標麻將算番記帳。和了拍一下，自動認牌、算番、記帳。完全免費，沒有廣告，不用註冊。",
    lead: "國標麻將算番記帳。和了拍一下，自動認牌、算番，四個人的帳一局一局記好，打完算出最少幾筆轉帳。",
    free: "完全免費，沒有廣告，不用註冊。iPhone 上用。",
    download: "在 App Store 下載", help: "說明", privacy: "隱私說明",
    sans: `-apple-system, "PingFang TC", "Noto Sans TC", sans-serif`,
  },
  en: {
    tagline: "Mahjong scorer",
    description: "Score Chinese Official (MCR) mahjong from a photo. Snap the winning hand to read the tiles, count the fan and keep the ledger. Free, no ads, no sign-up.",
    lead: "Score Chinese Official (MCR) mahjong. Snap the winning hand and the app reads the tiles, counts the fan and keeps all four players\u2019 scores hand by hand, then works out the fewest transfers to settle up.",
    free: "Completely free, no ads, no sign-up. For iPhone.",
    download: "Download on the App Store", help: "Help", privacy: "Privacy",
    sans: `-apple-system, "Helvetica Neue", sans-serif`,
  },
  ja: {
    tagline: "国標麻将の点数計算",
    description: "国標麻将（MCR）の点数計算と記録。和了したら撮るだけで、牌を読み取り、番数を数え、点数を記録します。完全無料、広告なし、登録不要。",
    lead: "国標麻将（MCR）の点数計算と記録。和了したら撮るだけで、牌を読み取って番数を数え、4 人の点数を局ごとに記録し、最後にいちばん少ない精算方法を出します。",
    free: "完全無料、広告なし、登録不要。iPhone 用。",
    download: "App Store でダウンロード", help: "ヘルプ", privacy: "プライバシー",
    sans: `-apple-system, "Hiragino Sans", "Noto Sans JP", sans-serif`,
  },
};

function homePage(lang) {
  const t = TEXT[lang];
  const q = lang === "zh-Hans" ? "" : `?lang=${lang}`;
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>拍照算番 · ${t.tagline}</title>
<meta name="description" content="${t.description}">
<meta name="apple-itunes-app" content="app-id=6827328659">
<style>
  :root { color-scheme: light; }
  body { margin: 0; background: #F7F6F2; color: #16150F;
    font: 16px/1.75 ${t.sans}; }
  main { max-width: 640px; margin: 0 auto; padding: 96px 20px 80px; }
  .seal { display: inline-flex; align-items: center; justify-content: center; width: 56px; height: 56px;
    background: #C23B22; color: #fff; border-radius: 13px;
    font: 700 34px/1 "Songti SC", "Noto Serif SC", serif; }
  h1 { font: 600 34px/1.3 "Songti SC", "Noto Serif SC", serif; margin: 28px 0 8px; letter-spacing: .04em; }
  .lead { color: #3A3933; font-size: 17px; margin: 0 0 8px; }
  .free { color: #6E6C64; font-size: 15px; margin: 0 0 40px; }
  .download { display: inline-block; background: #16150F; color: #fff; text-decoration: none;
    padding: 14px 28px; border-radius: 999px; font-weight: 600; font-size: 17px; }
  nav { margin-top: 56px; padding-top: 20px; border-top: 1px solid #E7E4DC; font-size: 15px; }
  nav a { color: #6E6C64; text-decoration: none; margin-right: 24px; }
</style>
</head>
<body>
<main>
<span class="seal">和</span>
<h1>拍照算番</h1>
<p class="lead">${t.lead}</p>
<p class="free">${t.free}</p>
<a class="download" href="https://apps.apple.com/app/id6827328659">${t.download}</a>
<nav><a href="/support${q}">${t.help}</a><a href="/privacy${q}">${t.privacy}</a></nav>
</main>
</body>
</html>
`;
}

export const HOME_PAGES = Object.fromEntries(Object.keys(TEXT).map((lang) => [lang, homePage(lang)]));
