# 开源麻将牌图片数据集调研（2026-10-26）

> 后续：我们自己收集的 33 张测试照片见 [test-photos.md](test-photos.md)。

## 结论

- **有开源的麻将牌图片数据集，但没有"真实牌桌上一整手和牌照片 + 标好番数"的数据集。** 现有的数据集都是为训练"识别单张牌"准备的，标注只到每张牌是什么，不包含和牌、番数。
- 所以测"算番"的正确答案，得用**文本形式的牌局数据**（Botzone 国标麻将对局记录）或我们自己拿 ChineseOfficialMahjongHelper 算出来；测"拍照识别"，最可靠的还是**你自己在真实牌桌上拍 10–20 张**。
- 公开数据集适合在你拍照之前先做一轮**粗测**：看多模态大模型能不能认出各种牌面、光线和角度下的单张牌。

## 图片数据集（识别用）

| 数据集 | 规模 | 牌种 | 许可证 | 照片风格 | 是否适合国标 |
|---|---|---|---|---|---|
| [Roman Nguyen / Mahjong（Roboflow）](https://universe.roboflow.com/roman-nguyen/mahjong-vtacs) | 约 4,378 张，有检测框 | 34 类（万/条/饼 + 风 + 箭），**没有花牌** | MIT | 拍摄的牌面照片（页面没写具体场景，需下载后确认） | 最大、许可最宽松，**首选用来粗测**。国标花牌缺失 |
| [Jon Chan / Mahjong（Roboflow）](https://universe.roboflow.com/jon-chan-gnsoa/mahjong-baq4s) | 页面未写数量 | 含 1B/1C/1D/1F 等类，像是包含花牌 | CC BY 4.0（需署名） | 有标注的照片；被开源项目 AR-Mahjong-Assistant 用来训练 YOLOv8 | 可以作为补充 |
| [leaf / Mahjong-Tile-Detection（Roboflow）](https://universe.roboflow.com/leaf-amkz3/mahjong-tile-detection-e629n) | 85 张 | 34 类（1m/1p/1s/1z 记法） | CC BY 4.0 | 牌面照片 | 太小，仅作补充 |
| [SG-mahjong（Roboflow）](https://universe.roboflow.com/mahjong-uko7s/sg-mahjong) | 57 张 | 44 种牌 + 新加坡麻将的动物牌 | CC BY 4.0 | 看文件名像是 WhatsApp 发的手机随手拍 | 太小；场景最接近真实牌桌 |
| 其他 Roboflow 项目（[mahjong-tiles-universal](https://universe.roboflow.com/test-ag8z6/mahjong-tiles-universal)、[mahjong-tiles](https://universe.roboflow.com/test-upsgd/mahjong-tiles-oc9zz)、[MJ](https://universe.roboflow.com/max-cys5n/mj-rvb0c)、[Mahjong 2: Hand analyser](https://universe.roboflow.com/laura-junga-gmail-com/mahjong-2:-hand-analyser) 等） | 多数页面没写数量 | 不一 | 多为 CC BY 4.0 | 页面没写 | 质量参差，大多是个人练手项目 |
| [Camerash/mahjong-dataset（GitHub）](https://github.com/Camerash/mahjong-dataset) | 628 张单牌切图（240×320）+ 1,050 张未标注切图 + 25 张原图 | **42 类，含 8 张花牌**，完整国标牌种 | MIT（但图片是作者从 Google/eBay/阿里巴巴抓的，版权并不干净，只适合内部测试） | 我下载看过：**正面平拍的商品图**，整齐排列、光线均匀，**不是牌桌实拍** | 牌种最全，但太"干净"，测不出真实场景的难度 |
| [HaseLab/mahjong-models（HuggingFace）](https://huggingface.co/HaseLab/mahjong-models) | 只有模型，没有公开数据 | 日麻 38 类（含赤五） | 未注明 | 整桌照片（手牌/牌河/副露区域分割） | 日麻，牌面和国标常用牌不同，仅作参考 |
| [Kaggle mexwell/mahjong](https://www.kaggle.com/datasets/mexwell/mahjong/data) | — | — | — | 看描述就是 Camerash 数据集的转载 | 同上 |

## 算番用的数据（不是图片，但有标准答案）

- [Dannibal/ijcai-mahjong-round2（HuggingFace）](https://huggingface.co/datasets/Dannibal/ijcai-mahjong-round2)：IJCAI 国标麻将 AI 比赛在 Botzone 上的约 44,400 局对局 JSON，CC BY 4.0。对局记录里有和牌时的手牌和裁判程序给出的番种，可以批量用来验证我们的算番引擎。注意这是 AI 之间的对局，不是人类对局。
- [Botzone 比赛页](https://botzone.org.cn/static/gamecontest2024a.html) 也提供了强 AI 的对局数据下载（北大网盘）。
- [ailab-pku/Chinese-Standard-Mahjong](https://github.com/ailab-pku/Chinese-Standard-Mahjong)：Botzone 官方的国标规则、裁判程序和算番库用法，可以当成"标准答案生成器"。

## 怎么下载样本

- **Roboflow**：注册一个免费账号，打开数据集页面，点 Download Dataset，选 YOLOv8 或 COCO 格式，就能拿到 zip（图片 + 标注）。我这边的云环境连不上 Roboflow，所以这几个数据集的图片我没能亲眼检查。
- **Camerash**：`git clone https://github.com/Camerash/mahjong-dataset.git`（约 123 MB），解压 `train.zip` 就有 `images/` 和 `data.csv`。我已经下载检查过。
- **Botzone 对局数据**：在 HuggingFace 页面下载 `finalist_games.tar.gz`。

## 建议的测试方案

1. 从 Roman Nguyen 数据集里挑 50 张多牌照片，加上 Camerash 的几张原图，先测多模态模型认牌的准确率（单张牌的准确率）。
2. 用 Botzone 对局数据里的和牌记录，批量对比我们的算番结果和裁判程序的结果。
3. 真实牌桌、整手和牌的照片网上没有现成的，还是需要你拍 10–20 张，这才是最终决定可行性的测试。
