from __future__ import annotations

import argparse
import csv
import json
import math
from datetime import date
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"style_drift_audit_{date.today().strftime('%Y_%m_%d')}"

ANCHORS: list[dict[str, str]] = [
    {
        "label": "REF Vellum raw",
        "kind": "vellum_raw_anchor",
        "role": "primary_anchor",
        "raw": "outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_selected_raw.png",
        "cutout": "outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_cutout_final.png",
        "board": "outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_cutout_cleanliness_comparison.png",
    },
    {
        "label": "REF Paisley",
        "kind": "paisley_goth_bubble_refit",
        "role": "secondary_contrast_anchor",
        "raw": "outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_raw_selected.png",
        "cutout": "outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_cutout_selected_birefnet_foregroundml_despill.png",
        "board": "outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_board_preview_selected.png",
    },
    {
        "label": "REF Token",
        "kind": "ability_token_contract_mark",
        "role": "small_asset_material_reference",
        "raw": "outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_raw_selected.png",
        "cutout": "outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_cutout_selected_birefnet_foregroundml_despill.png",
        "board": "outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_board_preview_selected.png",
    },
]

REFERENCE_ROLES = {"secondary_contrast_anchor", "small_asset_material_reference"}


def role_color(role: str) -> tuple[int, int, int]:
    if role == "primary_anchor":
        return (255, 222, 120)
    if role in REFERENCE_ROLES:
        return (230, 205, 135)
    if role == "review_candidate_not_anchor":
        return (210, 220, 255)
    if role == "negative_example":
        return (255, 150, 150)
    return (220, 220, 225)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def require_path(path_text: str | Path) -> Path:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    if not path.exists():
        raise FileNotFoundError(str(path_text))
    return path


def load_font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def fit_square(image: Image.Image, size: int) -> Image.Image:
    tile = image.convert("RGBA")
    tile.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (248, 68, 1, 255))
    canvas.alpha_composite(tile, ((size - tile.width) // 2, (size - tile.height) // 2))
    return canvas.convert("RGB")


def collect_entries(proof_data: dict[str, Any], proof_ids: set[str], include_rejected: bool) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = list(ANCHORS)
    for proof in proof_data.get("proofs", []):
        if not isinstance(proof, dict):
            continue
        proof_id = str(proof.get("id", ""))
        if proof_ids and proof_id not in proof_ids:
            continue
        status = str(proof.get("status", ""))
        if status == "rejected" and not include_rejected and not proof_ids:
            continue
        if status not in {"accepted", "current_candidate", "rejected"}:
            continue
        role = str(proof.get("reference_role", "narrow_proof_only"))
        if not proof_ids and role in REFERENCE_ROLES:
            continue
        subject_id = str(proof.get("subject_id", ""))
        if subject_id == "ability_token_contract_mark":
            continue
        entries.append(
            {
                "label": str(proof.get("display_name", proof_id)),
                "kind": proof_id,
                "role": role,
                "raw": str(proof.get("raw", "")),
                "cutout": str(proof.get("cutout", "")),
                "board": str(proof.get("board_preview", "")),
            }
        )
    return entries


def candidate_entry(args: argparse.Namespace) -> dict[str, str] | None:
    candidate_paths = [args.candidate_raw, args.candidate_cutout, args.candidate_board]
    if not any(candidate_paths):
        return None
    if not args.candidate_raw or not args.candidate_cutout:
        raise ValueError("--candidate-raw and --candidate-cutout are both required for pre-ledger candidate audits")
    label = args.candidate_label or "Pre-ledger candidate"
    candidate_id = args.candidate_id or "pre_ledger_candidate"
    role = args.candidate_role or "review_candidate_not_anchor"
    entry = {
        "label": label,
        "kind": candidate_id,
        "role": role,
        "raw": str(args.candidate_raw),
        "cutout": str(args.candidate_cutout),
        "board": str(args.candidate_board or ""),
    }
    for field in ("raw", "cutout"):
        require_path(entry[field])
    if entry["board"]:
        require_path(entry["board"])
    return entry


def write_raw_sheet(entries: list[dict[str, str]], output_path: Path) -> None:
    font = load_font(18)
    small = load_font(14)
    header = load_font(20)
    header_h = 88
    cell_w = 260
    cell_h = 316
    thumb = 240
    cols = 4
    rows = math.ceil(len(entries) / cols)
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h + header_h), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), "Vellum = primary/ultimate. Paisley = secondary contrast. Token = small-asset material.", font=header, fill=(255, 222, 120))
    draw.text((10, 40), "Later proofs are narrow coverage and keep ledger roles; user promotion is required to become anchors.", font=small, fill=(230, 205, 135))
    for index, entry in enumerate(entries):
        col = index % cols
        row = index // cols
        x = col * cell_w + 10
        y = row * cell_h + header_h
        image = Image.open(require_path(entry["raw"]))
        sheet.paste(fit_square(image, thumb), (x, y))
        role = entry.get("role", "narrow_proof_only")
        color = role_color(role)
        draw.text((x, y + thumb + 6), entry["label"][:28], font=font, fill=color)
        draw.text((x, y + thumb + 30), role[:36], font=small, fill=(190, 190, 195))
        draw.text((x, y + thumb + 48), entry["kind"][:36], font=small, fill=(145, 145, 150))
    sheet.save(output_path)


def write_vellum_pairwise_sheet(entries: list[dict[str, str]], output_path: Path) -> None:
    vellum = entries[0]
    comparison_entries = entries[1:]
    font = load_font(18)
    small = load_font(14)
    header = load_font(20)
    header_h = 96
    cell_w = 300
    text_w = 440
    cell_h = 330
    thumb = 260
    rows = max(1, len(comparison_entries))
    sheet = Image.new("RGB", (cell_w * 2 + text_w, rows * cell_h + header_h), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), "Mandatory Vellum-first side-by-side audit", font=header, fill=(255, 222, 120))
    draw.text(
        (10, 40),
        "Vellum remains the ultimate reference; passing proofs are narrow comparisons, not a pooled target.",
        font=small,
        fill=(230, 205, 135),
    )
    if not comparison_entries:
        draw.text((10, header_h), "No comparison entries found.", font=font, fill=(255, 150, 150))
        sheet.save(output_path)
        return
    vellum_image = Image.open(require_path(vellum["raw"]))
    vellum_tile = fit_square(vellum_image, thumb)
    for index, entry in enumerate(comparison_entries):
        y = index * cell_h + header_h
        compare_image = Image.open(require_path(entry["raw"]))
        compare_tile = fit_square(compare_image, thumb)
        sheet.paste(vellum_tile, (10, y))
        sheet.paste(compare_tile, (cell_w + 10, y))
        role = entry.get("role", "narrow_proof_only")
        color = role_color(role)
        draw.text((10, y + thumb + 8), "REF Vellum raw", font=font, fill=role_color("primary_anchor"))
        draw.text((cell_w + 10, y + thumb + 8), entry["label"][:28], font=font, fill=color)
        draw.text((cell_w + 10, y + thumb + 32), role[:36], font=small, fill=(190, 190, 195))
        text_x = cell_w * 2 + 10
        draw.text((text_x, y), "Decision order", font=font, fill=(255, 222, 120))
        draw.text((text_x, y + 34), "1. Does this match Vellum's dry material richness?", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 58), "2. If not, reject or revise before cutout/live use.", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 82), "3. Use Paisley/token/later proofs only as narrow context.", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 122), f"Proof id: {entry['kind'][:42]}", font=small, fill=(145, 145, 150))
        draw.text((text_x, y + 146), "Ledger reference_role controls how this may be reused.", font=small, fill=(145, 145, 150))
    sheet.save(output_path)


def write_reference_ladder_sheet(entries: list[dict[str, str]], output_path: Path) -> None:
    vellum = entries[0]
    paisley = entries[1]
    token = entries[2]
    comparison_entries = entries[3:]
    font = load_font(17)
    small = load_font(13)
    header = load_font(20)
    header_h = 104
    thumb = 190
    col_w = 210
    text_w = 410
    row_h = 270
    rows = max(1, len(comparison_entries))
    sheet = Image.new("RGB", (col_w * 4 + text_w, rows * row_h + header_h), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), "Reference ladder: Vellum first, context second, candidate last", font=header, fill=(255, 222, 120))
    draw.text(
        (10, 40),
        "Vellum can veto. Paisley/token/later proofs are narrow context and cannot rescue weaker candidates.",
        font=small,
        fill=(230, 205, 135),
    )
    if not comparison_entries:
        draw.text((10, header_h), "No comparison entries found.", font=font, fill=(255, 150, 150))
        sheet.save(output_path)
        return
    vellum_tile = fit_square(Image.open(require_path(vellum["raw"])), thumb)
    paisley_tile = fit_square(Image.open(require_path(paisley["raw"])), thumb)
    token_tile = fit_square(Image.open(require_path(token["raw"])), thumb)
    for index, entry in enumerate(comparison_entries):
        y = header_h + index * row_h
        candidate_tile = fit_square(Image.open(require_path(entry["raw"])), thumb)
        sheet.paste(vellum_tile, (10, y))
        sheet.paste(paisley_tile, (col_w + 10, y))
        sheet.paste(token_tile, (col_w * 2 + 10, y))
        sheet.paste(candidate_tile, (col_w * 3 + 10, y))
        role = entry.get("role", "narrow_proof_only")
        color = role_color(role)
        draw.text((10, y + thumb + 8), "1 REF Vellum", font=small, fill=role_color("primary_anchor"))
        draw.text((col_w + 10, y + thumb + 8), "2 REF Paisley", font=small, fill=role_color("secondary_contrast_anchor"))
        draw.text((col_w * 2 + 10, y + thumb + 8), "3 REF Token", font=small, fill=role_color("small_asset_material_reference"))
        draw.text((col_w * 3 + 10, y + thumb + 8), entry["label"][:22], font=small, fill=color)
        text_x = col_w * 4 + 10
        draw.text((text_x, y), entry["label"][:38], font=font, fill=color)
        draw.text((text_x, y + 30), f"Role: {role[:34]}", font=small, fill=(190, 190, 195))
        draw.text((text_x, y + 54), f"Proof: {entry['kind'][:38]}", font=small, fill=(145, 145, 150))
        draw.text((text_x, y + 92), "Read order", font=font, fill=(255, 222, 120))
        draw.text((text_x, y + 124), "1. Vellum veto: dry detail, realism, mood, scale.", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 148), "2. Paisley: contrast only, not a new average.", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 172), "3. Token: material/icon context only.", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 196), "4. Candidate may stay narrow even if accepted.", font=small, fill=(220, 220, 225))
    sheet.save(output_path)


def write_board_sheet(entries: list[dict[str, str]], output_path: Path) -> None:
    font = load_font(18)
    small = load_font(14)
    header = load_font(20)
    header_h = 88
    cols = 2
    cell_w = 600
    cell_h = 510
    rows = math.ceil(len(entries) / cols)
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h + header_h), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), "Board scale: compare to Vellum first.", font=header, fill=(255, 222, 120))
    draw.text((10, 40), "Paisley/token are reference rows; later proofs are secondary/narrow and keep ledger roles.", font=small, fill=(230, 205, 135))
    board_entries = [entry for entry in entries if entry.get("board")]
    for index, entry in enumerate(board_entries):
        col = index % cols
        row = index // cols
        x = col * cell_w + 10
        y = row * cell_h + header_h
        image = Image.open(require_path(entry["board"])).convert("RGB")
        image.thumbnail((cell_w - 20, cell_h - 50), Image.Resampling.LANCZOS)
        color = role_color(entry.get("role", "narrow_proof_only"))
        draw.text((x, y), f"{entry['label']} board"[:56], font=font, fill=color)
        sheet.paste(image, (x, y + 30))
    sheet.save(output_path)


def foreground_metrics(entry: dict[str, str]) -> dict[str, str | float | int]:
    image = Image.open(require_path(entry["cutout"])).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"empty alpha: {entry['cutout']}")
    crop = image.crop(bbox)
    mask = crop.getchannel("A")
    rgb = Image.new("RGB", crop.size, (0, 0, 0))
    rgb.paste(crop.convert("RGB"), mask=mask)
    gray = rgb.convert("L")
    gray_values = list(gray.getdata())
    alpha_values = list(mask.getdata())
    foreground_values = [value for value, a_value in zip(gray_values, alpha_values) if a_value > 32]
    histogram = [0] * 256
    for value in foreground_values:
        histogram[value] += 1
    total = len(foreground_values)
    entropy = -sum((count / total) * math.log2(count / total) for count in histogram if count)
    sorted_luma = sorted(foreground_values)
    p95_luma = sorted_luma[int((total - 1) * 0.95)]
    p99_luma = sorted_luma[int((total - 1) * 0.99)]
    edges = gray.filter(ImageFilter.FIND_EDGES)
    edge_values = [value for value, a_value in zip(edges.getdata(), alpha_values) if a_value > 32]
    edge_mean = sum(edge_values) / len(edge_values)
    mean = sum(foreground_values) / total
    gray_std = (sum((value - mean) ** 2 for value in foreground_values) / total) ** 0.5
    rg_values: list[float] = []
    yb_values: list[float] = []
    hot_highlight_pixels = 0
    bright_pixels = 0
    for red, green, blue, a_value in crop.convert("RGBA").getdata():
        if a_value > 32:
            rg_values.append(abs(red - green))
            yb_values.append(abs(0.5 * (red + green) - blue))
            luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            max_channel = max(red, green, blue)
            min_channel = min(red, green, blue)
            saturation = 0.0 if max_channel == 0 else (max_channel - min_channel) / max_channel
            if luma >= 215.0:
                bright_pixels += 1
            if luma >= 225.0 and saturation <= 0.22:
                hot_highlight_pixels += 1
    colorfulness = (sum(rg_values) / len(rg_values) + sum(yb_values) / len(yb_values)) / 2
    return {
        "label": entry["label"],
        "kind": entry["kind"],
        "role": entry.get("role", "narrow_proof_only"),
        "entropy": round(entropy, 3),
        "edge_mean": round(edge_mean, 2),
        "gray_std": round(gray_std, 2),
        "colorfulness": round(colorfulness, 2),
        "p95_luma": round(float(p95_luma), 2),
        "p99_luma": round(float(p99_luma), 2),
        "bright_pixel_ratio": round((bright_pixels / total) * 100.0, 3),
        "hot_highlight_ratio": round((hot_highlight_pixels / total) * 100.0, 3),
        "fg_pixels": total,
    }


def write_metrics(entries: list[dict[str, str]], csv_path: Path, summary_path: Path) -> None:
    rows: list[dict[str, str | float | int]] = []
    for entry in entries:
        rows.append(foreground_metrics(entry))
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "label",
                "kind",
                "role",
                "entropy",
                "edge_mean",
                "gray_std",
                "colorfulness",
                "p95_luma",
                "p99_luma",
                "bright_pixel_ratio",
                "hot_highlight_ratio",
                "fg_pixels",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)
    with summary_path.open("w", encoding="utf-8") as handle:
        handle.write("Reference hierarchy: Vellum is primary/ultimate; Paisley is secondary contrast; token is small-asset material only; later proofs are narrow coverage and keep their ledger reference_role unless user-promoted.\n")
        handle.write(
            "Foreground metrics are proxies only; visual audit decides. "
            "Higher entropy/edge_mean/std usually means more texture/detail/contrast. "
            "Hot-highlight ratios flag possible sheen or bright pale-material risk for visual review, not automatic failure.\n"
        )
        for row in rows:
            handle.write(
                f"{str(row['label'])[:14]:14s} {str(row['kind'])[:32]:32s} {str(row['role'])[:28]:28s} "
                f"entropy={float(row['entropy']):.3f} edge={float(row['edge_mean']):.2f} "
                f"contrast={float(row['gray_std']):.2f} color={float(row['colorfulness']):.2f} "
                f"p99={float(row['p99_luma']):.2f} hot={float(row['hot_highlight_ratio']):.3f}%\n"
            )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--proof-id", action="append", default=[], help="Specific proof id to compare against anchors.")
    parser.add_argument("--include-rejected", action="store_true", help="Include rejected proof entries when no proof id is specified.")
    parser.add_argument("--candidate-id", help="Pre-ledger candidate id for temporary Vellum-first audit output.")
    parser.add_argument("--candidate-label", help="Pre-ledger candidate label for temporary Vellum-first audit output.")
    parser.add_argument("--candidate-role", default="review_candidate_not_anchor", help="Reference role label for a pre-ledger candidate.")
    parser.add_argument("--candidate-raw", type=Path, help="Raw image path for a pre-ledger candidate.")
    parser.add_argument("--candidate-cutout", type=Path, help="Transparent cutout path for a pre-ledger candidate.")
    parser.add_argument("--candidate-board", type=Path, help="Board preview path for a pre-ledger candidate.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    proof_data = load_json(PROOF_MATRIX_PATH)
    entries = collect_entries(proof_data, set(args.proof_id), args.include_rejected)
    temporary_candidate = candidate_entry(args)
    if temporary_candidate:
        entries.append(temporary_candidate)
    write_raw_sheet(entries, output_dir / "raw_anchor_vs_later_contact_sheet.png")
    write_vellum_pairwise_sheet(entries, output_dir / "vellum_first_pairwise_raw_comparison.png")
    write_reference_ladder_sheet(entries, output_dir / "reference_ladder_raw_comparison.png")
    write_board_sheet(entries, output_dir / "board_preview_drift_contact_sheet.png")
    write_metrics(
        entries,
        output_dir / "foreground_detail_metrics.csv",
        output_dir / "foreground_detail_metrics_summary.txt",
    )
    print(output_dir / "raw_anchor_vs_later_contact_sheet.png")
    print(output_dir / "reference_ladder_raw_comparison.png")
    print(output_dir / "board_preview_drift_contact_sheet.png")
    print(output_dir / "foreground_detail_metrics.csv")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
