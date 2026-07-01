from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from collections.abc import Callable
from datetime import date
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from clean_unit_cutout_orange_edge import assert_edge_clean_delta_contract, edge_clean_delta_stats, file_sha256, stats_output_path


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"quick_art_audit_gates_{date.today().strftime('%Y_%m_%d')}"
STYLE_METRIC_FIELDS = {"p95_luma", "p99_luma", "bright_pixel_ratio", "hot_highlight_ratio"}
REFERENCE_ROLE_EXPECTATIONS = {
    "REF Vellum raw": ("vellum_raw_anchor", "primary_anchor"),
    "REF Paisley": ("paisley_goth_bubble_refit", "secondary_contrast_anchor"),
    "REF Token": ("ability_token_contract_mark", "small_asset_material_reference"),
}
ANCHOR_ROLES = {"primary_anchor", "secondary_contrast_anchor", "small_asset_material_reference"}
STYLE_AUDIT_SHEETS = [
    "raw_anchor_vs_later_contact_sheet.png",
    "vellum_first_pairwise_raw_comparison.png",
    "reference_ladder_raw_comparison.png",
    "board_preview_drift_contact_sheet.png",
]
CLEANER_DELTA_STAT_KEYS = [
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
]
CUTOUT_AUDIT_THRESHOLDS = {
    "edge_radius": 4,
    "max_edge_orange_pixels": 50,
    "max_soft_orange_pixels": 20,
    "max_edge_orange_ratio": 0.0006,
}
STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS = {
    "edge_radius": 4,
    "max_edge_orange_pixels": 0,
    "max_soft_orange_pixels": 0,
    "max_edge_orange_ratio": 0.0,
}


def rel(path_text: str | Path) -> str:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def run_command(command: list[str], report: list[str], expect_success: bool) -> subprocess.CompletedProcess[str]:
    report.append("```powershell")
    report.append(" ".join(command))
    report.append("```")
    result = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.stdout.strip():
        report.append("")
        report.append("```text")
        report.append(result.stdout.strip())
        report.append("```")
    report.append("")
    if expect_success and result.returncode != 0:
        raise RuntimeError(f"expected command to pass: {' '.join(command)}")
    if not expect_success and result.returncode == 0:
        raise RuntimeError(f"expected command to fail: {' '.join(command)}")
    return result


def parse_cleaner_delta_stdout(stdout: str) -> dict[str, int]:
    stats: dict[str, int] = {}
    for key in CLEANER_DELTA_STAT_KEYS:
        marker = f"{key}="
        if marker not in stdout:
            raise RuntimeError(f"edge cleaner did not self-report {key}")
        text = stdout.split(marker, 1)[1].splitlines()[0].strip()
        try:
            stats[key] = int(text)
        except ValueError as exc:
            raise RuntimeError(f"edge cleaner reported non-integer {key}: {text}") from exc
    return stats


def assert_cleaner_stats_json(
    path: Path,
    input_path: Path,
    output_path: Path,
    review_output_path: Path,
    edge_radius: int,
    cleaned_pixels: int,
    delta_stats: dict[str, int],
    raw_source_path: Path | None = None,
    raw_key_cleared_pixels: int = 0,
) -> None:
    if not path.exists():
        raise RuntimeError(f"edge cleaner stats JSON missing: {rel(path)}")
    payload = read_json(path)
    raw_loaded = raw_source_path is not None
    expected_input_contract = "cutout_rgba_plus_raw_background_key_pixels" if raw_loaded else "cutout_rgba_pixels_only"
    expected_clean_contract = "safety_orange_alpha_edge_or_soft_rgb_plus_raw_key_visible_alpha_clear" if raw_loaded else "safety_orange_alpha_edge_or_soft_pixels_only"
    if payload.get("audit_input_contract") != expected_input_contract:
        raise RuntimeError(f"edge cleaner stats JSON does not declare {expected_input_contract}")
    if payload.get("edge_clean_contract") != expected_clean_contract:
        raise RuntimeError(f"edge cleaner stats JSON does not declare {expected_clean_contract}")
    if payload.get("contract_status") != "pass":
        raise RuntimeError("edge cleaner stats JSON does not record contract_status=pass")
    for key in (
        "reference_images_loaded",
        "raw_images_loaded",
        "board_preview_images_loaded",
        "style_anchor_images_loaded",
    ):
        expected_value = raw_loaded if key == "raw_images_loaded" else False
        if payload.get(key) is not expected_value:
            raise RuntimeError(f"edge cleaner stats JSON must set {key}=false")
    if int(payload.get("cleaned_safety_orange_pixels", -1)) != cleaned_pixels:
        raise RuntimeError("edge cleaner stats JSON cleaned safety-orange pixel count does not match stdout")
    if int(payload.get("cleaned_edge_orange_pixels", -1)) != cleaned_pixels:
        raise RuntimeError("edge cleaner stats JSON cleaned pixel count does not match stdout")
    if int(payload.get("raw_key_alpha_cleared_pixels", -1)) != raw_key_cleared_pixels:
        raise RuntimeError("edge cleaner stats JSON raw-key alpha clear count does not match stdout")
    expected_paths = {
        "input": rel(input_path),
        "output": rel(output_path),
        "review_output": rel(review_output_path),
        "stats_output": rel(path),
    }
    for key, expected_path in expected_paths.items():
        if payload.get(key) != expected_path:
            raise RuntimeError(f"edge cleaner stats JSON {key} path mismatch: expected {expected_path}, got {payload.get(key)}")
    if payload.get("hash_algorithm") != "sha256":
        raise RuntimeError("edge cleaner stats JSON does not declare hash_algorithm=sha256")
    expected_hashes = {
        "input_sha256": file_sha256(input_path),
        "output_sha256": file_sha256(output_path),
        "review_output_sha256": file_sha256(review_output_path),
    }
    for key, expected_hash in expected_hashes.items():
        if payload.get(key) != expected_hash:
            raise RuntimeError(f"edge cleaner stats JSON {key} mismatch")
    if raw_source_path is not None:
        if payload.get("raw_source") != rel(raw_source_path):
            raise RuntimeError("edge cleaner stats JSON raw_source path mismatch")
        if payload.get("raw_source_sha256") != file_sha256(raw_source_path):
            raise RuntimeError("edge cleaner stats JSON raw_source_sha256 mismatch")
    if int(payload.get("edge_radius", -1)) != edge_radius:
        raise RuntimeError("edge cleaner stats JSON edge_radius does not match command")
    json_delta = payload.get("delta_stats")
    if not isinstance(json_delta, dict):
        raise RuntimeError("edge cleaner stats JSON missing delta_stats object")
    for key in CLEANER_DELTA_STAT_KEYS:
        if int(json_delta.get(key, -1)) != delta_stats[key]:
            raise RuntimeError(f"edge cleaner stats JSON {key}={json_delta.get(key)}, actual={delta_stats[key]}")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        raise RuntimeError(f"cannot write empty CSV: {rel(path)}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def csv_fields(path: Path) -> set[str]:
    with path.open(encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return set(reader.fieldnames or [])


def metric_csv_is_current_shape(path: Path) -> bool:
    if not path.exists():
        return False
    return STYLE_METRIC_FIELDS.issubset(csv_fields(path))


def expect_runtime_failure(label: str, expected_message: str, action: Callable[[], None], report: list[str]) -> None:
    try:
        action()
    except RuntimeError as exc:
        message = str(exc)
        if expected_message not in message:
            raise RuntimeError(f"{label} failed for the wrong reason: {message}") from exc
        report.append(f"- PASS {label} fails with `{expected_message}`.")
        return
    raise RuntimeError(f"{label} unexpectedly passed")


def find_latest_metrics_csv() -> Path:
    candidates: list[Path] = []
    base = ROOT / "outputs" / "art_pipeline" / "style_validation"
    for pattern in (
        "workflow_validation_*/style_drift_audit_all_current/foreground_detail_metrics.csv",
        "style_drift_audit_*/foreground_detail_metrics.csv",
    ):
        candidates.extend(base.glob(pattern))
    current_shape = [path for path in candidates if metric_csv_is_current_shape(path)]
    if not current_shape:
        raise RuntimeError(
            "no current-shape foreground_detail_metrics.csv found; run build_unit_style_drift_audit.py or pass --metrics-csv"
        )
    return max(current_shape, key=lambda path: path.stat().st_mtime)


def is_safety_orange_pixel(red: int, green: int, blue: int) -> bool:
    orange_like = (
        red > 175
        and green > 35
        and green < 170
        and blue < 115
        and (red - green) > 42
        and (green - blue) > 10
    )
    saturated = ((red - blue) / max(float(red), 1.0)) > 0.35
    return orange_like and saturated


def count_safety_orange_pixels_in_box(path: Path, box: tuple[int, int, int, int]) -> int:
    image = Image.open(path).convert("RGBA")
    count = 0
    left, top, right, bottom = box
    for red, green, blue, alpha in image.crop((left, top, right, bottom)).getdata():
        if alpha > 8 and is_safety_orange_pixel(red, green, blue):
            count += 1
    return count


def assert_alpha_unchanged(before_path: Path, after_path: Path) -> None:
    before_alpha = list(Image.open(before_path).convert("RGBA").getchannel("A").getdata())
    after_alpha = list(Image.open(after_path).convert("RGBA").getchannel("A").getdata())
    if before_alpha != after_alpha:
        raise RuntimeError("edge-orange cleaner changed synthetic cutout alpha")


def assert_nonblank_image(path: Path, label: str) -> tuple[int, int]:
    if not path.exists():
        raise RuntimeError(f"{label} missing: {rel(path)}")
    if path.stat().st_size <= 0:
        raise RuntimeError(f"{label} is empty: {rel(path)}")
    image = Image.open(path).convert("RGB")
    width, height = image.size
    if width < 128 or height < 128:
        raise RuntimeError(f"{label} is too small to be useful visual evidence: {width}x{height} at {rel(path)}")
    extrema = image.getextrema()
    channel_ranges = [high - low for low, high in extrema]
    if max(channel_ranges) < 16:
        raise RuntimeError(f"{label} appears blank or near-flat: {rel(path)}")
    return width, height


def assert_reference_free_manifest(
    manifest_path: Path,
    label: str,
    report: list[str],
    expected_proof_matrix_loaded: bool,
    expected_source_kinds: set[str],
    expected_row_count: int | None = None,
    expected_thresholds: dict[str, int | float] | None = None,
) -> None:
    if not manifest_path.exists():
        raise RuntimeError(f"{label} missing: {rel(manifest_path)}")
    manifest = read_json(manifest_path)
    if manifest.get("audit_input_contract") != "cutout_rgba_pixels_only":
        raise RuntimeError(f"{label} does not declare cutout_rgba_pixels_only")
    for key in (
        "reference_images_loaded",
        "raw_images_loaded",
        "board_preview_images_loaded",
        "style_anchor_images_loaded",
    ):
        if manifest.get(key) is not False:
            raise RuntimeError(f"{label} must set {key}=false")
    if manifest.get("proof_matrix_loaded_for_cutout_paths") is not expected_proof_matrix_loaded:
        raise RuntimeError(f"{label} proof_matrix_loaded_for_cutout_paths mismatch")
    source_kinds = set(str(value) for value in manifest.get("source_kinds", []))
    if source_kinds != expected_source_kinds:
        raise RuntimeError(f"{label} source_kinds expected {sorted(expected_source_kinds)}, got {sorted(source_kinds)}")
    if expected_row_count is not None and int(manifest.get("row_count", -1)) != expected_row_count:
        raise RuntimeError(f"{label} row_count expected {expected_row_count}, got {manifest.get('row_count')}")
    thresholds = manifest.get("thresholds")
    if not isinstance(thresholds, dict):
        raise RuntimeError(f"{label} missing thresholds")
    threshold_contract = expected_thresholds if expected_thresholds is not None else CUTOUT_AUDIT_THRESHOLDS
    for key, expected in threshold_contract.items():
        actual = thresholds.get(key)
        if isinstance(expected, float):
            if abs(float(actual) - expected) > 0.0000001:
                raise RuntimeError(f"{label} threshold {key} expected {expected}, got {actual}")
        elif int(actual) != expected:
            raise RuntimeError(f"{label} threshold {key} expected {expected}, got {actual}")
    report.append(f"- PASS {label} proves reference-free cutout-only input contract: `{rel(manifest_path)}`.")


def assert_raw_backed_cutout_manifest(
    manifest_path: Path,
    label: str,
    report: list[str],
    expected_row_count: int = 1,
    expected_thresholds: dict[str, int | float] | None = None,
    expected_proof_matrix_loaded: bool | None = None,
    expected_proof_matrix_raw_source_loaded: bool | None = None,
    expected_source_kinds: set[str] | None = None,
) -> None:
    if not manifest_path.exists():
        raise RuntimeError(f"{label} missing: {rel(manifest_path)}")
    manifest = read_json(manifest_path)
    if manifest.get("audit_input_contract") != "cutout_rgba_plus_raw_background_key_pixels":
        raise RuntimeError(f"{label} does not declare cutout_rgba_plus_raw_background_key_pixels")
    if manifest.get("raw_images_loaded") is not True:
        raise RuntimeError(f"{label} must set raw_images_loaded=true")
    for key in (
        "reference_images_loaded",
        "board_preview_images_loaded",
        "style_anchor_images_loaded",
    ):
        if manifest.get(key) is not False:
            raise RuntimeError(f"{label} must set {key}=false")
    if int(manifest.get("row_count", -1)) != expected_row_count:
        raise RuntimeError(f"{label} row_count expected {expected_row_count}, got {manifest.get('row_count')}")
    if (
        expected_proof_matrix_loaded is not None
        and manifest.get("proof_matrix_loaded_for_cutout_paths") is not expected_proof_matrix_loaded
    ):
        raise RuntimeError(f"{label} proof_matrix_loaded_for_cutout_paths mismatch")
    if (
        expected_proof_matrix_raw_source_loaded is not None
        and manifest.get("proof_matrix_raw_source_loaded") is not expected_proof_matrix_raw_source_loaded
    ):
        raise RuntimeError(f"{label} proof_matrix_raw_source_loaded mismatch")
    if expected_source_kinds is not None:
        source_kinds = set(str(value) for value in manifest.get("source_kinds", []))
        if source_kinds != expected_source_kinds:
            raise RuntimeError(f"{label} source_kinds expected {sorted(expected_source_kinds)}, got {sorted(source_kinds)}")
    thresholds = manifest.get("thresholds")
    if not isinstance(thresholds, dict):
        raise RuntimeError(f"{label} missing thresholds")
    threshold_contract = expected_thresholds if expected_thresholds is not None else STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS
    for key, expected in threshold_contract.items():
        actual = thresholds.get(key)
        if isinstance(expected, float):
            if abs(float(actual) - expected) > 0.0000001:
                raise RuntimeError(f"{label} threshold {key} expected {expected}, got {actual}")
        elif int(actual) != expected:
            raise RuntimeError(f"{label} threshold {key} expected {expected}, got {actual}")
    if int(thresholds.get("max_raw_key_visible_pixels", -1)) != 0:
        raise RuntimeError(f"{label} raw-key visible threshold must be zero")
    report.append(f"- PASS {label} proves raw-backed cutout/raw-key input contract: `{rel(manifest_path)}`.")


def write_synthetic_cutout(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((34, 18, 94, 112), fill=(70, 80, 92, 255))
    draw.ellipse((56, 56, 72, 72), fill=(248, 68, 1, 255))
    draw.ellipse((34, 18, 94, 112), outline=(248, 68, 1, 255), width=6)
    image.save(path)


def write_raw_key_hole_control(control_dir: Path) -> tuple[Path, Path]:
    control_dir.mkdir(parents=True, exist_ok=True)
    raw_path = control_dir / "raw_key_hole_control_raw.png"
    cutout_path = control_dir / "raw_key_hole_control_cutout.png"

    raw = Image.new("RGB", (128, 128), (248, 68, 1))
    raw_draw = ImageDraw.Draw(raw)
    raw_draw.ellipse((26, 18, 102, 112), fill=(70, 80, 92))
    raw_draw.rectangle((60, 48, 68, 84), fill=(248, 68, 1))
    raw_draw.ellipse((42, 64, 54, 76), fill=(216, 124, 48))
    raw.save(raw_path)

    cutout = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cutout_draw = ImageDraw.Draw(cutout)
    cutout_draw.ellipse((26, 18, 102, 112), fill=(70, 80, 92, 255))
    cutout_draw.rectangle((60, 48, 68, 84), fill=(54, 64, 82, 255))
    cutout_draw.ellipse((42, 64, 54, 76), fill=(216, 124, 48, 255))
    cutout.save(cutout_path)
    return raw_path, cutout_path


def count_visible_alpha_pixels_in_box(path: Path, box: tuple[int, int, int, int]) -> int:
    alpha = Image.open(path).convert("RGBA").crop(box).getchannel("A")
    return sum(1 for value in alpha.getdata() if value > 8)


def write_strict_zero_single_pixel_control(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    pixels = image.load()
    orange_written = False
    for y in range(8, 504, 2):
        for x in range(8, 504, 2):
            if not orange_written:
                pixels[x, y] = (248, 68, 1, 255)
                orange_written = True
            else:
                pixels[x, y] = (70, 80, 92, 255)
    image.save(path)


def write_cutout_self_test_images(control_dir: Path) -> dict[str, Path]:
    control_dir.mkdir(parents=True, exist_ok=True)
    paths = {
        "clean_cutout_control": control_dir / "clean_cutout_control.png",
        "interior_orange_material_control": control_dir / "interior_orange_material_control.png",
        "edge_orange_contamination_control": control_dir / "edge_orange_contamination_control.png",
        "soft_alpha_orange_halo_control": control_dir / "soft_alpha_orange_halo_control.png",
        "edge_orange_51_pixel_threshold_control": control_dir / "edge_orange_51_pixel_threshold_control.png",
        "edge_orange_ratio_threshold_control": control_dir / "edge_orange_ratio_threshold_control.png",
        "soft_alpha_21_pixel_threshold_control": control_dir / "soft_alpha_21_pixel_threshold_control.png",
    }
    for key, path in paths.items():
        if key == "edge_orange_51_pixel_threshold_control":
            image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
            pixels = image.load()
            orange_written = 0
            for y in range(8, 504, 2):
                for x in range(8, 504, 2):
                    color = (70, 80, 92, 255)
                    if orange_written < 51:
                        color = (248, 68, 1, 255)
                        orange_written += 1
                    pixels[x, y] = color
            image.save(path)
            continue
        image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.ellipse((34, 18, 94, 112), fill=(70, 80, 92, 255))
        if key == "interior_orange_material_control":
            draw.ellipse((54, 54, 74, 74), fill=(248, 68, 1, 255))
        elif key == "edge_orange_contamination_control":
            draw.ellipse((34, 18, 94, 112), outline=(248, 68, 1, 255), width=6)
        elif key == "soft_alpha_orange_halo_control":
            draw.ellipse((30, 14, 98, 116), outline=(248, 68, 1, 128), width=8)
        elif key == "edge_orange_ratio_threshold_control":
            pixels = image.load()
            pixels[61, 18] = (248, 68, 1, 255)
            pixels[62, 18] = (248, 68, 1, 255)
        elif key == "soft_alpha_21_pixel_threshold_control":
            pixels = image.load()
            for index in range(21):
                x = 54 + index
                pixels[x, 64] = (248, 68, 1, 128)
        image.save(path)
    return paths


def assert_cutout_gate(output_dir: Path, report: list[str]) -> None:
    report.append("## Current Cutout Orange-Fringe Gate")
    report.append("")
    audit_dir = output_dir / "cutout_orange_fringe_audit"
    command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--output-dir",
        rel(audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-accepted-fail",
    ]
    run_command(command, report, expect_success=True)
    assert_reference_free_manifest(
        audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "current cutout audit manifest",
        report,
        expected_proof_matrix_loaded=True,
        expected_source_kinds={"proof_matrix_cutout"},
    )
    review_sheet = audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png"
    review_width, review_height = assert_nonblank_image(review_sheet, "current cutout orange-fringe review sheet")
    rows = read_csv(audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    non_rejected_failures = [
        row
        for row in rows
        if row.get("quality_status") == "fail" and row.get("proof_status") != "rejected"
    ]
    if non_rejected_failures:
        details = ", ".join(row.get("id", "<unknown>") for row in non_rejected_failures)
        raise RuntimeError(f"non-rejected cutouts have safety-orange contamination: {details}")
    rejected_failures = [
        row
        for row in rows
        if row.get("quality_status") == "fail" and row.get("proof_status") == "rejected"
    ]
    report.append(f"- PASS non-rejected cutouts have no objective safety-orange edge/soft-alpha contamination.")
    report.append(f"- PASS current cutout orange-fringe review sheet exists and is nonblank: `{review_width}x{review_height}`.")
    report.append(f"- Rejected negative-example cutouts still flagged: `{len(rejected_failures)}`.")
    report.append("")


def assert_cutout_self_test_matrix(output_dir: Path, report: list[str]) -> None:
    report.append("## Objective Cutout Self-Test Matrix")
    report.append("")
    control_dir = output_dir / "cutout_self_test_matrix"
    image_paths = write_cutout_self_test_images(control_dir)
    audit_dir = control_dir / "audit"
    command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--output-dir",
        rel(audit_dir),
        "--report-date",
        date.today().isoformat(),
    ]
    for control_id, path in image_paths.items():
        command.extend([
            "--cutout",
            rel(path),
            "--cutout-id",
            control_id,
            "--cutout-label",
            control_id.replace("_", " "),
        ])
    run_command(command, report, expect_success=True)
    assert_reference_free_manifest(
        audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "cutout self-test matrix manifest",
        report,
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=7,
    )
    review_sheet = audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png"
    review_width, review_height = assert_nonblank_image(review_sheet, "cutout self-test matrix review sheet")
    rows = read_csv(audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    by_id = {row.get("id", ""): row for row in rows}
    expected_status = {
        "clean_cutout_control": "pass",
        "interior_orange_material_control": "pass",
        "edge_orange_contamination_control": "fail",
        "soft_alpha_orange_halo_control": "fail",
        "edge_orange_51_pixel_threshold_control": "fail",
        "edge_orange_ratio_threshold_control": "fail",
        "soft_alpha_21_pixel_threshold_control": "fail",
    }
    for control_id, status in expected_status.items():
        row = by_id.get(control_id)
        if row is None:
            raise RuntimeError(f"cutout self-test row missing: {control_id}")
        if row.get("quality_status") != status:
            raise RuntimeError(f"cutout self-test {control_id} expected {status}, got {row.get('quality_status')}")
    interior = by_id["interior_orange_material_control"]
    if int(interior.get("orange_pixels", "0")) <= 0:
        raise RuntimeError("interior-orange material control did not contain measurable orange pixels")
    if int(interior.get("edge_orange_pixels", "0")) != 0 or int(interior.get("soft_orange_pixels", "0")) != 0:
        raise RuntimeError("interior-orange material control was treated as edge/soft-alpha contamination")
    edge_issue = by_id["edge_orange_contamination_control"].get("issue", "")
    if "edge_background_orange" not in edge_issue:
        raise RuntimeError("edge-orange contamination control did not fail for edge contamination")
    soft_issue = by_id["soft_alpha_orange_halo_control"].get("issue", "")
    if "soft_alpha_background_orange_contamination" not in soft_issue:
        raise RuntimeError("soft-alpha orange halo control did not fail for soft-alpha contamination")
    edge_threshold = by_id["edge_orange_51_pixel_threshold_control"]
    if int(edge_threshold.get("edge_orange_pixels", "0")) != 51:
        raise RuntimeError("edge-orange 51-pixel threshold control did not create exactly 51 edge-orange pixels")
    if "edge_background_orange_contamination" not in edge_threshold.get("issue", ""):
        raise RuntimeError("edge-orange 51-pixel threshold control did not fail the pixel threshold")
    ratio_threshold = by_id["edge_orange_ratio_threshold_control"]
    if int(ratio_threshold.get("edge_orange_pixels", "0")) > CUTOUT_AUDIT_THRESHOLDS["max_edge_orange_pixels"]:
        raise RuntimeError("edge-orange ratio threshold control also exceeded the pixel threshold")
    if "edge_background_orange_ratio_contamination" not in ratio_threshold.get("issue", ""):
        raise RuntimeError("edge-orange ratio threshold control did not fail the ratio threshold")
    soft_threshold = by_id["soft_alpha_21_pixel_threshold_control"]
    if int(soft_threshold.get("soft_orange_pixels", "0")) != 21:
        raise RuntimeError("soft-alpha 21-pixel threshold control did not create exactly 21 soft-orange pixels")
    if "soft_alpha_background_orange_contamination" not in soft_threshold.get("issue", ""):
        raise RuntimeError("soft-alpha 21-pixel threshold control did not fail the soft-alpha threshold")
    report.append("- PASS clean transparent cutout control passes.")
    report.append("- PASS intentional interior orange material control passes while recording orange pixels.")
    report.append("- PASS safety-orange edge contamination control fails.")
    report.append("- PASS soft-alpha safety-orange halo control fails.")
    report.append("- PASS edge-orange 51-pixel threshold control fails exactly one pixel over the limit.")
    report.append("- PASS edge-orange ratio threshold control fails even below the pixel-count limit.")
    report.append("- PASS soft-alpha 21-pixel threshold control fails exactly one pixel over the limit.")
    report.append(f"- PASS cutout self-test matrix review sheet exists and is nonblank: `{review_width}x{review_height}`.")
    report.append("")


def assert_strict_zero_cutout_gate(output_dir: Path, report: list[str]) -> None:
    report.append("## Strict-Zero Cutout Gate")
    report.append("")
    control_dir = output_dir / "strict_zero_cutout_control"
    cutout_path = control_dir / "single_edge_orange_pixel_control.png"
    default_audit_dir = control_dir / "audit_default_thresholds"
    strict_audit_dir = control_dir / "audit_strict_zero"
    write_strict_zero_single_pixel_control(cutout_path)

    base_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cutout_path),
        "--cutout-id",
        "single_edge_orange_pixel_control",
        "--cutout-label",
        "single edge orange pixel control",
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
    ]

    default_command = base_command + ["--output-dir", rel(default_audit_dir)]
    default_result = run_command(default_command, report, expect_success=True)
    if "flagged=0" not in default_result.stdout:
        raise RuntimeError("default-threshold one-pixel residue control did not report flagged=0")
    assert_reference_free_manifest(
        default_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "strict-zero default-threshold control manifest",
        report,
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
    )

    strict_command = base_command + ["--output-dir", rel(strict_audit_dir), "--strict-zero"]
    strict_result = run_command(strict_command, report, expect_success=False)
    if "flagged=1" not in strict_result.stdout:
        raise RuntimeError("strict-zero one-pixel residue control did not report flagged=1")
    assert_reference_free_manifest(
        strict_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "strict-zero one-pixel control manifest",
        report,
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )
    strict_rows = read_csv(strict_audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    strict_row = strict_rows[0]
    if strict_row.get("quality_status") != "fail":
        raise RuntimeError("strict-zero one-pixel residue control did not fail")
    if int(strict_row.get("edge_orange_pixels", "0")) != 1:
        raise RuntimeError("strict-zero one-pixel residue control did not create exactly one edge-orange pixel")
    report.append("- PASS default-threshold audit passes a one-pixel edge-orange residue control.")
    report.append("- PASS strict-zero audit fails the same one-pixel edge-orange residue control.")
    report.append("")


def assert_raw_key_hole_gate(output_dir: Path, report: list[str]) -> None:
    report.append("## Raw-Key Background-Hole Gate")
    report.append("")
    control_dir = output_dir / "raw_key_hole_control"
    raw_path, cutout_path = write_raw_key_hole_control(control_dir)
    cutout_only_audit_dir = control_dir / "audit_cutout_only"
    raw_backed_audit_dir = control_dir / "audit_raw_backed"
    cleaned_path = control_dir / "raw_key_hole_control_cleaned.png"
    cleaner_review_path = control_dir / "raw_key_hole_control_cleaned_review.png"
    cleaner_stats_path = stats_output_path(cleaned_path)
    cleaned_audit_dir = control_dir / "audit_cleaned_raw_backed"

    base_audit_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cutout_path),
        "--cutout-id",
        "raw_key_hole_control",
        "--cutout-label",
        "raw key hole control",
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    cutout_only_result = run_command(
        base_audit_command + ["--output-dir", rel(cutout_only_audit_dir)],
        report,
        expect_success=True,
    )
    if "flagged=0" not in cutout_only_result.stdout:
        raise RuntimeError("raw-key hole cutout-only audit did not report flagged=0")
    assert_reference_free_manifest(
        cutout_only_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "raw-key hole cutout-only audit manifest",
        report,
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )

    raw_backed_result = run_command(
        base_audit_command + ["--raw-source", rel(raw_path), "--output-dir", rel(raw_backed_audit_dir)],
        report,
        expect_success=False,
    )
    if "flagged=1" not in raw_backed_result.stdout:
        raise RuntimeError("raw-key hole raw-backed audit did not report flagged=1")
    assert_raw_backed_cutout_manifest(
        raw_backed_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "raw-key hole raw-backed audit manifest",
        report,
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )
    raw_rows = read_csv(raw_backed_audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    raw_row = raw_rows[0]
    if raw_row.get("quality_status") != "fail":
        raise RuntimeError("raw-key hole raw-backed audit did not fail")
    if "raw_key_visible_background_contamination" not in raw_row.get("issue", ""):
        raise RuntimeError("raw-key hole raw-backed audit did not fail on visible raw key")
    raw_key_visible_pixels = int(raw_row.get("raw_key_visible_pixels", "0"))
    if raw_key_visible_pixels <= 0:
        raise RuntimeError("raw-key hole raw-backed audit did not measure visible raw-key pixels")

    clean_command = [
        sys.executable,
        "tools/art/clean_unit_cutout_orange_edge.py",
        "--input",
        rel(cutout_path),
        "--raw-source",
        rel(raw_path),
        "--output",
        rel(cleaned_path),
        "--review-output",
        rel(cleaner_review_path),
    ]
    clean_result = run_command(clean_command, report, expect_success=True)
    if "raw_key_alpha_cleared_pixels=" not in clean_result.stdout:
        raise RuntimeError("raw-key cleaner did not report raw_key_alpha_cleared_pixels")
    raw_key_cleared_pixels = int(clean_result.stdout.split("raw_key_alpha_cleared_pixels=", 1)[1].splitlines()[0].strip())
    if raw_key_cleared_pixels != raw_key_visible_pixels:
        raise RuntimeError("raw-key cleaner did not clear the measured visible raw-key pixels")
    cleaner_stdout_stats = parse_cleaner_delta_stdout(clean_result.stdout)
    delta_stats = edge_clean_delta_stats(Image.open(cutout_path), Image.open(cleaned_path), 4, Image.open(raw_path))
    for key in CLEANER_DELTA_STAT_KEYS:
        if cleaner_stdout_stats[key] != delta_stats[key]:
            raise RuntimeError(f"raw-key cleaner self-reported {key}={cleaner_stdout_stats[key]}, actual={delta_stats[key]}")
    assert_cleaner_stats_json(
        cleaner_stats_path,
        cutout_path,
        cleaned_path,
        cleaner_review_path,
        4,
        int(clean_result.stdout.split("cleaned_safety_orange_pixels=", 1)[1].splitlines()[0].strip()),
        delta_stats,
        raw_path,
        raw_key_cleared_pixels,
    )
    assert_nonblank_image(cleaner_review_path, "raw-key cleaner review sheet")

    cleaned_audit_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cleaned_path),
        "--cutout-id",
        "raw_key_hole_control_cleaned",
        "--cutout-label",
        "raw key hole control cleaned",
        "--raw-source",
        rel(raw_path),
        "--output-dir",
        rel(cleaned_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    cleaned_result = run_command(cleaned_audit_command, report, expect_success=True)
    if "flagged=0" not in cleaned_result.stdout:
        raise RuntimeError("raw-key cleaned audit did not report flagged=0")
    assert_raw_backed_cutout_manifest(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "raw-key hole cleaned raw-backed audit manifest",
        report,
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )
    cleaned_rows = read_csv(cleaned_audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    if int(cleaned_rows[0].get("raw_key_visible_pixels", "-1")) != 0:
        raise RuntimeError("raw-key cleaned audit still measured visible raw-key pixels")
    report.append("- PASS cutout-only strict-zero audit passes a recolored raw-key hole because no raw/reference images are loaded.")
    report.append("- PASS raw-backed audit fails the same cutout for visible reserved background-key pixels without style references.")
    report.append("- PASS raw-backed cleaner clears the measured background-key alpha leak and the cleaned raw-backed audit passes.")
    report.append("")


def assert_synthetic_edge_clean(output_dir: Path, report: list[str]) -> None:
    report.append("## Synthetic Edge-Clean Regression")
    report.append("")
    control_dir = output_dir / "synthetic_edgeclean"
    cutout_path = control_dir / "synthetic_orange_fringe_cutout.png"
    cleaned_path = control_dir / "synthetic_orange_fringe_cutout_edgeclean.png"
    cleaner_review_path = control_dir / "synthetic_orange_fringe_cutout_edgeclean_review.png"
    cleaner_stats_path = stats_output_path(cleaned_path)
    audit_dir = control_dir / "audit_before"
    cleaned_audit_dir = control_dir / "audit_after"
    write_synthetic_cutout(cutout_path)
    interior_box = (52, 52, 76, 76)
    interior_orange_before = count_safety_orange_pixels_in_box(cutout_path, interior_box)
    if interior_orange_before < 120:
        raise RuntimeError("synthetic interior orange marker was not created")
    before_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cutout_path),
        "--cutout-id",
        "quick_gate_synthetic_orange_fringe",
        "--cutout-label",
        "Quick gate synthetic orange-fringe control",
        "--output-dir",
        rel(audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    before_result = run_command(before_command, report, expect_success=False)
    if "flagged=1" not in before_result.stdout:
        raise RuntimeError("synthetic contaminated cutout did not fail with flagged=1")
    assert_reference_free_manifest(
        audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "synthetic contaminated cutout audit manifest",
        report,
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )
    before_review_width, before_review_height = assert_nonblank_image(
        audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png",
        "synthetic contaminated cutout audit review sheet",
    )
    clean_command = [
        sys.executable,
        "tools/art/clean_unit_cutout_orange_edge.py",
        "--input",
        rel(cutout_path),
        "--output",
        rel(cleaned_path),
        "--review-output",
        rel(cleaner_review_path),
    ]
    clean_result = run_command(clean_command, report, expect_success=True)
    if "cleaned_safety_orange_pixels=" not in clean_result.stdout:
        raise RuntimeError("edge cleaner did not report cleaned_safety_orange_pixels")
    if "cleaned_edge_orange_pixels=" not in clean_result.stdout:
        raise RuntimeError("edge cleaner did not report legacy cleaned_edge_orange_pixels")
    cleaner_review_width, cleaner_review_height = assert_nonblank_image(
        cleaner_review_path,
        "synthetic edge-cleaner review sheet",
    )
    cleaned_pixels = int(clean_result.stdout.split("cleaned_safety_orange_pixels=", 1)[1].splitlines()[0].strip())
    if cleaned_pixels <= 0:
        raise RuntimeError("edge cleaner did not remove any synthetic safety-orange edge pixels")
    delta_stats = edge_clean_delta_stats(Image.open(cutout_path), Image.open(cleaned_path), 4)
    cleaner_stdout_stats = parse_cleaner_delta_stdout(clean_result.stdout)
    for key in CLEANER_DELTA_STAT_KEYS:
        if cleaner_stdout_stats[key] != delta_stats[key]:
            raise RuntimeError(f"edge cleaner self-reported {key}={cleaner_stdout_stats[key]}, actual={delta_stats[key]}")
    assert_cleaner_stats_json(
        cleaner_stats_path,
        cutout_path,
        cleaned_path,
        cleaner_review_path,
        4,
        cleaned_pixels,
        delta_stats,
    )
    try:
        assert_edge_clean_delta_contract(delta_stats, cleaned_pixels, require_changed=True)
    except ValueError as exc:
        raise RuntimeError(str(exc)) from exc
    interior_orange_after = count_safety_orange_pixels_in_box(cleaned_path, interior_box)
    if interior_orange_after != interior_orange_before:
        raise RuntimeError("edge cleaner changed intentional interior orange material")
    assert_alpha_unchanged(cutout_path, cleaned_path)
    after_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cleaned_path),
        "--cutout-id",
        "quick_gate_synthetic_orange_fringe_cleaned",
        "--cutout-label",
        "Quick gate synthetic orange-fringe cleaned control",
        "--output-dir",
        rel(cleaned_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    after_result = run_command(after_command, report, expect_success=True)
    if "flagged=0" not in after_result.stdout:
        raise RuntimeError("synthetic cleaned cutout did not pass with flagged=0")
    assert_reference_free_manifest(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "synthetic cleaned cutout audit manifest",
        report,
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )
    after_review_width, after_review_height = assert_nonblank_image(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png",
        "synthetic cleaned cutout audit review sheet",
    )
    report.append(
        f"- PASS synthetic edge-clean regression removed `{cleaned_pixels}` edge/soft-alpha orange pixels while preserving alpha and interior orange material."
    )
    report.append(
        "- PASS edge cleaner pixel delta is limited to safety-orange alpha-edge/soft-alpha targets: "
        f"changed `{delta_stats['changed_rgb_pixels']}`, outside target `{delta_stats['changed_outside_target_pixels']}`, "
        f"opaque interior `{delta_stats['changed_opaque_interior_pixels']}`, alpha changes `{delta_stats['changed_alpha_pixels']}`, "
        f"remaining edge `{delta_stats['remaining_edge_orange_pixels']}`, remaining soft `{delta_stats['remaining_soft_orange_pixels']}`."
    )
    report.append(
        "- PASS edge cleaner stats JSON records the cutout-only/no-reference contract and matches stdout plus pixel delta: "
        f"`{rel(cleaner_stats_path)}`."
    )
    report.append("- PASS edge cleaner stats JSON path provenance matches the audited input, output, review image, and stats file.")
    report.append("- PASS edge cleaner stats JSON file hashes match the audited input, output, and review image bytes.")
    report.append("- PASS edge cleaner default stats-output path is exercised by the quick gate.")
    report.append("- PASS synthetic cleaned cutout audit reruns with strict-zero thresholds.")
    report.append(
        "- PASS synthetic edge-clean review sheets exist and are nonblank: "
        f"before `{before_review_width}x{before_review_height}`, "
        f"cleaner `{cleaner_review_width}x{cleaner_review_height}`, "
        f"after `{after_review_width}x{after_review_height}`."
    )
    report.append("")


def assert_synthetic_raw_key_hole_clean(output_dir: Path, report: list[str]) -> None:
    report.append("## Synthetic Raw-Key Internal-Hole Regression")
    report.append("")
    control_dir = output_dir / "synthetic_raw_key_hole"
    raw_path, cutout_path = write_raw_key_hole_control(control_dir)
    cleaned_path = control_dir / "raw_key_hole_control_cleaned.png"
    cleaner_review_path = control_dir / "raw_key_hole_control_cleaned_review.png"
    cleaner_stats_path = stats_output_path(cleaned_path)
    cutout_only_audit_dir = control_dir / "audit_cutout_only"
    raw_backed_audit_dir = control_dir / "audit_raw_backed_before"
    cleaned_audit_dir = control_dir / "audit_raw_backed_after"
    hole_box = (60, 48, 69, 85)
    material_box = (42, 64, 55, 77)

    if count_visible_alpha_pixels_in_box(cutout_path, hole_box) <= 0:
        raise RuntimeError("synthetic raw-key hole control did not create an opaque internal hole")
    material_alpha_before = count_visible_alpha_pixels_in_box(cutout_path, material_box)
    if material_alpha_before <= 0:
        raise RuntimeError("synthetic raw-key hole control did not create a non-key orange material marker")

    cutout_only_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cutout_path),
        "--cutout-id",
        "raw_key_hole_cutout_only_miss_control",
        "--cutout-label",
        "raw-key hole cutout-only miss control",
        "--output-dir",
        rel(cutout_only_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    cutout_only_result = run_command(cutout_only_command, report, expect_success=True)
    if "flagged=0" not in cutout_only_result.stdout:
        raise RuntimeError("cutout-only strict audit did not reproduce the raw-key hole blind spot")
    assert_reference_free_manifest(
        cutout_only_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "raw-key hole cutout-only audit manifest",
        report,
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )

    raw_backed_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cutout_path),
        "--raw-source",
        rel(raw_path),
        "--cutout-id",
        "raw_key_hole_raw_backed_fail_control",
        "--cutout-label",
        "raw-key hole raw-backed fail control",
        "--output-dir",
        rel(raw_backed_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    raw_backed_result = run_command(raw_backed_command, report, expect_success=False)
    if "flagged=1" not in raw_backed_result.stdout:
        raise RuntimeError("raw-backed strict audit did not flag the synthetic internal raw-key hole")
    assert_raw_backed_cutout_manifest(
        raw_backed_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "raw-key hole raw-backed audit manifest",
        report,
    )
    raw_rows = read_csv(raw_backed_audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    raw_row = raw_rows[0]
    if "raw_key_visible_background_contamination" not in raw_row.get("issue", ""):
        raise RuntimeError("raw-backed synthetic hole audit failed for the wrong issue")
    if int(raw_row.get("raw_key_opaque_interior_pixels", "0")) <= 0:
        raise RuntimeError("raw-backed synthetic hole audit did not measure opaque interior raw-key pixels")

    clean_command = [
        sys.executable,
        "tools/art/clean_unit_cutout_orange_edge.py",
        "--input",
        rel(cutout_path),
        "--raw-source",
        rel(raw_path),
        "--output",
        rel(cleaned_path),
        "--review-output",
        rel(cleaner_review_path),
    ]
    clean_result = run_command(clean_command, report, expect_success=True)
    if "raw_key_alpha_cleared_pixels=" not in clean_result.stdout:
        raise RuntimeError("raw-backed cleaner did not report raw_key_alpha_cleared_pixels")
    raw_key_cleared = int(clean_result.stdout.split("raw_key_alpha_cleared_pixels=", 1)[1].splitlines()[0].strip())
    if raw_key_cleared <= 0:
        raise RuntimeError("raw-backed cleaner did not clear the synthetic internal raw-key hole")
    cleaned_pixels = int(clean_result.stdout.split("cleaned_safety_orange_pixels=", 1)[1].splitlines()[0].strip())
    delta_stats = edge_clean_delta_stats(Image.open(cutout_path), Image.open(cleaned_path), 4, Image.open(raw_path), 20)
    cleaner_stdout_stats = parse_cleaner_delta_stdout(clean_result.stdout)
    for key in CLEANER_DELTA_STAT_KEYS:
        if cleaner_stdout_stats[key] != delta_stats[key]:
            raise RuntimeError(f"raw-backed cleaner self-reported {key}={cleaner_stdout_stats[key]}, actual={delta_stats[key]}")
    assert_cleaner_stats_json(
        cleaner_stats_path,
        cutout_path,
        cleaned_path,
        cleaner_review_path,
        4,
        cleaned_pixels,
        delta_stats,
        raw_path,
        raw_key_cleared,
    )
    try:
        assert_edge_clean_delta_contract(delta_stats, cleaned_pixels, raw_key_cleared, require_changed=True)
    except ValueError as exc:
        raise RuntimeError(str(exc)) from exc
    if count_visible_alpha_pixels_in_box(cleaned_path, hole_box) != 0:
        raise RuntimeError("raw-backed cleaner left visible alpha in the synthetic raw-key internal hole")
    if count_visible_alpha_pixels_in_box(cleaned_path, material_box) != material_alpha_before:
        raise RuntimeError("raw-backed cleaner changed non-key intentional orange material alpha")

    cleaned_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cleaned_path),
        "--raw-source",
        rel(raw_path),
        "--cutout-id",
        "raw_key_hole_cleaned_control",
        "--cutout-label",
        "raw-key hole cleaned control",
        "--output-dir",
        rel(cleaned_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    cleaned_result = run_command(cleaned_command, report, expect_success=True)
    if "flagged=0" not in cleaned_result.stdout:
        raise RuntimeError("raw-backed cleaned synthetic hole audit did not report flagged=0")
    assert_raw_backed_cutout_manifest(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "raw-key hole cleaned raw-backed audit manifest",
        report,
    )
    cutout_only_size = assert_nonblank_image(
        cutout_only_audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png",
        "raw-key hole cutout-only audit review sheet",
    )
    raw_backed_size = assert_nonblank_image(
        raw_backed_audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png",
        "raw-key hole raw-backed audit review sheet",
    )
    cleaner_size = assert_nonblank_image(cleaner_review_path, "raw-key hole cleaner review sheet")
    cleaned_size = assert_nonblank_image(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png",
        "raw-key hole cleaned audit review sheet",
    )
    report.append("- PASS cutout-only strict audit reproduces the old blind spot on an opaque internal raw-key hole.")
    report.append("- PASS raw-backed strict audit fails that same internal-hole control with raw_key_visible_background_contamination.")
    report.append(
        "- PASS raw-backed cleaner alpha-clears the raw-key internal hole while preserving non-key intentional orange material "
        f"(raw_key_alpha_cleared={raw_key_cleared})."
    )
    report.append("- PASS raw-backed cleaned cutout reruns with strict-zero raw-key thresholds.")
    report.append(
        "- PASS raw-key regression review sheets are nonblank: "
        f"cutout-only `{cutout_only_size[0]}x{cutout_only_size[1]}`, "
        f"raw-before `{raw_backed_size[0]}x{raw_backed_size[1]}`, "
        f"cleaner `{cleaner_size[0]}x{cleaner_size[1]}`, "
        f"raw-after `{cleaned_size[0]}x{cleaned_size[1]}`."
    )
    report.append("")


def write_raw_key_hole_proof_matrix(path: Path, raw_path: Path, cutout_path: Path) -> None:
    write_json(
        path,
        {
            "proofs": [
                {
                    "id": "raw_key_hole_proof_matrix_control",
                    "subject_id": "raw_key_hole_control",
                    "display_name": "Raw-key hole proof-matrix control",
                    "status": "current_candidate",
                    "reference_role": "review_candidate_not_anchor",
                    "raw": rel(raw_path),
                    "cutout": rel(cutout_path),
                }
            ]
        },
    )


def assert_proof_matrix_raw_source_gate(output_dir: Path, report: list[str]) -> None:
    report.append("## Proof-Matrix Raw-Source Gate")
    report.append("")
    control_dir = output_dir / "proof_matrix_raw_source_control"
    raw_path, cutout_path = write_raw_key_hole_control(control_dir)
    cleaned_path = control_dir / "raw_key_hole_proof_matrix_control_cleaned.png"
    cleaner_review_path = control_dir / "raw_key_hole_proof_matrix_control_cleaned_review.png"
    proof_matrix_path = control_dir / "raw_key_hole_proof_matrix.json"
    cutout_only_audit_dir = control_dir / "audit_cutout_only"
    raw_backed_audit_dir = control_dir / "audit_raw_backed_before"
    cleaned_audit_dir = control_dir / "audit_raw_backed_after"
    write_raw_key_hole_proof_matrix(proof_matrix_path, raw_path, cutout_path)

    cutout_only_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--proof-matrix",
        rel(proof_matrix_path),
        "--output-dir",
        rel(cutout_only_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    cutout_only_result = run_command(cutout_only_command, report, expect_success=True)
    if "flagged=0" not in cutout_only_result.stdout:
        raise RuntimeError("proof-matrix cutout-only audit did not report flagged=0")
    assert_reference_free_manifest(
        cutout_only_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "proof-matrix cutout-only raw-key hole manifest",
        report,
        expected_proof_matrix_loaded=True,
        expected_source_kinds={"proof_matrix_cutout"},
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )

    raw_backed_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--proof-matrix",
        rel(proof_matrix_path),
        "--use-proof-raw-source",
        "--output-dir",
        rel(raw_backed_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    raw_backed_result = run_command(raw_backed_command, report, expect_success=False)
    if "flagged=1" not in raw_backed_result.stdout:
        raise RuntimeError("proof-matrix raw-source audit did not report flagged=1")
    assert_raw_backed_cutout_manifest(
        raw_backed_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "proof-matrix raw-source raw-key hole manifest",
        report,
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
        expected_proof_matrix_loaded=True,
        expected_proof_matrix_raw_source_loaded=True,
        expected_source_kinds={"proof_matrix_cutout"},
    )
    raw_rows = read_csv(raw_backed_audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    raw_row = raw_rows[0]
    if raw_row.get("quality_status") != "fail":
        raise RuntimeError("proof-matrix raw-source audit did not fail")
    if "raw_key_visible_background_contamination" not in raw_row.get("issue", ""):
        raise RuntimeError("proof-matrix raw-source audit did not fail on visible raw-key contamination")
    raw_key_visible_pixels = int(raw_row.get("raw_key_visible_pixels", "0"))
    if raw_key_visible_pixels <= 0:
        raise RuntimeError("proof-matrix raw-source audit did not measure visible raw-key pixels")

    clean_command = [
        sys.executable,
        "tools/art/clean_unit_cutout_orange_edge.py",
        "--input",
        rel(cutout_path),
        "--raw-source",
        rel(raw_path),
        "--output",
        rel(cleaned_path),
        "--review-output",
        rel(cleaner_review_path),
    ]
    clean_result = run_command(clean_command, report, expect_success=True)
    raw_key_cleared = int(clean_result.stdout.split("raw_key_alpha_cleared_pixels=", 1)[1].splitlines()[0].strip())
    if raw_key_cleared != raw_key_visible_pixels:
        raise RuntimeError("proof-matrix raw-source cleaner did not clear measured visible raw-key pixels")

    write_raw_key_hole_proof_matrix(proof_matrix_path, raw_path, cleaned_path)
    cleaned_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--proof-matrix",
        rel(proof_matrix_path),
        "--use-proof-raw-source",
        "--output-dir",
        rel(cleaned_audit_dir),
        "--report-date",
        date.today().isoformat(),
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    cleaned_result = run_command(cleaned_command, report, expect_success=True)
    if "flagged=0" not in cleaned_result.stdout:
        raise RuntimeError("cleaned proof-matrix raw-source audit did not report flagged=0")
    assert_raw_backed_cutout_manifest(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "cleaned proof-matrix raw-source manifest",
        report,
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
        expected_proof_matrix_loaded=True,
        expected_proof_matrix_raw_source_loaded=True,
        expected_source_kinds={"proof_matrix_cutout"},
    )
    cleaned_rows = read_csv(cleaned_audit_dir / "unit_art_cutout_orange_fringe_audit.csv")
    if int(cleaned_rows[0].get("raw_key_visible_pixels", "-1")) != 0:
        raise RuntimeError("cleaned proof-matrix raw-source audit still measured visible raw-key pixels")
    report.append("- PASS proof-matrix cutout-only audit reproduces the raw-key blind spot without loading raw images.")
    report.append("- PASS proof-matrix raw-source audit fails an internal raw-key hole through --use-proof-raw-source.")
    report.append("- PASS cleaned proof-matrix raw-source audit passes with strict-zero raw-key thresholds.")
    report.append("")


def assert_style_sentinels(metrics_csv: Path, output_dir: Path, report: list[str]) -> None:
    report.append("## Style Sentinel Gate")
    report.append("")
    triage_dir = output_dir / "candidate_style_triage"
    command = [
        sys.executable,
        "tools/art/build_unit_art_candidate_triage.py",
        "--metrics-csv",
        rel(metrics_csv),
        "--output-dir",
        rel(triage_dir),
        "--report-date",
        date.today().isoformat(),
    ]
    run_command(command, report, expect_success=True)
    triage_sheet = triage_dir / "candidate_style_triage_review_sheet.png"
    triage_width, triage_height = assert_nonblank_image(triage_sheet, "candidate style triage review sheet")
    negative_control_sheet = triage_dir / "style_negative_control_review_sheet.png"
    negative_control_width, negative_control_height = assert_nonblank_image(
        negative_control_sheet,
        "style negative-control review sheet",
    )
    rows = read_csv(triage_dir / "unit_art_candidate_style_triage.csv")
    by_proof = {row.get("proof_id", ""): row for row in rows}
    totem = by_proof.get("totem_dry_wood_guardian_refit")
    if totem is None:
        raise RuntimeError("Totem style sentinel row missing from quick candidate triage")
    if totem.get("review_stance") != "style_audit_failed_negative_control":
        raise RuntimeError("Totem is no longer failing the quick style sentinel gate")
    if totem.get("metric_false_positive_control") != "yes":
        raise RuntimeError("Totem is no longer marked as the metric false-positive sentinel")
    if float(totem.get("edge_delta_vellum", "0")) < 0.0 or float(totem.get("contrast_delta_vellum", "0")) < 0.0:
        raise RuntimeError("Totem no longer proves proxy-metric false positive against Vellum")
    token = by_proof.get("ability_token_contract_mark")
    if token is None or token.get("prompt_context_status") != "small_asset_context_only_not_character_palette":
        raise RuntimeError("Token is not fenced as small-asset-only context")
    hot_highlight_rows = [row for row in rows if "hot_highlight_matte_review" in row.get("flags", "")]
    if not hot_highlight_rows:
        raise RuntimeError("hot-highlight matte-review sentinel rows missing")
    report.append(f"- Metrics source: `{rel(metrics_csv)}`")
    report.append("- PASS Totem fails style triage while still proving proxy metrics can lie.")
    report.append("- PASS Token remains small-asset-only context.")
    report.append(f"- PASS hot-highlight matte-review rows present: `{len(hot_highlight_rows)}`.")
    report.append(f"- PASS candidate triage review sheet exists and is nonblank: `{triage_width}x{triage_height}`.")
    report.append(f"- PASS style negative-control review sheet exists and is nonblank: `{negative_control_width}x{negative_control_height}`.")
    report.append("")


def assert_metrics_reference_hierarchy(metrics_csv: Path, report: list[str]) -> None:
    report.append("## Metrics Reference Hierarchy Gate")
    report.append("")
    rows = read_csv(metrics_csv)
    required_fields = {"label", "kind", "role"} | STYLE_METRIC_FIELDS
    present_fields = csv_fields(metrics_csv)
    missing_fields = sorted(required_fields - present_fields)
    if missing_fields:
        raise RuntimeError(f"metrics CSV missing required hierarchy fields: {missing_fields}")
    if len(rows) < len(REFERENCE_ROLE_EXPECTATIONS) + 1:
        raise RuntimeError("metrics CSV is too small to prove reference hierarchy")
    expected_labels = list(REFERENCE_ROLE_EXPECTATIONS.keys())
    actual_first_labels = [row.get("label", "") for row in rows[: len(expected_labels)]]
    if actual_first_labels != expected_labels:
        raise RuntimeError(f"metrics CSV must start with Vellum, Paisley, token rows; got {actual_first_labels}")
    by_label = {row.get("label", ""): row for row in rows}
    for label, (expected_kind, expected_role) in REFERENCE_ROLE_EXPECTATIONS.items():
        matching_rows = [row for row in rows if row.get("label") == label]
        if len(matching_rows) != 1:
            raise RuntimeError(f"metrics CSV must contain exactly one {label} row, got {len(matching_rows)}")
        row = by_label.get(label)
        if row is None:
            raise RuntimeError(f"metrics CSV missing reference row {label}")
        if row.get("kind") != expected_kind:
            raise RuntimeError(f"{label} kind must be {expected_kind}, got {row.get('kind')}")
        if row.get("role") != expected_role:
            raise RuntimeError(f"{label} role must be {expected_role}, got {row.get('role')}")
    invalid_anchor_rows = [
        row
        for row in rows
        if row.get("label", "") not in REFERENCE_ROLE_EXPECTATIONS
        and row.get("role", "") in ANCHOR_ROLES
    ]
    if invalid_anchor_rows:
        details = ", ".join(f"{row.get('label')}:{row.get('role')}" for row in invalid_anchor_rows)
        raise RuntimeError(f"only locked reference rows can use anchor roles: {details}")
    ordinary_roles = sorted({
        row.get("role", "")
        for row in rows
        if not str(row.get("label", "")).startswith("REF ")
    })
    report.append("- PASS metrics CSV starts with Vellum, Paisley, and token reference rows in that order.")
    report.append("- PASS Vellum is the only primary anchor, Paisley is secondary contrast, and the token is small-asset-only.")
    report.append("- PASS only locked reference rows can use anchor roles.")
    report.append(f"- Non-reference roles present: `{', '.join(ordinary_roles)}`.")
    report.append("")


def assert_tampered_metrics_negative_controls(metrics_csv: Path, output_dir: Path, report: list[str]) -> None:
    report.append("## Tampered Metrics Negative-Control Gate")
    report.append("")
    control_dir = output_dir / "tampered_metric_controls"
    rows = read_csv(metrics_csv)
    if len(rows) < 4:
        raise RuntimeError("metrics CSV is too small for tampered negative controls")

    def write_case(name: str, case_rows: list[dict[str, str]]) -> Path:
        path = control_dir / f"{name}.csv"
        write_csv(path, case_rows)
        return path

    swapped_rows = [dict(row) for row in rows]
    swapped_rows[0], swapped_rows[1] = swapped_rows[1], swapped_rows[0]
    swapped_path = write_case("bad_reference_order", swapped_rows)
    expect_runtime_failure(
        "bad reference row order",
        "metrics CSV must start with Vellum, Paisley, token rows",
        lambda: assert_metrics_reference_hierarchy(swapped_path, []),
        report,
    )

    duplicate_path = write_case("duplicate_vellum_reference", [dict(row) for row in rows] + [dict(rows[0])])
    expect_runtime_failure(
        "duplicate Vellum reference row",
        "metrics CSV must contain exactly one REF Vellum raw row",
        lambda: assert_metrics_reference_hierarchy(duplicate_path, []),
        report,
    )

    wrong_token_rows = [dict(row) for row in rows]
    for row in wrong_token_rows:
        if row.get("label") == "REF Token":
            row["role"] = "secondary_contrast_anchor"
            break
    wrong_token_path = write_case("wrong_token_anchor_role", wrong_token_rows)
    expect_runtime_failure(
        "wrong token anchor role",
        "REF Token role must be small_asset_material_reference",
        lambda: assert_metrics_reference_hierarchy(wrong_token_path, []),
        report,
    )

    extra_anchor = dict(rows[3])
    extra_anchor["label"] = "REF Fake Extra Anchor"
    extra_anchor["kind"] = "fake_extra_anchor"
    extra_anchor["role"] = "primary_anchor"
    extra_anchor_path = write_case("extra_ref_anchor_role", [dict(row) for row in rows] + [extra_anchor])
    expect_runtime_failure(
        "extra reference anchor row",
        "only locked reference rows can use anchor roles",
        lambda: assert_metrics_reference_hierarchy(extra_anchor_path, []),
        report,
    )

    ordinary_anchor_rows = [dict(row) for row in rows]
    ordinary_row = next((row for row in ordinary_anchor_rows if not str(row.get("label", "")).startswith("REF ")), None)
    if ordinary_row is None:
        raise RuntimeError("metrics CSV has no ordinary row for anchor-role tamper check")
    ordinary_row["role"] = "primary_anchor"
    ordinary_anchor_path = write_case("ordinary_row_anchor_role", ordinary_anchor_rows)
    expect_runtime_failure(
        "ordinary row promoted to primary anchor",
        "only locked reference rows can use anchor roles",
        lambda: assert_metrics_reference_hierarchy(ordinary_anchor_path, []),
        report,
    )

    missing_totem_rows = [
        dict(row)
        for row in rows
        if row.get("kind") != "totem_dry_wood_guardian_refit"
    ]
    missing_totem_path = write_case("missing_totem_negative_control", missing_totem_rows)
    triage_missing_dir = control_dir / "missing_totem_triage"
    missing_totem_command = [
        sys.executable,
        "tools/art/build_unit_art_candidate_triage.py",
        "--metrics-csv",
        rel(missing_totem_path),
        "--output-dir",
        rel(triage_missing_dir),
        "--report-date",
        date.today().isoformat(),
    ]
    missing_totem_result = subprocess.run(
        missing_totem_command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if missing_totem_result.returncode == 0:
        raise RuntimeError("missing Totem negative-control metrics unexpectedly passed candidate triage")
    if "required style negative controls missing" not in missing_totem_result.stdout:
        raise RuntimeError("missing Totem negative-control metrics failed for the wrong reason")
    report.append("- PASS missing Totem metrics row fails required negative-control enforcement.")

    low_proxy_rows = [dict(row) for row in rows]
    vellum_row = next((row for row in low_proxy_rows if row.get("label") == "REF Vellum raw"), None)
    totem_row = next((row for row in low_proxy_rows if row.get("kind") == "totem_dry_wood_guardian_refit"), None)
    if vellum_row is None or totem_row is None:
        raise RuntimeError("cannot build low-proxy Totem metric negative control")
    totem_row["edge_mean"] = f"{float(vellum_row['edge_mean']) - 8.0:.4f}"
    totem_row["gray_std"] = f"{float(vellum_row['gray_std']) - 8.0:.4f}"
    low_proxy_path = write_case("totem_low_proxy_metrics", low_proxy_rows)
    expect_runtime_failure(
        "Totem low-proxy metric mutation",
        "Totem is no longer marked as the metric false-positive sentinel",
        lambda: assert_style_sentinels(low_proxy_path, control_dir / "totem_low_proxy_sentinel", []),
        report,
    )
    report.append("- PASS tampered metric controls prove corrupted anchors and broken Totem sentinel states fail.")
    report.append("")


def proof_matrix_copy_with_totem_mutation(mutator: Callable[[dict[str, Any], dict[str, Any]], None]) -> dict[str, Any]:
    proof_data = json.loads(json.dumps(read_json(PROOF_MATRIX_PATH)))
    proofs = proof_data.get("proofs")
    if not isinstance(proofs, list):
        raise RuntimeError("proof matrix missing proofs array")
    totem = next(
        (
            proof
            for proof in proofs
            if isinstance(proof, dict) and proof.get("id") == "totem_dry_wood_guardian_refit"
        ),
        None,
    )
    if totem is None:
        raise RuntimeError("live proof matrix missing Totem negative-control proof")
    mutator(proof_data, totem)
    return proof_data


def expect_tampered_proof_matrix_failure(
    label: str,
    proof_data: dict[str, Any],
    expected_message: str,
    metrics_csv: Path,
    control_dir: Path,
    report: list[str],
) -> None:
    proof_path = control_dir / f"{label}.json"
    triage_dir = control_dir / f"{label}_triage"
    write_json(proof_path, proof_data)
    command = [
        sys.executable,
        "tools/art/build_unit_art_candidate_triage.py",
        "--metrics-csv",
        rel(metrics_csv),
        "--proof-matrix",
        rel(proof_path),
        "--output-dir",
        rel(triage_dir),
        "--report-date",
        date.today().isoformat(),
    ]
    result = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode == 0:
        raise RuntimeError(f"{label} proof-matrix mutation unexpectedly passed candidate triage")
    if expected_message not in result.stdout:
        raise RuntimeError(f"{label} proof-matrix mutation failed for the wrong reason: {result.stdout.strip()}")
    report.append(f"- PASS {label} fails with `{expected_message}`.")


def assert_tampered_proof_matrix_negative_controls(metrics_csv: Path, output_dir: Path, report: list[str]) -> None:
    report.append("## Tampered Proof-Matrix Negative-Control Gate")
    report.append("")
    control_dir = output_dir / "tampered_proof_matrix_controls"

    def remove_totem(proof_data: dict[str, Any], _totem: dict[str, Any]) -> None:
        proofs = proof_data.get("proofs")
        if not isinstance(proofs, list):
            raise RuntimeError("proof matrix missing proofs array")
        proof_data["proofs"] = [
            proof
            for proof in proofs
            if not (isinstance(proof, dict) and proof.get("id") == "totem_dry_wood_guardian_refit")
        ]

    def remove_negative_control_flag(_proof_data: dict[str, Any], totem: dict[str, Any]) -> None:
        totem["style_negative_control"] = False

    def promote_totem_verdict(_proof_data: dict[str, Any], totem: dict[str, Any]) -> None:
        override = totem.get("style_audit_override")
        if not isinstance(override, dict):
            override = {}
            totem["style_audit_override"] = override
        override["verdict"] = "pass"

    def remove_totem_reason(_proof_data: dict[str, Any], totem: dict[str, Any]) -> None:
        override = totem.get("style_audit_override")
        if not isinstance(override, dict):
            override = {}
            totem["style_audit_override"] = override
        override["reason"] = ""

    expect_tampered_proof_matrix_failure(
        "missing_totem_proof",
        proof_matrix_copy_with_totem_mutation(remove_totem),
        "required style negative control missing from proof matrix",
        metrics_csv,
        control_dir,
        report,
    )
    expect_tampered_proof_matrix_failure(
        "totem_negative_control_flag_removed",
        proof_matrix_copy_with_totem_mutation(remove_negative_control_flag),
        "required style negative control must be explicit style_negative_control=true",
        metrics_csv,
        control_dir,
        report,
    )
    expect_tampered_proof_matrix_failure(
        "totem_verdict_promoted_to_pass",
        proof_matrix_copy_with_totem_mutation(promote_totem_verdict),
        "required style negative control must declare style_audit_override verdict=fail",
        metrics_csv,
        control_dir,
        report,
    )
    expect_tampered_proof_matrix_failure(
        "totem_override_reason_removed",
        proof_matrix_copy_with_totem_mutation(remove_totem_reason),
        "required style negative control must include style_audit_override reason",
        metrics_csv,
        control_dir,
        report,
    )
    report.append("- PASS tampered proof-matrix controls prove Totem source-policy corruption fails before style report generation.")
    report.append("")


def assert_vellum_first_visual_evidence(metrics_csv: Path, report: list[str]) -> None:
    report.append("## Vellum-First Visual Evidence Gate")
    report.append("")
    audit_dir = metrics_csv.parent
    sizes: list[str] = []
    for sheet_name in STYLE_AUDIT_SHEETS:
        width, height = assert_nonblank_image(audit_dir / sheet_name, sheet_name)
        sizes.append(f"`{sheet_name}` {width}x{height}")
    report.append(f"- Metrics source: `{rel(metrics_csv)}`")
    report.append("- PASS Vellum-first pairwise, reference-ladder, raw contact, and board contact sheets exist and are nonblank.")
    report.append(f"- Sheet sizes: {', '.join(sizes)}.")
    report.append("")


def write_report(path: Path, report: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(report).rstrip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--metrics-csv", type=Path, help="Foreground detail metrics CSV for quick style sentinels.")
    parser.add_argument("--skip-style", action="store_true", help="Run only cutout/de-orange gates.")
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    report: list[str] = [
        "# Quick Unit Art Audit Gates",
        "",
        f"- Date: {date.today().isoformat()}",
        "- Scope: fast non-generative gate for objective cutout contamination, edge-clean regression, and style sentinels.",
        "",
    ]
    assert_cutout_gate(output_dir, report)
    assert_cutout_self_test_matrix(output_dir, report)
    assert_strict_zero_cutout_gate(output_dir, report)
    assert_raw_key_hole_gate(output_dir, report)
    assert_synthetic_edge_clean(output_dir, report)
    assert_synthetic_raw_key_hole_clean(output_dir, report)
    assert_proof_matrix_raw_source_gate(output_dir, report)
    if not args.skip_style:
        metrics_csv = args.metrics_csv if args.metrics_csv is not None else find_latest_metrics_csv()
        if not metrics_csv.is_absolute():
            metrics_csv = ROOT / metrics_csv
        if not metric_csv_is_current_shape(metrics_csv):
            raise RuntimeError(f"metrics CSV missing hot-highlight/luma fields: {rel(metrics_csv)}")
        assert_metrics_reference_hierarchy(metrics_csv, report)
        assert_tampered_metrics_negative_controls(metrics_csv, output_dir, report)
        assert_tampered_proof_matrix_negative_controls(metrics_csv, output_dir, report)
        assert_vellum_first_visual_evidence(metrics_csv, report)
        assert_style_sentinels(metrics_csv, output_dir, report)
    else:
        report.append("## Style Sentinel Gate")
        report.append("")
        report.append("- SKIP requested by --skip-style.")
        report.append("")
    report.append("## Verdict")
    report.append("")
    report.append("- PASS quick unit-art audit gates are satisfied.")
    report_path = output_dir / "quick_unit_art_audit_gates.md"
    write_report(report_path, report)
    print(f"PASS: wrote {rel(report_path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
