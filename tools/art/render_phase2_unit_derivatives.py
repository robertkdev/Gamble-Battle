#!/usr/bin/env python3
"""Create same-master face and 96 px review derivatives for one Phase 2 unit."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets" / "concepts" / "phase2_calibration"
BOARD_BACKGROUND = (22, 20, 23)


def parse_crop(value: str) -> tuple[int, int, int, int]:
    parts = tuple(int(part.strip()) for part in value.split(","))
    if len(parts) != 4 or parts[2] <= 0 or parts[3] <= 0:
        raise argparse.ArgumentTypeError("crop must be x,y,width,height with positive width and height")
    return parts


def render(unit_id: str, crop: tuple[int, int, int, int]) -> None:
    unit_dir = ASSETS / unit_id
    master_path = unit_dir / f"{unit_id}_master.png"
    if not master_path.exists():
        raise FileNotFoundError(master_path)

    with Image.open(master_path) as source:
        master = source.convert("RGB")

    x, y, width, height = crop
    if x < 0 or y < 0 or x + width > master.width or y + height > master.height:
        raise ValueError(f"face crop {crop} exceeds master size {master.size}")

    face = master.crop((x, y, x + width, y + height))
    face.thumbnail((768, 768), Image.Resampling.LANCZOS)
    face.save(unit_dir / f"{unit_id}_face.png", optimize=True)

    fitted = ImageOps.contain(master, (96, 96), Image.Resampling.LANCZOS)
    board = Image.new("RGB", (96, 96), BOARD_BACKGROUND)
    board.paste(fitted, ((96 - fitted.width) // 2, (96 - fitted.height) // 2))
    board.save(unit_dir / f"{unit_id}_96px.png", optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--unit", required=True)
    parser.add_argument("--face-crop", required=True, type=parse_crop)
    args = parser.parse_args()
    render(args.unit, args.face_crop)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
