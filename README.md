# majiang-ppc

国标麻将拍照算番 + 记账 iOS App（Guobiao mahjong photo scoring + ledger iOS app）。

## 想法

打完一局国标麻将，对着和牌的牌型拍一张照片，App 自动识别手牌，算出番种和番数，并把这一局的输赢记入牌局账本，多局自动累计。

## 核心流程

1. **拍照**：拍下和牌者的手牌（含已吃碰杠的副露）。
2. **识别**：视觉模型识别每张牌（34 种牌 + 8 张花牌）。
3. **确认 / 修正**：用户一键修正识别错的牌。
4. **补充信息**：照片看不出的信息，如自摸还是点炮、和的是哪张、门风圈风、花牌数量等。
5. **算番**：按国标 81 番规则计算番种与总番数。
6. **记账**：记录每局得分，按玩家累计，整场结束出结算。

## 文档索引

**产品**

- [可行性评估](docs/feasibility.md)：结论、技术路线、MVP 范围和工期
- [用户流程设计](docs/user-flow.md)：完整流程图、每个页面的截图、视觉风格和牌面风格

**调研**（总览和关键结论见 [research/README.md](research/README.md)）

- [开源数据集调研](research/datasets.md)
- [测试照片集](research/test-photos.md)
- [Gemini 识牌测试与改进方法对比](research/gemini-recognition.md)
- [竞品离线认牌模型评测 + 端侧/Gemini 双读模拟](research/competitor-offline-model.md)
- [国标规则与算番引擎](research/guobiao-rules.md)

## 仓库结构

```
docs/       产品文档：可行性评估、用户流程；assets/user-flow/ 是页面截图和设计源文件
research/   调研报告；results/ 是测试的原始 JSON
tools/      调研用的测试脚本（Gemini 识牌、竞品模型、双读模拟）和页面截图导出脚本，见 tools/README.md
data/       标准答案、照片来源表、番种测试用例，见 data/README.md
app/        iOS App：Xcode 工程、SwiftUI 界面、MajiangKit 逻辑包，见 app/README.md
```

测试照片、牌面参考图和竞品模型权重**没有可再分发的许可证，不进仓库**，存放位置见 [data/README.md](data/README.md)。API Key 也不进仓库。

## 状态

调研阶段已完成（2026-10-26）：认牌路线定为 Gemini Flash + 端侧模型双读 + 规则校验 + 用户核对，用户流程 v0.1 已出。

App v0.1 开始编码（2026-10-26）：算番引擎、牌局账本、识别接口和 10 个页面已写，见 [app/README.md](app/README.md)。下一步是在 Mac 上编译跑通，再用真实牌桌照片验证识别效果。
