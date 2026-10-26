#!/usr/bin/env python3
"""Speed vs accuracy: the app's recognition flow (app_test.py) on faster settings.

Each config is name:model:thinking:maxside
  thinking  default | minimal | low | medium | off   (Gemini 3 uses thinkingLevel; 2.5 uses thinkingBudget, off = 0)
  maxside   0 keeps the photo as is, otherwise shrink its long side to this many pixels first

Run from the folder holding the photos:
    python3 gemini-test/speed_test.py                      # the default configs below
    python3 gemini-test/speed_test.py --configs "a:gemini-3.8-flash:low:0"
"""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import app_test as A  # noqa: E402
import experiments as E  # noqa: E402
import run_gemini_test as R  # noqa: E402

HERE = R.HERE
DEFAULT = ",".join([
    "flash38-default:gemini-3.8-flash:default:0",
    "flash38-low:gemini-3.8-flash:low:0",
    "flash38-minimal:gemini-3.8-flash:minimal:0",
    "flash38-low-1280:gemini-3.8-flash:low:1280",
    "lite35:gemini-3.5-flash-lite:default:0",
    "lite31:gemini-3.1-flash-lite:default:0",
])


def thinking_config(model, level):
    if level == "default":
        return None
    if model.startswith("gemini-2."):
        budget = {"off": 0, "minimal": 0, "low": 512, "medium": 2048}[level]
        return {"thinkingBudget": budget}
    return {"thinkingLevel": "minimal" if level == "off" else level}


def call(key, model, contents, thinking):
    cfg = {"responseMimeType": "application/json", "responseSchema": A.SCHEMA}
    tc = thinking_config(model, thinking)
    if tc:
        cfg["thinkingConfig"] = tc
    body = {"contents": contents, "generationConfig": cfg}
    url = f"{R.API}/models/{model}:generateContent"
    code = out = err = None
    for attempt in range(5):
        t0 = time.time()
        code, out, err = R.curl(key, url, body)
        dt = time.time() - t0
        if code == 200:
            r = json.loads(out)
            parts = r["candidates"][0]["content"]["parts"]
            text = "".join(p.get("text", "") for p in parts if not p.get("thought"))
            return json.loads(text), dt, r.get("usageMetadata", {})
        if code in (429, 500, 502, 503, 504, 0):
            time.sleep(5 * 2 ** attempt)
            continue
        break
    raise RuntimeError(f"HTTP {code}: {(out or '')[:300]} {(err or '')[:200]}")


def shrink(src, maxside, tmpdir):
    if not maxside:
        return src
    out = Path(tmpdir) / (Path(src).stem + ".jpg")
    try:
        from PIL import Image
        with Image.open(src) as im:
            im = im.convert("RGB")
            im.thumbnail((maxside, maxside))
            im.save(out, "JPEG", quality=88)
    except ImportError:
        shutil.copy(src, str(out) + ".src")
        subprocess.run(["sips", "-s", "format", "jpeg", "-Z", str(maxside), str(out) + ".src", "--out", str(out)],
                       capture_output=True)
        Path(str(out) + ".src").unlink(missing_ok=True)
    return out


def one(key, cfg, p, base, tmpdir):
    model, thinking, maxside = cfg
    truth, _ = R.parse_tiles(p["tiles"])
    rec = {"id": p["id"], "truth_win": p["win"]}
    try:
        img = shrink(Path(base) / p["file"], maxside, tmpdir)
        parts = [{"text": A.SHEET_TEXT}, E.img_part(A.SHEETS["app"]), {"text": "要识别的照片："},
                 E.img_part(img), {"text": A.PROMPT}]
        contents = [{"role": "user", "parts": parts}]
        first, dt1, u1 = call(key, model, contents, thinking)
        rec.update(first=A.judge(truth, first), t_first=round(dt1, 1),
                   tok_in=u1.get("promptTokenCount", 0),
                   tok_out=u1.get("candidatesTokenCount", 0) + u1.get("thoughtsTokenCount", 0))
        final, t_total, why = first, dt1, A.problem(first)
        if why:
            contents += [{"role": "model", "parts": [{"text": json.dumps(first, ensure_ascii=False)}]},
                         {"role": "user", "parts": [{"text": why + "\n请对照照片逐张重新数点数，再输出一次 JSON。"}]}]
            try:
                second, dt2, u2 = call(key, model, contents, thinking)
                t_total += dt2
                rec["tok_in"] += u2.get("promptTokenCount", 0)
                rec["tok_out"] += u2.get("candidatesTokenCount", 0) + u2.get("thoughtsTokenCount", 0)
                if A.problem(second) is None:
                    final = second
            except Exception:
                pass
        rec.update(final=A.judge(truth, final), t_total=round(t_total, 1), rechecked=bool(why))
    except Exception as e:  # keep going
        rec["error"] = str(e)[:300]
    return rec


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--configs", default=DEFAULT)
    ap.add_argument("--base", default=str(HERE.parent))
    ap.add_argument("--only", default="")
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--out", default=str(HERE / "results" / "speed"))
    a = ap.parse_args()
    if not R.selftest():
        sys.exit("ground truth self-test failed")
    key = R.load_key()
    gt = json.loads((HERE / "ground_truth.json").read_text(encoding="utf-8"))["photos"]
    if a.only:
        gt = [p for p in gt if p["id"] in a.only.split(",")]
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    rows_md = []
    for spec in a.configs.split(","):
        name, model, thinking, maxside = spec.split(":")
        cfg = (model, thinking, int(maxside))
        with tempfile.TemporaryDirectory() as tmp, ThreadPoolExecutor(a.workers) as pool:
            rows = list(pool.map(lambda p: one(key, cfg, p, a.base, tmp), gt))
        (out / f"{name}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        ok = [r for r in rows if "error" not in r]
        errs = len(rows) - len(ok)
        if not ok:
            rows_md.append(f"| {name} | {model} | {thinking} | {maxside or '原图'} | 全部出错：{rows[0].get('error', '')[:80]} |||||||")
            print(name, "ALL ERRORS", rows[0].get("error"), flush=True)
            continue
        n = len(ok)
        exact1 = sum(r["first"]["exact"] for r in ok)
        exact = sum(r["final"]["exact"] for r in ok)
        win = sum(bool(r["final"]["rule"]) == r["truth_win"] for r in ok if r["truth_win"] is not None)
        wn = sum(1 for r in ok if r["truth_win"] is not None)
        false_win = sum(bool(r["final"]["rule"]) and not r["truth_win"] for r in ok if r["truth_win"] is not None)
        tf = [r["t_first"] for r in ok]
        wins = [r["t_total"] for r in ok if r["truth_win"]]
        cost = sum(r["tok_in"] * 0.75 + r["tok_out"] * 3.75 for r in ok) / 1e6 / n * 100
        bad = " ".join(r["id"] for r in ok if not r["final"]["exact"])
        rows_md.append(
            f"| {name} | {model} | {thinking} | {maxside or '原图'} | {exact}/{n}（只读一次 {exact1}） | {win}/{wn} | {false_win} | "
            f"{sum(tf)/n:.1f}s / {pct(tf, 0.9):.1f}s / {max(tf):.1f}s | "
            f"{sum(wins)/max(1, len(wins)):.1f}s | {cost:.2f} 美分 | {errs} | {bad} |")
        print(rows_md[-1], flush=True)
    md = ("# 提速对比（App 识别流程，App 参考图）\n\n"
          f"运行时间：{time.strftime('%Y-%m-%d %H:%M')}；并发 {a.workers}；胡没胡一律由规则引擎判断。\n\n"
          "| 配置 | 模型 | 思考 | 缩图 | 整手全对 | 胡没胡判对 | 没胡说成胡 | 第一次调用 平均 / 90% / 最慢 | 胡牌照片总耗时 | 每张花费 | 出错 | 没读对的照片 |\n"
          "|---|---|---|---|---|---|---|---|---|---|---|---|\n" + "\n".join(rows_md)
          + "\n\n费用一律按 gemini-3.8-flash 的单价（输入 0.75、输出 3.75 美元每百万 token）估算，Lite 模型实际更便宜。\n")
    (out / "summary.md").write_text(md, encoding="utf-8")
    print(md, flush=True)


if __name__ == "__main__":
    main()
