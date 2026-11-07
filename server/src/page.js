// /support、/privacy 共用的外壳：一样的样式，按语言换字体和 lang。

const FONTS = {
  "zh-Hans": { sans: `-apple-system, "PingFang SC", "Noto Sans SC", sans-serif`, serif: `"Songti SC", "Noto Serif SC", serif` },
  "zh-Hant": { sans: `-apple-system, "PingFang TC", "Noto Sans TC", sans-serif`, serif: `"Songti TC", "Noto Serif TC", serif` },
  en: { sans: `-apple-system, "Helvetica Neue", sans-serif`, serif: `"New York", "Iowan Old Style", Georgia, serif` },
  ja: { sans: `-apple-system, "Hiragino Sans", "Noto Sans JP", sans-serif`, serif: `"Hiragino Mincho ProN", "Noto Serif JP", serif` },
};

const escape = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/// title 进 <title> 和 <h1>，date 是标题下面的灰字，body 是正文 HTML。
export function page(lang, title, date, body) {
  const f = FONTS[lang] ?? FONTS["zh-Hans"];
  const cjk = lang !== "en";
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape(title)}</title>
<style>
  :root { color-scheme: light; }
  body { margin: 0; background: #F7F6F2; color: #16150F;
    font: 16px/1.75 ${f.sans}; }
  main { max-width: 640px; margin: 0 auto; padding: 56px 20px 80px; }
  .seal { display: inline-block; width: 10px; height: 10px; background: #C23B22; border-radius: 2px; }
  h1 { font: 600 30px/1.3 ${f.serif}; margin: 16px 0 4px; letter-spacing: ${cjk ? ".04em" : "0"}; }
  .date { color: #6E6C64; font-size: 14px; margin: 0 0 40px; }
  h2 { font-size: 17px; margin: 36px 0 8px; }
  p, li { color: #3A3933; }
  ul { padding-left: 1.2em; }
  a { color: #C23B22; }
  hr { border: 0; border-top: 1px solid #E7E4DC; margin: 40px 0 0; }
</style>
</head>
<body>
<main>
<span class="seal"></span>
<h1>${escape(title)}</h1>
<p class="date">${escape(date)}</p>
${body.trim()}
<hr>
</main>
</body>
</html>
`;
}

/// 按语言挑页面的回答。Vary 让缓存按 Accept-Language 分开存。
export function htmlResponse(html) {
  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8", "Vary": "Accept-Language" } });
}
