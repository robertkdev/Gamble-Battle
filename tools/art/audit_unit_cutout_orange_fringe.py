from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"cutout_orange_fringe_audit_{date.today().strftime('%Y_%m_%d')}"
SAFETY_ORANGE_KEY = np.array([248, 68, 1], dtype=np.int16)
DEFAULT_RAW_KEY_TOLERANCE = 64


@dataclass(frozen=True)
class CutoutAuditRow:
    id: str
    display_name: str
    proof_status: str
    reference_role: str
    source_kind: str
    cutout: str
    raw_source: str
    quality_status: str
    issue: str
    visible_pixels: int
    alpha_edge_pixels: int
    soft_alpha_pixels: int
    orange_pixels: int
    edge_orange_pixels: int
    soft_orange_pixels: int
    edge_orange_ratio: float
    raw_key_visible_pixels: int
    raw_key_edge_pixels: int
    raw_key_soft_pixels: int
    raw_key_opaque_interior_pixels: int
    visual_fringe_pixels: int
    visual_orange_fringe_pixels: int
    visual_blue_fringe_pixels: int
    raw_edge_orange_pixels: int


def rel(path: str | Path) -> str:
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    try:
        return candidate.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(candidate)


def resolve_image_path(path_text: str | Path) -> Path:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    return path


def load_font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def checker(size: tuple[int, int], tile: int = 24) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size, (46, 50, 60, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            if (x // tile + y // tile) % 2 == 0:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(25, 28, 36, 255))
    return image


def safety_orange_residue(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    orange_like = (
        (red > 175)
        & (green > 35)
        & (green < 170)
        & (blue < 115)
        & ((red - green) > 42)
        & ((green - blue) > 10)
    )
    saturated = ((red.astype(np.float32) - blue.astype(np.float32)) / np.maximum(red.astype(np.float32), 1.0)) > 0.35
    return orange_like & saturated


def background_orange_field_residue(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    orange_like = (
        (red > 88)
        & (green > 18)
        & (green < 190)
        & (blue < 155)
        & ((red - green) > 12)
        & ((green - blue) > -10)
    )
    warm_saturated = ((red.astype(np.float32) - blue.astype(np.float32)) / np.maximum(red.astype(np.float32), 1.0)) > 0.22
    return orange_like & warm_saturated


def cool_blue_fringe_residue(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    blue_lift = blue - np.maximum(red, green)
    saturation = (blue.astype(np.float32) - np.minimum(red, green).astype(np.float32)) / np.maximum(blue.astype(np.float32), 1.0)
    return (blue > 70) & (blue_lift > 12) & ((blue - red) > 28) & (saturation > 0.22)


def background_key_residue(rgb: np.ndarray, tolerance: int = DEFAULT_RAW_KEY_TOLERANCE) -> np.ndarray:
    values = rgb.astype(np.float32)
    key = SAFETY_ORANGE_KEY.astype(np.float32)
    distance = np.sqrt(np.sum((values - key) ** 2, axis=2))
    return distance <= tolerance


def border_connected_mask(mask: np.ndarray) -> np.ndarray:
    """Return only mask pixels connected to an image border."""
    try:
        from scipy import ndimage

        seed = np.zeros(mask.shape, dtype=bool)
        seed[0, :] = mask[0, :]
        seed[-1, :] = mask[-1, :]
        seed[:, 0] = mask[:, 0]
        seed[:, -1] = mask[:, -1]
        return ndimage.binary_propagation(seed, mask=mask)
    except Exception:
        from collections import deque

        height, width = mask.shape
        connected = np.zeros(mask.shape, dtype=bool)
        queue: deque[tuple[int, int]] = deque()
        for x in range(width):
            for y in (0, height - 1):
                if mask[y, x] and not connected[y, x]:
                    connected[y, x] = True
                    queue.append((y, x))
        for y in range(height):
            for x in (0, width - 1):
                if mask[y, x] and not connected[y, x]:
                    connected[y, x] = True
                    queue.append((y, x))
        while queue:
            y, x = queue.popleft()
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    if mask[ny, nx] and not connected[ny, nx]:
                        connected[ny, nx] = True
                        queue.append((ny, nx))
        return connected


def raw_background_field_residue(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)
    peak = np.maximum(np.maximum(red, green), blue).astype(np.float32)
    valley = np.minimum(np.minimum(red, green), blue).astype(np.float32)
    saturation = (peak - valley) / np.maximum(peak, 1.0)
    orange_field = (
        (red > 120)
        & (red >= green)
        & (red >= blue)
        & (green < 125)
        & (blue < 95)
        & ((red - green) > 35)
        & ((red - blue) > 80)
        & (saturation > 0.55)
    )
    return border_connected_mask(orange_field)


def raw_background_residue(rgb: np.ndarray, tolerance: int = DEFAULT_RAW_KEY_TOLERANCE) -> np.ndarray:
    return background_key_residue(rgb, tolerance) | raw_background_field_residue(rgb)


def alpha_edge_band(alpha: np.ndarray, radius: int) -> np.ndarray:
    foreground = Image.fromarray(np.where(alpha > 8, 255, 0).astype(np.uint8), "L")
    filter_size = max(3, radius * 2 + 1)
    if filter_size % 2 == 0:
        filter_size += 1
    dilated = np.asarray(foreground.filter(ImageFilter.MaxFilter(filter_size))) > 0
    eroded = np.asarray(foreground.filter(ImageFilter.MinFilter(filter_size))) > 0
    return dilated & ~eroded


def component_boxes(mask: np.ndarray, min_pixels: int = 18, max_boxes: int = 80) -> list[tuple[int, int, int, int, int]]:
    height, width = mask.shape
    visited = np.zeros(mask.shape, dtype=bool)
    boxes: list[tuple[int, int, int, int, int]] = []
    points = np.argwhere(mask)
    for y0, x0 in points:
        if visited[y0, x0] or not mask[y0, x0]:
            continue
        stack: list[tuple[int, int]] = [(int(y0), int(x0))]
        visited[y0, x0] = True
        min_x = int(x0)
        max_x = int(x0)
        min_y = int(y0)
        max_y = int(y0)
        count = 0
        while stack:
            y, x = stack.pop()
            count += 1
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)
            for ny in range(max(0, y - 1), min(height, y + 2)):
                for nx in range(max(0, x - 1), min(width, x + 2)):
                    if not visited[ny, nx] and mask[ny, nx]:
                        visited[ny, nx] = True
                        stack.append((ny, nx))
        if count >= min_pixels:
            boxes.append((min_x, min_y, max_x, max_y, count))
    boxes.sort(key=lambda item: item[4], reverse=True)
    return boxes[:max_boxes]


def background_residue_masks(
    rgba: np.ndarray,
    edge_radius: int,
    raw_rgb: np.ndarray | None = None,
    raw_key_tolerance: int = DEFAULT_RAW_KEY_TOLERANCE,
) -> dict[str, np.ndarray]:
    alpha = rgba[:, :, 3]
    visible = alpha > 8
    soft_alpha = (alpha > 8) & (alpha < 245)
    edge = alpha_edge_band(alpha, edge_radius)
    near_matte_boundary = visible & (edge | soft_alpha)

    cutout_rgb = rgba[:, :, :3]
    cutout_orange_field = background_orange_field_residue(cutout_rgb)
    cutout_blue_field = cool_blue_fringe_residue(cutout_rgb)
    orange = safety_orange_residue(cutout_rgb) & visible
    edge_orange = orange & edge
    soft_orange = orange & soft_alpha
    raw_key_visible = np.zeros(alpha.shape, dtype=bool)
    raw_key_edge = np.zeros(alpha.shape, dtype=bool)
    raw_key_soft = np.zeros(alpha.shape, dtype=bool)
    raw_key_opaque_interior = np.zeros(alpha.shape, dtype=bool)
    raw_edge_orange = np.zeros(alpha.shape, dtype=bool)

    if raw_rgb is not None:
        raw_key = raw_background_residue(raw_rgb, raw_key_tolerance)
        raw_key_visible = raw_key & visible
        raw_key_edge = raw_key_visible & edge
        raw_key_soft = raw_key_visible & soft_alpha
        raw_key_opaque_interior = raw_key_visible & (alpha >= 245) & ~edge
        raw_edge_orange = raw_key & near_matte_boundary & (cutout_orange_field | cutout_blue_field | soft_alpha)

    cutout_orange_fringe = cutout_orange_field & near_matte_boundary
    # Without raw backing, only exact safety-orange-like pixels are trusted as orange fringe.
    # Raw-backed mode relies on the raw border-connected field for darker spill so
    # intentional warm foreground art at the silhouette is not treated as a leak.
    cutout_orange_fringe &= safety_orange_residue(cutout_rgb)

    cutout_blue_fringe = cutout_blue_field & near_matte_boundary
    if raw_rgb is not None:
        cutout_blue_fringe &= raw_key
    visual_orange_fringe = cutout_orange_fringe | raw_edge_orange
    visual_fringe = visual_orange_fringe | cutout_blue_fringe

    return {
        "visible": visible,
        "soft_alpha": soft_alpha,
        "edge": edge,
        "orange": orange,
        "edge_orange": edge_orange,
        "soft_orange": soft_orange,
        "raw_key_visible": raw_key_visible,
        "raw_key_edge": raw_key_edge,
        "raw_key_soft": raw_key_soft,
        "raw_key_opaque_interior": raw_key_opaque_interior,
        "raw_edge_orange": raw_edge_orange,
        "visual_orange_fringe": visual_orange_fringe,
        "visual_blue_fringe": cutout_blue_fringe,
        "visual_fringe": visual_fringe,
    }


def issue_for_metrics(
    edge_orange_pixels: int,
    soft_orange_pixels: int,
    edge_orange_ratio: float,
    raw_key_visible_pixels: int,
    visual_fringe_pixels: int,
    max_edge_orange_pixels: int,
    max_soft_orange_pixels: int,
    max_edge_orange_ratio: float,
    max_raw_key_visible_pixels: int | None,
    max_visual_fringe_pixels: int | None,
) -> str:
    issues: list[str] = []
    if edge_orange_pixels > max_edge_orange_pixels:
        issues.append("edge_background_orange_contamination")
    if edge_orange_ratio > max_edge_orange_ratio:
        issues.append("edge_background_orange_ratio_contamination")
    if soft_orange_pixels > max_soft_orange_pixels:
        issues.append("soft_alpha_background_orange_contamination")
    if max_raw_key_visible_pixels is not None and raw_key_visible_pixels > max_raw_key_visible_pixels:
        issues.append("raw_key_visible_background_contamination")
    if max_visual_fringe_pixels is not None and visual_fringe_pixels > max_visual_fringe_pixels:
        issues.append("visual_background_fringe_contamination")
    return ", ".join(issues)


def audit_cutout(
    cutout_path: str,
    raw_source_path: str | None,
    row_id: str,
    display_name: str,
    proof_status: str,
    reference_role: str,
    source_kind: str,
    edge_radius: int,
    max_edge_orange_pixels: int,
    max_soft_orange_pixels: int,
    max_edge_orange_ratio: float,
    max_raw_key_visible_pixels: int | None,
    max_visual_fringe_pixels: int | None,
    raw_key_tolerance: int,
) -> CutoutAuditRow:
    path = resolve_image_path(cutout_path)
    cutout_ref = rel(path)
    raw_ref = rel(raw_source_path) if raw_source_path else ""
    if not path.exists():
        return CutoutAuditRow(
            id=row_id,
            display_name=display_name,
            proof_status=proof_status,
            reference_role=reference_role,
            source_kind=source_kind,
            cutout=cutout_ref,
            raw_source=raw_ref,
            quality_status="fail",
            issue="missing_cutout",
            visible_pixels=0,
            alpha_edge_pixels=0,
            soft_alpha_pixels=0,
            orange_pixels=0,
            edge_orange_pixels=0,
            soft_orange_pixels=0,
            edge_orange_ratio=1.0,
            raw_key_visible_pixels=0,
            raw_key_edge_pixels=0,
            raw_key_soft_pixels=0,
            raw_key_opaque_interior_pixels=0,
            visual_fringe_pixels=0,
            visual_orange_fringe_pixels=0,
            visual_blue_fringe_pixels=0,
            raw_edge_orange_pixels=0,
        )

    image = Image.open(path).convert("RGBA")
    rgba = np.asarray(image)
    raw_rgb: np.ndarray | None = None
    raw_issue = ""
    if raw_source_path:
        raw_path = resolve_image_path(raw_source_path)
        raw_ref = rel(raw_path)
        if not raw_path.exists():
            raw_issue = "missing_raw_source"
        else:
            raw_image = Image.open(raw_path).convert("RGB")
            if raw_image.size != image.size:
                raw_issue = "raw_source_size_mismatch"
            else:
                raw_rgb = np.asarray(raw_image)

    masks = background_residue_masks(rgba, edge_radius, raw_rgb, raw_key_tolerance)
    edge_pixels = int(np.count_nonzero(masks["edge"]))
    edge_orange_pixels = int(np.count_nonzero(masks["edge_orange"]))
    soft_orange_pixels = int(np.count_nonzero(masks["soft_orange"]))
    edge_orange_ratio = edge_orange_pixels / max(edge_pixels, 1)
    raw_key_visible_pixels = int(np.count_nonzero(masks["raw_key_visible"]))
    raw_key_edge_pixels = int(np.count_nonzero(masks["raw_key_edge"]))
    raw_key_soft_pixels = int(np.count_nonzero(masks["raw_key_soft"]))
    raw_key_opaque_interior_pixels = int(np.count_nonzero(masks["raw_key_opaque_interior"]))
    visual_fringe_pixels = int(np.count_nonzero(masks["visual_fringe"]))
    visual_orange_fringe_pixels = int(np.count_nonzero(masks["visual_orange_fringe"]))
    visual_blue_fringe_pixels = int(np.count_nonzero(masks["visual_blue_fringe"]))
    raw_edge_orange_pixels = int(np.count_nonzero(masks["raw_edge_orange"]))

    issue = issue_for_metrics(
        edge_orange_pixels,
        soft_orange_pixels,
        edge_orange_ratio,
        raw_key_visible_pixels,
        visual_fringe_pixels,
        max_edge_orange_pixels,
        max_soft_orange_pixels,
        max_edge_orange_ratio,
        max_raw_key_visible_pixels if raw_source_path and not raw_issue else None,
        max_visual_fringe_pixels,
    )
    if raw_issue:
        issue = ", ".join(part for part in (issue, raw_issue) if part)
    return CutoutAuditRow(
        id=row_id,
        display_name=display_name,
        proof_status=proof_status,
        reference_role=reference_role,
        source_kind=source_kind,
        cutout=cutout_ref,
        raw_source=raw_ref,
        quality_status="fail" if issue else "pass",
        issue=issue,
        visible_pixels=int(np.count_nonzero(masks["visible"])),
        alpha_edge_pixels=edge_pixels,
        soft_alpha_pixels=int(np.count_nonzero(masks["soft_alpha"])),
        orange_pixels=int(np.count_nonzero(masks["orange"])),
        edge_orange_pixels=edge_orange_pixels,
        soft_orange_pixels=soft_orange_pixels,
        edge_orange_ratio=edge_orange_ratio,
        raw_key_visible_pixels=raw_key_visible_pixels,
        raw_key_edge_pixels=raw_key_edge_pixels,
        raw_key_soft_pixels=raw_key_soft_pixels,
        raw_key_opaque_interior_pixels=raw_key_opaque_interior_pixels,
        visual_fringe_pixels=visual_fringe_pixels,
        visual_orange_fringe_pixels=visual_orange_fringe_pixels,
        visual_blue_fringe_pixels=visual_blue_fringe_pixels,
        raw_edge_orange_pixels=raw_edge_orange_pixels,
    )


def row_to_dict(row: CutoutAuditRow) -> dict[str, str]:
    return {
        "id": row.id,
        "display_name": row.display_name,
        "proof_status": row.proof_status,
        "reference_role": row.reference_role,
        "source_kind": row.source_kind,
        "cutout": row.cutout,
        "raw_source": row.raw_source,
        "quality_status": row.quality_status,
        "issue": row.issue,
        "visible_pixels": str(row.visible_pixels),
        "alpha_edge_pixels": str(row.alpha_edge_pixels),
        "soft_alpha_pixels": str(row.soft_alpha_pixels),
        "orange_pixels": str(row.orange_pixels),
        "edge_orange_pixels": str(row.edge_orange_pixels),
        "soft_orange_pixels": str(row.soft_orange_pixels),
        "edge_orange_ratio": f"{row.edge_orange_ratio:.6f}",
        "raw_key_visible_pixels": str(row.raw_key_visible_pixels),
        "raw_key_edge_pixels": str(row.raw_key_edge_pixels),
        "raw_key_soft_pixels": str(row.raw_key_soft_pixels),
        "raw_key_opaque_interior_pixels": str(row.raw_key_opaque_interior_pixels),
        "visual_fringe_pixels": str(row.visual_fringe_pixels),
        "visual_orange_fringe_pixels": str(row.visual_orange_fringe_pixels),
        "visual_blue_fringe_pixels": str(row.visual_blue_fringe_pixels),
        "raw_edge_orange_pixels": str(row.raw_edge_orange_pixels),
    }


def standalone_cutout_rows(args: argparse.Namespace) -> list[CutoutAuditRow]:
    rows: list[CutoutAuditRow] = []
    for index, cutout in enumerate(args.cutout):
        row_id = args.cutout_id[index] if index < len(args.cutout_id) else f"standalone_cutout_{index + 1}"
        label = args.cutout_label[index] if index < len(args.cutout_label) else row_id
        raw_source = args.raw_source[index] if index < len(args.raw_source) else None
        rows.append(
            audit_cutout(
                str(cutout),
                str(raw_source) if raw_source is not None else None,
                str(row_id),
                str(label),
                "standalone",
                "none",
                "standalone_cutout",
                args.edge_radius,
                args.max_edge_orange_pixels,
                args.max_soft_orange_pixels,
                args.max_edge_orange_ratio,
                args.max_raw_key_visible_pixels,
                args.max_visual_fringe_pixels,
                args.raw_key_tolerance,
            )
        )
    return rows


def collect_rows(args: argparse.Namespace) -> list[CutoutAuditRow]:
    rows: list[CutoutAuditRow] = []

    if args.include_proof_matrix:
        proof_data = json.loads(args.proof_matrix.read_text(encoding="utf-8"))
        for proof in proof_data.get("proofs", []):
            if not isinstance(proof, dict):
                continue
            cutout = str(proof.get("cutout", ""))
            if not cutout:
                continue
            raw_source = str(proof.get("raw", "")) if args.use_proof_raw_source else None
            rows.append(
                audit_cutout(
                    cutout,
                    raw_source if raw_source else None,
                    str(proof.get("id", "")),
                    str(proof.get("display_name", proof.get("subject_id", ""))),
                    str(proof.get("status", "")),
                    str(proof.get("reference_role", "")),
                    "proof_matrix_cutout",
                    args.edge_radius,
                    args.max_edge_orange_pixels,
                    args.max_soft_orange_pixels,
                    args.max_edge_orange_ratio,
                    args.max_raw_key_visible_pixels,
                    args.max_visual_fringe_pixels,
                    args.raw_key_tolerance,
                )
            )
    rows.extend(standalone_cutout_rows(args))
    return rows


def write_csv(path: Path, rows: list[CutoutAuditRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(row_to_dict(rows[0]).keys()) if rows else ["id"]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row_to_dict(row))


def write_manifest(path: Path, rows: list[CutoutAuditRow], report_date: str, args: argparse.Namespace) -> None:
    raw_images_loaded = any(row.raw_source for row in rows)
    manifest = {
        "schema_version": 1,
        "report_date": report_date,
        "audit_input_contract": "cutout_rgba_plus_raw_background_key_pixels_plus_visual_background_fringe" if raw_images_loaded else "cutout_rgba_pixels_only",
        "reference_images_loaded": False,
        "raw_images_loaded": raw_images_loaded,
        "board_preview_images_loaded": False,
        "style_anchor_images_loaded": False,
        "proof_matrix_loaded_for_cutout_paths": bool(args.include_proof_matrix),
        "standalone_cutout_count": len(args.cutout),
        "standalone_raw_source_count": len(args.raw_source),
        "proof_matrix_raw_source_loaded": bool(args.include_proof_matrix and args.use_proof_raw_source),
        "row_count": len(rows),
        "source_kinds": sorted({row.source_kind for row in rows}),
        "thresholds": {
            "edge_radius": args.edge_radius,
            "max_edge_orange_pixels": args.max_edge_orange_pixels,
            "max_soft_orange_pixels": args.max_soft_orange_pixels,
            "max_edge_orange_ratio": args.max_edge_orange_ratio,
            "max_raw_key_visible_pixels": args.max_raw_key_visible_pixels,
            "max_visual_fringe_pixels": args.max_visual_fringe_pixels,
            "raw_key_tolerance": args.raw_key_tolerance,
        },
        "cutout_ids": [row.id for row in rows],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def compose_preview(cutout_path: str, background: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = Image.open(resolve_image_path(cutout_path)).convert("RGBA")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = background.resize(size, Image.Resampling.BICUBIC).convert("RGBA")
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas.convert("RGB")


def orange_overlay(cutout_path: str, raw_source_path: str, size: tuple[int, int], edge_radius: int, raw_key_tolerance: int) -> Image.Image:
    image = Image.open(resolve_image_path(cutout_path)).convert("RGBA")
    rgba = np.asarray(image)
    raw_rgb: np.ndarray | None = None
    if raw_source_path:
        raw_path = resolve_image_path(raw_source_path)
        if raw_path.exists():
            raw_image = Image.open(raw_path).convert("RGB")
            if raw_image.size == image.size:
                raw_rgb = np.asarray(raw_image)
    masks = background_residue_masks(rgba, edge_radius, raw_rgb, raw_key_tolerance)
    base = Image.new("RGBA", image.size, (0, 0, 0, 255))
    base.alpha_composite(image)
    overlay = np.asarray(base).copy()
    cutout_orange = masks["edge_orange"] | masks["soft_orange"]
    visual_orange = masks["visual_orange_fringe"] & ~masks["raw_key_visible"]
    visual_blue = masks["visual_blue_fringe"]
    raw_key_visible = masks["raw_key_visible"]
    overlay[cutout_orange] = [255, 0, 0, 255]
    overlay[visual_orange] = [255, 0, 220, 255]
    overlay[visual_blue] = [0, 210, 255, 255]
    overlay[raw_key_visible] = [255, 230, 0, 255]
    result = Image.fromarray(overlay, "RGBA")
    draw = ImageDraw.Draw(result)
    proof_mask = cutout_orange | visual_orange | visual_blue | raw_key_visible
    for left, top, right, bottom, count in component_boxes(proof_mask):
        pad = max(3, min(10, int(count ** 0.35)))
        draw.rounded_rectangle(
            (max(0, left - pad), max(0, top - pad), min(image.width - 1, right + pad), min(image.height - 1, bottom + pad)),
            radius=pad,
            outline=(255, 255, 255, 255),
            width=2,
        )
    result.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 255))
    canvas.alpha_composite(result, ((size[0] - result.width) // 2, (size[1] - result.height) // 2))
    return canvas.convert("RGB")


def write_review_sheet(path: Path, rows: list[CutoutAuditRow], edge_radius: int, raw_key_tolerance: int) -> None:
    failing_rows = [row for row in rows if row.quality_status == "fail"]
    top_rows = sorted(rows, key=lambda row: row.edge_orange_pixels + row.soft_orange_pixels + row.raw_key_visible_pixels + row.visual_fringe_pixels, reverse=True)
    selected: list[CutoutAuditRow] = []
    for row in failing_rows + top_rows:
        if row not in selected and row.cutout and resolve_image_path(row.cutout).exists():
            selected.append(row)
        if len(selected) >= 12:
            break

    tile = (210, 210)
    label_h = 74
    columns = 4
    row_h = tile[1] + label_h
    width = tile[0] * columns
    height = row_h * max(1, len(selected)) + 52
    sheet = Image.new("RGB", (width, height), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    title_font = load_font(18)
    small_font = load_font(12)
    draw.text((12, 14), "Objective Cutout Background Audit: checker / black / white / overlay (red=safety orange, yellow=raw key/field, magenta=orange field, cyan=blue spill)", font=title_font, fill=(255, 222, 120))

    backgrounds = [
        checker(tile),
        Image.new("RGBA", tile, (0, 0, 0, 255)),
        Image.new("RGBA", tile, (255, 255, 255, 255)),
    ]
    for index, row in enumerate(selected):
        y = 52 + index * row_h
        previews = [
            compose_preview(row.cutout, backgrounds[0], tile),
            compose_preview(row.cutout, backgrounds[1], tile),
            compose_preview(row.cutout, backgrounds[2], tile),
            orange_overlay(row.cutout, row.raw_source, tile, edge_radius, raw_key_tolerance),
        ]
        for column, preview in enumerate(previews):
            sheet.paste(preview, (column * tile[0], y))
        label = f"{row.id} | {row.quality_status} | edge {row.edge_orange_pixels} soft {row.soft_orange_pixels} raw-key {row.raw_key_visible_pixels} visual {row.visual_fringe_pixels}"
        draw.rectangle((0, y + tile[1], width, y + row_h), fill=(12, 13, 17))
        draw.text((10, y + tile[1] + 8), label[:118], font=small_font, fill=(235, 236, 240))
        issue = row.issue or "no measurable safety-orange contamination in the active cutout/raw-key gate"
        draw.text((10, y + tile[1] + 30), issue[:132], font=small_font, fill=(255, 170, 130) if row.issue else (170, 220, 170))
        draw.text((10, y + tile[1] + 52), row.cutout[:132], font=small_font, fill=(170, 170, 180))

    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def write_markdown(
    path: Path,
    rows: list[CutoutAuditRow],
    csv_path: Path,
    manifest_path: Path,
    review_sheet_path: Path,
    report_date: str,
    args: argparse.Namespace,
) -> None:
    failing = [row for row in rows if row.quality_status == "fail"]
    protected_failures = [row for row in failing if row.proof_status in {"accepted", "reference"}]
    current_failures = [row for row in failing if row.proof_status == "current_candidate"]
    raw_backed = any(row.raw_source for row in rows)
    input_rule = (
        "- Input rule: raw-backed mode reads each cutout's RGBA pixels plus its matching raw orange-background source, then fails any visible reserved background-key or border-connected orange background-field pixels anywhere in the alpha matte."
        if raw_backed
        else "- Input rule: cutout-only mode reads only each cutout's RGBA pixels. It cannot prove internal raw-background holes after cleanup has recolored pixels."
    )
    manifest_rule = (
        "- Manifest rule: `raw_images_loaded` is `true` only in raw-backed mode; reference, board-preview, and style-anchor image loads must stay `false`."
        if raw_backed
        else "- Manifest rule: `reference_images_loaded`, `raw_images_loaded`, `board_preview_images_loaded`, and `style_anchor_images_loaded` must all be `false` for cutout-only runs."
    )
    lines = [
        "# Unit Art Cutout Orange-Fringe Audit",
        "",
        f"- Date: {report_date}",
        f"- CSV: `{rel(csv_path)}`",
        f"- Manifest: `{rel(manifest_path)}`",
        f"- Review sheet: `{rel(review_sheet_path)}`",
        "- Purpose: objectively catch safety-orange background contamination in transparent cutouts before a proof is accepted or used as visual context.",
        "- Scope: cutout quality only. This does not approve style, matte finish, identity, or board readability.",
        input_rule,
        "",
        "## Objective Background-Contamination Gate",
        "",
        f"- Edge band radius: `{args.edge_radius}` px.",
        f"- Pass threshold: edge-orange pixels <= `{args.max_edge_orange_pixels}`, edge-orange ratio <= `{args.max_edge_orange_ratio:.4%}`, soft-alpha orange pixels <= `{args.max_soft_orange_pixels}`, raw-key/background-field visible pixels <= `{args.max_raw_key_visible_pixels}` when a raw source is supplied, and visual background-fringe pixels <= `{args.max_visual_fringe_pixels}` when that threshold is enabled.",
        f"- Raw-key/background-field check: pixels within `{args.raw_key_tolerance}` RGB units of reserved safety-orange `#f84401` or inside the border-connected raw orange background field must not remain visible in the cutout alpha matte.",
        "- Visual-fringe check: raw-backed perfect-exit mode also fails measured orange/red or cool-blue background-field residue at raw background pixels on alpha edges or soft matte pixels, then renders those pixels in the review overlay.",
        "- The gate does not compare to Vellum, Paisley, the token, or any other reference image. It tests cutout contamination against the known safety-orange background contract directly.",
        manifest_rule,
        "- Interior orange/gold pixels in the cutout are counted but do not fail by themselves. Raw-backed mode fails reserved raw background-key or border-connected background-field pixels anywhere and edge/soft visual background-field residue at the matte boundary.",
        "",
        "## Summary",
        "",
        f"- Rows audited: `{len(rows)}`",
        f"- Rows flagged for orange-fringe cleanup: `{len(failing)}`",
        f"- Protected ledger rows flagged: `{len(protected_failures)}`",
        f"- Current-candidate rows flagged: `{len(current_failures)}`",
        "",
    ]
    if failing:
        lines.extend(["## Flagged Rows", ""])
        lines.append("| id | proof status | edge orange | edge ratio | soft orange | raw-key visible | visual fringe | issue |")
        lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |")
        for row in sorted(failing, key=lambda item: item.edge_orange_pixels + item.soft_orange_pixels + item.raw_key_visible_pixels + item.visual_fringe_pixels, reverse=True):
            lines.append(
                f"| `{row.id}` | `{row.proof_status}` | {row.edge_orange_pixels} | {row.edge_orange_ratio:.4%} | {row.soft_orange_pixels} | {row.raw_key_visible_pixels} | {row.visual_fringe_pixels} | {row.issue} |"
            )
        lines.append("")
    lines.extend(
        [
            "## Decision Rule",
            "",
            "- Protected ledger rows, meaning accepted proofs and anchor/status rows from the proof ledger, must have no measurable safety-orange background contamination above the active objective gate. If one fails here, re-run cutout cleanup before using it as a technical cutout example.",
            "- Current candidates that fail can stay in the ledger as review candidates, but they need an edge-orange/raw-background-field clean pass before acceptance or live asset replacement.",
            "- Perfect-exit claims must use raw-backed mode with strict-zero thresholds so opaque or soft internal background holes, darker orange/red background-field residue, and cool blue spill cannot hide behind recolored cutout RGB.",
            "- Review the PNG sheet before trusting the metric when the character has intentional orange materials near the silhouette.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--proof-matrix", type=Path, default=PROOF_MATRIX_PATH)
    parser.add_argument("--include-proof-matrix", action=argparse.BooleanOptionalAction, default=True, help="Use --no-include-proof-matrix for a reference-free standalone cutout audit.")
    parser.add_argument("--cutout", type=Path, action="append", default=[], help="Standalone transparent cutout path to audit without requiring a reference image.")
    parser.add_argument("--raw-source", type=Path, action="append", default=[], help="Optional matching raw orange-background image for each --cutout. Enables raw-key and border-connected raw background-field visible background-hole detection.")
    parser.add_argument("--cutout-id", action="append", default=[], help="Optional id for each --cutout entry.")
    parser.add_argument("--cutout-label", action="append", default=[], help="Optional display label for each --cutout entry.")
    parser.add_argument("--use-proof-raw-source", action="store_true", help="When auditing the proof matrix, also load each proof's raw image for raw-key visible background-hole detection.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--docs-output", type=Path)
    parser.add_argument("--report-date", default=date.today().isoformat())
    parser.add_argument("--edge-radius", type=int, default=4)
    parser.add_argument("--max-edge-orange-pixels", type=int, default=50)
    parser.add_argument("--max-soft-orange-pixels", type=int, default=20)
    parser.add_argument("--max-edge-orange-ratio", type=float, default=0.0006)
    parser.add_argument("--max-raw-key-visible-pixels", type=int, default=0, help="Raw-backed mode threshold for visible raw background-key pixels anywhere in the cutout alpha matte.")
    parser.add_argument("--max-visual-fringe-pixels", type=int, help="Optional threshold for visible orange/red/blue background-field fringe at alpha edges or soft matte pixels.")
    parser.add_argument("--raw-key-tolerance", type=int, default=DEFAULT_RAW_KEY_TOLERANCE, help="Max RGB distance from #f84401 for raw background-key detection before adding border-connected raw orange background-field pixels.")
    parser.add_argument(
        "--strict-zero",
        action="store_true",
        help="Perfect-exit mode: fail on any measured safety-orange edge or soft-alpha residue.",
    )
    parser.add_argument("--fail-on-accepted-fail", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--fail-on-any-fail", action="store_true")
    args = parser.parse_args()

    if args.strict_zero:
        args.max_edge_orange_pixels = 0
        args.max_soft_orange_pixels = 0
        args.max_edge_orange_ratio = 0.0
        args.max_raw_key_visible_pixels = 0
        args.max_visual_fringe_pixels = 0

    if args.include_proof_matrix and not args.proof_matrix.is_absolute():
        args.proof_matrix = ROOT / args.proof_matrix
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    rows = collect_rows(args)
    csv_path = output_dir / "unit_art_cutout_orange_fringe_audit.csv"
    manifest_path = output_dir / "unit_art_cutout_orange_fringe_audit_manifest.json"
    review_sheet_path = output_dir / "unit_art_cutout_orange_fringe_review_sheet.png"
    report_path = output_dir / "unit_art_cutout_orange_fringe_audit.md"
    write_csv(csv_path, rows)
    write_manifest(manifest_path, rows, args.report_date, args)
    write_review_sheet(review_sheet_path, rows, args.edge_radius, args.raw_key_tolerance)
    write_markdown(report_path, rows, csv_path, manifest_path, review_sheet_path, args.report_date, args)
    if args.docs_output:
        docs_output = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        write_markdown(docs_output, rows, csv_path, manifest_path, review_sheet_path, args.report_date, args)

    failing = [row for row in rows if row.quality_status == "fail"]
    protected_failures = [row for row in failing if row.proof_status in {"accepted", "reference"}]
    print(f"rows={len(rows)}")
    print(f"flagged={len(failing)}")
    print(f"protected_ledger_flagged={len(protected_failures)}")
    print(f"report={rel(report_path)}")
    print(f"manifest={rel(manifest_path)}")
    print(f"review_sheet={rel(review_sheet_path)}")

    if args.fail_on_any_fail and failing:
        return 1
    if args.fail_on_accepted_fail and protected_failures:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
