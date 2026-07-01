from __future__ import annotations

import argparse
import csv
import subprocess
import sys
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"quick_art_audit_gates_{date.today().strftime('%Y_%m_%d')}"
STYLE_METRIC_FIELDS = {"p95_luma", "p99_luma", "bright_pixel_ratio", "hot_highlight_ratio"}


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


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def csv_fields(path: Path) -> set[str]:
    with path.open(encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return set(reader.fieldnames or [])


def metric_csv_is_current_shape(path: Path) -> bool:
    if not path.exists():
        return False
    return STYLE_METRIC_FIELDS.issubset(csv_fields(path))


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


def write_synthetic_cutout(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((34, 18, 94, 112), fill=(70, 80, 92, 255))
    draw.ellipse((56, 56, 72, 72), fill=(248, 68, 1, 255))
    draw.ellipse((34, 18, 94, 112), outline=(248, 68, 1, 255), width=6)
    image.save(path)


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
    report.append(f"- Rejected negative-example cutouts still flagged: `{len(rejected_failures)}`.")
    report.append("")


def assert_synthetic_edge_clean(output_dir: Path, report: list[str]) -> None:
    report.append("## Synthetic Edge-Clean Regression")
    report.append("")
    control_dir = output_dir / "synthetic_edgeclean"
    cutout_path = control_dir / "synthetic_orange_fringe_cutout.png"
    cleaned_path = control_dir / "synthetic_orange_fringe_cutout_edgeclean.png"
    cleaner_review_path = control_dir / "synthetic_orange_fringe_cutout_edgeclean_review.png"
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
    ]
    before_result = run_command(before_command, report, expect_success=False)
    if "flagged=1" not in before_result.stdout:
        raise RuntimeError("synthetic contaminated cutout did not fail with flagged=1")
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
    if "cleaned_edge_orange_pixels=" not in clean_result.stdout:
        raise RuntimeError("edge cleaner did not report cleaned_edge_orange_pixels")
    cleaned_pixels = int(clean_result.stdout.split("cleaned_edge_orange_pixels=", 1)[1].splitlines()[0].strip())
    if cleaned_pixels <= 0:
        raise RuntimeError("edge cleaner did not remove any synthetic safety-orange edge pixels")
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
    ]
    after_result = run_command(after_command, report, expect_success=True)
    if "flagged=0" not in after_result.stdout:
        raise RuntimeError("synthetic cleaned cutout did not pass with flagged=0")
    report.append(
        f"- PASS synthetic edge-clean regression removed `{cleaned_pixels}` edge-orange pixels while preserving alpha and interior orange material."
    )
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
    assert_synthetic_edge_clean(output_dir, report)
    if not args.skip_style:
        metrics_csv = args.metrics_csv if args.metrics_csv is not None else find_latest_metrics_csv()
        if not metrics_csv.is_absolute():
            metrics_csv = ROOT / metrics_csv
        if not metric_csv_is_current_shape(metrics_csv):
            raise RuntimeError(f"metrics CSV missing hot-highlight/luma fields: {rel(metrics_csv)}")
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
