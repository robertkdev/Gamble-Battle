from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from audit_unit_cutout_orange_fringe import (
    DEFAULT_RAW_KEY_TOLERANCE,
    alpha_edge_band,
    background_key_residue,
    checker,
    safety_orange_residue,
)


ROOT = Path(__file__).resolve().parents[2]


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def cleanup_target_mask(rgba: np.ndarray, edge_radius: int) -> np.ndarray:
    alpha = rgba[:, :, 3]
    edge = alpha_edge_band(alpha, edge_radius)
    soft_alpha = (alpha > 8) & (alpha < 245)
    return safety_orange_residue(rgba[:, :, :3]) & ((edge & (alpha > 0)) | soft_alpha)


def raw_background_key_target_mask(rgba: np.ndarray, raw_source: Image.Image | None, raw_key_tolerance: int) -> np.ndarray:
    alpha = rgba[:, :, 3]
    target = np.zeros(alpha.shape, dtype=bool)
    if raw_source is None:
        return target
    raw = raw_source.convert("RGB")
    if raw.size != (rgba.shape[1], rgba.shape[0]):
        raise ValueError("raw source and cutout image have different sizes")
    return background_key_residue(np.asarray(raw), raw_key_tolerance) & (alpha > 0)


def clean_edge_orange(image: Image.Image, edge_radius: int) -> tuple[Image.Image, int]:
    after, cleaned_pixels, _raw_key_cleared_pixels = clean_cutout_background(image, edge_radius, None, DEFAULT_RAW_KEY_TOLERANCE)
    return after, cleaned_pixels


def clean_cutout_background(
    image: Image.Image,
    edge_radius: int,
    raw_source: Image.Image | None = None,
    raw_key_tolerance: int = DEFAULT_RAW_KEY_TOLERANCE,
) -> tuple[Image.Image, int, int]:
    rgba = np.asarray(image.convert("RGBA"))
    alpha = rgba[:, :, 3]
    raw_key_target = raw_background_key_target_mask(rgba, raw_source, raw_key_tolerance)
    cleaned_alpha = alpha.copy()
    cleaned_alpha[raw_key_target] = 0

    target_rgba = rgba.copy()
    target_rgba[:, :, 3] = cleaned_alpha
    target = cleanup_target_mask(target_rgba, edge_radius)

    rgb = rgba[:, :, :3].copy().astype(np.float32)
    gray = rgb[:, :, 0] * 0.22 + rgb[:, :, 1] * 0.46 + rgb[:, :, 2] * 0.32
    rgb[target, 0] = gray[target] * 0.24
    rgb[target, 1] = gray[target] * 0.34
    rgb[target, 2] = np.maximum(rgb[target, 2], gray[target] * 0.86)

    cleaned_rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    cleaned_rgb[raw_key_target] = 0

    cleaned = np.dstack((cleaned_rgb, cleaned_alpha))
    return Image.fromarray(cleaned, "RGBA"), int(np.count_nonzero(target)), int(np.count_nonzero(raw_key_target))


def edge_clean_delta_stats(
    before: Image.Image,
    after: Image.Image,
    edge_radius: int,
    raw_source: Image.Image | None = None,
    raw_key_tolerance: int = DEFAULT_RAW_KEY_TOLERANCE,
) -> dict[str, int]:
    before_rgba = np.asarray(before.convert("RGBA"))
    after_rgba = np.asarray(after.convert("RGBA"))
    if before_rgba.shape != after_rgba.shape:
        raise ValueError("before/after images have different shapes")
    alpha = before_rgba[:, :, 3]
    raw_key_target = raw_background_key_target_mask(before_rgba, raw_source, raw_key_tolerance)
    contract_alpha = alpha.copy()
    contract_alpha[raw_key_target] = 0
    edge = alpha_edge_band(contract_alpha, edge_radius)
    soft_alpha = (contract_alpha > 8) & (contract_alpha < 245)
    target_edge = safety_orange_residue(before_rgba[:, :, :3]) & edge & (contract_alpha > 0)
    target_soft = safety_orange_residue(before_rgba[:, :, :3]) & soft_alpha
    target = target_edge | target_soft
    after_alpha = after_rgba[:, :, 3]
    after_orange = safety_orange_residue(after_rgba[:, :, :3]) & (after_alpha > 8)
    after_edge_orange = after_orange & edge
    after_soft_orange = after_orange & soft_alpha
    changed_rgb = np.any(before_rgba[:, :, :3] != after_rgba[:, :, :3], axis=2)
    changed_alpha = before_rgba[:, :, 3] != after_rgba[:, :, 3]
    opaque_interior = (alpha >= 245) & ~edge
    after_raw_key_visible = raw_key_target & (after_rgba[:, :, 3] > 0)
    return {
        "target_edge_orange_pixels": int(np.count_nonzero(target_edge)),
        "target_soft_orange_pixels": int(np.count_nonzero(target_soft)),
        "target_cleanup_pixels": int(np.count_nonzero(target)),
        "target_raw_key_visible_pixels": int(np.count_nonzero(raw_key_target)),
        "changed_rgb_pixels": int(np.count_nonzero(changed_rgb)),
        "changed_alpha_pixels": int(np.count_nonzero(changed_alpha)),
        "changed_outside_target_pixels": int(np.count_nonzero(changed_rgb & ~target)),
        "changed_outside_edge_pixels": int(np.count_nonzero(changed_rgb & ~edge)),
        "changed_opaque_interior_pixels": int(np.count_nonzero(changed_rgb & opaque_interior)),
        "changed_opaque_interior_outside_raw_key_pixels": int(np.count_nonzero(changed_rgb & opaque_interior & ~raw_key_target)),
        "changed_alpha_outside_raw_key_pixels": int(np.count_nonzero(changed_alpha & ~raw_key_target)),
        "remaining_edge_orange_pixels": int(np.count_nonzero(after_edge_orange)),
        "remaining_soft_orange_pixels": int(np.count_nonzero(after_soft_orange)),
        "remaining_raw_key_visible_pixels": int(np.count_nonzero(after_raw_key_visible)),
        "removed_edge_orange_pixels": int(np.count_nonzero(target_edge & ~after_edge_orange)),
        "removed_soft_orange_pixels": int(np.count_nonzero(target_soft & ~after_soft_orange)),
        "removed_cleanup_pixels": int(np.count_nonzero(target & ~after_orange)),
        "cleared_raw_key_visible_pixels": int(np.count_nonzero(raw_key_target & (after_rgba[:, :, 3] == 0))),
    }


def edge_clean_delta_contract_errors(
    delta_stats: dict[str, int],
    cleaned_pixels: int,
    raw_key_cleared_pixels: int = 0,
    require_changed: bool = False,
) -> list[str]:
    errors: list[str] = []
    if delta_stats["target_cleanup_pixels"] != cleaned_pixels:
        errors.append("reported pixel count does not match target cleanup pixels")
    if delta_stats["target_raw_key_visible_pixels"] != raw_key_cleared_pixels:
        errors.append("reported raw-key cleared count does not match raw-key target pixels")
    if require_changed and delta_stats["changed_rgb_pixels"] <= 0:
        errors.append("no RGB pixels changed")
    if raw_key_cleared_pixels <= 0:
        if delta_stats["changed_alpha_pixels"] != 0:
            errors.append("alpha pixels changed")
        if delta_stats["changed_outside_target_pixels"] != 0:
            errors.append("pixels outside safety-orange edge/soft-alpha target changed")
        if delta_stats["changed_opaque_interior_pixels"] != 0:
            errors.append("opaque interior pixels changed")
    else:
        if delta_stats["changed_alpha_outside_raw_key_pixels"] != 0:
            errors.append("alpha pixels outside raw background-key target changed")
        if delta_stats["changed_opaque_interior_outside_raw_key_pixels"] != 0:
            errors.append("opaque interior pixels outside raw background-key target changed")
        if delta_stats["remaining_raw_key_visible_pixels"] != 0:
            errors.append("raw background-key pixels remain visible")
    if delta_stats["remaining_edge_orange_pixels"] != 0:
        errors.append("safety-orange residue remains in alpha edge band")
    if delta_stats["remaining_soft_orange_pixels"] != 0:
        errors.append("safety-orange residue remains in soft-alpha matte")
    return errors


def assert_edge_clean_delta_contract(
    delta_stats: dict[str, int],
    cleaned_pixels: int,
    raw_key_cleared_pixels: int = 0,
    require_changed: bool = False,
) -> None:
    errors = edge_clean_delta_contract_errors(delta_stats, cleaned_pixels, raw_key_cleared_pixels, require_changed)
    if errors:
        raise ValueError("edge-clean delta contract failed: " + "; ".join(errors))


def stats_output_path(output_path: Path) -> Path:
    stem = output_path.stem
    stats_stem = stem if stem.endswith("_edgeclean") else f"{stem}_edgeclean"
    return output_path.with_name(f"{stats_stem}_stats.json")


def edge_clean_stats_payload(
    input_path: Path,
    output_path: Path,
    review_output_path: Path,
    stats_path: Path,
    edge_radius: int,
    cleaned_pixels: int,
    raw_key_cleared_pixels: int,
    delta_stats: dict[str, int],
    raw_source_path: Path | None = None,
    raw_key_tolerance: int = DEFAULT_RAW_KEY_TOLERANCE,
) -> dict[str, object]:
    raw_loaded = raw_source_path is not None
    payload: dict[str, object] = {
        "tool": "clean_unit_cutout_orange_edge.py",
        "audit_input_contract": "cutout_rgba_plus_raw_background_key_pixels" if raw_loaded else "cutout_rgba_pixels_only",
        "edge_clean_contract": "safety_orange_alpha_edge_or_soft_rgb_plus_raw_key_visible_alpha_clear" if raw_loaded else "safety_orange_alpha_edge_or_soft_pixels_only",
        "contract_status": "pass",
        "reference_images_loaded": False,
        "raw_images_loaded": raw_loaded,
        "board_preview_images_loaded": False,
        "style_anchor_images_loaded": False,
        "input": rel(input_path),
        "output": rel(output_path),
        "review_output": rel(review_output_path),
        "stats_output": rel(stats_path),
        "hash_algorithm": "sha256",
        "input_sha256": file_sha256(input_path),
        "output_sha256": file_sha256(output_path),
        "review_output_sha256": file_sha256(review_output_path),
        "edge_radius": edge_radius,
        "raw_key_tolerance": raw_key_tolerance,
        "cleaned_safety_orange_pixels": cleaned_pixels,
        "cleaned_edge_orange_pixels": cleaned_pixels,
        "raw_key_alpha_cleared_pixels": raw_key_cleared_pixels,
        "delta_stats": delta_stats,
    }
    if raw_source_path is not None:
        payload["raw_source"] = rel(raw_source_path)
        payload["raw_source_sha256"] = file_sha256(raw_source_path)
    return payload


def write_stats_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def preview(cutout: Image.Image, background: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = cutout.copy()
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = background.resize(size, Image.Resampling.BICUBIC).convert("RGBA")
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas.convert("RGB")


def overlay_removed(
    before: Image.Image,
    after: Image.Image,
    edge_radius: int,
    size: tuple[int, int],
    raw_source: Image.Image | None = None,
    raw_key_tolerance: int = DEFAULT_RAW_KEY_TOLERANCE,
) -> Image.Image:
    before_rgba = np.asarray(before.convert("RGBA"))
    after_rgba = np.asarray(after.convert("RGBA"))
    before_orange = cleanup_target_mask(before_rgba, edge_radius)
    after_orange = cleanup_target_mask(after_rgba, edge_radius)
    removed = before_orange & ~after_orange
    raw_cleared = raw_background_key_target_mask(before_rgba, raw_source, raw_key_tolerance) & (after_rgba[:, :, 3] == 0)

    overlay = before_rgba.copy()
    overlay[removed, 0] = 255
    overlay[removed, 1] = 0
    overlay[removed, 2] = 0
    overlay[removed, 3] = 255
    overlay[raw_cleared, 0] = 255
    overlay[raw_cleared, 1] = 230
    overlay[raw_cleared, 2] = 0
    overlay[raw_cleared, 3] = 255
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


def write_review_sheet(
    path: Path,
    before: Image.Image,
    after: Image.Image,
    cleaned_pixels: int,
    raw_key_cleared_pixels: int,
    edge_radius: int,
    raw_source: Image.Image | None = None,
    raw_key_tolerance: int = DEFAULT_RAW_KEY_TOLERANCE,
) -> None:
    size = (260, 260)
    black = Image.new("RGBA", size, (0, 0, 0, 255))
    white = Image.new("RGBA", size, (255, 255, 255, 255))
    check = checker(size)
    tiles = [
        label_tile(preview(before, check, size), "before checker"),
        label_tile(preview(after, check, size), "after checker", f"rgb safety: {cleaned_pixels} raw alpha: {raw_key_cleared_pixels}"),
        label_tile(preview(after, black, size), "after black"),
        label_tile(preview(after, white, size), "after white"),
        label_tile(
            overlay_removed(before, after, edge_radius, size, raw_source, raw_key_tolerance),
            "red rgb / yellow raw alpha",
        ),
    ]
    title_h = 42
    sheet = Image.new("RGB", (size[0] * len(tiles), size[1] + 54 + title_h), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 12), "Unit cutout safety-orange post-clean review", font=load_font(16), fill=(255, 222, 120))
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
    parser.add_argument("--raw-source", type=Path, help="Optional matching raw orange-background image. Clears visible raw #f84401 background-key pixels anywhere in the alpha matte.")
    parser.add_argument("--raw-key-tolerance", type=int, default=DEFAULT_RAW_KEY_TOLERANCE)
    parser.add_argument("--edge-radius", type=int, default=4)
    args = parser.parse_args()

    before = Image.open(args.input).convert("RGBA")
    raw_source = Image.open(args.raw_source).convert("RGBA") if args.raw_source else None
    after, cleaned_pixels, raw_key_cleared_pixels = clean_cutout_background(
        before,
        args.edge_radius,
        raw_source,
        args.raw_key_tolerance,
    )
    delta_stats = edge_clean_delta_stats(before, after, args.edge_radius, raw_source, args.raw_key_tolerance)
    assert_edge_clean_delta_contract(delta_stats, cleaned_pixels, raw_key_cleared_pixels)
    stats_path = args.stats_output if args.stats_output is not None else stats_output_path(args.output)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    after.save(args.output)
    write_review_sheet(
        args.review_output,
        before,
        after,
        cleaned_pixels,
        raw_key_cleared_pixels,
        args.edge_radius,
        raw_source,
        args.raw_key_tolerance,
    )
    write_stats_json(
        stats_path,
        edge_clean_stats_payload(
            args.input,
            args.output,
            args.review_output,
            stats_path,
            args.edge_radius,
            cleaned_pixels,
            raw_key_cleared_pixels,
            delta_stats,
            args.raw_source,
            args.raw_key_tolerance,
        ),
    )

    print(f"cleaned_safety_orange_pixels={cleaned_pixels}")
    print(f"cleaned_edge_orange_pixels={cleaned_pixels}")
    print(f"raw_key_alpha_cleared_pixels={raw_key_cleared_pixels}")
    for key in [
        "target_edge_orange_pixels",
        "target_soft_orange_pixels",
        "target_cleanup_pixels",
        "target_raw_key_visible_pixels",
        "changed_rgb_pixels",
        "changed_alpha_pixels",
        "changed_outside_target_pixels",
        "changed_outside_edge_pixels",
        "changed_opaque_interior_pixels",
        "changed_opaque_interior_outside_raw_key_pixels",
        "changed_alpha_outside_raw_key_pixels",
        "remaining_edge_orange_pixels",
        "remaining_soft_orange_pixels",
        "remaining_raw_key_visible_pixels",
        "removed_edge_orange_pixels",
        "removed_soft_orange_pixels",
        "removed_cleanup_pixels",
        "cleared_raw_key_visible_pixels",
    ]:
        print(f"{key}={delta_stats[key]}")
    print(f"stats_output={stats_path}")
    print(args.output)
    print(args.review_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
