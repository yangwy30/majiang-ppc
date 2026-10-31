// /support：App Store 产品页的「App 支持」链接。常见问题和联系方式。
// 样式跟 /privacy 一样。

export const SUPPORT_HTML = `<!doctype html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>拍照算番 · 帮助</title>
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
  a { color: #C23B22; }
  hr { border: 0; border-top: 1px solid #E7E4DC; margin: 40px 0 0; }
</style>
</head>
<body>
<main>
<span class="seal"></span>
<h1>拍照算番 · 帮助</h1>
<p class="date">国标麻将算番记账</p>

<h2>怎么用</h2>
<p>首页点「开一局」，填四个人的名字。有人和了就点「有人和了」，对着牌拍一张，确认牌面后就出番数和这一局谁付多少。打完点「结算」，看最少几笔转账就能结清。</p>

<h2>AI 认牌要邀请码吗</h2>
<p>AI 认牌现在是邀请制，填了邀请码才用。没有邀请码也能正常用：手机上的离线认牌照样能认，认不准的牌点一下就能改，也可以点「手动输入」自己选牌。</p>

<h2>认错了怎么办</h2>
<p>确认页上点那张牌，换成对的就行。看不清的牌会给两个候选，标出哪张能和。</p>

<h2>记错了一局</h2>
<p>在牌局里点那一局就能改，后面每一局的分数会跟着重算。</p>

<h2>换手机</h2>
<p>打开 iCloud 同步的话，换手机后用同一个 Apple ID 登录就会回来。也可以在首页「备份与换手机」导出文件，在新手机上导入。</p>

<h2>隐私</h2>
<p>不用注册、没有广告。详见<a href="/privacy">隐私说明</a>。</p>

<h2>联系</h2>
<p>有问题或建议，可以在 <a href="https://github.com/yangwy30/majiang-ppc/issues">GitHub</a> 上留言。</p>
<hr>
</main>
</body>
</html>
`;
