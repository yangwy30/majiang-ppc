#!/usr/bin/env python3
"""Compare ways of making Gemini read mahjong tiles more accurately.

Run from the folder holding the photos (same layout as run_gemini_test.py):
    python3 gemini-test/experiments.py --flash gemini-3.8-flash --pro gemini-3.1-pro-preview
    python3 gemini-test/experiments.py ... --methods base,high,crop   # a subset
    python3 gemini-test/experiments.py ... --only g02,w09             # a few photos

Methods (Flash unless noted):
  base   same prompt as run_gemini_test.py (control)
  high   media_resolution HIGH
  crop   1st call finds a box per tile, then each tile is cropped and read separately
  ref    a reference sheet of all tile faces is attached, and the prompt asks to count pips
  vote   3 independent runs of base, tile counts by majority; disagreements flagged
  retry  base, then if the rule check says the reading is impossible / not a win,
         ask once to re-check the tiles
  combo  high + pip-counting prompt + retry
  pro    base prompt on the Pro model

The API key is handled as in run_gemini_test.py (stdin to curl, never printed).
"""
import argparse
import base64
import json
import shutil
import subprocess
import sys
import tempfile
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_gemini_test as R  # noqa: E402

HERE = R.HERE
REF_SHEET = HERE / "reference_tiles.jpg"

PIP_HINT = """
特别注意：条子和饼子要逐张数点数，不要凭整体印象猜。
- 条子数竹节根数：1条通常画成一只鸟；5条是四角各一根 + 中间一根（中间那根常是红色）；4条是两列各两根、中间没有；6条是两排各三根；7条是顶上一根 + 下面六根；8条常画成 W/M 形；9条是三排各三根。
- 饼子数圆点：6饼是上面 2 个 + 下面 4 个；7饼是斜着 3 个 + 下面 4 个；8饼是两列各 4 个。
- 每张先数清楚再写，写 tiles 前确认张数（一般 14 张，杠多 1 张）。"""

PRICE_NOTE = "费用按 token 数估算，单价以 Google AI Studio 价格页为准。"


def mime_of(p):
    return "image/png" if Path(p).suffix.lower() == ".png" else "image/jpeg"


def img_part(path, high=False):
    part = {"inline_data": {"mime_type": mime_of(path),
                            "data": base64.b64encode(Path(path).read_bytes()).decode()}}
    return part


def call(key, model, contents, schema, high=False):
    """One generateContent call. Returns (json_answer, raw_parts, seconds, usage)."""
    cfg = {"responseMimeType": "application/json", "responseSchema": schema}
    if high:
        cfg["mediaResolution"] = "MEDIA_RESOLUTION_HIGH"
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
            return json.loads(text), parts, dt, r.get("usageMetadata", {})
        if code in (429, 500, 502, 503, 504, 0):
            time.sleep(5 * 2 ** attempt)
            continue
        break
    raise RuntimeError(f"HTTP {code}: {(out or '')[:300]} {(err or '')[:200]}")


class Meter:
    def __init__(self):
        self.sec = 0.0
        self.inp = 0
        self.outp = 0
        self.calls = 0

    def add(self, dt, usage):
        self.sec += dt
        self.calls += 1
        self.inp += usage.get("promptTokenCount", 0)
        self.outp += usage.get("candidatesTokenCount", 0) + usage.get("thoughtsTokenCount", 0)


# ------------------------------------------------------------- methods

def m_single(key, model, img, m, prompt=R.PROMPT, high=False, ref=False):
    parts = []
    if ref:
        parts += [{"text": "参考图：各种麻将牌的牌面（不同牌的画法可能不同，仅作参考）。"}, img_part(REF_SHEET)]
        parts += [{"text": "要识别的照片："}]
    parts += [img_part(img), {"text": prompt}]
    contents = [{"role": "user", "parts": parts}]
    ans, raw, dt, u = call(key, model, contents, R.SCHEMA, high)
    m.add(dt, u)
    return ans, contents, raw


def needs_recheck(ans):
    tiles, bad = R.parse_tiles(ans.get("tiles", []))
    c = Counter(tiles)
    if bad or any(v > 4 for v in c.values()):
        return "读出的牌里有无法识别的记法，或同一种牌超过 4 张，这不可能。"
    n, k = len(tiles), sum(1 for v in c.values() if v == 4)
    if n < 14 and ans.get("is_win") is False and n == 13:
        return None  # a plain 13-tile hand is a legitimate non-win
    if n == 13 or (14 <= n <= 18 and not R.win_type(tiles)):
        return (f"按国标规则，你读出的这 {n} 张牌拼不成和牌。很可能有一两张牌认错了"
                "（常见是条子、饼子的点数差一，或漏读了被遮挡、切边的牌）。")
    return None


def m_retry(key, model, img, m, prompt=R.PROMPT, high=False):
    ans, contents, raw = m_single(key, model, img, m, prompt, high)
    why = needs_recheck(ans)
    if not why:
        return ans, {"rechecked": False}
    follow = (why + "请重新仔细看照片，逐张数点数，重新输出完整 JSON。"
              "如果你确认原来的读法没错，就原样输出，不要为了凑和牌而改牌。")
    contents = contents + [{"role": "model", "parts": raw}, {"role": "user", "parts": [{"text": follow}]}]
    ans2, _, dt, u = call(key, model, contents, R.SCHEMA, high)
    m.add(dt, u)
    return ans2, {"rechecked": True, "first": ans.get("tiles")}


def m_vote(key, model, img, m):
    runs = [m_single(key, model, img, m)[0] for _ in range(3)]
    counts = [Counter(R.parse_tiles(a.get("tiles", []))[0]) for a in runs]
    final, doubtful = [], []
    for t in R.ALL_TILES:
        vals = sorted(c[t] for c in counts)
        v = vals[1]  # median of 3 = majority when two agree
        final += [t] * v
        if len(set(vals)) > 1:
            doubtful.append(t)
    wins = [bool(a.get("is_win")) for a in runs]
    return {"tiles": final, "is_win": sum(wins) >= 2, "reason": "3 次投票",
            "confidence": "high" if not doubtful else "low"}, {"doubtful": doubtful,
                                                               "runs": [a.get("tiles") for a in runs]}


BOX_SCHEMA = {
    "type": "OBJECT",
    "properties": {"boxes": {"type": "ARRAY", "items": {
        "type": "OBJECT",
        "properties": {"box_2d": {"type": "ARRAY", "items": {"type": "INTEGER"}}},
        "required": ["box_2d"]}}},
    "required": ["boxes"],
}
BOX_PROMPT = """找出照片里"一个玩家的手牌"（含吃碰杠副露、单独放的胡牌那张，不含花牌、牌河、牌墙和散牌）中的每一张牌，
按从左到右（多排时先上排再下排）的顺序，给出每张牌的框 box_2d = [ymin, xmin, ymax, xmax]，坐标归一化到 0-1000。只输出 JSON。"""
CROP_PROMPT = """上面按顺序给出了同一手麻将牌里每一张牌的特写（第 1 张、第 2 张……），最后是整张原图。
请逐张识别特写里的牌，tiles 数组按特写顺序一一对应（一张特写对应一张牌；如果某张特写里明显是两张牌或者不是牌，按实际情况处理）。
记法：1m-9m=万子，1p-9p=饼/筒子，1s-9s=条/索子，字牌用汉字：东 南 西 北 中 发 白。暗杠里扣着的牌算作这张杠牌，花牌不要放进 tiles。
然后按中国国标麻将判断是否已经完整和牌。只输出 JSON。""" + PIP_HINT


def image_size(path):
    try:
        from PIL import Image
        with Image.open(path) as im:
            return im.size
    except ImportError:
        out = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                             capture_output=True, text=True).stdout
        vals = [int(line.split(":")[1]) for line in out.splitlines() if "pixel" in line]
        return vals[0], vals[1]


def crop(path, box, out, size):
    w, h = size
    y0, x0, y1, x1 = [v / 1000 for v in box]
    py, px = (y1 - y0) * 0.08, (x1 - x0) * 0.08
    left, top = max(0, int((x0 - px) * w)), max(0, int((y0 - py) * h))
    right, bottom = min(w, int((x1 + px) * w)), min(h, int((y1 + py) * h))
    if right - left < 4 or bottom - top < 4:
        return False
    try:
        from PIL import Image
        with Image.open(path) as im:
            c = im.convert("RGB").crop((left, top, right, bottom))
            if c.width < 160:
                s = 160 / c.width
                c = c.resize((160, int(c.height * s)))
            c.save(out, "JPEG", quality=92)
    except ImportError:
        shutil.copy(path, out + ".src")
        subprocess.run(["sips", "-s", "format", "jpeg", "-c", str(bottom - top), str(right - left),
                        "--cropOffset", str(top), str(left), out + ".src", "--out", out],
                       capture_output=True)
        Path(out + ".src").unlink(missing_ok=True)
    return Path(out).exists()


def m_crop(key, model, img, m):
    contents = [{"role": "user", "parts": [img_part(img), {"text": BOX_PROMPT}]}]
    boxes, _, dt, u = call(key, model, contents, BOX_SCHEMA)
    m.add(dt, u)
    size = image_size(img)
    parts = []
    with tempfile.TemporaryDirectory() as d:
        n = 0
        for b in boxes.get("boxes", []):
            bb = b.get("box_2d", [])
            if len(bb) != 4:
                continue
            out = f"{d}/{n}.jpg"
            if crop(img, bb, out, size):
                n += 1
                parts += [{"text": f"第 {n} 张："}, img_part(out)]
        parts += [{"text": "整张原图："}, img_part(img), {"text": CROP_PROMPT}]
    ans, _, dt, u = call(key, model, [{"role": "user", "parts": parts}], R.SCHEMA)
    m.add(dt, u)
    return ans, {"boxes": n}


METHODS = {
    "base": lambda k, a, img, m: (m_single(k, a.flash, img, m)[0], {}),
    "high": lambda k, a, img, m: (m_single(k, a.flash, img, m, high=True)[0], {}),
    "crop": lambda k, a, img, m: m_crop(k, a.flash, img, m),
    "ref": lambda k, a, img, m: (m_single(k, a.flash, img, m, R.PROMPT + PIP_HINT, ref=True)[0], {}),
    "vote": lambda k, a, img, m: m_vote(k, a.flash, img, m),
    "retry": lambda k, a, img, m: m_retry(k, a.flash, img, m),
    "combo": lambda k, a, img, m: m_retry(k, a.flash, img, m, R.PROMPT + PIP_HINT, high=True),
    "pro": lambda k, a, img, m: (m_single(k, a.pro, img, m)[0], {}),
}
LABELS = {"base": "对照（原方法）", "high": "高分辨率", "crop": "先框再逐张裁剪识别",
          "ref": "附牌面参考图 + 要求数点数", "vote": "跑 3 次投票", "retry": "规则校验不通过就重看",
          "combo": "高分辨率 + 数点数 + 重看", "pro": "Pro 模型（原方法）"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flash", required=True)
    ap.add_argument("--pro", default="")
    ap.add_argument("--methods", default="base,high,crop,ref,vote,retry,combo,pro")
    ap.add_argument("--base", default=str(HERE.parent))
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=str(HERE / "results" / "experiments"))
    a = ap.parse_args()
    if not R.selftest():
        sys.exit("ground truth self-test failed")
    key = R.load_key()
    methods = [x for x in a.methods.split(",") if x != "pro" or a.pro]
    if "ref" in methods and not REF_SHEET.exists():
        print("reference_tiles.jpg missing, skipping ref")
        methods.remove("ref")
    gt = json.loads((HERE / "ground_truth.json").read_text(encoding="utf-8"))["photos"]
    if a.only:
        gt = [p for p in gt if p["id"] in a.only.split(",")]
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    table = []
    for meth in methods:
        meter, rows, s = Meter(), [], Counter()
        for p in gt:
            img = Path(a.base) / p["file"]
            truth, _ = R.parse_tiles(p["tiles"])
            rec = {"id": p["id"]}
            try:
                ans, extra = METHODS[meth](key, a, img, meter)
            except Exception as e:  # keep going
                rec["error"] = str(e)[:300]
                s["err"] += 1
                rows.append(rec)
                print(meth, p["id"], "ERROR", rec["error"])
                continue
            got, bad = R.parse_tiles(ans.get("tiles", []))
            miss, more = R.diff(truth, got)
            rule = R.win_type(got) if not bad else None
            exact = not miss and not more and not bad
            s["n"] += 1
            s["exact"] += exact
            s["tile_err"] += len(miss) + len(more) + len(bad)
            if p["win"] is not None:
                s["wn"] += 1
                s["win_ok"] += bool(ans.get("is_win")) == p["win"]
                s["false_win"] += bool(ans.get("is_win")) and not p["win"]
            rec.update(exact=exact, missing=miss, extra=more + bad, is_win=ans.get("is_win"),
                       rule=rule, truth_win=p["win"], got=R.fmt(got), **extra)
            rows.append(rec)
            print(f"{meth} {p['id']} exact={exact} win={ans.get('is_win')} truth={p['win']} miss={miss} extra={more}")
        (out / f"{meth}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        n = s["n"] or 1
        table.append(
            f"| {LABELS[meth]} | {s['exact']}/{s['n']}（{s['exact']/n:.0%}） | {s['tile_err']} | "
            f"{s['win_ok']}/{s['wn']} | {s['false_win']} | {meter.sec/n:.1f}s | {meter.calls/n:.1f} | "
            f"{meter.inp//n:,} / {meter.outp//n:,} | {s['err']} |")
    md = ("# 提高识别准确率的方法对比\n\n"
          f"运行时间：{time.strftime('%Y-%m-%d %H:%M')}；Flash = {a.flash}；Pro = {a.pro or '未测'}\n\n"
          "| 方法 | 整手全对 | 读错的牌 | 胡没胡判对 | 没胡说成胡 | 每张平均耗时 | 每张调用次数 | 每张输入 / 输出 token | 出错 |\n"
          "|---|---|---|---|---|---|---|---|---|\n" + "\n".join(table) + f"\n\n{PRICE_NOTE}\n")
    (out / "summary.md").write_text(md, encoding="utf-8")
    print(md)


if __name__ == "__main__":
    main()
