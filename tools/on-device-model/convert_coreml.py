"""Convert the open-source YOLOv8 tile detector (ONNX) to Core ML for the iOS app's on-device recognizer.

The weights come from LYiHub/AR-Mahjong-Assistant-preview and are not kept in the repo. Run this locally and
drop the output into app/MajiangApp/Resources/Models/ (gitignored). See app/README.md.

    pip install torch onnx onnx2torch coremltools onnxruntime numpy
    YOLOV8_ONNX=path/to/weights.onnx python3 tools/on-device-model/convert_coreml.py \
        app/MajiangApp/Resources/Models/MahjongTileDetector.mlpackage

The model keeps its raw output (1 x 46 x 8400: 4 box values + 42 class scores per anchor); the app does
letterboxing, decoding and NMS itself (MajiangKit/Recognition/TileDetection.swift), so any other model only
has to keep the same input/output convention and list its class names in the "names" metadata.
"""
import os
import sys

import coremltools as ct
import numpy as np
import onnx
import onnxruntime as ort
import torch
from onnx2torch import convert

# Jon Chan Roboflow classes, in model order (B = bamboo/条, C = characters/万, D = dots/饼, F/S = flowers/seasons).
NAMES = ("1B 1C 1D 1F 1S 2B 2C 2D 2F 2S 3B 3C 3D 3F 3S 4B 4C 4D 4F 4S 5B 5C 5D 6B 6C 6D 7B 7C 7D "
         "8B 8C 8D 9B 9C 9D EW GD NW RD SW WD WW").split()


def main():
    src = os.environ.get("YOLOV8_ONNX", "mahjong_yolov8.onnx")
    out = sys.argv[1] if len(sys.argv) > 1 else "MahjongTileDetector.mlpackage"

    model = convert(onnx.load(src)).eval()
    example = torch.rand(1, 3, 640, 640)
    with torch.no_grad():
        traced = torch.jit.trace(model, example)

    # Check the PyTorch graph matches ONNX Runtime before converting.
    x = np.random.default_rng(0).random((1, 3, 640, 640), dtype=np.float32)
    ref = ort.InferenceSession(src).run(None, {"images": x})[0]
    with torch.no_grad():
        got = traced(torch.from_numpy(x)).numpy()
    err = float(np.abs(ref - got).max())
    print("max |onnx - torch| =", err)
    assert err < 1e-2, "onnx2torch output differs from ONNX Runtime"

    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="images", shape=(1, 3, 640, 640), dtype=np.float32)],
        outputs=[ct.TensorType(name="output0", dtype=np.float32)],
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
    )
    mlmodel.short_description = "Mahjong tile detector (YOLOv8n, 42 classes)."
    mlmodel.user_defined_metadata["names"] = ",".join(NAMES)
    mlmodel.user_defined_metadata["source"] = "LYiHub/AR-Mahjong-Assistant-preview weights.onnx"
    mlmodel.save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
