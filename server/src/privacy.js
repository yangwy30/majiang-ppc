// /privacy：App 的隐私说明。TestFlight 和 App Store 都要一个能公开打开的地址。
// 改了 App 收集或发送的东西，这里要跟着改，四种语言都要改（繁体可以用 OpenCC s2twp 从简体转）。

import { page } from "./page.js";

const ZH_HANS = `

<p>拍照算番是一个国标麻将算番记账的小工具。没有账号、没有广告，也不追踪你。</p>

<h2>你拍的牌</h2>
<p>填了邀请码、开了 AI 认牌时，拍完的照片会通过我们的服务器转给 Google Gemini 读出牌面，读完就把结果还给 App。我们的服务器不保存照片。Google 按 Gemini API 的条款处理这次请求。</p>
<p>AI 认错了、你又改对了的时候，结果页上会问一句要不要把照片发给我们。只有你勾上才会发：这张照片、认出来的牌和你改对的牌会存在我们的服务器上，只用来让认牌更准，不给别人看，也不和你的身份关联，180 天後自动删除。不勾就不发，照片也不会存。</p>
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
`;

const ZH_HANT = `

<p>拍照算番是一個國標麻將算番記帳的小工具。沒有帳號、沒有廣告，也不追蹤你。</p>

<h2>你拍的牌</h2>
<p>填了邀請碼、開了 AI 認牌時，拍完的照片會通過我們的伺服器轉給 Google Gemini 讀出牌面，讀完就把結果還給 App。我們的伺服器不儲存照片。Google 按 Gemini API 的條款處理這次請求。</p>
<p>AI 認錯了、你又改對了的時候，結果頁上會問一句要不要把照片發給我們。只有你勾上才會發：這張照片、認出來的牌和你改對的牌會存在我們的伺服器上，只用來讓認牌更準，不給別人看，也不和你的身份關聯，180 天後自動刪除。不勾就不發，照片也不會存。</p>
<p>和沒和、幾番、誰付多少，都在手機上算，不聯網。</p>

<h2>提意見</h2>
<p>在 App 的「更多 → 提意見」裡發給我們的，只有你寫的話、你自己填的聯絡方式（可以不填），以及 App 版本和手機型號（比如 iPhone18,1）。我們只用它來改進 App，留了聯絡方式的話用來回覆你。為防止被刷，伺服器會按裝置編號統計當天發了幾條。</p>

<h2>為了限制次數</h2>
<p>為防止服務被濫用，每次識別會帶上一個隨機生成的裝置編號（存在手機鑰匙串裡，和你的身份無關）。伺服器按天統計這個編號和 IP 位址用了幾次，超過上限就暫停。計數只留當天的，伺服器的執行日誌短期保留後自動刪除。</p>
<p>AI 認牌目前是邀請制。填了邀請碼的話，伺服器會記下這個碼綁在哪幾個裝置編號上、一共用了幾次、最近一次是什麼時候，用來防止一個碼被轉給太多人。沒有邀請碼時，App 用手機上的離線認牌，照片不出手機。</p>

<h2>牌局記錄</h2>
<ul>
<li>牌局、牌友名字和分數存在你的手機上。</li>
<li>開啟 iCloud 時，會同步到你自己的 iCloud 私有空間，只有你的 Apple ID 能看到，我們看不到。</li>
<li>「分享」「匯出」只在你點的時候，通過系統分享面板發出去。</li>
</ul>

<h2>相機和相簿</h2>
<p>只用來拍或選一張和牌照片，用於上面說的識別（以及你勾上時發給我們的認錯照片）。這張照片存在你的手機上、跟著那一局，在帳本裡點開那一局可以看，也可以刪掉。開了 iCloud 同步也不會同步照片。</p>

<h2>聯絡</h2>
<p>有問題可以在 App 的「更多 → 提意見」裡告訴我們，也可以看<a href="/support">說明</a>。</p>
`;

const EN = `
<p>拍照算番 is a small tool for scoring Chinese Official (MCR) mahjong and keeping the ledger. There are no accounts and no ads, and it doesn't track you.</p>

<h2>Photos of your tiles</h2>
<p>When you have entered an invite code and AI tile reading is on, the photo you take is passed through our server to Google Gemini, which reads the tiles and sends the result back to the app. Our server does not keep the photo. Google handles the request under the Gemini API terms.</p>
<p>If the AI misread a tile and you corrected it, the result screen asks whether to send us the photo. It is sent only if you tick the box: the photo, the tiles that were read and the tiles you corrected are stored on our server, used only to make tile reading more accurate, shown to no one else, not linked to your identity, and deleted automatically after 180 days. If you don't tick it, nothing is sent and the photo is not stored.</p>
<p>Whether a hand wins, how many fan it scores and who pays what are all worked out on your phone, without the internet.</p>

<h2>Feedback</h2>
<p>When you use “More → Send feedback” in the app, we receive only what you write, the contact details you choose to give (optional), and the app version and phone model (for example iPhone18,1). We use it only to improve the app, and to reply to you if you left contact details. To prevent abuse, the server counts how many messages each device ID sends per day.</p>

<h2>Usage limits</h2>
<p>To prevent abuse of the service, each reading carries a randomly generated device ID (stored in the phone's keychain, unrelated to your identity). The server counts per day how many readings this ID and the IP address have used, and pauses once a limit is reached. Only today's counts are kept, and the server's logs are deleted automatically after a short time.</p>
<p>AI tile reading is currently invite-only. If you enter an invite code, the server records which device IDs the code is bound to, how many times it has been used and when it was last used, to stop one code being passed around to too many people. Without an invite code, the app reads tiles on the phone, offline, and the photo never leaves the phone.</p>

<h2>Game records</h2>
<ul>
<li>Games, players' names and scores are stored on your phone.</li>
<li>With iCloud turned on, they sync to your own private iCloud space. Only your Apple ID can see them; we cannot.</li>
<li>“Share” and “Export” send things out through the system share sheet only when you tap them.</li>
</ul>

<h2>Camera and photos</h2>
<p>Used only to take or choose one photo of a winning hand, for the reading described above (and for the misread photo you choose to send us). The photo is kept on your phone with that hand; open the hand in the ledger to view or delete it. Photos are not synced, even with iCloud sync on.</p>

<h2>Contact</h2>
<p>If you have questions, tell us through “More → Send feedback” in the app, or see the <a href="/support?lang=en">help page</a>.</p>
`;

const JA = `
<p>拍照算番は、国標麻将（MCR）の点数計算と記録のための小さなツールです。アカウントも広告もなく、トラッキングもしません。</p>

<h2>撮影した牌の写真</h2>
<p>招待コードを入れて AI 読み取りを使うと、撮影した写真は私たちのサーバーを経由して Google Gemini に送られ、牌を読み取った結果がアプリに返されます。私たちのサーバーは写真を保存しません。Google は Gemini API の規約に沿ってこのリクエストを処理します。</p>
<p>AI が牌を読み違え、あなたがそれを直したときは、結果画面で写真を送ってよいか確認します。チェックを入れた場合だけ送られます。その写真、読み取った牌、あなたが直した牌は私たちのサーバーに保存され、読み取りの精度を上げるためだけに使われます。他人には見せず、あなたの身元とも結び付けず、180 日後に自動で削除します。チェックを入れなければ何も送られず、写真も保存されません。</p>
<p>和了かどうか、何番か、誰がいくら払うかは、すべて端末内で計算し、通信はしません。</p>

<h2>ご意見</h2>
<p>アプリの「その他 → ご意見」から送られるのは、あなたが書いた内容、任意で入れた連絡先、アプリのバージョンと機種名（例：iPhone18,1）だけです。アプリの改善にのみ使い、連絡先があれば返信に使います。いたずら防止のため、サーバーは端末 ID ごとに 1 日の送信数を数えます。</p>

<h2>回数の制限について</h2>
<p>サービスの濫用を防ぐため、読み取りのたびにランダムに作られた端末 ID（端末のキーチェーンに保存、あなたの身元とは無関係）を付けて送ります。サーバーはこの ID と IP アドレスごとに 1 日の利用回数を数え、上限を超えると一時停止します。回数は当日の分だけ残し、サーバーのログも短期間で自動削除します。</p>
<p>AI 読み取りはいまのところ招待制です。招待コードを入れると、サーバーはそのコードがどの端末 ID に紐付いているか、何回使われたか、最後に使われたのはいつかを記録します。1 つのコードが多くの人に回されるのを防ぐためです。招待コードがない場合は端末内（オフライン）で読み取り、写真は端末の外に出ません。</p>

<h2>対局の記録</h2>
<ul>
<li>対局、プレイヤー名、点数はあなたの端末に保存されます。</li>
<li>iCloud をオンにすると、あなた自身の iCloud のプライベート領域に同期されます。見られるのはあなたの Apple ID だけで、私たちには見えません。</li>
<li>「共有」「書き出し」は、あなたがタップしたときだけ、システムの共有シートから送られます。</li>
</ul>

<h2>カメラと写真</h2>
<p>和了した手牌の写真を 1 枚撮るか選ぶためだけに使い、上記の読み取り（と、あなたが送ることを選んだ読み違いの写真）に使います。写真はその局と一緒に端末に保存され、スコア表でその局を開くと見たり削除したりできます。iCloud 同期をオンにしても写真は同期されません。</p>

<h2>お問い合わせ</h2>
<p>ご質問はアプリの「その他 → ご意見」からお寄せいただくか、<a href="/support?lang=ja">ヘルプ</a>をご覧ください。</p>
`;

export const PRIVACY_PAGES = {
  "zh-Hans": page("zh-Hans", "拍照算番 · 隐私说明", "2026 年 11 月 6 日", ZH_HANS),
  "zh-Hant": page("zh-Hant", "拍照算番 · 隱私說明", "2026 年 11 月 6 日", ZH_HANT),
  en: page("en", "拍照算番 · Privacy", "6 November 2026", EN),
  ja: page("ja", "拍照算番 · プライバシー", "2026 年 11 月 6 日", JA),
};
