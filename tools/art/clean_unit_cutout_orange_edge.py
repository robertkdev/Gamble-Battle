from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from audit_unit_cutout_orange_fringe import alpha_edge_band, checker, safety_orange_residue


def load_font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def clean_edge_orange(image: Image.Image, edge_radius: int) -> tuple[Image.Image, int]:
    rgba = np.asarray(image.convert("RGBA"))
    alpha = rgba[:, :, 3]
    edge = alpha_edge_band(alpha, edge_radius)
    target = safety_orange_residue(rgba[:, :, :3]) & edge & (alpha > 0)

    rgb = rgba[:, :, :3].copy().astype(np.float32)
    gray = rgb[:, :, 0] * 0.22 + rgb[:, :, 1] * 0.46 + rgb[:, :, 2] * 0.32
    rgb[target, 0] = gray[target] * 0.24
    rgb[target, 1] = gray[target] * 0.34
    rgb[target, 2] = np.maximum(rgb[target, 2], gray[target] * 0.86)

    cleaned = np.dstack((np.clip(rgb, 0, 255).astype(np.uint8), alpha))
    return Image.fromarray(cleaned, "RGBA"), int(np.count_nonzero(target))


def preview(cutout: Image.Image, background: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = cutout.copy()
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = background.resize(size, Image.Resampling.BICUBIC).convert("RGBA")
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas.convert("RGB")


def overlay_removed(before: Image.Image, after: Image.Image, edge_radius: int, size: tuple[int, int]) -> Image.Image:
    before_rgba = np.asarray(before.convert("RGBA"))
    after_rgba = np.asarray(after.convert("RGBA"))
    alpha = before_rgba[:, :, 3]
    edge = alpha_edge_band(alpha, edge_radius)
    before_orange = safety_orange_residue(before_rgba[:, :, :3]) & edge & (alpha > 0)
    after_orange = safety_orange_residue(after_rgba[:, :, :3]) & edge & (alpha > 0)
    removed = before_orange & ~after_orange

    overlay = before_rgba.copy()
    overlay[removed, 0] = 255
    overlay[removed, 1] = 0
    overlay[removed, 2] = 0
    overlay[removed, 3] = 255
    image = Image.fromarray(overlay, "RGBA")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 255))
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas.convert("RGB")


def label_tile(tile: Image.Image, label: str, status: str = "") -> Image.Image:
    label_h = 54
    out = Image.new("RGB", (tile.width, tile.height + label_h), (12, 13, 17))
    out.paste(tile.convert("RGB"), (0, 0))
    draw = ImageDraw.Draw(out)
    draw.text((10, tile.height + 8), label[:42], font=load_font(13), fill=(235, 236, 240))
    if status:
        draw.text((10, tile.height + 28), status[:54], font=load_font(11), fill=(190, 190, 200))
    return out


def write_review_sheet(path: Path, before: Image.Image, after: Image.Image, cleaned_pixels: int, edge_radius: int) -> None:
    size = (260, 260)
    black = Image.new("RGBA", size, (0, 0, 0, 255))
    white = Image.new("RGBA", size, (255, 255, 255, 255))
    check = checker(size)
    tiles = [
        label_tile(preview(before, check, size), "before checker"),
        label_tile(preview(after, check, size), "after checker", f"cleaned edge px: {cleaned_pixels}"),
        label_tile(preview(after, black, size), "after black"),
        label_tile(preview(after, white, size), "after white"),
        label_tile(overlay_removed(before, after, edge_radius, size), "red = cleaned edge residue"),
    ]
    title_h = 42
    sheet = Image.new("RGB", (size[0] * len(tiles), size[1] + 54 + title_h), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 12), "Unit cutout edge-orange post-clean review", font=load_font(16), fill=(255, 222, 120))
    x = 0
    for tile in tiles:
        sheet.paste(tile, (x, title_h))
        x += tile.width
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--review-output", required=True, type=Path)
    parser.add_argument("--edge-radius", type=int, default=4)
    args = parser.parse_args()

    before = Image.open(args.input).convert("RGBA")
    after, cleaned_pixels = clean_edge_orange(before, args.edge_radius)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    after.save(args.output)
    write_review_sheet(args.review_output, before, after, cleaned_pixels, args.edge_radius)

    print(f"cleaned_edge_orange_pixels={cleaned_pixels}")
    print(args.output)
    print(args.review_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
