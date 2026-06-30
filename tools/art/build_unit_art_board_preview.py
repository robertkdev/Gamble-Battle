from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SCALES = (384, 256, 128, 96, 64)


def checker(size: tuple[int, int], tile: int = 24) -> Image.Image:
    width, height = size
    out = Image.new("RGBA", size, (34, 36, 44, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            if (x // tile + y // tile) % 2 == 0:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(56, 60, 70, 255))
    return out


def label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str) -> None:
    draw.text(xy, text, fill=(235, 236, 240, 255), font=ImageFont.load_default())


def tile(image: Image.Image, size: int, background: Image.Image, caption: str) -> Image.Image:
    pad = 18
    label_h = 26
    out = Image.new("RGBA", (size + pad * 2, size + pad * 2 + label_h), (14, 15, 20, 255))
    bg = background.resize((size, size), Image.Resampling.BICUBIC).convert("RGBA")
    fg = image.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")
    bg.alpha_composite(fg)
    out.alpha_composite(bg, (pad, pad))
    draw = ImageDraw.Draw(out)
    label(draw, (pad, pad + size + 8), caption)
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--title", required=True)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    dark = Image.new("RGBA", image.size, (8, 9, 12, 255))
    white = Image.new("RGBA", image.size, (255, 255, 255, 255))
    check = checker(image.size)

    rows: list[Image.Image] = []
    for name, bg in (("checker", check), ("black", dark), ("white", white)):
        row_tiles = [tile(image, size, bg, f"{name} {size}px") for size in SCALES]
        width = sum(item.width for item in row_tiles)
        height = max(item.height for item in row_tiles)
        row = Image.new("RGBA", (width, height), (14, 15, 20, 255))
        x = 0
        for item in row_tiles:
            row.alpha_composite(item, (x, 0))
            x += item.width
        rows.append(row)

    title_h = 48
    width = max(row.width for row in rows)
    height = title_h + sum(row.height for row in rows)
    sheet = Image.new("RGBA", (width, height), (14, 15, 20, 255))
    draw = ImageDraw.Draw(sheet)
    label(draw, (18, 18), args.title)
    y = title_h
    for row in rows:
        sheet.alpha_composite(row, (0, y))
        y += row.height

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
