# 测试照片集（仅限内部测试）

> 照片本身不在仓库里（没有可再分发的许可证），存放位置见 [data/README.md](../data/README.md)。标准答案以 [data/ground_truth.json](../data/ground_truth.json) 为准（下面表格是最初的读法，后来复核改过几张，比如 07 其实是和牌）。第一批的 01–10 在标准答案里编号 `g01`–`g10`（11–14 没参与识别测试），第二批的 01–24 编号 `w01`–`w24`（22 是台湾 16 张麻将，没参与）。两批合计 33 张测试照片。

# 第一批：GitHub 开源项目里的实拍照

收集日期：2026-10-26。这些图片都来自 GitHub 上公开的开源项目，**只能用于我们内部测试识别效果，不能放进 App、宣传材料或公开发布**。大部分仓库没有写许可证，默认版权归原作者所有。

牌面记法：m=万，p=饼/筒，s=条/索，东南西北中发白直接写字。下面"我读到的牌"是我人工看图读出来的，可以当作初步答案，正式用来打分前最好再核对一遍。

| 文件 | 内容 | 我读到的牌 | 是否和牌 | 来源 |
|---|---|---|---|---|
| 01_实拍_14张_清一色和牌.jpg | 自动麻将桌红色桌布，俯拍一排 14 张 | 1p1p1p 2p2p 3p3p 4p4p 5p5p 6p6p 7p | **和牌**：1p对 + 123p 234p 456p 567p，清一色 | [xingfanxia/mahjong_hand_detection](https://github.com/xingfanxia/mahjong_hand_detection/tree/main/test_real_images)（IMG_2781，无许可证） |
| 02_实拍_14张_未和.jpg | 同上桌面，乱序 | 3s 3m 8p 5s 3s 7s 南 4m 5s 2m 发 3m 9m 9m | 未和（乱序摆的测试牌） | 同上 IMG_2778 |
| 03_实拍_14张_未和.jpg | 同上 | 北北 2p 3p 5p 6p 7p 3m 4m 4m 5m 5m 6m 9p | 未和 | 同上 IMG_2780 |
| 04_实拍_13张_听牌.jpg | 同上，牌是浅绿底 | 1s 2s 3s 6s 7s 8s 5m 7m 白白 3p 4p 5p | 13 张，听 6m（嵌张） | 同上 IMG_2783 |
| 05_实拍_13张.jpg | 同上，牌有倾斜 | 1m1m 2m2m 3m 6m6m 7p 8p 9p 4s 5s 7s（第 8 张是 7p 还是 6p 不太确定） | 未和 | 同上 IMG_2786 |
| 06_实拍_13张.jpg | 同上 | 1m1m 1p 3p 3p 7p 7p 4s 4s 5s 南南 5p | 未和 | 同上 IMG_2788 |
| 07_实拍_14张_手牌特写.jpg | 很宽的手牌特写，牌挨得近 | 2p 3p 2p 2m 3m 4m 1p 1p 5p 1s 2s 3s 3p 5p | 和牌（复核后：123p 123p 234m 123s 55p，最初误判为未和） | 同上 flask_app/static/uploads/IMG_2649 |
| 08_实拍_13张_自动麻将桌杂乱背景.jpg | 绿桌布，竖着摆，旁边有乱牌和麻将机收纳槽，**最接近真实牌局** | 发发发 9s 8s 7s 6s 2s 北北 1p 2p 3p | 未和 | [mmdtoycar/mahjong-omakase](https://github.com/mmdtoycar/mahjong-omakase/blob/main/ml/tests/test_hand.jpg)（GPL-3.0） |
| 09_实拍_14张_红桌布两排.jpg | 红色桌布，两排摆，光线很好 | 上排 2s 2s 3s 5s 6s 7s 8s；下排 3m 5m 8m 8m 8p 9p 9p | 未和 | [LYiHub/AR-Mahjong-Assistant-preview](https://github.com/LYiHub/AR-Mahjong-Assistant-preview/tree/main/server)（无许可证） |
| 10_渲染图_14张_文件名即答案.png | 3D 渲染，不是实拍 | 3m4m6m7m 2p3p5p6p 5s5s7s8s 东东（原文件名 3467m2356d5578s11z） | 未和 | 同上 |
| 11_视频截图_带识别框_13张加箭牌.jpg | 牌局视频截图，原作者的识别框已经画在图上 | 1s1s 4s5s6s 4m5m6m7m8m9m 2p3p；上方另有 白白发发中中 | 未和 | [DrCheeseFace/mahjonging](https://github.com/DrCheeseFace/mahjonging)（看 LICENSE.txt） |
| 12_截图_App拍照界面_杂乱牌桌.png | 别人 App 的拍照界面截图，背景是真实牌桌，牌桌上很乱 | 框里两排饼子 | — | [alanfeiyuchang/majiang_calculator](https://github.com/alanfeiyuchang/majiang_calculator)（无许可证） |
| 13_参考_整副144张实拍.jpg | 整副牌摊开平拍，含花牌 | 一副完整的牌 | — | [mikemazzetti/mahjong-ar](https://github.com/mikemazzetti/mahjong-ar/tree/main/web/public/samples)（无许可证） |
| 14_参考_42种牌面含花牌.jpg | 42 种牌面各一张 | — | — | 同上 |

## 需要注意

- **真正"和了"的整手照片只有 01 这一张**（复核后 07 也是和牌）。 其他照片的牌大多是为了测识别随手摆的，没有和牌。不过它们照样可以测"认牌准不准"。算番还是要靠后面造的和牌，或者你自己拍的照片。
- 01–07 来自同一个人、同一张桌子、同一部 iPhone，场景很单一。
- 没有一张是"打完一局、手牌推倒、旁边还有吃碰杠副露"那种真实场面。这个缺口只能你自己拍来补。

## 为什么没去小红书、微博、百度图片找

我这边的云环境网络只放行 GitHub，小红书、微博、贴吧、知乎、Wikimedia、Flickr、Kaggle、HuggingFace、Roboflow 都连不上，下载不了图片。如果你想让我去这些网站找，可以在项目设置里给云环境加白名单（见回复里的链接）。另外小红书这类平台的图片大多是个人发的，版权上只适合自己看看、测一测。

## 顺便找到的

- [guobiao-fan-cases_mahjong-omakase.json](../data/guobiao-fan-cases_mahjong-omakase.json)：64 条国标番种的文字测试用例（每条是一手牌加它应有的番种），来自 mahjong-omakase（GPL-3.0），可以直接拿来测算番引擎。
- [alanfeiyuchang/majiang_calculator](https://github.com/alanfeiyuchang/majiang_calculator) 是一个已经做出来的 iOS App：用设备端模型拍照识牌，支持国标麻将算番，可以当作竞品参考。

---

# 第二批：网上的胡牌照片（24 张）

收集日期：2026-10-26，用你 Mac 的网络从 Wikimedia Commons、Flickr 和中文维基找来的。每张图的原图链接、来源页面、许可证、读到的牌面和备注都写在 [data/test-photos/web-sources.csv](../data/test-photos/web-sources.csv) 里（m=万，p=饼，s=条）。许可证：Commons 上的是 CC BY / BY-SA，Flickr 上的是 CC BY-NC-SA 或 BY-ND，内部测试可以用，不能放进 App 里。

| 编号 | 内容 | 是否胡牌 |
|---|---|---|
| 01 | 十三幺，绿色牌桌，桌上有乱牌，胡的那张放在上面 | 是 |
| 02 | 13 张万子排成一排（标题叫 "Mahjong ron"），胡的那张不在这排里 | 不确定 |
| 03–06 | 同一手碰碰和：555s 东东东(东) 999p 111m 44p，分别是暗杠（一张扣着）、明杠和不开杠，**近似重复** | 是 |
| 07 | 十三幺，两排摆，花桌布 | 是 |
| 08 | 一个人双手举着 14 张牌，牌比较小 | 是 |
| 09 | 清一色条子 + 3 张花牌，两排斜拍 | 是 |
| 10 | 清一色饼子，黑桌面斜拍，最右边一张被画面切掉一点 | 是 |
| 11–21 | 中文维基番种条目的配图：大三元、大四喜、对对胡、混幺九、混一色、清幺九、清一色、十八罗汉、小三元、小四喜、一条龙。**只有约 420×60 像素**，个别条子数字看不清 | 是 |
| 22 | 台湾 16 张麻将的胡牌（17 张，带 5 张花），不是国标 | 不确定 |
| 23 | 九莲宝灯的 13 张听牌，没有第 14 张 | 否（反例） |
| 24 | 十三幺 13 面听，没有对子 | 否（反例） |

**确认胡牌的一共 20 张**，但真正不重复、而且清晰的只有大约 6 手（01、03–06 算一手、07、08、09、10）。

还缺的：吃碰杠副露摆在手牌旁边的真实场面、国标比赛或直播截图。百度图片拦截了脚本访问，知乎、搜狐也还没去找。
