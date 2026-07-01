from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from audit_unit_cutout_orange_fringe import alpha_edge_band, checker, safety_orange_residue


ROOT = Path(__file__).resolve().parents[2]


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


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


def edge_clean_delta_stats(before: Image.Image, after: Image.Image, edge_radius: int) -> dict[str, int]:
    before_rgba = np.asarray(before.convert("RGBA"))
    after_rgba = np.asarray(after.convert("RGBA"))
    if before_rgba.shape != after_rgba.shape:
        raise ValueError("before/after images have different shapes")
    alpha = before_rgba[:, :, 3]
    edge = alpha_edge_band(alpha, edge_radius)
    target = safety_orange_residue(before_rgba[:, :, :3]) & edge & (alpha > 0)
    after_orange = safety_orange_residue(after_rgba[:, :, :3]) & edge & (alpha > 0)
    changed_rgb = np.any(before_rgba[:, :, :3] != after_rgba[:, :, :3], axis=2)
    changed_alpha = before_rgba[:, :, 3] != after_rgba[:, :, 3]
    return {
        "target_edge_orange_pixels": int(np.count_nonzero(target)),
        "changed_rgb_pixels": int(np.count_nonzero(changed_rgb)),
        "changed_alpha_pixels": int(np.count_nonzero(changed_alpha)),
        "changed_outside_target_pixels": int(np.count_nonzero(changed_rgb & ~target)),
        "changed_outside_edge_pixels": int(np.count_nonzero(changed_rgb & ~edge)),
        "remaining_edge_orange_pixels": int(np.count_nonzero(after_orange)),
        "removed_edge_orange_pixels": int(np.count_nonzero(target & ~after_orange)),
    }


def edge_clean_delta_contract_errors(
    delta_stats: dict[str, int],
    cleaned_pixels: int,
    require_changed: bool = False,
) -> list[str]:
    errors: list[str] = []
    if delta_stats["target_edge_orange_pixels"] != cleaned_pixels:
        errors.append("reported pixel count does not match target edge-orange pixels")
    if require_changed and delta_stats["changed_rgb_pixels"] <= 0:
        errors.append("no RGB pixels changed")
    if delta_stats["changed_alpha_pixels"] != 0:
        errors.append("alpha pixels changed")
    if delta_stats["changed_outside_target_pixels"] != 0:
        errors.append("pixels outside safety-orange edge target changed")
    if delta_stats["changed_outside_edge_pixels"] != 0:
        errors.append("pixels outside alpha edge band changed")
    if delta_stats["remaining_edge_orange_pixels"] != 0:
        errors.append("safety-orange residue remains in alpha edge band")
    return errors


def assert_edge_clean_delta_contract(
    delta_stats: dict[str, int],
    cleaned_pixels: int,
    require_changed: bool = False,
) -> None:
    errors = edge_clean_delta_contract_errors(delta_stats, cleaned_pixels, require_changed)
    if errors:
        raise ValueError("edge-clean delta contract failed: " + "; ".join(errors))


def stats_output_path(output_path: Path) -> Path:
    return output_path.with_name(f"{output_path.stem}_edgeclean_stats.json")


def edge_clean_stats_payload(
    input_path: Path,
    output_path: Path,
    review_output_path: Path,
    stats_path: Path,
    edge_radius: int,
    cleaned_pixels: int,
    delta_stats: dict[str, int],
) -> dict[str, object]:
    return {
        "tool": "clean_unit_cutout_orange_edge.py",
        "audit_input_contract": "cutout_rgba_pixels_only",
        "edge_clean_contract": "safety_orange_alpha_edge_pixels_only",
        "contract_status": "pass",
        "reference_images_loaded": False,
        "raw_images_loaded": False,
        "board_preview_images_loaded": False,
        "style_anchor_images_loaded": False,
        "input": rel(input_path),
        "output": rel(output_path),
        "review_output": rel(review_output_path),
        "stats_output": rel(stats_path),
        "edge_radius": edge_radius,
        "cleaned_edge_orange_pixels": cleaned_pixels,
        "delta_stats": delta_stats,
    }


def write_stats_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


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
    parser.add_argument("--stats-output", type=Path, help="Optional JSON stats output. Defaults beside --output.")
    parser.add_argument("--edge-radius", type=int, default=4)
    args = parser.parse_args()

    before = Image.open(args.input).convert("RGBA")
    after, cleaned_pixels = clean_edge_orange(before, args.edge_radius)
    delta_stats = edge_clean_delta_stats(before, after, args.edge_radius)
    assert_edge_clean_delta_contract(delta_stats, cleaned_pixels)
    stats_path = args.stats_output if args.stats_output is not None else stats_output_path(args.output)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    after.save(args.output)
    write_review_sheet(args.review_output, before, after, cleaned_pixels, args.edge_radius)
    write_stats_json(
        stats_path,
        edge_clean_stats_payload(
            args.input,
            args.output,
            args.review_output,
            stats_path,
            args.edge_radius,
            cleaned_pixels,
            delta_stats,
        ),
    )

    print(f"cleaned_edge_orange_pixels={cleaned_pixels}")
    for key in [
        "target_edge_orange_pixels",
        "changed_rgb_pixels",
        "changed_alpha_pixels",
        "changed_outside_target_pixels",
        "changed_outside_edge_pixels",
        "remaining_edge_orange_pixels",
        "removed_edge_orange_pixels",
    ]:
        print(f"{key}={delta_stats[key]}")
    print(f"stats_output={stats_path}")
    print(args.output)
    print(args.review_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
