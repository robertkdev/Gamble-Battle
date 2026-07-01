from __future__ import annotations

import argparse
import csv
import json
from datetime import date
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_METRICS = ROOT / "outputs" / "art_pipeline" / "style_validation" / "style_drift_audit_2026_06_30" / "foreground_detail_metrics.csv"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"candidate_style_triage_{date.today().strftime('%Y_%m_%d')}"
REQUIRED_STYLE_NEGATIVE_CONTROLS = {"totem_dry_wood_guardian_refit"}


def rel(path_text: str | Path) -> str:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_metrics(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def metric(row: dict[str, str], field: str) -> float:
    return float(row[field])


def optional_metric(row: dict[str, str], field: str, default: float = 0.0) -> float:
    value = row.get(field, "")
    if value == "":
        return default
    return float(value)


def require_path(path_text: str) -> Path:
    path = ROOT / path_text
    if not path.exists():
        raise FileNotFoundError(path_text)
    return path


def load_font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def fit_image(path_text: str, size: tuple[int, int], background: tuple[int, int, int]) -> Image.Image:
    image = Image.open(require_path(path_text)).convert("RGBA")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, background + (255,))
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas.convert("RGB")


def proof_lookup(proof_data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for proof in proof_data.get("proofs", []):
        if isinstance(proof, dict):
            result[str(proof.get("id", ""))] = proof
    return result


def style_audit_override(proof: dict[str, Any]) -> dict[str, str]:
    override = proof.get("style_audit_override", {})
    if not isinstance(override, dict):
        return {}
    return {str(key): str(value) for key, value in override.items()}


def is_style_negative_control(proof_id: str, proof: dict[str, Any]) -> bool:
    return proof_id in REQUIRED_STYLE_NEGATIVE_CONTROLS or bool(proof.get("style_negative_control", False))


def validate_required_negative_control_policy(proof_data: dict[str, Any]) -> None:
    by_kind = proof_lookup(proof_data)
    for proof_id in sorted(REQUIRED_STYLE_NEGATIVE_CONTROLS):
        proof = by_kind.get(proof_id)
        if proof is None:
            raise RuntimeError(f"required style negative control missing from proof matrix: {proof_id}")
        if proof.get("style_negative_control") is not True:
            raise RuntimeError(f"required style negative control must be explicit style_negative_control=true: {proof_id}")
        override = style_audit_override(proof)
        if override.get("verdict", "").strip().lower() != "fail":
            raise RuntimeError(f"required style negative control must declare style_audit_override verdict=fail: {proof_id}")
        if not override.get("reason", "").strip():
            raise RuntimeError(f"required style negative control must include style_audit_override reason: {proof_id}")


def build_rows(metrics_rows: list[dict[str, str]], proof_data: dict[str, Any]) -> list[dict[str, str]]:
    by_kind = proof_lookup(proof_data)
    by_label = {row["label"]: row for row in metrics_rows}
    vellum = by_label["REF Vellum raw"]
    paisley = by_label["REF Paisley"]
    vellum_edge = metric(vellum, "edge_mean")
    paisley_edge = metric(paisley, "edge_mean")
    vellum_contrast = metric(vellum, "gray_std")
    paisley_contrast = metric(paisley, "gray_std")
    vellum_hot_highlight = optional_metric(vellum, "hot_highlight_ratio")
    rows: list[dict[str, str]] = []
    for row in metrics_rows:
        kind = row["kind"]
        role = row["role"]
        proof = by_kind.get(kind, {})
        raw_path = str(proof.get("raw", ""))
        board_preview = str(proof.get("board_preview", ""))
        if role == "primary_anchor":
            primary_anchor = proof_data.get("style_contract", {}).get("reference_policy", {}).get("primary_anchor", {})
            raw_path = str(primary_anchor.get("path", ""))
        status = str(proof.get("status", "reference" if row["label"].startswith("REF ") else "unknown"))
        override = style_audit_override(proof)
        override_verdict = override.get("verdict", "").strip().lower()
        override_reason = override.get("reason", "").strip()
        negative_control = is_style_negative_control(kind, proof)
        edge_delta_vellum = metric(row, "edge_mean") - vellum_edge
        edge_delta_paisley = metric(row, "edge_mean") - paisley_edge
        contrast_delta_vellum = metric(row, "gray_std") - vellum_contrast
        contrast_delta_paisley = metric(row, "gray_std") - paisley_contrast
        p99_luma = optional_metric(row, "p99_luma")
        hot_highlight_ratio = optional_metric(row, "hot_highlight_ratio")
        hot_highlight_delta_vellum = hot_highlight_ratio - vellum_hot_highlight
        flags: list[str] = []
        if role == "primary_anchor":
            stance = "ultimate_reference"
        elif role in {"secondary_contrast_anchor", "small_asset_material_reference"}:
            stance = "reference_context_not_primary"
        else:
            if edge_delta_paisley < -4.0:
                flags.append("edge_detail_far_below_paisley")
            elif edge_delta_vellum < -2.0:
                flags.append("edge_detail_below_vellum")
            if contrast_delta_paisley < -4.0:
                flags.append("contrast_far_below_paisley")
            elif contrast_delta_vellum < -2.0:
                flags.append("contrast_below_vellum")
            if metric(row, "colorfulness") < 8.0:
                flags.append("very_muted_color_proxy")
            if hot_highlight_ratio >= 0.5 and p99_luma >= 210.0:
                flags.append("hot_highlight_matte_review")
            if role == "review_candidate_not_anchor":
                flags.append("human_review_gate")
            if status == "current_candidate":
                flags.append("candidate_not_accepted")
            if negative_control:
                flags.append("required_style_negative_control")
            if override_verdict == "fail":
                flags.append("human_style_fail_negative_control")
                if override_reason:
                    flags.append(override_reason)
            if not flags and edge_delta_vellum >= 0.0 and contrast_delta_vellum >= 0.0:
                flags.append("metric_detail_near_or_above_vellum")
            if override_verdict == "fail":
                stance = "style_audit_failed_negative_control"
            elif "edge_detail_far_below_paisley" in flags or "contrast_far_below_paisley" in flags:
                stance = "high_risk_re_review_before_acceptance"
            elif "edge_detail_below_vellum" in flags or "contrast_below_vellum" in flags:
                stance = "needs_vellum_pairwise_visual_review"
            elif role == "review_candidate_not_anchor":
                stance = "next_gate_human_review_required"
            else:
                stance = "metrics_do_not_replace_visual_review"
        if role == "primary_anchor":
            prompt_context_status = "primary_anchor"
        elif role == "secondary_contrast_anchor":
            prompt_context_status = "reference_context_only"
        elif role == "small_asset_material_reference":
            prompt_context_status = "small_asset_context_only_not_character_palette"
        elif negative_control:
            prompt_context_status = "blocked_style_negative_control"
        elif status == "current_candidate":
            prompt_context_status = "blocked_current_candidate"
        elif stance in {"high_risk_re_review_before_acceptance", "needs_vellum_pairwise_visual_review", "next_gate_human_review_required"}:
            prompt_context_status = "blocked_until_vellum_pairwise_review"
        else:
            prompt_context_status = "narrow_context_only_not_anchor"
        metric_false_positive_control = (
            negative_control
            and stance == "style_audit_failed_negative_control"
            and edge_delta_vellum >= 0.0
            and contrast_delta_vellum >= 0.0
        )
        if metric_false_positive_control:
            flags.append("metric_false_positive_style_sentinel")
        rows.append(
            {
                "label": row["label"],
                "proof_id": kind,
                "status": status,
                "reference_role": role,
                "prompt_context_status": prompt_context_status,
                "edge_mean": row["edge_mean"],
                "edge_delta_vellum": f"{edge_delta_vellum:.2f}",
                "edge_delta_paisley": f"{edge_delta_paisley:.2f}",
                "gray_std": row["gray_std"],
                "contrast_delta_vellum": f"{contrast_delta_vellum:.2f}",
                "contrast_delta_paisley": f"{contrast_delta_paisley:.2f}",
                "p99_luma": f"{p99_luma:.2f}",
                "hot_highlight_ratio": f"{hot_highlight_ratio:.3f}",
                "hot_highlight_delta_vellum": f"{hot_highlight_delta_vellum:.3f}",
                "flags": ", ".join(flags) if flags else "none",
                "review_stance": stance,
                "expected_negative_control": "yes" if negative_control else "no",
                "metric_false_positive_control": "yes" if metric_false_positive_control else "no",
                "raw": raw_path,
                "board_preview": board_preview,
            }
        )
    return rows


def enforce_negative_controls(rows: list[dict[str, str]]) -> None:
    by_proof_id = {row["proof_id"]: row for row in rows}
    missing = sorted(REQUIRED_STYLE_NEGATIVE_CONTROLS - set(by_proof_id))
    if missing:
        raise RuntimeError(f"required style negative controls missing from triage metrics: {', '.join(missing)}")
    not_failed = [
        row
        for row in rows
        if row["expected_negative_control"] == "yes"
        and row["review_stance"] != "style_audit_failed_negative_control"
    ]
    if not_failed:
        details = ", ".join(f"{row['proof_id']} -> {row['review_stance']}" for row in not_failed)
        raise RuntimeError(f"style negative controls did not fail triage: {details}")


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def visual_review_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        row
        for row in rows
        if row["review_stance"] in {
            "style_audit_failed_negative_control",
            "high_risk_re_review_before_acceptance",
            "needs_vellum_pairwise_visual_review",
            "next_gate_human_review_required",
        }
    ]


def prompt_context_quarantine_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        row
        for row in rows
        if row["prompt_context_status"].startswith("blocked_")
    ]


def metric_false_positive_controls(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        row
        for row in rows
        if row["metric_false_positive_control"] == "yes"
    ]


def hot_highlight_review_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        row
        for row in rows
        if "hot_highlight_matte_review" in row["flags"]
    ]


def wrap_text(text: str, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if len(candidate) <= width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def write_visual_review_sheet(path: Path, rows: list[dict[str, str]]) -> None:
    vellum = next(row for row in rows if row["reference_role"] == "primary_anchor")
    review_rows = visual_review_rows(rows)
    font = load_font(16)
    small = load_font(13)
    header = load_font(22)
    row_h = 280
    header_h = 96
    vellum_w = 230
    raw_w = 230
    board_w = 360
    text_w = 470
    width = vellum_w + raw_w + board_w + text_w + 60
    height = header_h + max(1, len(review_rows)) * row_h
    sheet = Image.new("RGB", (width, height), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((14, 12), "Candidate Drift Review: Vellum First", font=header, fill=(255, 222, 120))
    draw.text(
        (14, 44),
        "Metrics flag risk only. Vellum visual review decides; candidates do not become style anchors.",
        font=small,
        fill=(230, 205, 135),
    )
    if not review_rows:
        draw.text((14, header_h), "No visual-review rows flagged.", font=font, fill=(220, 220, 225))
        sheet.save(path)
        return
    vellum_tile = fit_image(vellum["raw"], (210, 210), (248, 68, 1))
    for index, row in enumerate(review_rows):
        y = header_h + index * row_h
        raw_tile = fit_image(row["raw"], (210, 210), (248, 68, 1))
        sheet.paste(vellum_tile, (14, y + 8))
        sheet.paste(raw_tile, (vellum_w + 24, y + 8))
        if row["board_preview"]:
            board_tile = fit_image(row["board_preview"], (board_w - 20, 210), (26, 26, 29))
            sheet.paste(board_tile, (vellum_w + raw_w + 34, y + 8))
        text_x = vellum_w + raw_w + board_w + 44
        color = (255, 170, 130) if row["review_stance"] in {"style_audit_failed_negative_control", "high_risk_re_review_before_acceptance"} else (210, 220, 255)
        draw.text((14, y + 224), "REF Vellum raw", font=small, fill=(255, 222, 120))
        draw.text((vellum_w + 24, y + 224), row["label"], font=small, fill=color)
        draw.text((text_x, y + 8), row["label"], font=font, fill=color)
        draw.text((text_x, y + 34), row["review_stance"], font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 58), f"Role: {row['reference_role']}  Status: {row['status']}", font=small, fill=(180, 180, 185))
        draw.text((text_x, y + 82), f"Edge vs Vellum: {row['edge_delta_vellum']}  Contrast vs Vellum: {row['contrast_delta_vellum']}", font=small, fill=(180, 180, 185))
        wrapped = wrap_text(f"Flags: {row['flags']}", 62)
        for line_index, line in enumerate(wrapped[:5]):
            draw.text((text_x, y + 112 + line_index * 20), line, font=small, fill=(205, 205, 210))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def draw_reference_tile(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    row: dict[str, str],
    x: int,
    y: int,
    title: str,
    subtitle: str,
    font: ImageFont.ImageFont,
    small: ImageFont.ImageFont,
    title_color: tuple[int, int, int],
) -> None:
    tile = fit_image(row["raw"], (210, 210), (248, 68, 1))
    sheet.paste(tile, (x, y))
    draw.text((x, y + 216), title, font=font, fill=title_color)
    for line_index, line in enumerate(wrap_text(subtitle, 29)[:3]):
        draw.text((x, y + 242 + line_index * 18), line, font=small, fill=(205, 205, 210))


def write_negative_control_sheet(path: Path, rows: list[dict[str, str]]) -> None:
    vellum = next(row for row in rows if row["reference_role"] == "primary_anchor")
    paisley = next(row for row in rows if row["reference_role"] == "secondary_contrast_anchor")
    token = next(row for row in rows if row["reference_role"] == "small_asset_material_reference")
    negative_controls = [row for row in rows if row["expected_negative_control"] == "yes"]
    if not negative_controls:
        raise RuntimeError("cannot write negative-control sheet without required negative controls")
    font = load_font(16)
    small = load_font(13)
    header = load_font(24)
    width = 1280
    row_h = 350
    header_h = 100
    height = header_h + len(negative_controls) * row_h
    sheet = Image.new("RGB", (width, height), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "Required Style Negative Controls: Vellum First", font=header, fill=(255, 222, 120))
    draw.text(
        (16, 48),
        "These rows must fail. Vellum stays primary; Paisley is secondary contrast; token is small-asset material only.",
        font=small,
        fill=(230, 205, 135),
    )
    for index, row in enumerate(negative_controls):
        y = header_h + index * row_h
        draw_reference_tile(
            sheet,
            draw,
            vellum,
            16,
            y + 10,
            "REF Vellum raw",
            "Ultimate unit style anchor",
            font,
            small,
            (255, 222, 120),
        )
        draw_reference_tile(
            sheet,
            draw,
            paisley,
            250,
            y + 10,
            "REF Paisley",
            "Secondary contrast only",
            font,
            small,
            (210, 220, 255),
        )
        draw_reference_tile(
            sheet,
            draw,
            token,
            484,
            y + 10,
            "REF Token",
            "Small asset only, not unit palette",
            font,
            small,
            (210, 220, 255),
        )
        draw_reference_tile(
            sheet,
            draw,
            row,
            718,
            y + 10,
            f"{row['label']} MUST FAIL",
            row["review_stance"],
            font,
            small,
            (255, 170, 130),
        )
        text_x = 952
        draw.text((text_x, y + 12), row["label"], font=font, fill=(255, 170, 130))
        draw.text((text_x, y + 40), f"Proof: {row['proof_id']}", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 62), f"Prompt context: {row['prompt_context_status']}", font=small, fill=(220, 220, 225))
        draw.text((text_x, y + 84), f"Edge vs Vellum: {row['edge_delta_vellum']}", font=small, fill=(180, 180, 185))
        draw.text((text_x, y + 106), f"Contrast vs Vellum: {row['contrast_delta_vellum']}", font=small, fill=(180, 180, 185))
        draw.text((text_x, y + 128), f"Hot highlight: {row['hot_highlight_ratio']}%", font=small, fill=(180, 180, 185))
        for line_index, line in enumerate(wrap_text(f"Fail reason: {row['flags']}", 46)[:8]):
            draw.text((text_x, y + 160 + line_index * 19), line, font=small, fill=(205, 205, 210))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def write_markdown(
    path: Path,
    rows: list[dict[str, str]],
    metrics_path: Path,
    report_date: str,
    review_sheet_path: Path,
    negative_control_sheet_path: Path,
) -> None:
    non_reference = [row for row in rows if not row["label"].startswith("REF ")]
    failed_controls = [row for row in non_reference if row["review_stance"] == "style_audit_failed_negative_control"]
    expected_controls = [row for row in non_reference if row["expected_negative_control"] == "yes"]
    high_risk = [row for row in non_reference if row["review_stance"] == "high_risk_re_review_before_acceptance"]
    review_gate = [row for row in non_reference if row["reference_role"] == "review_candidate_not_anchor"]
    quarantined = prompt_context_quarantine_rows(rows)
    false_positive_controls = metric_false_positive_controls(rows)
    hot_highlight_rows = hot_highlight_review_rows(non_reference)
    lines: list[str] = [
        "# Unit Art Candidate Style Triage",
        "",
        f"- Generated: {report_date}",
        f"- Metrics source: `{rel(metrics_path)}`",
        f"- Visual review sheet: `{rel(review_sheet_path)}`",
        f"- Style negative-control sheet: `{rel(negative_control_sheet_path)}`",
        "- Primary rule: Vellum is the ultimate character reference. Metrics are proxies only; visual side-by-side review decides.",
        "- Passing-pool rule: accepted/current proofs remain narrow evidence by `reference_role` unless the user explicitly promotes one.",
        "",
        "## Summary",
        "",
        f"- Non-reference rows reviewed: {len(non_reference)}",
        f"- Human negative-control failures: {len(failed_controls)}",
        f"- Required style negative controls: {len(expected_controls)}",
        f"- High-risk re-review rows: {len(high_risk)}",
        f"- Review-gate rows: {len(review_gate)}",
        f"- Prompt-context quarantined rows: {len(quarantined)}",
        f"- Metric false-positive controls: {len(false_positive_controls)}",
        f"- Hot-highlight matte-review rows: {len(hot_highlight_rows)}",
        "",
        "Human negative-control failures are hard fails recorded from visual review. They prove the audit can reject a candidate that has palette/detail but still misses Vellum's dry gothic finish.",
        "",
        "Required style negative controls are expected to fail every run. Totem is the current required negative control; if it stops failing, the style audit is broken or the ledger has changed without a new human promotion decision.",
        "",
        "Metric false-positive controls are required failures whose edge/detail and contrast proxies are near or above Vellum. They prove that proxy metrics cannot approve style by themselves.",
        "",
        "Hot-highlight matte-review rows have enough near-white foreground pixels to deserve visual review for possible sheen, pale-material glare, or board-scale hot spots. This is a proxy warning only; pale parchment, bone, ivory, or holy materials can be valid if they still read dry beside Vellum.",
        "",
        "High-risk here means the candidate is materially below Paisley or Vellum on edge/contrast proxies and should not be allowed to pull the target style, even if the image has a clean cutout or matches the palette.",
        "",
        "Prompt-context quarantine is the machine-readable guardrail for the user's warning about the passing pool getting muddy. Quarantined rows must not be used as prompt/style context until they pass a fresh Vellum-first visual review or receive an explicit user promotion/reclassification.",
        "",
        "Small-asset context rows are not character palette references. The token can inform small non-character material treatment, but it cannot pull unit character color, silhouette, or style decisions away from Vellum.",
        "",
        "## Required Style Negative Controls",
        "",
    ]
    if expected_controls:
        for row in expected_controls:
            lines.append(
                f"- `{row['label']}` / `{row['proof_id']}`: expected to fail style triage; actual stance `{row['review_stance']}`."
            )
    else:
        lines.append("- None configured. This is invalid for the current workflow because Totem should be a failing control.")
    lines.extend([
        "",
        "## Human Negative-Control Failures",
        "",
    ])
    if failed_controls:
        for row in failed_controls:
            lines.append(
                f"- `{row['label']}` / `{row['proof_id']}`: {row['flags']} "
                f"(edge vs Vellum {row['edge_delta_vellum']}, contrast vs Vellum {row['contrast_delta_vellum']})."
            )
    else:
        lines.append("- None recorded. This is suspicious if known visual failures exist.")
    lines.extend([
        "",
        "## Metric False-Positive Controls",
        "",
    ])
    if false_positive_controls:
        for row in false_positive_controls:
            lines.append(
                f"- `{row['label']}` / `{row['proof_id']}`: proxy metrics look acceptable "
                f"(edge vs Vellum {row['edge_delta_vellum']}, contrast vs Vellum {row['contrast_delta_vellum']}), "
                "but visual review still fails it for missing the matte gothic target."
            )
    else:
        lines.append("- None. This is suspicious while Totem remains the required negative control.")
    lines.extend([
        "",
        "## Hot-Highlight Matte Review",
        "",
    ])
    if hot_highlight_rows:
        for row in hot_highlight_rows:
            lines.append(
                f"- `{row['label']}` / `{row['proof_id']}`: hot highlight ratio {row['hot_highlight_ratio']}%, "
                f"delta vs Vellum {row['hot_highlight_delta_vellum']}%, p99 luma {row['p99_luma']}; "
                "review beside Vellum to confirm this is dry pale material rather than sheen."
            )
    else:
        lines.append("- None by the current proxy thresholds.")
    lines.extend([
        "",
        "## Highest Risk Rows",
        "",
    ])
    if high_risk:
        for row in high_risk:
            lines.append(
                f"- `{row['label']}` / `{row['proof_id']}`: {row['flags']} "
                f"(edge vs Vellum {row['edge_delta_vellum']}, contrast vs Vellum {row['contrast_delta_vellum']})."
            )
    else:
        lines.append("- None by the current proxy thresholds.")
    lines.extend([
        "",
        "## Prompt-Context Quarantine",
        "",
    ])
    if quarantined:
        for row in quarantined:
            lines.append(
                f"- `{row['label']}` / `{row['proof_id']}`: `{row['prompt_context_status']}`; "
                f"stance `{row['review_stance']}`; {row['flags']}."
            )
    else:
        lines.append("- None.")
    lines.extend([
        "",
        "## Full Triage Table",
        "",
        "| Label | Proof | Status | Role | Prompt context | Edge vs Vellum | Contrast vs Vellum | Hot highlight % | Flags | Stance |",
        "| --- | --- | --- | --- | --- | ---: | ---: | ---: | --- | --- |",
    ])
    for row in rows:
        lines.append(
            f"| {row['label']} | `{row['proof_id']}` | `{row['status']}` | `{row['reference_role']}` | "
            f"`{row['prompt_context_status']}` | {row['edge_delta_vellum']} | {row['contrast_delta_vellum']} | "
            f"{row['hot_highlight_ratio']} | {row['flags']} | {row['review_stance']} |"
        )
    lines.extend([
        "",
        "## Use",
        "",
        "- Start visual review from the Vellum pairwise sheet, not this table.",
        "- Use the visual review sheet as a shortcut for the rows most likely to drift away from Vellum.",
        "- If a row is high-risk or prompt-context quarantined, compare it beside Vellum before accepting or using it as prompt context.",
        "- If a high-risk row is already accepted, keep it quarantined from prompt influence and do not let it influence the global target without explicit user review.",
        "- If a row is a current candidate, leave it out of live assets until the user approves it.",
        "",
    ])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metrics-csv", type=Path, default=DEFAULT_METRICS)
    parser.add_argument("--proof-matrix", type=Path, default=PROOF_MATRIX_PATH)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--docs-output", type=Path)
    parser.add_argument("--report-date", default=date.today().isoformat())
    parser.add_argument("--enforce-negative-controls", action=argparse.BooleanOptionalAction, default=True)
    args = parser.parse_args()

    metrics_path = args.metrics_csv if args.metrics_csv.is_absolute() else ROOT / args.metrics_csv
    proof_matrix_path = args.proof_matrix if args.proof_matrix.is_absolute() else ROOT / args.proof_matrix
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    proof_data = load_json(proof_matrix_path)
    if args.enforce_negative_controls:
        validate_required_negative_control_policy(proof_data)
    rows = build_rows(load_metrics(metrics_path), proof_data)
    if args.enforce_negative_controls:
        enforce_negative_controls(rows)
    csv_path = output_dir / "unit_art_candidate_style_triage.csv"
    md_path = output_dir / "unit_art_candidate_style_triage.md"
    review_sheet_path = output_dir / "candidate_style_triage_review_sheet.png"
    negative_control_sheet_path = output_dir / "style_negative_control_review_sheet.png"
    write_csv(csv_path, rows)
    write_visual_review_sheet(review_sheet_path, rows)
    write_negative_control_sheet(negative_control_sheet_path, rows)
    write_markdown(md_path, rows, metrics_path, args.report_date, review_sheet_path, negative_control_sheet_path)
    if args.docs_output:
        docs_path = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        write_markdown(docs_path, rows, metrics_path, args.report_date, review_sheet_path, negative_control_sheet_path)
        print(rel(docs_path))
    print(rel(md_path))
    print(rel(csv_path))
    print(rel(review_sheet_path))
    print(rel(negative_control_sheet_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
