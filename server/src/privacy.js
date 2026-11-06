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
<p class="date">2026 年 11 月 6 日</p>

<p>拍照算番是一个国标麻将算番记账的小工具。没有账号、没有广告，也不追踪你。</p>

<h2>你拍的牌</h2>
<p>填了邀请码、开了 AI 认牌时，拍完的照片会通过我们的服务器转给 Google Gemini 读出牌面，读完就把结果还给 App。我们的服务器不保存照片。Google 按 Gemini API 的条款处理这次请求。</p>
<p>AI 认错了、你又改对了的时候，结果页上会问一句要不要把照片发给我们。只有你勾上才会发：这张照片、认出来的牌和你改对的牌会存在我们的服务器上，只用来让认牌更准，不给别人看，也不和你的身份关联，180 天后自动删除。不勾就不发，照片也不会存。</p>
<p>和没和、几番、谁付多少，都在手机上算，不联网。</p>

<h2>提意见</h2>
<p>在 App 的「更多 → 提意见」里发给我们的，只有你写的话、你自己填的联系方式（可以不填），以及 App 版本和手机型号（比如 iPhone18,1）。我们只用它来改进 App，留了联系方式的话用来回复你。为防止被刷，服务器会按设备编号统计当天发了几条。</p>

<h2>为了限制次数</h2>
<p>为防止服务被滥用，每次识别会带上一个随机生成的设备编号（存在手机钥匙串里，和你的身份无关）。服务器按天统计这个编号和 IP 地址用了几次，超过上限就暂停。计数只留当天的，服务器的运行日志短期保留后自动删除。</p>
<p>AI 认牌目前是邀请制。填了邀请码的话，服务器会记下这个码绑在哪几个设备编号上、一共用了几次、最近一次是什么时候，用来防止一个码被转给太多人。没有邀请码时，App 用手机上的离线认牌，照片不出手机。</p>

<h2>牌局记录</h2>
<ul>
<li>牌局、牌友名字和分数存在你的手机上。</li>
<li>打开 iCloud 时，会同步到你自己的 iCloud 私有空间，只有你的 Apple ID 能看到，我们看不到。</li>
<li>「分享」「导出」只在你点的时候，通过系统分享面板发出去。</li>
</ul>

<h2>相机和相册</h2>
<p>只用来拍或选一张和牌照片，用于上面说的识别（以及你勾上时发给我们的认错照片）。这张照片存在你的手机上、跟着那一局，在账本里点开那一局可以看，也可以删掉。开了 iCloud 同步也不会同步照片。</p>

<h2>联系</h2>
<p>有问题可以在 App 的「更多 → 提意见」里告诉我们，也可以看<a href="/support">帮助</a>。</p>
<hr>
</main>
</body>
</html>
`;
