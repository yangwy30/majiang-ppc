# 调研总览

2026-10-25 到 10-26 的调研结果。每篇报告开头都有结论，这里只列最重要的几条。

## 结论

1. **可行，最大的风险是认牌。** 算番和记账是确定性的，没有技术风险。见 [可行性评估](../docs/feasibility.md)。
2. **认牌用多模态大模型（Gemini Flash）。** 附上牌面参考图、要求逐张数点数之后，33 张测试照片整手全对 32/33，胡没胡交给规则引擎判可以 33/33，没有一次把没胡说成胡，每张约 0.6 美分、10 秒左右。见 [Gemini 识牌测试](gemini-recognition.md)。
3. **端侧模型 + Gemini 双读更稳。** 开源的端侧 YOLO 认牌模型（AR麻将助手）单独 23/33，但错的照片和 Gemini 不重叠。两边一致就直接算（22/33 张零操作，全部正确），不一致就高亮差异牌让用户点一下。见 [开源端侧认牌模型](on-device-model.md)。
4. **没有现成的「真实牌桌整手和牌 + 番数」数据集。** 单张牌的数据集有（Jon Chan、Roman Nguyen），但最终还要靠 Yang 自己在牌桌上拍照来验证。见 [数据集调研](datasets.md)、[测试照片集](test-photos.md)。
5. **规则由 App 来承担**，算番用开源 C++ 引擎。见 [国标规则调研](guobiao-rules.md)。

## 报告

| 报告 | 内容 |
|---|---|
| [datasets.md](datasets.md) | 开源麻将牌图片数据集和算番数据调研 |
| [test-photos.md](test-photos.md) | 33 张测试照片的来源和内容 |
| [gemini-recognition.md](gemini-recognition.md) | Gemini Flash 识牌、判胡测试，标准答案复核，7 种提高准确率的方法对比 |
| [on-device-model.md](on-device-model.md) | 开源端侧认牌模型评测，端侧 + Gemini 双读模拟 |
| [guobiao-rules.md](guobiao-rules.md) | 国标规则、计分、算番引擎选型 |
| [results/](results/) | 以上测试的原始 JSON 结果 |

## 局限

- 33 张照片太少，场景偏单一，标准答案是 Claude 看图读的（复核过，但没有人工核对）。
- 还没有真实牌局里「手牌推倒 + 旁边吃碰杠副露 + 牌河」的照片。

## 下一步

- Yang 在真实牌桌上拍 10–20 张和牌照片，重跑测试。
- 确认家规（计分方式、带不带花）。
- 确认算番库的开源协议。
