// /：有人在浏览器里直接打开 majiang.acrossus.app 时看到的一页。一句话说这是什么，App Store 下载，帮助和隐私。
// 样式跟 /support、/privacy 一样。

export const HOME_HTML = `<!doctype html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>拍照算番 · 国标麻将 AI 助手</title>
<meta name="description" content="国标麻将算番记账。和了拍一下，自动认牌、算番、记账。完全免费，没有广告，不用注册。">
<meta name="apple-itunes-app" content="app-id=6827328659">
<style>
  :root { color-scheme: light; }
  body { margin: 0; background: #F7F6F2; color: #16150F;
    font: 16px/1.75 -apple-system, "PingFang SC", "Noto Sans SC", sans-serif; }
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
<p class="lead">国标麻将算番记账。和了拍一下，自动认牌、算番，四个人的账一局一局记好，打完算出最少几笔转账。</p>
<p class="free">完全免费，没有广告，不用注册。iPhone 上用。</p>
<a class="download" href="https://apps.apple.com/app/id6827328659">在 App Store 下载</a>
<nav><a href="/support">帮助</a><a href="/privacy">隐私说明</a></nav>
</main>
</body>
</html>
`;
