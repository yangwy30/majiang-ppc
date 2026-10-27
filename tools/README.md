# 测试脚本

都是调研阶段的一次性脚本，不是 App 代码。结果已经整理进 [research/](../research/)，原始输出在 [research/results/](../research/results/)。

## gemini-test：Gemini 识牌和判胡测试

| 脚本 | 做什么 |
|---|---|
| `run_gemini_test.py` | 用一个模型跑全部 33 张照片，对比标准答案，并用国标规则（标准型、七对、十三幺、全不靠、组合龙）校验读出的牌能不能和。`--selftest` 只跑规则校验，不调 API |
| `experiments.py` | 对比几种提高准确率的方法：高分辨率、逐张裁剪、附牌面参考图、3 次投票、规则不过就重看、组合、Pro |

```bash
# 在仓库根目录运行
python3 tools/gemini-test/run_gemini_test.py --models gemini-3.8-flash --out research/results/gemini-flash
python3 tools/gemini-test/experiments.py --flash gemini-3.8-flash --methods ref --out research/results/gemini-flash
```

- **API Key**：从环境变量 `GEMINI_API_KEY` 或 `~/.config/gemini/api_key` 读，通过 stdin 交给 curl，不会打印或写进文件。**不要把 Key 提交到仓库。**
- **网络**：云端环境连不上 Google API，要在 Yang 的 Mac 上跑。
- **照片**：默认读 `~/Downloads/majiang-test-photos/`，可用 `--base` 或 `MAJIANG_PHOTOS` 改。标准答案读 `data/ground_truth.json`（可用 `MAJIANG_GT` 改）。
- **参考牌面图**（`ref` 方法需要）：来自 [mikemazzetti/mahjong-ar](https://github.com/mikemazzetti/mahjong-ar/tree/main/web/public/samples) 的 42 种牌面图，没有许可证，不进仓库。放到 `tools/gemini-test/reference_tiles.jpg`，或用 `MAJIANG_REF_SHEET` 指定。项目文件夹里有一份：`gemini-test/reference_tiles.jpg`。
- 只用 Flash 模型（Yang 的决定，不跑 Pro）。

## on-device-model：开源端侧认牌模型测试

| 脚本 | 做什么 |
|---|---|
| `yolo_eval.py` | 用开源的 YOLO ONNX 认牌模型跑 33 张照片，流程照搬 majiang_calculator（整图粗检 → 裁出牌区放大重检）。`python3 tools/on-device-model/yolo_eval.py out.json` |
| `hybrid_sim.py` | 离线模拟「端侧 YOLO + Gemini 双读」的几种合并方式。`GEM=research/results/gemini-flash/ref.json python3 tools/on-device-model/hybrid_sim.py out.json`（不设 `GEM` 时按 Gemini 测试报告里的错误表还原 Gemini 的读法） |

- 依赖：`pip install onnxruntime opencv-python numpy`。只用 ONNX Runtime 推理。
- **模型权重不进仓库**，自己从原仓库下载，再用环境变量指定：
  - `YOLOV8_ONNX`：[alanfeiyuchang/majiang_calculator](https://github.com/alanfeiyuchang/majiang_calculator) 里的 `majiang calculator/Models/mahjong_yolov8.onnx`，和 [LYiHub/AR-Mahjong-Assistant-preview](https://github.com/LYiHub/AR-Mahjong-Assistant-preview) 的 `server/models/yolo/weights.onnx` 是同一个文件
  - `YOLO11_ONNX`：[mikemazzetti/mahjong-ar](https://github.com/mikemazzetti/mahjong-ar) 里的 `web/public/models/tiles.onnx`
