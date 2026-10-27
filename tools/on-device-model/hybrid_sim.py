"""Offline simulation: combine on-device YOLO with Gemini Flash readings on the 33 photos."""
import json, sys
from collections import Counter
from pathlib import Path
import cv2, numpy as np, onnxruntime as ort
sys.path.insert(0, str(Path(__file__).parent))
from yolo_eval import GT, PHOTOS, YOLOV8_ONNX, recognize, names_v8  # noqa: E402

# Gemini Flash errors from research/gemini-recognition.md (miss = in truth not read, extra = read but absent).
# g08/g09/w13/w15/w17: the answer key was corrected to Gemini's reading, so Gemini == truth there.
GEM_ERR = {"g02": ("5s 5s", "4s 4s"), "g03": ("7p", "6p"), "g06": ("7p 7p 5s", "4p 4p 3s"),
           "g10": ("6p 5s 5s", "4p 4s 4s"), "w01": ("西", "北"), "w09": ("2s 4s 4s", "1s 1s 1s"),
           "w10": ("7p 7p", "5p"), "w19": ("5s 5s 5s", "6s 6s 6s")}


import os
GEM_FILE = os.environ.get("GEM")
GEM_ROWS = {r["id"]: r["got"].split() for r in json.load(open(GEM_FILE))} if GEM_FILE else None


def gemini_reading(pid, truth):
    if GEM_ROWS is not None:
        return GEM_ROWS[pid]
    if pid not in GEM_ERR:
        return list(truth)
    miss, extra = GEM_ERR[pid]
    return list((Counter(truth) - Counter(miss.split()) + Counter(extra.split())).elements())


def legal(tiles):
    """Rule check that needs no knowledge of the truth: right tile count and at most 4 of a kind."""
    c = Counter(tiles)
    kongs = sum(1 for v in c.values() if v == 4)
    return max(c.values(), default=0) <= 4 and len(tiles) - kongs in (13, 14)


def same(a, b):
    return Counter(a) == Counter(b)


def main():
    sess = ort.InferenceSession(YOLOV8_ONNX)
    rows = []
    for p in GT["photos"]:
        f = p["file"]
        fp = PHOTOS / f
        img = cv2.imdecode(np.fromfile(str(fp), np.uint8), cv2.IMREAD_COLOR)
        dets = [(names_v8(c), s) for _, s, c in recognize(sess, img)]
        dets = [(t, s) for t, s in dets if t]
        truth = p["tiles"].split()
        y = [t for t, _ in dets]
        g = gemini_reading(p["id"], truth)
        rows.append(dict(id=p["id"], truth=truth, y=y, g=g, conf=dets, win=p["win"]))

    n = len(rows)
    out = {}
    out["YOLO alone"] = sum(same(r["y"], r["truth"]) for r in rows)
    out["Gemini alone"] = sum(same(r["g"], r["truth"]) for r in rows)

    # 1) agree -> auto; disagree -> user fixes the differing tiles
    agree = [r for r in rows if same(r["y"], r["g"])]
    taps = []
    for r in rows:
        if not same(r["y"], r["g"]):
            # user taps every tile the two readers disagree on (upper bound on effort)
            dy = Counter(r["y"]) - Counter(r["g"])
            dg = Counter(r["g"]) - Counter(r["y"])
            taps.append(max(sum(dy.values()), sum(dg.values())))
    out["1 auto"] = len(agree)
    out["1 auto correct"] = sum(same(r["y"], r["truth"]) for r in agree)
    out["1 flagged"] = n - len(agree)
    out["1 taps per flagged photo"] = round(sum(taps) / max(1, len(taps)), 1)
    # after the user checks the flagged ones the final result is correct if the user is right
    out["1 final (user fixes flagged)"] = len(agree) and out["1 auto correct"] + out["1 flagged"]

    # 2) no user: on disagreement look at YOLO's confidence on the tiles only YOLO read.
    #    All of them >= T -> trust YOLO, else trust Gemini. Then rule check: an illegal pick
    #    falls back to the other reading if that one is legal.
    for T in (0.5, 0.6, 0.7, 0.8, 0.9, 0.95):
        ok = 0
        for r in rows:
            if same(r["y"], r["g"]):
                pick = r["y"]
            else:
                only_y = Counter(r["y"]) - Counter(r["g"])
                contested = sorted([s for t, s in r["conf"] if only_y[t] > 0])[:sum(only_y.values())] or [0]
                pick, other = (r["y"], r["g"]) if min(contested) >= T else (r["g"], r["y"])
                if not legal(pick) and legal(other):
                    pick = other
            ok += same(pick, r["truth"])
        out[f"2 conf-pick T={T}"] = ok

    # 2b) simpler: prefer Gemini, but if Gemini's reading breaks the rules use YOLO's (and vice versa)
    ok = 0
    for r in rows:
        pick = r["g"] if legal(r["g"]) or not legal(r["y"]) else r["y"]
        ok += same(pick, r["truth"])
    out["2b Gemini, YOLO if Gemini illegal"] = ok
    ok = 0
    for r in rows:
        pick = r["y"] if legal(r["y"]) or not legal(r["g"]) else r["g"]
        ok += same(pick, r["truth"])
    out["2b YOLO, Gemini if YOLO illegal"] = ok

    for k, v in out.items():
        print(f"{k}: {v}")
    print()
    for r in rows:
        if not same(r["y"], r["g"]):
            low = [f"{t}:{s:.2f}" for t, s in r["conf"] if s < 0.8]
            print(r["id"], "Y ok" if same(r["y"], r["truth"]) else "Y XX", "G ok" if same(r["g"], r["truth"]) else "G XX",
                  "legalY", legal(r["y"]), "legalG", legal(r["g"]), "low:", low)
    json.dump([{k: v for k, v in r.items()} for r in rows], open(sys.argv[1], "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
