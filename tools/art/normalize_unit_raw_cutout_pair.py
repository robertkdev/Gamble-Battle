from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.convert("RGBA"))[:, :, 3]
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0 or len(ys) == 0:
        raise ValueError("cutout has no visible alpha pixels")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def normalize_pair(
    raw: Image.Image,
    cutout: Image.Image,
    canvas_size: int,
    padding: int,
) -> tuple[Image.Image, Image.Image, dict[str, object]]:
    raw_rgba = raw.convert("RGBA")
    cutout_rgba = cutout.convert("RGBA")
    if raw_rgba.size != cutout_rgba.size:
        raise ValueError(f"raw and cutout sizes differ: raw={raw_rgba.size} cutout={cutout_rgba.size}")

    bbox = alpha_bbox(cutout_rgba)
    crop_w = bbox[2] - bbox[0]
    crop_h = bbox[3] - bbox[1]
    if crop_w <= 0 or crop_h <= 0:
        raise ValueError(f"invalid alpha bbox: {bbox}")

    max_size = canvas_size - padding * 2
    if max_size <= 0:
        raise ValueError("padding leaves no drawable canvas")
    scale = min(max_size / crop_w, max_size / crop_h)
    new_size = (max(1, round(crop_w * scale)), max(1, round(crop_h * scale)))
    paste_xy = ((canvas_size - new_size[0]) // 2, canvas_size - padding - new_size[1])

    raw_crop = raw_rgba.crop(bbox).resize(new_size, Image.Resampling.LANCZOS)
    cutout_crop = cutout_rgba.crop(bbox).resize(new_size, Image.Resampling.LANCZOS)
    raw_canvas = Image.new("RGBA", (canvas_size, canvas_size), (248, 68, 1, 255))
    cutout_canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    raw_canvas.alpha_composite(raw_crop, paste_xy)
    cutout_canvas.alpha_composite(cutout_crop, paste_xy)

    manifest: dict[str, object] = {
        "alpha_bbox": list(bbox),
        "source_size": list(raw_rgba.size),
        "crop_size": [crop_w, crop_h],
        "canvas_size": canvas_size,
        "padding": padding,
        "scale": scale,
        "normalized_size": list(new_size),
        "paste_xy": list(paste_xy),
        "contract": "raw and cutout were cropped, resized, and pasted with identical geometry",
    }
    return raw_canvas, cutout_canvas, manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True, type=Path)
    parser.add_argument("--cutout", required=True, type=Path)
    parser.add_argument("--raw-output", required=True, type=Path)
    parser.add_argument("--cutout-output", required=True, type=Path)
    parser.add_argument("--manifest-output", type=Path)
    parser.add_argument("--canvas-size", type=int, default=1024)
    parser.add_argument("--padding", type=int, default=56)
    args = parser.parse_args()

    raw = Image.open(args.raw)
    cutout = Image.open(args.cutout)
    raw_canvas, cutout_canvas, manifest = normalize_pair(raw, cutout, args.canvas_size, args.padding)
    args.raw_output.parent.mkdir(parents=True, exist_ok=True)
    args.cutout_output.parent.mkdir(parents=True, exist_ok=True)
    raw_canvas.save(args.raw_output)
    cutout_canvas.save(args.cutout_output)

    manifest["raw"] = rel(args.raw)
    manifest["cutout"] = rel(args.cutout)
    manifest["raw_output"] = rel(args.raw_output)
    manifest["cutout_output"] = rel(args.cutout_output)
    if args.manifest_output is not None:
        args.manifest_output.parent.mkdir(parents=True, exist_ok=True)
        args.manifest_output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        manifest["manifest_output"] = rel(args.manifest_output)

    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
