# iOS App（v0.2）

```
app/
  Majiang.xcodeproj   Xcode 工程（需要 Xcode 16 或更新；源码目录自动同步，加文件不用改工程）
  MajiangApp/         SwiftUI 界面，iOS 17+
  MajiangKit/         纯逻辑的 Swift 包：牌、算番、牌局账本、识别。能在 Linux 上编译和跑测试
```

## 怎么跑

- **App**：用 Xcode 打开 `app/Majiang.xcodeproj`，选一个 iPhone 模拟器运行。真机要在 Signing 里选自己的开发者 Team。
  第一次打开默认是「演示数据」识别，不看照片，按顺序给出三手示例牌（清一色带一张待确认的牌、带碰和暗杠的混一色、认错一张不成和的花龙），可以把整条流程走通。
- **用 Gemini 认牌**：开发版长按首页的「国标记分」标题打开设置 → 填 Gemini API Key（只存在手机钥匙串里）→ 识别方式选 Gemini。正式版没有设置页。
- **截图**：开发版启动参数 `-demo-screen <页面>` 用临时假数据直接停在某一页，见 [用户流程设计](../docs/user-flow.md#截图怎么更新)。
- **测试**：`cd app/MajiangKit && swift test`（Mac 或 Linux 都行）。

## 结构

| 部分 | 内容 |
|---|---|
| `MajiangKit/Sources/CGuobiao` | 国标算番。直接用 [ChineseOfficialMahjongHelper](https://github.com/summerinsects/ChineseOfficialMahjongHelper) 的 C++ 算法（MIT，版权声明见 `vendor/LICENSE`，上架时要在 App 的「致谢」里列出），外面包一层 C 接口 |
| `MajiangKit/Sources/MajiangKit/Tiles` | 牌、副露、手牌，牌的记法解析（`123m456p东东`、`5饼`、`五万`） |
| `MajiangKit/Sources/MajiangKit/Scoring` | `FanCalculator` 算番（81 番 + 明暗杠，花牌单独计、不计入起和），`WinAssistant` 不成和时给改牌建议，`SpecialWin` 特殊情况的置灰规则 |
| `MajiangKit/Sources/MajiangKit/Game` | 牌局：圈风、门风、庄家自动轮转（不连庄，可选每圈换座），自摸/点炮收付，荒庄，错和，手动记分，最少转账，JSON 存档 |
| `MajiangKit/Sources/MajiangKit/Recognition` | `TileRecognizer` 协议和几种实现，见下 |
| `MajiangApp` | [用户流程 v0.2](../docs/user-flow.md) 的页面：首页、开局、牌桌（也是账本）、拍照（内嵌取景器）、核对、结果（弹出层）、结算，加规则说明、直接改分和开发版设置。视觉规范「墨与朱」在 `Support/Theme.swift` |

### 识别

界面只认 `TileRecognizer` 协议，识别方式可以随时换：

- `GeminiRecognizer`：研究里效果最好的方法，附牌面参考图 + 要求逐张数点数（Flash，33 张里 32 张全对）。模型只负责读牌，和没和、几番由规则引擎决定。
- `RuleCheckedRecognizer`：读出的牌凑不成和牌时，带着原因让模型再看一次。
- `DualReadRecognizer`：端侧模型和 Gemini 同时跑，不一致的牌标出来让用户选；`RecognitionResolver` 在候选里挑出能和的组合，标成「这张才能和」。
- `OnDeviceRecognizer`：占位。将来用自己训练的模型（Jon Chan Roboflow 数据集，CC BY 4.0）接在这里。**不能用竞品的 ONNX 权重和 Ultralytics（AGPL）代码。**
- `MockRecognizer`：演示数据。

### API Key 和后端代理

- Key **不进代码、不进仓库**。开发阶段在 App 设置里填，存钥匙串，请求时放在 `x-goog-api-key` 请求头里（不放在 URL 上）。
- 上架前要加一个很小的后端代理：App 把请求体原样 POST 到代理（带 `X-Majiang-Model` 头指明模型），代理加上 Key 转发到 `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`，再把回答原样返回。代理还应该做用户鉴权和限流。在设置里填代理地址后 App 就走代理。

## 还没做 / 待验证

- 给 Gemini 的参考图改成了 App 自己画的扁平牌面（研究用的参考图没有许可证，不能打包），提示词也改成了分开读立牌和副露。这两处对准确率的影响要用测试照片重新跑一次。
- 端侧模型没有接入，双读目前只有 Gemini 一路。
- 拍照页的实时检查（牌数、光线、对焦）还没做，取景器里只有一句提示。
- 账本只能撤销刚记下的一局，更早的局不能点进去改。
- 没有 App 图标。
