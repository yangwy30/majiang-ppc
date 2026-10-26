#!/usr/bin/env python3
"""Test Gemini on mahjong hand photos: does it read the tiles, and does it
correctly decide whether the hand is a complete (Guobiao) win?

Usage (from the folder holding the photos):
    python3 gemini-test/run_gemini_test.py                 # auto-pick newest pro + flash
    python3 gemini-test/run_gemini_test.py --models flash          # newest flash only
    python3 gemini-test/run_gemini_test.py --models gemini-2.5-pro
    python3 gemini-test/run_gemini_test.py --only w03,g01  # a few photos
    python3 gemini-test/run_gemini_test.py --selftest      # rule checker only, no API

API key: read from $GEMINI_API_KEY, else from ~/.config/gemini/api_key.
The key is sent to curl on stdin (never on the command line) and is never
printed or written anywhere.
"""
import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from collections import Counter
from pathlib import Path

API = "https://generativelanguage.googleapis.com/v1beta"
HERE = Path(__file__).resolve().parent

# ---------------------------------------------------------------- tiles

HONORS = ["东", "南", "西", "北", "中", "发", "白"]
ALIASES = {"東": "东", "發": "发", "E": "东", "S": "南", "W": "西", "N": "北",
           "C": "中", "F": "发", "P": "白", "红中": "中", "发财": "发", "白板": "白",
           "Z": "中"}
ALL_TILES = [f"{n}{s}" for s in "mps" for n in range(1, 10)] + HONORS
INDEX = {t: i for i, t in enumerate(ALL_TILES)}


def norm_tile(t):
    t = t.strip().replace("?", "")
    t = ALIASES.get(t, t)
    t = (t.replace("万", "m").replace("萬", "m").replace("饼", "p").replace("筒", "p")
         .replace("条", "s").replace("索", "s"))
    if re.fullmatch(r"[1-9][1-7]z", t):  # 1z..7z notation
        t = HONORS[int(t[0]) - 1]
    return t if t in INDEX else None


def parse_tiles(tiles):
    if isinstance(tiles, str):
        tiles = tiles.split()
    out, bad = [], []
    for t in tiles:
        n = norm_tile(str(t))
        (out if n else bad).append(n or t)
    return out, bad


# ---------------------------------------------------------- rule checker

def _std(c, need_pair=True):
    """c: list of 34 counts. True if c splits into sets (+ one pair)."""
    if need_pair:
        for i in range(34):
            if c[i] >= 2:
                c[i] -= 2
                ok = _std(c, False)
                c[i] += 2
                if ok:
                    return True
        return False
    i = next((k for k in range(34) if c[k]), None)
    if i is None:
        return True
    if c[i] >= 3:
        c[i] -= 3
        ok = _std(c, False)
        c[i] += 3
        if ok:
            return True
    if i < 27 and i % 9 <= 6 and c[i + 1] and c[i + 2]:
        for k in (i, i + 1, i + 2):
            c[k] -= 1
        ok = _std(c, False)
        for k in (i, i + 1, i + 2):
            c[k] += 1
        if ok:
            return True
    return False


ORPHANS = [0, 8, 9, 17, 18, 26] + list(range(27, 34))
KNITS = [[a + 0, a + 3, a + 6, 9 + b, 9 + b + 3, 9 + b + 6, 18 + d, 18 + d + 3, 18 + d + 6]
         for a, b, d in [(0, 1, 2), (0, 2, 1), (1, 0, 2), (1, 2, 0), (2, 0, 1), (2, 1, 0)]]


def win_type14(c):
    if sum(c) != 14:
        return None
    if _std(list(c)):
        return "标准型(4组+1对)"
    if all(x in (0, 2, 4) for x in c):
        return "七对"
    if all(c[i] >= 1 for i in ORPHANS) and sum(c[i] for i in ORPHANS) == 14:
        return "十三幺"
    for k in KNITS:
        allowed = set(k) | set(range(27, 34))
        if all(x <= 1 for x in c) and all(c[i] == 0 or i in allowed for i in range(34)):
            return "全不靠"
        if all(c[i] >= 1 for i in k):
            r = list(c)
            for i in k:
                r[i] -= 1
            if _std(r):
                return "组合龙"
    return None


def win_type(tiles):
    """tiles: list of tile codes, kongs given as 4 tiles. Returns win type or None."""
    c = [0] * 34
    for t in tiles:
        c[INDEX[t]] += 1
    if any(x > 4 for x in c):
        return None
    k = sum(c) - 14
    if k < 0 or k > 4:
        return None
    quads = [i for i in range(34) if c[i] == 4]
    from itertools import combinations
    for chosen in combinations(quads, k):
        r = list(c)
        for i in chosen:
            r[i] = 0
        if k:  # with kongs only the standard shape is possible
            if _std(r):
                return f"标准型(含{k}杠)"
        else:
            w = win_type14(r)
            if w:
                return w
    return None


def selftest():
    cases = {
        "1p 1p 1p 2p 2p 3p 3p 4p 4p 5p 5p 6p 6p 7p": True,
        "1p 9p 1m 9m 1s 9s 白 东 南 西 北 中 发 白": True,
        "1p 9p 1s 9s 1m 9m 东 南 西 北 中 发 白": False,
        "5s 5s 5s 东 东 东 东 9p 9p 9p 1m 1m 1m 4p 4p": True,
        "中 中 中 中 6s 6s 6s 6s 西 西 西 西 6p 6p 6p 6p 8m 8m": True,
        "1m 1m 2m 2m 3m 3m 4m 4m 5p 5p 6s 6s 东 东": True,
        "1m 4m 7m 2p 5p 8p 3s 6s 9s 东 南 西 北 中": True,
        "1m 4m 7m 2p 5p 8p 3s 6s 9s 1p 2p 3p 白 白": True,
        "3s 3m 8p 5s 3s 7s 南 4m 5s 2m 发 3m 9m 9m": False,
    }
    ok = True
    for s, want in cases.items():
        got = win_type(parse_tiles(s)[0])
        if bool(got) != want:
            ok = False
            print("FAIL", s, got)
    gt = json.loads((HERE / "ground_truth.json").read_text(encoding="utf-8"))
    for p in gt["photos"]:
        tiles, bad = parse_tiles(p["tiles"])
        w = win_type(tiles)
        if bad or (p["win"] is not None and bool(w) != p["win"]):
            ok = ok and p.get("uncertain", False)  # uncertain readings only warn
            print("GT mismatch", p["id"], bad, w, p["win"])
    print("selftest", "OK" if ok else "FAILED")
    return ok


# ------------------------------------------------------------ gemini call

def load_key():
    k = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not k:
        f = Path.home() / ".config" / "gemini" / "api_key"
        if f.exists():
            k = f.read_text().strip()
    if not k:
        sys.exit("No API key: set GEMINI_API_KEY or write it to ~/.config/gemini/api_key")
    return k


def curl(key, url, body=None, timeout=600):
    """Call the API with curl; the key goes in a header read from stdin."""
    headers = f"x-goog-api-key: {key}\nContent-Type: application/json\n"
    cmd = ["curl", "-sS", "-m", str(timeout), "-w", "\n%{http_code}", "-H", "@-", url]
    tmp = None
    if body is not None:
        tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
        json.dump(body, tmp)
        tmp.close()
        cmd += ["--data-binary", f"@{tmp.name}"]
    try:
        p = subprocess.run(cmd, input=headers, capture_output=True, text=True)
    finally:
        if tmp:
            os.unlink(tmp.name)
    out, _, code = p.stdout.rpartition("\n")
    try:
        code = int(code)
    except ValueError:
        code = 0
    return code, out, p.stderr.replace(key, "***")


def pick_models(key):
    code, out, err = curl(key, f"{API}/models?pageSize=1000")
    if code != 200:
        sys.exit(f"ListModels failed: HTTP {code} {out[:500]} {err[:300]}")
    names = [m["name"].split("/", 1)[1] for m in json.loads(out).get("models", [])
             if "generateContent" in m.get("supportedGenerationMethods", [])]
    print("Available gemini models:", ", ".join(n for n in names if n.startswith("gemini")))
    best = {}
    for n in names:
        m = re.fullmatch(r"gemini-(\d+(?:\.\d+)?)-(pro|flash)(-preview)?(-[\d-]+)?", n)
        if not m:
            continue
        # prefer higher version, then GA over preview, then undated alias
        score = (float(m.group(1)), m.group(3) is None, m.group(4) is None)
        if m.group(2) not in best or score > best[m.group(2)][0]:
            best[m.group(2)] = (score, n)
    return [best[k][1] for k in ("pro", "flash") if k in best]


PROMPT = """这是一张麻将照片。请找出照片里"一个玩家的手牌"（包括摆在旁边的吃、碰、杠副露），逐张读出每一张牌。
- 不要算进别人的牌、打出去的牌（牌河）、牌墙和桌上其他散牌。
- 记法：1m-9m=万子，1p-9p=饼/筒子，1s-9s=条/索子，字牌用汉字：东 南 西 北 中 发 白。
- 杠要写满 4 张；暗杠里扣着的那张也算作这张杠牌。
- 花牌（春夏秋冬梅兰竹菊）不要放进 tiles，只在 flowers 里报数量。
- 照片里如果另外单独放了一张"胡的那张牌"，也算进 tiles。
然后按中国国标麻将判断：这手牌是不是已经完整和牌（14 张，或含杠时 14+杠数；4 组顺子/刻子 + 1 对，或七对、十三幺、全不靠、组合龙）。13 张的听牌不算和牌。
只输出 JSON。"""

SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "tiles": {"type": "ARRAY", "items": {"type": "STRING"},
                  "description": "Every tile of the hand, left to right, e.g. 1m, 5p, 9s, 东"},
        "flowers": {"type": "INTEGER"},
        "melds": {"type": "STRING", "description": "How the tiles split into sets and pair, if it is a win"},
        "is_win": {"type": "BOOLEAN"},
        "reason": {"type": "STRING"},
        "confidence": {"type": "STRING", "enum": ["high", "medium", "low"]},
    },
    "required": ["tiles", "is_win", "reason", "confidence"],
}


def ask(key, model, img):
    mime = "image/png" if img.suffix.lower() == ".png" else "image/jpeg"
    body = {
        "contents": [{"parts": [
            {"inline_data": {"mime_type": mime, "data": base64.b64encode(img.read_bytes()).decode()}},
            {"text": PROMPT},
        ]}],
        "generationConfig": {"responseMimeType": "application/json", "responseSchema": SCHEMA},
    }
    url = f"{API}/models/{model}:generateContent"
    for attempt in range(5):
        t0 = time.time()
        code, out, err = curl(key, url, body)
        dt = time.time() - t0
        if code == 200:
            r = json.loads(out)
            parts = r["candidates"][0]["content"]["parts"]
            text = "".join(p.get("text", "") for p in parts if not p.get("thought"))
            return json.loads(text), dt, r.get("usageMetadata", {})
        if code in (429, 500, 502, 503, 504, 0):
            time.sleep(5 * 2 ** attempt)
            continue
        raise RuntimeError(f"HTTP {code}: {out[:400]} {err[:200]}")
    raise RuntimeError(f"HTTP {code} after retries: {out[:400]} {err[:200]}")


# ---------------------------------------------------------------- scoring

def diff(truth, got):
    t, g = Counter(truth), Counter(got)
    return sorted((t - g).elements(), key=INDEX.get), sorted((g - t).elements(), key=INDEX.get)


def fmt(tiles):
    return " ".join(sorted(tiles, key=INDEX.get))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=str(HERE.parent), help="folder the photo paths are relative to")
    ap.add_argument("--models", default="auto")
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=str(HERE / "results"))
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if not selftest() or a.selftest:
        return
    key = load_key()
    if a.models in ("auto", "pro", "flash"):
        models = [m for m in pick_models(key) if a.models == "auto" or f"-{a.models}" in m]
    else:
        models = a.models.split(",")
    print("Testing models:", models)
    gt = json.loads((HERE / "ground_truth.json").read_text(encoding="utf-8"))["photos"]
    if a.only:
        gt = [p for p in gt if p["id"] in a.only.split(",")]
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    base = Path(a.base)
    summary = [f"# Gemini 麻将识别测试结果\n\n运行时间：{time.strftime('%Y-%m-%d %H:%M')}\n"]
    for model in models:
        rows, stats = [], Counter()
        for p in gt:
            img = base / p["file"]
            truth, _ = parse_tiles(p["tiles"])
            truth_win = p["win"]
            rec = {"id": p["id"], "file": p["file"], "truth": p["tiles"], "truth_win": truth_win,
                   "uncertain": p.get("uncertain", False)}
            if not img.exists():
                rec["error"] = "photo not found"
                rows.append(rec)
                print(p["id"], "MISSING", img)
                continue
            try:
                ans, dt, usage = ask(key, model, img)
            except Exception as e:  # keep going on one bad photo
                rec["error"] = str(e)[:300]
                rows.append(rec)
                stats["errors"] += 1
                print(p["id"], "ERROR", rec["error"])
                continue
            got, bad = parse_tiles(ans.get("tiles", []))
            miss, extra = diff(truth, got)
            rule = win_type(got) if not bad else None
            rec.update(answer=ans, got=fmt(got), unparsed=bad, missing=miss, extra=extra,
                       exact=not miss and not extra and not bad, rule_win=rule,
                       seconds=round(dt, 1), tokens=usage.get("totalTokenCount"))
            stats["n"] += 1
            stats["exact"] += rec["exact"]
            stats["tile_err"] += len(miss) + len(extra) + len(bad)
            stats["tiles"] += len(truth)
            if truth_win is not None:
                stats["win_n"] += 1
                stats["gem_ok"] += ans.get("is_win") == truth_win
                stats["rule_ok"] += bool(rule) == truth_win
                stats["agree"] += bool(rule) == bool(ans.get("is_win"))
            rows.append(rec)
            print(f"{p['id']} {model} exact={rec['exact']} gemini_win={ans.get('is_win')} "
                  f"rule_win={rule} truth={truth_win} miss={miss} extra={extra} {dt:.0f}s")
        (out / f"{model}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        n, w = stats["n"] or 1, stats["win_n"] or 1
        summary.append(
            f"\n## {model}\n\n"
            f"- 牌面完全读对：{stats['exact']}/{stats['n']}（{stats['exact']/n:.0%}）\n"
            f"- 读错的牌（漏读+多读）：{stats['tile_err']} 张 / 共 {stats['tiles']} 张\n"
            f"- Gemini 自己判断胡没胡，判对：{stats['gem_ok']}/{stats['win_n']}（{stats['gem_ok']/w:.0%}）\n"
            f"- 用 Gemini 读出的牌再跑规则校验，判对：{stats['rule_ok']}/{stats['win_n']}（{stats['rule_ok']/w:.0%}）\n"
            f"- Gemini 的判断和它自己读的牌对不上（自相矛盾）：{stats['win_n'] - stats['agree']} 次\n"
            f"- 调用出错：{stats['errors']}\n\n"
            "| 照片 | 牌面全对 | 漏读 | 多读 | Gemini说胡 | 规则校验 | 真实 | 信心 | 耗时 |\n"
            "|---|---|---|---|---|---|---|---|---|\n")
        for r in rows:
            if "error" in r:
                summary.append(f"| {r['id']} | 出错：{r['error'][:60]} |||||||\n")
                continue
            yn = lambda v: "—" if v is None else ("胡" if v else "没胡")
            summary.append(
                f"| {r['id']}{'(答案存疑)' if r['uncertain'] else ''} | {'✅' if r['exact'] else '❌'} | "
                f"{' '.join(r['missing'])} | {' '.join(r['extra'] + r['unparsed'])} | "
                f"{yn(r['answer'].get('is_win'))} | {r['rule_win'] or '没胡'} | {yn(r['truth_win'])} | "
                f"{r['answer'].get('confidence')} | {r['seconds']}s |\n")
    (out / "summary.md").write_text("".join(summary), encoding="utf-8")
    print("".join(summary))


if __name__ == "__main__":
    main()
