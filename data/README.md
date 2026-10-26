# 测试数据

这里只放**文本形式**的数据：标准答案、图片来源、算番测试用例。照片本身不进仓库，原因见下面「照片在哪」。

| 文件 | 内容 | 来源 / 许可证 |
|---|---|---|
| [ground_truth.json](ground_truth.json) | 33 张测试照片的标准答案：每张的牌面（m=万 p=饼 s=条，字牌写汉字）和是否和牌。`g01`–`g10` 是 GitHub 那批，`w01`–`w24`（缺 w22）是网上胡牌照片那批 | 我们自己标的（Claude 看图读出，2026-10-26 放大复核过，未经人工核对） |
| [test-photos/web-sources.csv](test-photos/web-sources.csv) | 网上胡牌照片（`w01`–`w24`）每张的原图链接、来源页面、许可证、读到的牌面和备注 | 照片来自 Wikimedia Commons（CC BY / BY-SA）和 Flickr（CC BY-NC-SA / BY-ND） |
| [guobiao-fan-cases_mahjong-omakase.json](guobiao-fan-cases_mahjong-omakase.json) | 64 条国标番种测试用例，每条是一手牌和它应有的番种，以后用来测算番引擎 | [mmdtoycar/mahjong-omakase](https://github.com/mmdtoycar/mahjong-omakase)，GPL-3.0。只用于测试，不要打包进 App |

各张照片的内容和来源说明见 [research/test-photos.md](../research/test-photos.md)。

## 照片在哪

照片没有可以再分发的许可证（GitHub 那批多数仓库没写许可证，Flickr 的是 NC/ND），所以只放在本地和项目文件夹里，**不要提交到仓库**（`.gitignore` 已经挡住了 `data/` 和 `tools/` 下的图片）。

- Yang 的 Mac：`~/Downloads/majiang-test-photos/`，GitHub 那批在 `github/` 子文件夹，网上那批直接是 `01.jpg`–`24.jpg`。这就是 `ground_truth.json` 里 `file` 字段对应的目录结构，脚本默认从这里读（可用环境变量 `MAJIANG_PHOTOS` 改）。
- 项目文件夹：`test-photos/`（GitHub 那批）和 `test-photos/web-胡牌照片/`（网上那批）。

## 标记约定

- 杠写 4 张（扣着的那张也算）。花牌不列。
- `win: null` 表示不判这张的胡没胡；`uncertain: true` 表示标准答案本身不确定。
