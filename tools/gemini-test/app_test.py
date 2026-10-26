#!/usr/bin/env python3
"""Re-run the 33 test photos the way the iOS app (PR #7) asks Gemini.

Mirrors app/MajiangKit/Sources/MajiangKit/Recognition/GeminiRecognizer.swift and
RuleCheckedRecognizer in RecognitionPipeline.swift:
  - the app's prompt and schema (standing tiles and melds read separately, tiles limited to the 34 notations),
  - a reference sheet in front of the photo,
  - win decided by the rule engine, never by the model,
  - if the reading is impossible or not a winning shape, ask once more with the reason,
    and keep the second answer only if it passes.

Sheets:
  app       app_reference_sheet.jpg (the app's own flat tile faces, rendered from TileFace.swift)
  research  reference_tiles.jpg (the unlicensed photo sheet that scored 32/33 in experiments.py)

Run from the folder holding the photos:
    python3 gemini-test/app_test.py --flash gemini-3.8-flash                 # both sheets
    python3 gemini-test/app_test.py --flash gemini-3.8-flash --sheets app
"""
import argparse
import json
import sys
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import experiments as E  # noqa: E402
import run_gemini_test as R  # noqa: E402

HERE = R.HERE
SHEETS = {"app": HERE / "app_reference_sheet.jpg", "research": HERE / "reference_tiles.jpg"}

SHEET_TEXT = ("参考图：34 种牌的简化画法，下面标了记法，用来对照花色和点数。真实的牌画法会不同："
              "1条常画成一只鸟，8条常画成 W/M 形，以照片里数出的竹节、圆点数为准。")

PROMPT = """这是一张麻将照片，拍的是和牌那家的牌：手牌推倒排成一排，和的那张放在最右；吃、碰、杠放在旁边，暗杠翻开一张。
请逐张读出这家的牌。
- 不要算进别人的牌、打出去的牌（牌河）、牌墙和桌上其他散牌。
- 记法：1m-9m=万子，1p-9p=饼/筒子，1s-9s=条/索子，字牌用汉字：东 南 西 北 中 发 白。
- concealed：排成一排的手牌，从左到右，包括最右边和的那张。
- melds：摆在旁边的每一组吃、碰、杠。kind 写 chow（吃）、pung（碰）、kong（明杠）或 concealed_kong（暗杠）；杠写满 4 张，扣着的那张也算作这张杠牌。
- 花牌（春夏秋冬梅兰竹菊）不要放进牌里，只在 flowers 里报数量。
特别注意：条子和饼子要逐张数点数，不要凭整体印象猜。
- 条子数竹节根数：1条通常画成一只鸟；5条是四角各一根 + 中间一根（中间那根常是红色）；4条是两列各两根、中间没有；6条是两排各三根；7条是顶上一根 + 下面六根；8条常画成 W/M 形；9条是三排各三根。
- 饼子数圆点：6饼是上面 2 个 + 下面 4 个；7饼是斜着 3 个 + 下面 4 个；8饼是两列各 4 个。
- 每张先数清楚再写，写完确认张数：立牌 + 每组副露 3 张（杠 4 张）一般共 14 张，每个杠多 1 张。
不要判断和没和，只输出 JSON。"""

NOTATIONS = R.ALL_TILES
SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "concealed": {"type": "ARRAY", "items": {"type": "STRING", "enum": NOTATIONS},
                      "description": "Standing tiles left to right, winning tile last, e.g. 1m, 5p, 9s, 东"},
        "melds": {"type": "ARRAY", "items": {
            "type": "OBJECT",
            "properties": {"kind": {"type": "STRING", "enum": ["chow", "pung", "kong", "concealed_kong"]},
                           "tiles": {"type": "ARRAY", "items": {"type": "STRING", "enum": NOTATIONS}}},
            "required": ["kind", "tiles"]}},
        "flowers": {"type": "INTEGER"},
        "confidence": {"type": "STRING", "enum": ["high", "medium", "low"]},
    },
    "required": ["concealed", "melds", "flowers"],
}


def all_tiles(ans):
    """Concealed + meld tiles; a kong reported with 3 tiles counts as 4, like the app's parser."""
    tiles = list(ans.get("concealed", []))
    for m in ans.get("melds", []) or []:
        t = list(m.get("tiles", []))
        if m.get("kind") in ("kong", "concealed_kong") and len(t) == 3 and len(set(t)) == 1:
            t.append(t[0])
        tiles += t
    return R.parse_tiles(tiles)[0]


def problem(ans):
    """Same checks as RuleCheckedRecognizer.problem."""
    tiles = all_tiles(ans)
    over = [t for t, n in Counter(tiles).items() if n > 4]
    if over:
        return f"你读出的牌里 {' '.join(over)} 超过 4 张，这不可能。"
    if not R.win_type(tiles):
        return (f"按国标规则，你读出的这 {len(tiles)} 张牌拼不成和牌。请对照照片逐张再核对一遍"
                "（常见的错是条子、饼子的点数差一，或漏读了被遮挡、切边的牌）。"
                "如果照片里的牌确实就是这样，就照实输出，不要为了凑成和牌而改。")
    return None


def recognize(key, model, img, sheet, meter):
    parts = [{"text": SHEET_TEXT}, E.img_part(sheet), {"text": "要识别的照片："},
             E.img_part(img), {"text": PROMPT}]
    contents = [{"role": "user", "parts": parts}]
    first, _, dt, u = E.call(key, model, contents, SCHEMA)
    meter.add(dt, u)
    why = problem(first)
    if not why:
        return first, first, False
    # The app sends its own re-encoded answer back as plain text, not the raw model parts.
    contents += [{"role": "model", "parts": [{"text": json.dumps(first, ensure_ascii=False)}]},
                 {"role": "user", "parts": [{"text": why + "\n请对照照片逐张重新数点数，再输出一次 JSON。"}]}]
    try:
        second, _, dt, u = E.call(key, model, contents, SCHEMA)
        meter.add(dt, u)
    except Exception:
        return first, first, True
    return first, (second if problem(second) is None else first), True


def score(rows, field):
    s = Counter()
    for r in rows:
        if "error" in r:
            continue
        a = r[field]
        s["n"] += 1
        s["exact"] += a["exact"]
        s["tile_err"] += len(a["missing"]) + len(a["extra"])
        if r["truth_win"] is not None:
            s["wn"] += 1
            s["win_ok"] += bool(a["rule"]) == r["truth_win"]
            s["false_win"] += bool(a["rule"]) and not r["truth_win"]
    return s


def judge(truth, ans):
    got = all_tiles(ans)
    miss, extra = R.diff(truth, got)
    return {"got": R.fmt(got), "missing": miss, "extra": extra, "exact": not miss and not extra,
            "rule": R.win_type(got), "melds": ans.get("melds", []), "flowers": ans.get("flowers")}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flash", required=True)
    ap.add_argument("--sheets", default="app,research")
    ap.add_argument("--base", default=str(HERE.parent))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=str(HERE / "results" / "app"))
    a = ap.parse_args()
    if not R.selftest():
        sys.exit("ground truth self-test failed")
    key = R.load_key()
    gt = json.loads((HERE / "ground_truth.json").read_text(encoding="utf-8"))["photos"]
    if a.only:
        gt = [p for p in gt if p["id"] in a.only.split(",")]
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    table = []
    for name in a.sheets.split(","):
        sheet = SHEETS[name]
        meter, rows = E.Meter(), []
        for p in gt:
            truth, _ = R.parse_tiles(p["tiles"])
            rec = {"id": p["id"], "truth_win": p["win"]}
            try:
                first, final, rechecked = recognize(key, a.flash, Path(a.base) / p["file"], sheet, meter)
            except Exception as e:  # keep going
                rec["error"] = str(e)[:300]
                rows.append(rec)
                print(name, p["id"], "ERROR", rec["error"], flush=True)
                continue
            rec.update(first=judge(truth, first), final=judge(truth, final), rechecked=rechecked)
            rows.append(rec)
            f = rec["final"]
            print(f"{name} {p['id']} exact={f['exact']} rule_win={bool(f['rule'])} truth={p['win']} "
                  f"recheck={rechecked} miss={f['missing']} extra={f['extra']}", flush=True)
        (out / f"{name}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        n = sum(1 for r in rows if "error" not in r) or 1
        for field, label in (("first", "只读一次"), ("final", "加规则校验重看（App 实际流程）")):
            s = score(rows, field)
            table.append(f"| {name} 参考图 · {label} | {s['exact']}/{s['n']}（{s['exact']/n:.0%}） | {s['tile_err']} | "
                         f"{s['win_ok']}/{s['wn']} | {s['false_win']} |")
        cost = (meter.inp * 0.75 + meter.outp * 3.75) / 1e6 / n * 100
        table.append(f"| {name} 参考图 · 平均每张 | {meter.sec/n:.1f}s，{meter.calls/n:.2f} 次调用，"
                     f"输入 {meter.inp//n:,} / 输出 {meter.outp//n:,} token，约 {cost:.2f} 美分 ||||")
    md = ("# App 识别方式重测\n\n"
          f"运行时间：{time.strftime('%Y-%m-%d %H:%M')}；模型 {a.flash}；胡没胡一律由规则引擎按读出的牌判断。\n\n"
          "| 方案 | 整手全对 | 读错的牌 | 胡没胡判对 | 没胡说成胡 |\n|---|---|---|---|---|\n"
          + "\n".join(table) + "\n\n对照：experiments.py 里「附参考图 + 数点数」是 32/33。"
          "费用按每百万 token 输入 0.75、输出 3.75 美元估算。\n")
    (out / "summary.md").write_text(md, encoding="utf-8")
    print(md, flush=True)


if __name__ == "__main__":
    main()
