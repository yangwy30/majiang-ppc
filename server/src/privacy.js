// /privacy：App 的隐私说明。TestFlight 和 App Store 都要一个能公开打开的地址。
// 改了 App 收集或发送的东西，这里要跟着改。

export const PRIVACY_HTML = `<!doctype html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>拍照算番 · 隐私说明</title>
<style>
  :root { color-scheme: light; }
  body { margin: 0; background: #F7F6F2; color: #16150F;
    font: 16px/1.75 -apple-system, "PingFang SC", "Noto Sans SC", sans-serif; }
  main { max-width: 640px; margin: 0 auto; padding: 56px 20px 80px; }
  .seal { display: inline-block; width: 10px; height: 10px; background: #C23B22; border-radius: 2px; }
  h1 { font: 600 30px/1.3 "Songti SC", "Noto Serif SC", serif; margin: 16px 0 4px; letter-spacing: .04em; }
  .date { color: #6E6C64; font-size: 14px; margin: 0 0 40px; }
  h2 { font-size: 17px; margin: 36px 0 8px; }
  p, li { color: #3A3933; }
  ul { padding-left: 1.2em; }
  hr { border: 0; border-top: 1px solid #E7E4DC; margin: 40px 0 0; }
</style>
</head>
<body>
<main>
<span class="seal"></span>
<h1>拍照算番 · 隐私说明</h1>
<p class="date">2026 年 10 月 26 日</p>

<p>拍照算番是一个国标麻将算番记账的小工具。没有账号、没有广告，也不追踪你。</p>

<h2>你拍的牌</h2>
<p>点「识别」时，照片会通过我们的服务器转给 Google Gemini 读出牌面，读完就把结果还给 App。我们的服务器不保存照片。Google 按 Gemini API 的条款处理这次请求。</p>
<p>和没和、几番、谁付多少，都在手机上算，不联网。</p>

<h2>为了限制次数</h2>
<p>为防止服务被滥用，每次识别会带上一个随机生成的设备编号（存在手机钥匙串里，和你的身份无关）。服务器按天统计这个编号和 IP 地址用了几次，超过上限就暂停。计数只留当天的，服务器的运行日志短期保留后自动删除。</p>

<h2>牌局记录</h2>
<ul>
<li>牌局、牌友名字和分数存在你的手机上。</li>
<li>打开 iCloud 时，会同步到你自己的 iCloud 私有空间，只有你的 Apple ID 能看到，我们看不到。</li>
<li>「发到微信群」「导出」只在你点的时候，通过系统分享面板发出去。</li>
</ul>

<h2>相机和相册</h2>
<p>只用来拍或选一张和牌照片，用于上面说的识别。</p>

<h2>联系</h2>
<p>有问题可以在 TestFlight 里截图反馈，或在 App Store 的产品页联系开发者。</p>
<hr>
</main>
</body>
</html>
`;
