# 原始测试结果

报告里的数字都出自这些文件。分析和结论见上一级的各篇报告。

## gemini-flash/（gemini-3.8-flash，33 张，2026-10-26）

| 文件 | 内容 |
|---|---|
| `gemini-3.8-flash.json` | 第一轮测试的逐张结果（`run_gemini_test.py`）。注意这一轮用的是复核前的标准答案 |
| `base.json` `high.json` `crop.json` `ref.json` `vote.json` `retry.json` `combo.json` | 各种改进方法的逐张结果（`experiments.py`），标准答案已改正 |
| `summary.md` | 方法对比汇总表 |
| `app/` | 按 App 实际识别流程（PR #7 的提示词、立牌副露分开读、规则校验重看）重测：`app.json` 用 App 自己画的参考图，`research.json` 用研究参考图 |
| `speed/` | 提速对比：`flash38-low.json`（3.8 Flash 思考 low）、`lite35*.json`（3.5 Flash-Lite），汇总在 `summary.md` 和 `summary-lite35.md` |

## on-device-yolo/（开源端侧认牌模型）

| 文件 | 内容 |
|---|---|
| `report.json` | 两个开源 YOLO 认牌模型在 33 张上的逐张结果（`yolo_eval.py`） |
| `sim.json` | 双读模拟，Gemini 读法按第一轮测试报告的错误表还原（`hybrid_sim.py`） |
| `sim_base.json` `sim_ref.json` `sim_crop.json` `sim_combo.json` | 双读模拟，Gemini 读法用对应改进方法的真实结果（`GEM=… hybrid_sim.py`） |
