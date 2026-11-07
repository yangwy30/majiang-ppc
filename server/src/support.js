// /support：App Store 产品页的「App 支持」链接。常见问题和联系方式。
// 按浏览器语言给简体、繁体、英文、日文（?lang= 可以指定），说法跟 App 里的按钮一致。

import { page } from "./page.js";

const ZH_HANS = `
<h2>怎么用</h2>
<p>首页点「开一局」，填四个人的名字。有人和了就点「有人和了」，对着牌拍一张，核对牌面后就出番数和这一局谁付多少。打满 16 局自动结算；提前散场就在牌桌右上角「更多」里点「结束牌局」，看最少几笔转账就能结清。</p>

<h2>AI 认牌要邀请码吗</h2>
<p>AI 认牌现在是邀请制，在首页右上角「更多」里点「AI 认牌」，填 6 位邀请码。没有邀请码也能正常用：手机上的离线认牌照样能认，认不准的牌点一下就能改，也可以点「手动输入」自己选牌。</p>

<h2>认错了怎么办</h2>
<p>核对页上点那张牌，换成对的就行。看不清的牌会给两个候选，标出哪张能和。</p>

<h2>记错了一局</h2>
<p>在牌桌下面的账本里点那一局，能看那把是怎么和的，也能改，后面每一局的分数会跟着重算。</p>

<h2>换手机</h2>
<p>打开 iCloud 同步的话，换手机后用同一个 Apple ID 登录就会回来。也可以在首页右上角「更多」里点「备份与换手机」导出文件，在新手机上导入。</p>

<h2>隐私</h2>
<p>不用注册、没有广告。详见<a href="/privacy">隐私说明</a>。</p>

<h2>联系</h2>
<p>有问题或建议，在 App 首页右上角「更多」里点「提意见」，写几句就能发给我们，想要回复的话留个微信号或邮箱。也可以在 <a href="https://github.com/yangwy30/majiang-ppc/issues">GitHub</a> 上留言。</p>
`;

const ZH_HANT = `
<h2>怎麼用</h2>
<p>首頁點「開一局」，填四個人的名字。有人和了就點「有人和了」，對著牌拍一張，核對牌面後就出番數和這一局誰付多少。打滿 16 局自動結算；提前散場就在牌桌右上角「更多」裡點「結束牌局」，看最少幾筆轉帳就能結清。</p>

<h2>AI 認牌要邀請碼嗎</h2>
<p>AI 認牌現在是邀請制，在首頁右上角「更多」裡點「AI 認牌」，填 6 位邀請碼。沒有邀請碼也能正常用：手機上的離線認牌照樣能認，認不準的牌點一下就能改，也可以點「手動輸入」自己選牌。</p>

<h2>認錯了怎麼辦</h2>
<p>核對頁上點那張牌，換成對的就行。看不清的牌會給兩個候選，標出哪張能和。</p>

<h2>記錯了一局</h2>
<p>在牌桌下面的帳本裡點那一局，能看那把是怎麼和的，也能改，後面每一局的分數會跟著重算。</p>

<h2>換手機</h2>
<p>開啟 iCloud 同步的話，換手機後用同一個 Apple ID 登入就會回來。也可以在首頁右上角「更多」裡點「備份與換手機」匯出檔案，在新手機上匯入。</p>

<h2>隱私</h2>
<p>不用註冊、沒有廣告。詳見<a href="/privacy">隱私說明</a>。</p>

<h2>聯絡</h2>
<p>有問題或建議，在 App 首頁右上角「更多」裡點「提意見」，寫幾句就能發給我們，想要回覆的話留個微信號或Email。也可以在 <a href="https://github.com/yangwy30/majiang-ppc/issues">GitHub</a> 上留言。</p>
`;

const EN = `
<h2>How to use it</h2>
<p>On the home screen tap “New game” and enter the four players’ names. When someone wins, tap “Someone won”, take a photo of the winning hand and check the tiles. The app shows the fan count and who pays what for that hand. A game settles automatically after 16 hands. To stop early, tap “More” at the top right of the table, then “End game”, and you’ll see the fewest transfers that settle everyone up.</p>
<p>Scoring follows Chinese Official (Guobiao) rules, also known as Mahjong Competition Rules (MCR).</p>

<h2>Does AI tile reading need an invite code?</h2>
<p>AI tile reading is invite-only for now. On the home screen tap “More” at the top right, then “AI tile reading”, and enter a 6-character invite code. The app works fine without one: photos are still read on the phone, offline, any misread tile can be fixed with a tap, and you can tap “Enter by hand” to pick the tiles yourself.</p>

<h2>A tile was misread</h2>
<p>On the check screen, tap the tile and swap it for the right one. If a tile is unclear, the app offers two candidates and marks which one completes the hand.</p>

<h2>A hand was recorded wrong</h2>
<p>Tap that hand in the ledger below the table. You can see how it was won and edit it, and every later hand is rescored.</p>

<h2>Moving to a new phone</h2>
<p>With iCloud sync on, sign in with the same Apple ID on the new phone and your games come back. You can also tap “More” at the top right of the home screen, then “Backup &amp; new phone”, to export a file and import it on the new phone.</p>

<h2>Privacy</h2>
<p>No sign-up and no ads. See the <a href="/privacy?lang=en">privacy policy</a>.</p>

<h2>Contact</h2>
<p>For questions or suggestions, tap “More” at the top right of the home screen, then “Send feedback”, and write us a few lines. Leave an email address if you’d like a reply. You can also open an issue on <a href="https://github.com/yangwy30/majiang-ppc/issues">GitHub</a>.</p>
`;

const JA = `
<h2>使い方</h2>
<p>ホームで「対局を始める」をタップし、4 人の名前を入れます。誰かが和了したら「和了」をタップして手牌を撮影し、牌を確認すると、番数とその局の支払いが出ます。16 局を打ち終えると自動で精算します。途中でやめるときは、卓の右上「その他」から「対局を終了」をタップすると、いちばん少ない精算方法が表示されます。</p>
<p>点数計算は中国麻将の国標ルール（MCR）に沿っています。</p>

<h2>AI 読み取りに招待コードは必要？</h2>
<p>AI 読み取りはいまのところ招待制です。ホーム右上の「その他」から「AI 読み取り」をタップし、6 桁の招待コードを入れてください。コードがなくても普通に使えます。写真は端末内（オフライン）で読み取り、読み違えた牌はタップで直せます。「手入力」で自分で牌を選ぶこともできます。</p>

<h2>牌を読み違えたとき</h2>
<p>確認画面でその牌をタップし、正しい牌に替えてください。はっきりしない牌には候補が 2 つ出て、どちらで和了になるかが示されます。</p>

<h2>局の記録を間違えたとき</h2>
<p>卓の下のスコア表でその局をタップすると、どう和了したかを見たり直したりでき、それ以降の局の点数も計算し直されます。</p>

<h2>機種変更</h2>
<p>iCloud 同期をオンにしていれば、新しい端末で同じ Apple ID にサインインすると対局が戻ってきます。ホーム右上の「その他」から「バックアップと機種変更」でファイルを書き出し、新しい端末で読み込むこともできます。</p>

<h2>プライバシー</h2>
<p>登録不要、広告なし。詳しくは<a href="/privacy?lang=ja">プライバシーポリシー</a>をご覧ください。</p>

<h2>お問い合わせ</h2>
<p>ご質問やご要望は、アプリのホーム右上「その他」から「ご意見」をタップして、ひと言お送りください。返信をご希望ならメールアドレスを添えてください。<a href="https://github.com/yangwy30/majiang-ppc/issues">GitHub</a> でも受け付けています。</p>
`;

export const SUPPORT_PAGES = {
  "zh-Hans": page("zh-Hans", "拍照算番 · 帮助", "国标麻将算番记账", ZH_HANS),
  "zh-Hant": page("zh-Hant", "拍照算番 · 說明", "國標麻將算番記帳", ZH_HANT),
  en: page("en", "拍照算番 · Help", "Score Chinese Official (MCR) mahjong from a photo", EN),
  ja: page("ja", "拍照算番 · ヘルプ", "国標麻将の点数計算と記録", JA),
};
