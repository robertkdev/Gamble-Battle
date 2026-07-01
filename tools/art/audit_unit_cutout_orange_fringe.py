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
PROMPT_CASES_PATH = ROOT / "docs" / "art" / "unit_art_prompt_cases.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"cutout_orange_fringe_audit_{date.today().strftime('%Y_%m_%d')}"


@dataclass(frozen=True)
class CutoutAuditRow:
    id: str
    display_name: str
    proof_status: str
    reference_role: str
    source_kind: str
    cutout: str
    quality_status: str
    issue: str
    visible_pixels: int
    alpha_edge_pixels: int
    soft_alpha_pixels: int
    orange_pixels: int
    edge_orange_pixels: int
    soft_orange_pixels: int
    edge_orange_ratio: float


def rel(path: str | Path) -> str:
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    try:
        return candidate.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(candidate)


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


def alpha_edge_band(alpha: np.ndarray, radius: int) -> np.ndarray:
    foreground = Image.fromarray(np.where(alpha > 8, 255, 0).astype(np.uint8), "L")
    filter_size = max(3, radius * 2 + 1)
    if filter_size % 2 == 0:
        filter_size += 1
    dilated = np.asarray(foreground.filter(ImageFilter.MaxFilter(filter_size))) > 0
    eroded = np.asarray(foreground.filter(ImageFilter.MinFilter(filter_size))) > 0
    return dilated & ~eroded


def issue_for_metrics(
    edge_orange_pixels: int,
    soft_orange_pixels: int,
    edge_orange_ratio: float,
    max_edge_orange_pixels: int,
    max_soft_orange_pixels: int,
    max_edge_orange_ratio: float,
) -> str:
    issues: list[str] = []
    if edge_orange_pixels > max_edge_orange_pixels:
        issues.append("edge_orange_pixels_above_vellum_baseline")
    if edge_orange_ratio > max_edge_orange_ratio:
        issues.append("edge_orange_ratio_above_vellum_baseline")
    if soft_orange_pixels > max_soft_orange_pixels:
        issues.append("soft_alpha_orange_above_vellum_baseline")
    return ", ".join(issues)


def audit_cutout(
    cutout_path: str,
    row_id: str,
    display_name: str,
    proof_status: str,
    reference_role: str,
    source_kind: str,
    edge_radius: int,
    max_edge_orange_pixels: int,
    max_soft_orange_pixels: int,
    max_edge_orange_ratio: float,
) -> CutoutAuditRow:
    path = ROOT / cutout_path
    if not path.exists():
        return CutoutAuditRow(
            id=row_id,
            display_name=display_name,
            proof_status=proof_status,
            reference_role=reference_role,
            source_kind=source_kind,
            cutout=cutout_path,
            quality_status="fail",
            issue="missing_cutout",
            visible_pixels=0,
            alpha_edge_pixels=0,
            soft_alpha_pixels=0,
            orange_pixels=0,
            edge_orange_pixels=0,
            soft_orange_pixels=0,
            edge_orange_ratio=1.0,
        )

    image = Image.open(path).convert("RGBA")
    rgba = np.asarray(image)
    alpha = rgba[:, :, 3]
    visible = alpha > 8
    soft_alpha = (alpha > 8) & (alpha < 245)
    edge = alpha_edge_band(alpha, edge_radius)
    orange = safety_orange_residue(rgba[:, :, :3]) & visible
    edge_orange = orange & edge
    soft_orange = orange & soft_alpha
    edge_pixels = int(np.count_nonzero(edge))
    edge_orange_pixels = int(np.count_nonzero(edge_orange))
    soft_orange_pixels = int(np.count_nonzero(soft_orange))
    edge_orange_ratio = edge_orange_pixels / max(edge_pixels, 1)
    issue = issue_for_metrics(
        edge_orange_pixels,
        soft_orange_pixels,
        edge_orange_ratio,
        max_edge_orange_pixels,
        max_soft_orange_pixels,
        max_edge_orange_ratio,
    )
    return CutoutAuditRow(
        id=row_id,
        display_name=display_name,
        proof_status=proof_status,
        reference_role=reference_role,
        source_kind=source_kind,
        cutout=cutout_path,
        quality_status="fail" if issue else "pass",
        issue=issue,
        visible_pixels=int(np.count_nonzero(visible)),
        alpha_edge_pixels=edge_pixels,
        soft_alpha_pixels=int(np.count_nonzero(soft_alpha)),
        orange_pixels=int(np.count_nonzero(orange)),
        edge_orange_pixels=edge_orange_pixels,
        soft_orange_pixels=soft_orange_pixels,
        edge_orange_ratio=edge_orange_ratio,
    )


def row_to_dict(row: CutoutAuditRow) -> dict[str, str]:
    return {
        "id": row.id,
        "display_name": row.display_name,
        "proof_status": row.proof_status,
        "reference_role": row.reference_role,
        "source_kind": row.source_kind,
        "cutout": row.cutout,
        "quality_status": row.quality_status,
        "issue": row.issue,
        "visible_pixels": str(row.visible_pixels),
        "alpha_edge_pixels": str(row.alpha_edge_pixels),
        "soft_alpha_pixels": str(row.soft_alpha_pixels),
        "orange_pixels": str(row.orange_pixels),
        "edge_orange_pixels": str(row.edge_orange_pixels),
        "soft_orange_pixels": str(row.soft_orange_pixels),
        "edge_orange_ratio": f"{row.edge_orange_ratio:.6f}",
    }


def collect_rows(args: argparse.Namespace) -> list[CutoutAuditRow]:
    proof_data = json.loads(args.proof_matrix.read_text(encoding="utf-8"))
    prompt_cases = json.loads(args.prompt_cases.read_text(encoding="utf-8"))
    rows: list[CutoutAuditRow] = []

    anchor = prompt_cases.get("style_anchor", {})
    anchor_cutout = str(anchor.get("cutout_proof", ""))
    if anchor_cutout:
        rows.append(
            audit_cutout(
                anchor_cutout,
                "vellum_cutout_anchor",
                "Vellum",
                "reference",
                "primary_cutout_anchor",
                "prompt_case_anchor",
                args.edge_radius,
                args.max_edge_orange_pixels,
                args.max_soft_orange_pixels,
                args.max_edge_orange_ratio,
            )
        )

    for proof in proof_data.get("proofs", []):
        if not isinstance(proof, dict):
            continue
        cutout = str(proof.get("cutout", ""))
        if not cutout:
            continue
        rows.append(
            audit_cutout(
                cutout,
                str(proof.get("id", "")),
                str(proof.get("display_name", proof.get("subject_id", ""))),
                str(proof.get("status", "")),
                str(proof.get("reference_role", "")),
                "proof_matrix_cutout",
                args.edge_radius,
                args.max_edge_orange_pixels,
                args.max_soft_orange_pixels,
                args.max_edge_orange_ratio,
            )
        )
    return rows


def write_csv(path: Path, rows: list[CutoutAuditRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(row_to_dict(rows[0]).keys()) if rows else ["id"]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row_to_dict(row))


def compose_preview(cutout_path: str, background: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = Image.open(ROOT / cutout_path).convert("RGBA")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = background.resize(size, Image.Resampling.BICUBIC).convert("RGBA")
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas.convert("RGB")


def orange_overlay(cutout_path: str, size: tuple[int, int], edge_radius: int) -> Image.Image:
    image = Image.open(ROOT / cutout_path).convert("RGBA")
    rgba = np.asarray(image)
    alpha = rgba[:, :, 3]
    edge = alpha_edge_band(alpha, edge_radius)
    orange = safety_orange_residue(rgba[:, :, :3]) & (alpha > 8) & edge
    base = Image.new("RGBA", image.size, (0, 0, 0, 255))
    base.alpha_composite(image)
    overlay = np.asarray(base).copy()
    overlay[orange, 0] = 255
    overlay[orange, 1] = 0
    overlay[orange, 2] = 0
    overlay[orange, 3] = 255
    result = Image.fromarray(overlay, "RGBA")
    result.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 255))
    canvas.alpha_composite(result, ((size[0] - result.width) // 2, (size[1] - result.height) // 2))
    return canvas.convert("RGB")


def write_review_sheet(path: Path, rows: list[CutoutAuditRow], edge_radius: int) -> None:
    reference_rows = [row for row in rows if row.reference_role in {"primary_cutout_anchor", "secondary_contrast_anchor", "small_asset_material_reference"}]
    failing_rows = [row for row in rows if row.quality_status == "fail"]
    top_rows = sorted(rows, key=lambda row: row.edge_orange_pixels, reverse=True)
    selected: list[CutoutAuditRow] = []
    for row in reference_rows + failing_rows + top_rows:
        if row not in selected and row.cutout and (ROOT / row.cutout).exists():
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
    draw.text((12, 14), "Cutout Orange-Fringe Audit: checker / black / white / red edge-residue overlay", font=title_font, fill=(255, 222, 120))

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
            orange_overlay(row.cutout, tile, edge_radius),
        ]
        for column, preview in enumerate(previews):
            sheet.paste(preview, (column * tile[0], y))
        label = f"{row.id} | {row.quality_status} | edge orange {row.edge_orange_pixels}"
        draw.rectangle((0, y + tile[1], width, y + row_h), fill=(12, 13, 17))
        draw.text((10, y + tile[1] + 8), label[:118], font=small_font, fill=(235, 236, 240))
        issue = row.issue or "within Vellum/Paisley cutout cleanliness baseline"
        draw.text((10, y + tile[1] + 30), issue[:132], font=small_font, fill=(255, 170, 130) if row.issue else (170, 220, 170))
        draw.text((10, y + tile[1] + 52), row.cutout[:132], font=small_font, fill=(170, 170, 180))

    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def write_markdown(
    path: Path,
    rows: list[CutoutAuditRow],
    csv_path: Path,
    review_sheet_path: Path,
    report_date: str,
    args: argparse.Namespace,
) -> None:
    failing = [row for row in rows if row.quality_status == "fail"]
    accepted_failures = [row for row in failing if row.proof_status in {"accepted", "reference"}]
    current_failures = [row for row in failing if row.proof_status == "current_candidate"]
    lines = [
        "# Unit Art Cutout Orange-Fringe Audit",
        "",
        f"- Date: {report_date}",
        f"- CSV: `{rel(csv_path)}`",
        f"- Review sheet: `{rel(review_sheet_path)}`",
        "- Purpose: quickly catch safety-orange fringe on transparent cutouts before a proof is accepted or used as visual context.",
        "- Scope: cutout quality only. This does not approve style, matte finish, identity, or board readability.",
        "",
        "## Vellum/Paisley Cutout Cleanliness Baseline",
        "",
        f"- Edge band radius: `{args.edge_radius}` px.",
        f"- Pass threshold: edge-orange pixels <= `{args.max_edge_orange_pixels}`, edge-orange ratio <= `{args.max_edge_orange_ratio:.4%}`, and soft-alpha orange pixels <= `{args.max_soft_orange_pixels}`.",
        "- Vellum is included from the prompt-case anchor cutout. Paisley and the token are included from the proof ledger.",
        "- Interior orange/gold pixels are counted but do not fail the audit by themselves; the gate is edge/soft-alpha residue because that is the visible fringe risk.",
        "",
        "## Summary",
        "",
        f"- Rows audited: `{len(rows)}`",
        f"- Rows flagged for orange-fringe cleanup: `{len(failing)}`",
        f"- Accepted/reference rows flagged: `{len(accepted_failures)}`",
        f"- Current-candidate rows flagged: `{len(current_failures)}`",
        "",
    ]
    if failing:
        lines.extend(["## Flagged Rows", ""])
        lines.append("| id | proof status | edge orange | edge ratio | soft orange | issue |")
        lines.append("| --- | --- | ---: | ---: | ---: | --- |")
        for row in sorted(failing, key=lambda item: item.edge_orange_pixels, reverse=True):
            lines.append(
                f"| `{row.id}` | `{row.proof_status}` | {row.edge_orange_pixels} | {row.edge_orange_ratio:.4%} | {row.soft_orange_pixels} | {row.issue} |"
            )
        lines.append("")
    lines.extend(
        [
            "## Decision Rule",
            "",
            "- Accepted/reference rows should stay under the Vellum/Paisley baseline. If an accepted proof fails here, re-run cutout cleanup before using it as a reference.",
            "- Current candidates that fail can stay in the ledger as review candidates, but they need an edge-orange-clean pass before acceptance or live asset replacement.",
            "- Review the PNG sheet before trusting the metric when the character has intentional orange materials near the silhouette.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--proof-matrix", type=Path, default=PROOF_MATRIX_PATH)
    parser.add_argument("--prompt-cases", type=Path, default=PROMPT_CASES_PATH)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--docs-output", type=Path)
    parser.add_argument("--report-date", default=date.today().isoformat())
    parser.add_argument("--edge-radius", type=int, default=4)
    parser.add_argument("--max-edge-orange-pixels", type=int, default=50)
    parser.add_argument("--max-soft-orange-pixels", type=int, default=20)
    parser.add_argument("--max-edge-orange-ratio", type=float, default=0.0006)
    parser.add_argument("--fail-on-accepted-fail", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--fail-on-any-fail", action="store_true")
    args = parser.parse_args()

    if not args.proof_matrix.is_absolute():
        args.proof_matrix = ROOT / args.proof_matrix
    if not args.prompt_cases.is_absolute():
        args.prompt_cases = ROOT / args.prompt_cases
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    rows = collect_rows(args)
    csv_path = output_dir / "unit_art_cutout_orange_fringe_audit.csv"
    review_sheet_path = output_dir / "unit_art_cutout_orange_fringe_review_sheet.png"
    report_path = output_dir / "unit_art_cutout_orange_fringe_audit.md"
    write_csv(csv_path, rows)
    write_review_sheet(review_sheet_path, rows, args.edge_radius)
    write_markdown(report_path, rows, csv_path, review_sheet_path, args.report_date, args)
    if args.docs_output:
        docs_output = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        write_markdown(docs_output, rows, csv_path, review_sheet_path, args.report_date, args)

    failing = [row for row in rows if row.quality_status == "fail"]
    accepted_failures = [row for row in failing if row.proof_status in {"accepted", "reference"}]
    print(f"rows={len(rows)}")
    print(f"flagged={len(failing)}")
    print(f"accepted_or_reference_flagged={len(accepted_failures)}")
    print(f"report={rel(report_path)}")
    print(f"review_sheet={rel(review_sheet_path)}")

    if args.fail_on_any_fail and failing:
        return 1
    if args.fail_on_accepted_fail and accepted_failures:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
