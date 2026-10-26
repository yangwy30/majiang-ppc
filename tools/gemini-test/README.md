# Gemini 识牌测试脚本

内部测试用。照片不放进仓库（多数来源没有许可证），在 Yang 的 Mac 上 `~/Downloads/majiang-test-photos/`。

- `run_gemini_test.py`：用一个模型跑全部照片，对比标准答案，判断胡没胡并用国标规则校验。
- `experiments.py`：对比几种提高准确率的方法（高分辨率、逐张裁剪、参考图、投票、规则校验重看、Pro）。
- `ground_truth.json`：标准答案（Claude 看图读的，2026-10-26 放大复核过）。
- `reference_tiles.jpg`：牌面参考图，来自 mikemazzetti/mahjong-ar（无许可证，仅内部测试）。

把这个文件夹复制到照片文件夹里，命名为 `gemini-test/`，然后在照片文件夹里运行。API Key 从 `$GEMINI_API_KEY` 或 `~/.config/gemini/api_key` 读取，不会打印。
