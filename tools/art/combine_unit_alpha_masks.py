from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def checker(size: tuple[int, int], tile: int = 32) -> Image.Image:
    width, height = size
    out = Image.new("RGBA", size, (46, 50, 60, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            if (x // tile + y // tile) % 2 == 0:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(25, 28, 36, 255))
    return out


def preview_tile(cutout: Image.Image, background: Image.Image, label: str, tile_size: int) -> Image.Image:
    tile = Image.new("RGBA", (tile_size, tile_size + 46), (18, 19, 24, 255))
    bg = background.resize((tile_size, tile_size), Image.Resampling.BICUBIC).convert("RGBA")
    fg = cutout.resize((tile_size, tile_size), Image.Resampling.LANCZOS)
    bg.alpha_composite(fg)
    tile.alpha_composite(bg, (0, 0))
    draw = ImageDraw.Draw(tile)
    draw.rectangle((0, tile_size, tile_size, tile_size + 46), fill=(12, 13, 17, 255))
    draw.text((14, tile_size + 14), label, fill=(235, 236, 240, 255))
    return tile


def make_review(raw: Image.Image, mask: Image.Image, cutout: Image.Image, output: Path) -> None:
    tile_size = 384
    raw_tile = preview_tile(raw.convert("RGBA"), Image.new("RGBA", raw.size, (0, 0, 0, 0)), "raw", tile_size)
    mask_rgba = Image.merge("RGBA", (mask, mask, mask, Image.new("L", mask.size, 255)))
    mask_tile = preview_tile(mask_rgba, Image.new("RGBA", mask.size, (0, 0, 0, 0)), "combined alpha", tile_size)
    tiles = [
        raw_tile,
        mask_tile,
        preview_tile(cutout, checker(cutout.size), "checker preview", tile_size),
        preview_tile(cutout, Image.new("RGBA", cutout.size, (0, 0, 0, 255)), "black preview", tile_size),
        preview_tile(cutout, Image.new("RGBA", cutout.size, (255, 255, 255, 255)), "white preview", tile_size),
    ]
    sheet = Image.new("RGBA", (tile_size * len(tiles), tile_size + 46), (18, 19, 24, 255))
    for index, tile in enumerate(tiles):
        sheet.alpha_composite(tile, (index * tile_size, 0))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--primary-mask", required=True, type=Path)
    parser.add_argument("--rescue-mask", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mask-output", required=True, type=Path)
    parser.add_argument("--review-output", type=Path)
    parser.add_argument("--mode", default="union", choices=["union", "primary", "rescue"])
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    primary = Image.open(args.primary_mask).convert("L").resize(source.size, Image.Resampling.LANCZOS)
    rescue = Image.open(args.rescue_mask).convert("L").resize(source.size, Image.Resampling.NEAREST)

    primary_arr = np.asarray(primary).astype(np.uint8)
    rescue_arr = np.asarray(rescue).astype(np.uint8)
    if args.mode == "union":
        alpha_arr = np.maximum(primary_arr, rescue_arr)
    elif args.mode == "primary":
        alpha_arr = primary_arr
    else:
        alpha_arr = rescue_arr

    alpha = Image.fromarray(alpha_arr, "L")
    cutout = source.copy()
    cutout.putalpha(alpha)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.mask_output.parent.mkdir(parents=True, exist_ok=True)
    cutout.save(args.output)
    alpha.save(args.mask_output)
    if args.review_output is not None:
        make_review(source, alpha, cutout, args.review_output)

    print(args.output)
    print(args.mask_output)
    if args.review_output is not None:
        print(args.review_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
