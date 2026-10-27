"""Run open-source YOLO tile detectors on our 33 ground-truth photos."""
import json, os, sys, time
from collections import Counter
from pathlib import Path
import cv2, numpy as np, onnxruntime as ort
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "gemini-test"))
from run_gemini_test import win_type, diff, fmt, INDEX, GT_FILE, PHOTOS  # noqa: E402

# Photos and ONNX weights are not in the repo; see tools/README.md.
PHOTOS = Path(PHOTOS)
GT = json.loads(GT_FILE.read_text(encoding="utf-8"))
YOLOV8_ONNX = os.environ.get("YOLOV8_ONNX", "mahjong_yolov8.onnx")  # majiang_calculator / AR-Mahjong-Assistant
YOLO11_ONNX = os.environ.get("YOLO11_ONNX", "tiles.onnx")  # mahjong-ar
HON = {"EW": "东", "SW": "南", "WW": "西", "NW": "北", "RD": "中", "GD": "发", "WD": "白",
       "E": "东", "S": "南", "W": "西", "N": "北", "C": "中", "F": "发", "P": "白"}


def names_v8(i):  # AR-Mahjong / majiang_calculator, Jon Chan Roboflow classes
    n = ("1B 1C 1D 1F 1S 2B 2C 2D 2F 2S 3B 3C 3D 3F 3S 4B 4C 4D 4F 4S 5B 5C 5D 6B 6C 6D 7B 7C 7D "
         "8B 8C 8D 9B 9C 9D EW GD NW RD SW WD WW").split()[i]
    if n in HON: return HON[n]
    if n[1] in "FS": return None  # flower / season
    return n[0] + {"B": "s", "C": "m", "D": "p"}[n[1]]


def names_ar(i):  # mahjong-ar YOLO11n
    n = ([f"m{k}" for k in range(1, 10)] + [f"p{k}" for k in range(1, 10)] + [f"s{k}" for k in range(1, 10)]
         + ["E", "S", "W", "N", "C", "F", "P"])
    if i >= len(n): return None
    n = n[i]
    return HON.get(n) or n[1] + n[0]


def detect(sess, img, thr, iou=0.45):
    h, w = img.shape[:2]
    s = 640 / max(h, w)
    nh, nw = round(h * s), round(w * s)
    canvas = np.full((640, 640, 3), 114, np.uint8)
    dh, dw = (640 - nh) // 2, (640 - nw) // 2
    canvas[dh:dh + nh, dw:dw + nw] = cv2.resize(img, (nw, nh))
    x = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB).transpose(2, 0, 1)[None].astype(np.float32) / 255
    out = sess.run(None, {"images": x})[0][0]  # 46 x 8400
    sc = out[4:].max(0); cl = out[4:].argmax(0); k = sc >= thr
    b = out[:4, k].T; sc, cl = sc[k], cl[k]
    boxes = np.stack([b[:, 0] - b[:, 2] / 2, b[:, 1] - b[:, 3] / 2, b[:, 0] + b[:, 2] / 2, b[:, 1] + b[:, 3] / 2], 1)
    boxes = (boxes - [dw, dh, dw, dh]) / s
    keep = cv2.dnn.NMSBoxes([[float(a), float(c), float(e - a), float(f - c)] for a, c, e, f in boxes],
                            sc.tolist(), thr, iou) if len(sc) else []
    keep = np.array(keep).flatten()
    return [(boxes[i], float(sc[i]), int(cl[i])) for i in keep]


def recognize(sess, img, two_pass=True, region_thr=0.35, thr=0.5):
    """Mirrors majiang_calculator's LocalTileRecognizer: coarse pass, then zoomed re-detection."""
    first = detect(sess, img, region_thr)
    final = [d for d in first if d[1] >= thr]
    if two_pass and final:
        bx = np.array([d[0] for d in final])
        x1, y1 = bx[:, :2].min(0); x2, y2 = bx[:, 2:].max(0)
        avg_h = (bx[:, 3] - bx[:, 1]).mean()
        pad = max(avg_h * 1.5, max(x2 - x1, y2 - y1) * 0.12)
        H, W = img.shape[:2]
        X1, Y1, X2, Y2 = int(max(0, x1 - pad)), int(max(0, y1 - pad)), int(min(W, x2 + pad)), int(min(H, y2 + pad))
        if not ((X2 - X1) > W * .85 and (Y2 - Y1) > H * .85):
            second = detect(sess, img[Y1:Y2, X1:X2], thr)
            if len(second) >= len(final):
                final = second
    return final


def main():
    models = {
        "yolov8_majiang_calculator": (YOLOV8_ONNX, names_v8),
        "yolo11n_mahjong_ar": (YOLO11_ONNX, names_ar),
    }
    report = {}
    for mname, (path, namefn) in models.items():
        if not Path(path).exists():
            print(mname, "model not found:", path)
            continue
        sess = ort.InferenceSession(path)
        rows = []
        for p in GT["photos"]:
            f = p["file"]
            fp = PHOTOS / f
            img = cv2.imdecode(np.fromfile(str(fp), np.uint8), cv2.IMREAD_COLOR)
            t0 = time.time()
            dets = recognize(sess, img)
            ms = (time.time() - t0) * 1000
            got = [namefn(c) for _, _, c in dets]
            got = [g for g in got if g]
            truth = p["tiles"].split()
            miss, extra = diff(truth, got)
            pred_win = win_type(got) is not None if all(g in INDEX for g in got) else False
            rows.append(dict(id=p["id"], exact=not miss and not extra, n_truth=len(truth), n_got=len(got),
                             miss=" ".join(miss), extra=" ".join(extra), got=fmt(got),
                             pred_win=pred_win, win=p.get("win"), ms=round(ms),
                             low_conf=sum(1 for d in dets if d[1] < 0.7)))
        n = len(rows)
        tile_ok = sum(r["n_truth"] - len(r["miss"].split()) for r in rows)
        tot = sum(r["n_truth"] for r in rows)
        report[mname] = dict(
            exact=sum(r["exact"] for r in rows), n=n,
            win_ok=sum(r["pred_win"] == r["win"] for r in rows if r["win"] is not None),
            win_n=sum(r["win"] is not None for r in rows),
            tiles_found=tile_ok, tiles_total=tot, extra_tiles=sum(len(r["extra"].split()) for r in rows),
            median_ms=sorted(r["ms"] for r in rows)[n // 2], rows=rows)
        print(mname, {k: v for k, v in report[mname].items() if k != "rows"})
        for r in rows:
            print(f"  {r['id']:4} {'OK ' if r['exact'] else 'XX '} truth={r['n_truth']} got={r['n_got']} "
                  f"miss=[{r['miss']}] extra=[{r['extra']}] win {r['pred_win']}/{r['win']}")
    json.dump(report, open(sys.argv[1], "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
