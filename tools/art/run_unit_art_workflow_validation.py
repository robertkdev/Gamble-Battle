from __future__ import annotations

import argparse
import csv
import json
import py_compile
import subprocess
import sys
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw

from clean_unit_cutout_orange_edge import assert_edge_clean_delta_contract, edge_clean_delta_stats, file_sha256, stats_output_path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"workflow_validation_{date.today().strftime('%Y_%m_%d')}"
CREEP_REVISION_PROMPT_PACKET = ROOT / "docs" / "art" / "creep_revision_prompt_packet_2026_07_01" / "creep.md"
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"

ART_TOOLS = [
    ROOT / "tools" / "art" / "apply_unit_art_review_decision.py",
    ROOT / "tools" / "art" / "audit_unit_cutout_orange_fringe.py",
    ROOT / "tools" / "art" / "build_unit_art_board_preview.py",
    ROOT / "tools" / "art" / "build_unit_art_prompt_packet.py",
    ROOT / "tools" / "art" / "build_unit_art_candidate_triage.py",
    ROOT / "tools" / "art" / "build_unit_art_review_packet.py",
    ROOT / "tools" / "art" / "build_unit_art_review_queue.py",
    ROOT / "tools" / "art" / "build_unit_roster_contact_sheet.py",
    ROOT / "tools" / "art" / "build_unit_art_workflow_completion_audit.py",
    ROOT / "tools" / "art" / "build_unit_roster_prompt_packet.py",
    ROOT / "tools" / "art" / "build_unit_style_drift_audit.py",
    ROOT / "tools" / "art" / "check_unit_art_audit_gates.py",
    ROOT / "tools" / "art" / "combine_unit_alpha_masks.py",
    ROOT / "tools" / "art" / "clean_unit_cutout_orange_edge.py",
    ROOT / "tools" / "art" / "run_unit_art_workflow_validation.py",
    ROOT / "tools" / "art" / "validate_unit_art_workflow_doc.py",
]

REFERENCE_ROLE_EXPECTATIONS = {
    "REF Vellum raw": "primary_anchor",
    "REF Paisley": "secondary_contrast_anchor",
    "REF Token": "small_asset_material_reference",
}
CLEANER_DELTA_STAT_KEYS = [
    "target_edge_orange_pixels",
    "target_soft_orange_pixels",
    "target_cleanup_pixels",
    "target_raw_key_visible_pixels",
    "target_visual_fringe_pixels",
    "target_background_alpha_pixels",
    "changed_rgb_pixels",
    "changed_alpha_pixels",
    "changed_outside_target_pixels",
    "changed_outside_edge_pixels",
    "changed_opaque_interior_pixels",
    "changed_opaque_interior_outside_raw_key_pixels",
    "changed_alpha_outside_raw_key_pixels",
    "changed_opaque_interior_outside_background_target_pixels",
    "changed_alpha_outside_background_target_pixels",
    "remaining_edge_orange_pixels",
    "remaining_soft_orange_pixels",
    "remaining_raw_key_visible_pixels",
    "remaining_visual_fringe_pixels",
    "removed_edge_orange_pixels",
    "removed_soft_orange_pixels",
    "removed_cleanup_pixels",
    "cleared_raw_key_visible_pixels",
    "cleared_visual_fringe_pixels",
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
    "max_visual_fringe_pixels": 0,
}


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def run_step(name: str, command: list[str], report: list[str]) -> None:
    report.append(f"## {name}")
    report.append("")
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
    if result.returncode != 0:
        raise RuntimeError(f"{name} failed with exit code {result.returncode}")


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
    payload = json.loads(path.read_text(encoding="utf-8"))
    raw_loaded = raw_source_path is not None
    expected_input_contract = "cutout_rgba_plus_raw_background_key_pixels_plus_visual_background_fringe" if raw_loaded else "cutout_rgba_pixels_only"
    expected_clean_contract = "safety_orange_alpha_edge_or_soft_rgb_plus_raw_key_visible_alpha_clear_plus_visual_fringe_alpha_clear" if raw_loaded else "safety_orange_alpha_edge_or_soft_pixels_only"
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
    if int(payload.get("visual_fringe_alpha_cleared_pixels", -1)) != delta_stats["target_visual_fringe_pixels"]:
        raise RuntimeError("edge cleaner stats JSON visual-fringe alpha clear count does not match pixel delta")
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


def find_proof(proof_id: str) -> dict[str, str]:
    data = json.loads(PROOF_MATRIX_PATH.read_text(encoding="utf-8"))
    for proof in data.get("proofs", []):
        if isinstance(proof, dict) and proof.get("id") == proof_id:
            return {str(key): str(value) for key, value in proof.items()}
    raise RuntimeError(f"unknown proof id: {proof_id}")


def assert_accept_requires_scorecard(proof_id: str, report: list[str]) -> None:
    command = [
        sys.executable,
        "tools/art/apply_unit_art_review_decision.py",
        "--proof-id",
        proof_id,
        "--decision",
        "accept",
        "--reason",
        "validation missing-scorecard negative control",
        "--dry-run",
    ]
    report.append("## Review Decision Helper Missing Scorecard Guard")
    report.append("")
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
    if result.returncode == 0:
        raise RuntimeError("accept without scorecard unexpectedly passed")
    if "accept requires every scorecard gate to be pass" not in result.stdout:
        raise RuntimeError("accept missing-scorecard guard failed without the expected error")
    report.append("- PASS accept is blocked unless every scorecard gate is recorded as pass.")
    report.append("")


def assert_style_negative_control_cannot_accept(proof_id: str, report: list[str]) -> None:
    scorecard_path = ROOT / "outputs" / "art_pipeline" / "style_validation" / "_validation_style_negative_control_all_pass_scorecard.json"
    write_all_pass_scorecard(scorecard_path, proof_id)
    command = [
        sys.executable,
        "tools/art/apply_unit_art_review_decision.py",
        "--proof-id",
        proof_id,
        "--decision",
        "accept",
        "--reason",
        "validation negative-control accept guard",
        "--scorecard-json",
        rel(scorecard_path),
        "--dry-run",
    ]
    report.append("## Review Decision Helper Style Negative-Control Guard")
    report.append("")
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
    if result.returncode == 0:
        raise RuntimeError(f"style negative control {proof_id} unexpectedly accepted")
    if "style_negative_control and cannot be accepted" not in result.stdout:
        raise RuntimeError("style negative-control accept guard failed without the expected error")
    report.append(f"- PASS `{proof_id}` cannot be accepted even with an all-pass scorecard.")
    report.append("")


def write_all_pass_scorecard(path: Path, proof_id: str) -> None:
    scorecard = {
        "vellum_veto": "pass",
        "creep_identity": "pass",
        "de_shined_material": "pass",
        "detail_richness": "pass",
        "board_scale_read": "pass",
        "cutout_quality": "pass",
        "reference_role": "pass",
    }
    path.write_text(
        json.dumps(
            {
                "proof_id": proof_id,
                "scorecard": scorecard,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def compile_art_tools(report: list[str]) -> None:
    report.append("## Python Compile")
    report.append("")
    for path in ART_TOOLS:
        py_compile.compile(str(path), doraise=True)
        report.append(f"- PASS `{rel(path)}`")
    report.append("")


def assert_packet_reference_hierarchy(packet_dir: Path, report: list[str]) -> None:
    packets = sorted(packet_dir.glob("*.md"))
    unit_packets = [path for path in packets if path.name != "index.md"]
    if len(unit_packets) < 23:
        raise RuntimeError(f"expected at least 23 unit packets, found {len(unit_packets)} in {rel(packet_dir)}")
    required = [
        "## Reference Hierarchy",
        "Primary/ultimate anchor: `vellum_raw_anchor`",
        "Promotion rule:",
        "Candidate rule:",
        "Small-asset rule:",
        "Do not use its warmer parchment palette as a character palette or unit style anchor.",
        "Prompt-context rule:",
        "## Unit Proof Context",
    ]
    failures: list[str] = []
    for path in unit_packets:
        text = path.read_text(encoding="utf-8")
        missing = [snippet for snippet in required if snippet not in text]
        if missing:
            failures.append(f"{rel(path)} missing {missing}")
    if failures:
        raise RuntimeError("; ".join(failures))
    grint_packet = packet_dir / "grint.md"
    if not grint_packet.exists():
        raise RuntimeError(f"expected Grint prompt packet: {rel(grint_packet)}")
    grint_text = grint_packet.read_text(encoding="utf-8")
    grint_required = [
        "grint_hard_matte_refit",
        "blocked_until_vellum_pairwise_review",
        "Do not use as prompt/style context until Vellum-first review clears it.",
    ]
    missing_grint = [snippet for snippet in grint_required if snippet not in grint_text]
    if missing_grint:
        raise RuntimeError(f"{rel(grint_packet)} missing Grint quarantine snippets: {missing_grint}")
    kythera_packet = packet_dir / "kythera.md"
    if not kythera_packet.exists():
        raise RuntimeError(f"expected Kythera prompt packet: {rel(kythera_packet)}")
    kythera_text = kythera_packet.read_text(encoding="utf-8")
    kythera_required = [
        "kythera_mummy_goth_refit",
        "narrow_context_only_not_anchor",
        "Same-unit identity/process history only; do not feed as a style reference",
        "Identity/process-history raw, not a style reference",
    ]
    missing_kythera = [snippet for snippet in kythera_required if snippet not in kythera_text]
    if missing_kythera:
        raise RuntimeError(f"{rel(kythera_packet)} missing accepted-proof identity-history fence snippets: {missing_kythera}")
    if "Narrow proof raw" in kythera_text:
        raise RuntimeError(f"{rel(kythera_packet)} still labels accepted proof raw as a narrow proof reference")
    paisley_packet = packet_dir / "paisley.md"
    if not paisley_packet.exists():
        raise RuntimeError(f"expected Paisley prompt packet: {rel(paisley_packet)}")
    paisley_text = paisley_packet.read_text(encoding="utf-8")
    if "prompt context `reference_context_only`" not in paisley_text:
        raise RuntimeError("Paisley secondary anchor is not rendered as reference_context_only in its packet")
    report.append("## Packet Reference Hierarchy")
    report.append("")
    report.append(f"- PASS `{rel(packet_dir)}` contains {len(unit_packets)} unit packets with Vellum-first reference hierarchy sections.")
    report.append("- PASS Grint prompt packet carries its prompt-context quarantine instead of treating the accepted proof as reusable style context.")
    report.append("- PASS Accepted same-unit proof raws are labeled identity/process history, not style references.")
    report.append("- PASS Paisley remains secondary reference context in its own packet, with Vellum still primary.")
    report.append("")


def assert_audit_roles(csv_path: Path, report: list[str]) -> None:
    with csv_path.open(encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fieldnames = reader.fieldnames or []
    if len(rows) < 4:
        raise RuntimeError(f"style audit CSV too small: {rel(csv_path)}")
    required_metric_fields = {"p95_luma", "p99_luma", "bright_pixel_ratio", "hot_highlight_ratio"}
    missing_metric_fields = sorted(required_metric_fields - set(fieldnames))
    if missing_metric_fields:
        raise RuntimeError(f"{rel(csv_path)} missing matte hot-highlight metric fields: {missing_metric_fields}")
    invalid_metric_rows: list[str] = []
    for row in rows:
        for field in required_metric_fields:
            try:
                value = float(row.get(field, ""))
            except ValueError:
                invalid_metric_rows.append(f"{row.get('label', '<unknown>')}:{field}=not-float")
                continue
            if value < 0.0:
                invalid_metric_rows.append(f"{row.get('label', '<unknown>')}:{field}=negative")
    if invalid_metric_rows:
        raise RuntimeError(f"{rel(csv_path)} has invalid hot-highlight metric values: {', '.join(invalid_metric_rows[:8])}")
    by_label = {row["label"]: row for row in rows}
    for label, role in REFERENCE_ROLE_EXPECTATIONS.items():
        actual = by_label.get(label, {}).get("role")
        if actual != role:
            raise RuntimeError(f"{rel(csv_path)} expected {label} role {role}, got {actual}")
    ordinary_roles = {row["role"] for row in rows if not row["label"].startswith("REF ")}
    invalid_anchor_roles = ordinary_roles & {"primary_anchor", "secondary_contrast_anchor", "small_asset_material_reference"}
    if invalid_anchor_roles:
        raise RuntimeError(f"{rel(csv_path)} has non-reference rows with anchor roles: {sorted(invalid_anchor_roles)}")
    report.append("## Style Audit Reference Roles")
    report.append("")
    report.append(f"- PASS `{rel(csv_path)}` keeps Vellum/Paisley/token as the only reference rows.")
    report.append("- PASS foreground-detail metrics include p95/p99 luma plus bright/hot-highlight ratios for matte-sheen review.")
    report.append(f"- Non-reference roles present: `{', '.join(sorted(ordinary_roles))}`.")
    report.append("")


def assert_audit_outputs(audit_dir: Path, report: list[str]) -> None:
    required = [
        "raw_anchor_vs_later_contact_sheet.png",
        "vellum_first_pairwise_raw_comparison.png",
        "reference_ladder_raw_comparison.png",
        "board_preview_drift_contact_sheet.png",
        "foreground_detail_metrics.csv",
    ]
    missing = [name for name in required if not (audit_dir / name).exists()]
    if missing:
        raise RuntimeError(f"{rel(audit_dir)} missing style audit outputs: {missing}")
    report.append("## Vellum Pairwise Audit Output")
    report.append("")
    report.append(f"- PASS `{rel(audit_dir)}` includes the mandatory Vellum-first pairwise comparison sheet and reference-ladder sheet.")
    report.append("")


def assert_proof_policy(report: list[str]) -> None:
    proof_path = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
    data = json.loads(proof_path.read_text(encoding="utf-8"))
    policy = data["style_contract"]["reference_policy"]
    primary = policy["primary_anchor"]
    primary_path = ROOT / primary["path"]
    if primary["id"] != "vellum_raw_anchor":
        raise RuntimeError("primary anchor id is not vellum_raw_anchor")
    if not primary_path.exists():
        raise RuntimeError(f"primary anchor path missing: {rel(primary_path)}")
    if "paisley_goth_bubble_refit" not in policy["secondary_anchor_proof_ids"]:
        raise RuntimeError("Paisley missing from secondary anchor proof ids")
    if "ability_token_contract_mark" not in policy["small_asset_reference_proof_ids"]:
        raise RuntimeError("contract token missing from small asset reference proof ids")
    if "character palette" not in str(policy.get("small_asset_rule", "")):
        raise RuntimeError("small asset rule must fence the token away from character palette use")
    for field, phrases in (
        ("side_by_side_rule", ("Vellum-first", "side-by-side")),
        ("passing_pool_rule", ("Do not average", "passing pool")),
    ):
        value = str(policy.get(field, ""))
        missing = [phrase for phrase in phrases if phrase.lower() not in value.lower()]
        if missing:
            raise RuntimeError(f"reference policy {field} missing {missing}")
    report.append("## Proof Reference Policy")
    report.append("")
    report.append(f"- PASS primary anchor `{primary['id']}` exists at `{primary['path']}`.")
    report.append("- PASS Paisley/token remain the only promoted secondary/small-asset references.")
    report.append("- PASS The token is fenced as small-asset material context, not a character palette/style anchor.")
    report.append("")


def assert_completion_audit(audit_path: Path, report: list[str]) -> None:
    text = audit_path.read_text(encoding="utf-8")
    required = [
        "Verdict: **INCOMPLETE**",
        "candidate needs human approval",
        "style negative control, must fail audit",
        "Expected style negative controls are not candidates for approval",
        "needs visual proof",
        "next recommended stress test remains `creep`",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(audit_path)} missing completion audit snippets: {missing}")
    report.append("## Completion Audit")
    report.append("")
    report.append(f"- PASS `{rel(audit_path)}` conservatively records the workflow as incomplete and names the remaining gates.")
    report.append("")


def assert_review_queue(queue_path: Path, report: list[str]) -> None:
    text = queue_path.read_text(encoding="utf-8")
    required = [
        "Next Gate",
        "Creep (`creep`)",
        "creep_vellum_primary_detail_refit",
        "Do not continue to Veyra or broader roster generation",
        "apply_unit_art_review_decision.py",
        "--decision request_revision",
        "--scorecard-json",
        "Expected style negative controls are non-approvable",
        "style_negative_control",
        "Scorecard template",
        "creep_review_decision_packet_2026-07-01_scorecard_template.json",
        "Approval Checklist",
        "Rejection Checklist",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(queue_path)} missing review queue snippets: {missing}")
    report.append("## Review Queue")
    report.append("")
    report.append(f"- PASS `{rel(queue_path)}` names Creep as the next gate and includes approval/rejection criteria.")
    report.append("")


def assert_nonblank_report_image(path: Path, label: str, min_width: int = 128, min_height: int = 128) -> tuple[int, int]:
    if not path.exists():
        raise RuntimeError(f"{label} missing: {rel(path)}")
    if path.stat().st_size <= 0:
        raise RuntimeError(f"{label} is empty: {rel(path)}")
    image = Image.open(path).convert("RGB")
    width, height = image.size
    if width < min_width or height < min_height:
        raise RuntimeError(f"{label} is too small to be useful: {width}x{height}")
    extrema = image.getextrema()
    if max(high - low for low, high in extrema) < 16:
        raise RuntimeError(f"{label} appears blank or near-flat: {rel(path)}")
    return width, height


def assert_reference_free_cutout_manifest(
    manifest_path: Path,
    label: str,
    expected_proof_matrix_loaded: bool,
    expected_source_kinds: set[str],
    expected_row_count: int | None = None,
    expected_thresholds: dict[str, int | float] | None = None,
) -> dict[str, object]:
    if not manifest_path.exists():
        raise RuntimeError(f"{label} missing: {rel(manifest_path)}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
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
    return manifest


def assert_candidate_triage(triage_path: Path, report: list[str]) -> None:
    text = triage_path.read_text(encoding="utf-8")
    required = [
        "Vellum is the ultimate character reference",
        "Passing-pool rule",
        "Visual review sheet",
        "Style negative-control sheet",
        "Required Style Negative Controls",
        "Totem is the current required negative control",
        "Human Negative-Control Failures",
        "Hot-Highlight Matte Review",
        "Hot-highlight matte-review rows",
        "hot_highlight_matte_review",
        "style_audit_failed_negative_control",
        "Highest Risk Rows",
        "Prompt-Context Quarantine",
        "blocked_until_vellum_pairwise_review",
        "high_risk_re_review_before_acceptance",
        "Start visual review from the Vellum pairwise sheet",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(triage_path)} missing candidate triage snippets: {missing}")
    review_sheet = triage_path.with_name("candidate_style_triage_review_sheet.png")
    if not review_sheet.exists():
        raise RuntimeError(f"{rel(triage_path.parent)} missing candidate style triage review sheet")
    negative_control_sheet = triage_path.with_name("style_negative_control_review_sheet.png")
    if not negative_control_sheet.exists():
        raise RuntimeError(f"{rel(triage_path.parent)} missing style negative-control review sheet")
    assert_nonblank_report_image(review_sheet, "candidate style triage review sheet", 300, 200)
    assert_nonblank_report_image(negative_control_sheet, "style negative-control review sheet", 300, 200)
    csv_path = triage_path.with_name("unit_art_candidate_style_triage.csv")
    if not csv_path.exists():
        raise RuntimeError(f"{rel(triage_path.parent)} missing candidate style triage CSV")
    rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
    totem_rows = [row for row in rows if row.get("proof_id") == "totem_dry_wood_guardian_refit"]
    if not totem_rows:
        raise RuntimeError("candidate style triage missing Totem negative-control row")
    if totem_rows[0].get("expected_negative_control") != "yes":
        raise RuntimeError("Totem negative control is not marked expected_negative_control=yes")
    if totem_rows[0].get("review_stance") != "style_audit_failed_negative_control":
        raise RuntimeError("Totem negative control did not fail candidate style triage")
    if totem_rows[0].get("metric_false_positive_control") != "yes":
        raise RuntimeError("Totem is not marked as the metric false-positive style sentinel")
    if "metric_false_positive_style_sentinel" not in totem_rows[0].get("flags", ""):
        raise RuntimeError("Totem metric false-positive sentinel flag is missing")
    totem_edge_delta = float(totem_rows[0].get("edge_delta_vellum", "0"))
    totem_contrast_delta = float(totem_rows[0].get("contrast_delta_vellum", "0"))
    if totem_edge_delta < 0.0 or totem_contrast_delta < 0.0:
        raise RuntimeError("Totem no longer proves the metric false-positive case against Vellum")
    hot_highlight_rows = [
        row
        for row in rows
        if "hot_highlight_matte_review" in row.get("flags", "")
    ]
    if not hot_highlight_rows:
        raise RuntimeError("candidate style triage has no hot-highlight matte-review rows")
    pale_material_sentinels = [
        row
        for row in hot_highlight_rows
        if row.get("proof_id") in {"kythera_mummy_goth_refit", "korath_haloed_tank_refit"}
    ]
    if not pale_material_sentinels:
        raise RuntimeError("hot-highlight matte review does not flag a known bright pale-material sentinel")
    for row in hot_highlight_rows:
        try:
            hot_ratio = float(row.get("hot_highlight_ratio", ""))
            p99_luma = float(row.get("p99_luma", ""))
        except ValueError as exc:
            raise RuntimeError(f"hot-highlight review row has invalid metrics: {row.get('proof_id', '<unknown>')}") from exc
        if hot_ratio < 0.5 or p99_luma < 210.0:
            raise RuntimeError(f"hot-highlight review row below its own threshold: {row.get('proof_id', '<unknown>')}")
    grint_rows = [row for row in rows if row.get("proof_id") == "grint_hard_matte_refit"]
    if not grint_rows:
        raise RuntimeError("candidate style triage missing Grint row")
    if grint_rows[0].get("prompt_context_status") != "blocked_until_vellum_pairwise_review":
        raise RuntimeError("Grint is not quarantined from prompt context despite Vellum-pairwise warning")
    token_rows = [row for row in rows if row.get("proof_id") == "ability_token_contract_mark"]
    if not token_rows:
        raise RuntimeError("candidate style triage missing token small-asset row")
    if token_rows[0].get("reference_role") != "small_asset_material_reference":
        raise RuntimeError("token is not marked as small_asset_material_reference")
    if token_rows[0].get("prompt_context_status") != "small_asset_context_only_not_character_palette":
        raise RuntimeError("token is not fenced off from character palette/style context")
    unsafe_accepted = [
        row
        for row in rows
        if row.get("status") == "accepted"
        and row.get("reference_role") == "narrow_proof_only"
        and row.get("review_stance") in {"high_risk_re_review_before_acceptance", "needs_vellum_pairwise_visual_review"}
        and not str(row.get("prompt_context_status", "")).startswith("blocked_")
    ]
    if unsafe_accepted:
        ids = ", ".join(row.get("proof_id", "<unknown>") for row in unsafe_accepted)
        raise RuntimeError(f"accepted risky proofs are not prompt-context quarantined: {ids}")
    report.append("## Candidate Style Triage")
    report.append("")
    report.append(f"- PASS `{rel(triage_path)}` flags candidate-pool drift risks and fails the Totem negative control.")
    report.append("- PASS Totem remains a metric false-positive sentinel: proxy metrics look acceptable, but visual review still fails the matte gothic style.")
    report.append("- PASS Hot-highlight proxy flags bright/pale-material rows for matte visual review without auto-approving or auto-rejecting them.")
    report.append("- PASS Token remains small-asset context only and cannot become a character palette reference.")
    report.append("- PASS Grint and any accepted risky narrow proofs are quarantined from prompt context until Vellum-first review clears them.")
    report.append(f"- PASS `{rel(review_sheet)}` exists for focused visual review.")
    report.append(f"- PASS `{rel(negative_control_sheet)}` exists for Vellum/Paisley/token/Totem negative-control review.")
    report.append("")


def assert_cutout_orange_fringe_audit(audit_path: Path, report: list[str]) -> None:
    text = audit_path.read_text(encoding="utf-8")
    required = [
        "Unit Art Cutout Orange-Fringe Audit",
        "Objective Background-Contamination Gate",
        "does not compare to Vellum, Paisley, the token, or any other reference image",
        "Protected ledger rows flagged: `0`",
        "Current candidates that fail can stay in the ledger as review candidates",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(audit_path)} missing cutout orange-fringe audit snippets: {missing}")
    csv_path = audit_path.with_name("unit_art_cutout_orange_fringe_audit.csv")
    manifest_path = audit_path.with_name("unit_art_cutout_orange_fringe_audit_manifest.json")
    review_sheet = audit_path.with_name("unit_art_cutout_orange_fringe_review_sheet.png")
    if not csv_path.exists():
        raise RuntimeError(f"{rel(audit_path.parent)} missing cutout orange-fringe audit CSV")
    if not manifest_path.exists():
        raise RuntimeError(f"{rel(audit_path.parent)} missing cutout orange-fringe audit manifest")
    if not review_sheet.exists():
        raise RuntimeError(f"{rel(audit_path.parent)} missing cutout orange-fringe review sheet")
    manifest = assert_reference_free_cutout_manifest(
        manifest_path,
        "cutout orange-fringe audit manifest",
        expected_proof_matrix_loaded=True,
        expected_source_kinds={"proof_matrix_cutout"},
    )
    review_width, review_height = assert_nonblank_report_image(review_sheet, "cutout orange-fringe review sheet")
    rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
    protected_failures = [
        row
        for row in rows
        if row.get("quality_status") == "fail" and row.get("proof_status") in {"accepted", "reference"}
    ]
    if protected_failures:
        ids = ", ".join(row.get("id", "<unknown>") for row in protected_failures)
        raise RuntimeError(f"protected ledger cutouts failed orange-fringe audit: {ids}")
    report.append("## Cutout Orange-Fringe Audit")
    report.append("")
    report.append(f"- PASS `{rel(audit_path)}` scores cutout edge residue as objective safety-orange background contamination.")
    report.append(f"- PASS `{rel(manifest_path)}` proves the audit input contract is `{manifest['audit_input_contract']}` and no reference/raw/board/style-anchor images were loaded.")
    report.append(f"- PASS `{rel(review_sheet)}` exists and is nonblank for fast checker/black/white/overlay review: `{review_width}x{review_height}`.")
    report.append("")


def write_synthetic_orange_fringe_cutout(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((34, 18, 94, 112), fill=(70, 80, 92, 255))
    draw.ellipse((56, 56, 72, 72), fill=(248, 68, 1, 255))
    draw.ellipse((34, 18, 94, 112), outline=(248, 68, 1, 255), width=6)
    image.save(path)


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


def assert_synthetic_cutout_negative_control(output_dir: Path, report: list[str]) -> None:
    control_dir = output_dir / "synthetic_cutout_orange_fringe_negative_control"
    cutout_path = control_dir / "synthetic_orange_fringe_cutout.png"
    audit_dir = control_dir / "audit"
    cleaned_path = control_dir / "synthetic_orange_fringe_cutout_edgeclean.png"
    cleaner_review_path = control_dir / "synthetic_orange_fringe_cutout_edgeclean_review.png"
    cleaner_stats_path = stats_output_path(cleaned_path)
    cleaned_audit_dir = control_dir / "audit_after_edgeclean"
    write_synthetic_orange_fringe_cutout(cutout_path)
    interior_box = (52, 52, 76, 76)
    interior_orange_before = count_safety_orange_pixels_in_box(cutout_path, interior_box)
    if interior_orange_before < 120:
        raise RuntimeError("synthetic cutout interior orange preservation marker was not created")
    command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cutout_path),
        "--cutout-id",
        "synthetic_orange_fringe_negative_control",
        "--cutout-label",
        "Synthetic orange-fringe negative control",
        "--output-dir",
        rel(audit_dir),
        "--report-date",
        "2026-07-01",
        "--fail-on-any-fail",
    ]
    report.append("## Synthetic Cutout Orange-Fringe Negative Control")
    report.append("")
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
    if result.returncode == 0:
        raise RuntimeError("synthetic orange-fringe negative control unexpectedly passed")
    if "flagged=1" not in result.stdout:
        raise RuntimeError("synthetic orange-fringe negative control failed without expected flagged=1 output")
    assert_reference_free_cutout_manifest(
        audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "synthetic contaminated cutout audit manifest",
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
    )
    before_review_size = assert_nonblank_report_image(
        audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png",
        "synthetic contaminated cutout audit review sheet",
    )
    report.append("- PASS standalone cutout audit fails a synthetic safety-orange edge-contamination sample without loading any reference images.")
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
    report.append("")
    report.append("```powershell")
    report.append(" ".join(clean_command))
    report.append("```")
    clean_result = subprocess.run(
        clean_command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if clean_result.stdout.strip():
        report.append("")
        report.append("```text")
        report.append(clean_result.stdout.strip())
        report.append("```")
    report.append("")
    if clean_result.returncode != 0:
        raise RuntimeError("synthetic orange-fringe edge cleaner failed")
    if "cleaned_safety_orange_pixels=" not in clean_result.stdout:
        raise RuntimeError("synthetic edge cleaner did not report cleaned_safety_orange_pixels")
    if "cleaned_edge_orange_pixels=" not in clean_result.stdout:
        raise RuntimeError("synthetic edge cleaner did not report legacy cleaned_edge_orange_pixels")
    cleaner_review_size = assert_nonblank_report_image(cleaner_review_path, "synthetic edge-cleaner review sheet")
    cleaned_pixels_text = clean_result.stdout.split("cleaned_safety_orange_pixels=", 1)[1].splitlines()[0].strip()
    try:
        cleaned_pixels = int(cleaned_pixels_text)
    except ValueError as exc:
        raise RuntimeError("synthetic edge cleaner reported a non-integer cleaned pixel count") from exc
    if cleaned_pixels <= 0:
        raise RuntimeError("synthetic edge cleaner did not remove any safety-orange edge pixels")
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
        raise RuntimeError("edge-orange cleaner changed intentional interior orange material")
    assert_alpha_unchanged(cutout_path, cleaned_path)
    cleaned_audit_command = [
        sys.executable,
        "tools/art/audit_unit_cutout_orange_fringe.py",
        "--no-include-proof-matrix",
        "--cutout",
        rel(cleaned_path),
        "--cutout-id",
        "synthetic_orange_fringe_cleaned_control",
        "--cutout-label",
        "Synthetic orange-fringe cleaned control",
        "--output-dir",
        rel(cleaned_audit_dir),
        "--report-date",
        "2026-07-01",
        "--fail-on-any-fail",
        "--strict-zero",
    ]
    report.append("")
    report.append("```powershell")
    report.append(" ".join(cleaned_audit_command))
    report.append("```")
    cleaned_audit_result = subprocess.run(
        cleaned_audit_command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if cleaned_audit_result.stdout.strip():
        report.append("")
        report.append("```text")
        report.append(cleaned_audit_result.stdout.strip())
        report.append("```")
    report.append("")
    if cleaned_audit_result.returncode != 0:
        raise RuntimeError("synthetic cleaned cutout still failed orange-fringe audit")
    if "flagged=0" not in cleaned_audit_result.stdout:
        raise RuntimeError("synthetic cleaned cutout did not report flagged=0")
    assert_reference_free_cutout_manifest(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_audit_manifest.json",
        "synthetic cleaned cutout audit manifest",
        expected_proof_matrix_loaded=False,
        expected_source_kinds={"standalone_cutout"},
        expected_row_count=1,
        expected_thresholds=STRICT_ZERO_CUTOUT_AUDIT_THRESHOLDS,
    )
    after_review_size = assert_nonblank_report_image(
        cleaned_audit_dir / "unit_art_cutout_orange_fringe_review_sheet.png",
        "synthetic cleaned cutout audit review sheet",
    )
    report.append("- PASS edge cleaner removes synthetic safety-orange edge/soft-alpha contamination while preserving alpha and intentional interior orange material.")
    report.append(
        "- PASS edge-cleaner pixel delta is limited to safety-orange alpha-edge/soft-alpha targets "
        f"(changed={delta_stats['changed_rgb_pixels']}, outside_target={delta_stats['changed_outside_target_pixels']}, "
        f"opaque_interior={delta_stats['changed_opaque_interior_pixels']}, alpha_changes={delta_stats['changed_alpha_pixels']}, "
        f"remaining_edge={delta_stats['remaining_edge_orange_pixels']}, remaining_soft={delta_stats['remaining_soft_orange_pixels']})."
    )
    report.append(
        "- PASS edge-cleaner stats JSON records the cutout-only/no-reference contract and matches stdout plus pixel delta: "
        f"`{rel(cleaner_stats_path)}`."
    )
    report.append("- PASS edge-cleaner stats JSON path provenance matches the audited input, output, review image, and stats file.")
    report.append("- PASS edge-cleaner stats JSON file hashes match the audited input, output, and review image bytes.")
    report.append("- PASS edge-cleaner default stats-output path is exercised by the full workflow runner.")
    report.append("- PASS synthetic cleaned cutout audit reruns with strict-zero thresholds.")
    report.append(
        "- PASS synthetic cutout review sheets are nonblank: "
        f"before `{before_review_size[0]}x{before_review_size[1]}`, "
        f"cleaner `{cleaner_review_size[0]}x{cleaner_review_size[1]}`, "
        f"after `{after_review_size[0]}x{after_review_size[1]}`."
    )
    report.append("")


def assert_quick_audit_gates(metrics_csv: Path, output_dir: Path, report: list[str]) -> None:
    quick_dir = output_dir / "quick_unit_art_audit_gates"
    command = [
        sys.executable,
        "tools/art/check_unit_art_audit_gates.py",
        "--output-dir",
        rel(quick_dir),
        "--metrics-csv",
        rel(metrics_csv),
    ]
    report.append("## Quick Unit Art Audit Gates")
    report.append("")
    run_step("Quick Unit Art Audit Gates", command, report)
    quick_report = quick_dir / "quick_unit_art_audit_gates.md"
    if not quick_report.exists():
        raise RuntimeError(f"quick audit gate report missing: {rel(quick_report)}")
    text = quick_report.read_text(encoding="utf-8")
    required = [
        "non-rejected cutouts have no objective safety-orange edge/soft-alpha contamination",
        "current cutout audit manifest proves reference-free cutout-only input contract",
        "current cutout orange-fringe review sheet exists and is nonblank",
        "Objective Cutout Self-Test Matrix",
        "cutout self-test matrix manifest proves reference-free cutout-only input contract",
        "clean transparent cutout control passes",
        "intentional interior orange material control passes",
        "safety-orange edge contamination control fails",
        "soft-alpha safety-orange halo control fails",
        "edge-orange 51-pixel threshold control fails exactly one pixel over the limit",
        "edge-orange ratio threshold control fails even below the pixel-count limit",
        "soft-alpha 21-pixel threshold control fails exactly one pixel over the limit",
        "cutout self-test matrix review sheet exists and is nonblank",
        "Strict-Zero Cutout Gate",
        "default-threshold audit passes a one-pixel edge-orange residue control",
        "strict-zero audit fails the same one-pixel edge-orange residue control",
        "Visual Background-Fringe Gate",
        "raw-backed strict audit fails blue/orange visual background-fringe residue with visual_background_fringe_contamination",
        "visual-fringe cleaner alpha-clears measured blue/orange background-field residue while preserving intentional interior orange material",
        "visual-fringe cleaned cutout reruns with strict-zero visual-fringe thresholds",
        "visual-fringe review sheets are nonblank",
        "Raw-Key Background-Hole Gate",
        "cutout-only strict-zero audit passes a recolored raw-key hole",
        "raw-backed audit fails the same cutout for visible reserved background-key pixels",
        "raw-backed cleaner clears the measured background-key alpha leak",
        "synthetic edge-clean regression removed",
        "edge cleaner pixel delta is limited to safety-orange alpha-edge/soft-alpha targets",
        "synthetic contaminated cutout audit manifest proves reference-free cutout-only input contract",
        "synthetic cleaned cutout audit manifest proves reference-free cutout-only input contract",
        "synthetic cleaned cutout audit reruns with strict-zero thresholds",
        "synthetic edge-clean review sheets exist and are nonblank",
        "Synthetic Raw-Key Internal-Hole Regression",
        "cutout-only strict audit reproduces the old blind spot on an opaque internal raw-key hole",
        "raw-backed strict audit fails that same internal-hole control with raw_key_visible_background_contamination",
        "raw-backed cleaner alpha-clears the raw-key internal hole while preserving non-key intentional orange material",
        "raw-backed cleaned cutout reruns with strict-zero raw-key thresholds",
        "Proof-Matrix Raw-Source Gate",
        "proof-matrix cutout-only audit reproduces the raw-key blind spot without loading raw images",
        "proof-matrix raw-source audit fails an internal raw-key hole through --use-proof-raw-source",
        "proof-matrix raw-source cleaner stats JSON records raw-source hashes, stdout parity, and pixel delta",
        "cleaned proof-matrix raw-source audit passes with strict-zero raw-key thresholds",
        "proof-matrix raw-source review sheets are nonblank",
        "Metrics Reference Hierarchy Gate",
        "Tampered Metrics Negative-Control Gate",
        "Tampered Proof-Matrix Negative-Control Gate",
        "bad reference row order",
        "duplicate Vellum reference row",
        "wrong token anchor role",
        "extra reference anchor row",
        "ordinary row promoted to primary anchor",
        "missing Totem metrics row fails required negative-control enforcement",
        "Totem low-proxy metric mutation",
        "tampered metric controls prove corrupted anchors and broken Totem sentinel states fail",
        "missing_totem_proof",
        "totem_negative_control_flag_removed",
        "totem_verdict_promoted_to_pass",
        "totem_override_reason_removed",
        "tampered proof-matrix controls prove Totem source-policy corruption fails before style report generation",
        "Totem fails style triage while still proving proxy metrics can lie",
        "hot-highlight matte-review rows present",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(quick_report)} missing quick audit snippets: {missing}")
    report.append(f"- PASS `{rel(quick_report)}` verifies fast cutout, false-positive, edge-clean, Totem, token, and hot-highlight gates.")
    report.append("")


def assert_review_packet(packet_path: Path, report: list[str]) -> None:
    text = packet_path.read_text(encoding="utf-8")
    required = [
        "Review Decision Packet",
        "Visual decision sheet",
        "Board-scale decision sheet",
        "Creep is the next revision gate",
        "Active revision request",
        "Latest scorecard",
        "Decision Scorecard",
        "Scorecard template",
        "Scorecard rule",
        "Approve only if",
        "--scorecard-json",
        "request_revision",
        "Prior Creep Lessons",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(packet_path)} missing review packet snippets: {missing}")
    visual_sheet = packet_path.with_name(packet_path.stem.replace("_packet", "_sheet") + ".png")
    if not visual_sheet.exists():
        raise RuntimeError(f"{rel(packet_path.parent)} missing review decision visual sheet")
    board_sheet = packet_path.with_name(packet_path.stem.replace("_review_decision_packet", "_board_scale_decision_sheet") + ".png")
    if not board_sheet.exists():
        raise RuntimeError(f"{rel(packet_path.parent)} missing board-scale decision sheet")
    scorecard_template = packet_path.with_name(packet_path.stem.replace("_review_decision_packet", "_scorecard_template") + ".json")
    if not scorecard_template.exists():
        raise RuntimeError(f"{rel(packet_path.parent)} missing scorecard template")
    report.append("## Review Decision Packet")
    report.append("")
    report.append(f"- PASS `{rel(packet_path)}` packages the current gate for human review.")
    report.append(f"- PASS `{rel(visual_sheet)}` exists for Creep visual review.")
    report.append(f"- PASS `{rel(board_sheet)}` exists for board-scale review.")
    report.append(f"- PASS `{rel(scorecard_template)}` exists for Vellum-first gate recording.")
    report.append("")


def assert_creep_revision_prompt_packet(report: list[str]) -> None:
    if not CREEP_REVISION_PROMPT_PACKET.exists():
        raise RuntimeError(f"missing Creep revision prompt packet: {rel(CREEP_REVISION_PROMPT_PACKET)}")
    text = CREEP_REVISION_PROMPT_PACKET.read_text(encoding="utf-8")
    required = [
        "Revision lock",
        "original source sprite",
        "Creep Vellum-primary candidate only as a negative comparison",
        "unsegmented tendril/blade ring",
        "surface weathering, not armor clutter",
        "segmented mechanical tube tendrils",
        "mechanical black tube tendrils",
        "talisman clutter as fake detail",
        "Paisley only as secondary contrast context",
        "--edge-orange-clean",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(CREEP_REVISION_PROMPT_PACKET)} missing Creep revision snippets: {missing}")
    report.append("## Creep Revision Prompt Packet")
    report.append("")
    report.append(f"- PASS `{rel(CREEP_REVISION_PROMPT_PACKET)}` locks original smooth-alien identity, Vellum-level dry detail, and the current negative drift bans.")
    report.append("")


def write_report(output_dir: Path, report: list[str]) -> Path:
    path = output_dir / "workflow_validation_report.md"
    path.write_text("\n".join(report).rstrip() + "\n", encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--audit-proof-id", default="creep_vellum_primary_detail_refit")
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    packet_dir = output_dir / "roster_prompt_packets_all"
    all_audit_dir = output_dir / "style_drift_audit_all_current"
    proof_audit_dir = output_dir / f"style_drift_audit_{args.audit_proof_id}"
    preledger_audit_dir = output_dir / "style_drift_audit_preledger_candidate_mode"
    completion_audit_dir = output_dir / "workflow_completion_audit"
    review_queue_dir = output_dir / "review_queue"
    review_packet_dir = output_dir / "review_packet"
    candidate_triage_dir = output_dir / "candidate_style_triage"
    cutout_fringe_audit_dir = output_dir / "cutout_orange_fringe_audit"
    report: list[str] = [
        "# Unit Art Workflow Validation Report",
        "",
        f"- Output dir: `{rel(output_dir)}`",
        f"- Audit proof id: `{args.audit_proof_id}`",
        "",
    ]

    try:
        assert_proof_policy(report)
        run_step(
            "Workflow Completion Audit",
            [
                sys.executable,
                "tools/art/build_unit_art_workflow_completion_audit.py",
                "--output-dir",
                rel(completion_audit_dir),
                "--docs-output",
                "docs/art/unit_art_workflow_completion_audit_2026-06-30.md",
            ],
            report,
        )
        assert_completion_audit(completion_audit_dir / "unit_art_workflow_completion_audit.md", report)
        run_step(
            "Review Queue",
            [
                sys.executable,
                "tools/art/build_unit_art_review_queue.py",
                "--output-dir",
                rel(review_queue_dir),
                "--docs-output",
                "docs/art/unit_art_review_queue_2026-06-30.md",
            ],
            report,
        )
        assert_review_queue(review_queue_dir / "unit_art_review_queue.md", report)
        run_step(
            "Review Decision Packet",
            [
                sys.executable,
                "tools/art/build_unit_art_review_packet.py",
                "--proof-id",
                args.audit_proof_id,
                "--output-dir",
                rel(review_packet_dir),
                "--docs-output",
                "docs/art/creep_review_decision_packet_2026-07-01.md",
                "--report-date",
                "2026-07-01",
            ],
            report,
        )
        assert_review_packet(review_packet_dir / f"{args.audit_proof_id}_review_decision_packet.md", report)
        assert_creep_revision_prompt_packet(report)
        all_pass_scorecard_path = output_dir / f"{args.audit_proof_id}_all_pass_scorecard.json"
        write_all_pass_scorecard(all_pass_scorecard_path, args.audit_proof_id)
        run_step(
            "Review Decision Helper Dry Run",
            [
                sys.executable,
                "tools/art/apply_unit_art_review_decision.py",
                "--proof-id",
                args.audit_proof_id,
                "--decision",
                "request_revision",
                "--reason",
                "validation dry run only",
                "--dry-run",
            ],
            report,
        )
        run_step(
            "Review Decision Helper Accept Scorecard Dry Run",
            [
                sys.executable,
                "tools/art/apply_unit_art_review_decision.py",
                "--proof-id",
                args.audit_proof_id,
                "--decision",
                "accept",
                "--reason",
                "validation all-gates-pass dry run only",
                "--next-unit-id",
                "veyra",
                "--scorecard-json",
                rel(all_pass_scorecard_path),
                "--dry-run",
            ],
            report,
        )
        assert_accept_requires_scorecard(args.audit_proof_id, report)
        assert_style_negative_control_cannot_accept("totem_dry_wood_guardian_refit", report)
        run_step("Workflow Document Validator", [sys.executable, "tools/art/validate_unit_art_workflow_doc.py"], report)
        run_step(
            "Full Roster Prompt Packet Build",
            [
                sys.executable,
                "tools/art/build_unit_roster_prompt_packet.py",
                "--all",
                "--output-dir",
                rel(packet_dir),
            ],
            report,
        )
        assert_packet_reference_hierarchy(packet_dir, report)
        run_step(
            "All Current Style Drift Audit",
            [
                sys.executable,
                "tools/art/build_unit_style_drift_audit.py",
                "--output-dir",
                rel(all_audit_dir),
            ],
            report,
        )
        assert_audit_roles(all_audit_dir / "foreground_detail_metrics.csv", report)
        assert_audit_outputs(all_audit_dir, report)
        run_step(
            "Candidate Style Triage",
            [
                sys.executable,
                "tools/art/build_unit_art_candidate_triage.py",
                "--metrics-csv",
                rel(all_audit_dir / "foreground_detail_metrics.csv"),
                "--output-dir",
                rel(candidate_triage_dir),
                "--docs-output",
                "docs/art/unit_art_candidate_style_triage_2026-07-01.md",
                "--report-date",
                "2026-07-01",
            ],
            report,
        )
        assert_candidate_triage(candidate_triage_dir / "unit_art_candidate_style_triage.md", report)
        run_step(
            "Cutout Orange-Fringe Audit",
            [
                sys.executable,
                "tools/art/audit_unit_cutout_orange_fringe.py",
                "--output-dir",
                rel(cutout_fringe_audit_dir),
                "--docs-output",
                "docs/art/unit_art_cutout_orange_fringe_audit_2026-07-01.md",
                "--report-date",
                "2026-07-01",
            ],
            report,
        )
        assert_cutout_orange_fringe_audit(cutout_fringe_audit_dir / "unit_art_cutout_orange_fringe_audit.md", report)
        assert_synthetic_cutout_negative_control(output_dir, report)
        assert_quick_audit_gates(all_audit_dir / "foreground_detail_metrics.csv", output_dir, report)
        run_step(
            "Focused Proof Style Drift Audit",
            [
                sys.executable,
                "tools/art/build_unit_style_drift_audit.py",
                "--proof-id",
                args.audit_proof_id,
                "--output-dir",
                rel(proof_audit_dir),
            ],
            report,
        )
        assert_audit_roles(proof_audit_dir / "foreground_detail_metrics.csv", report)
        assert_audit_outputs(proof_audit_dir, report)
        audit_proof = find_proof(args.audit_proof_id)
        run_step(
            "Pre-Ledger Candidate Style Audit Dry Run",
            [
                sys.executable,
                "tools/art/build_unit_style_drift_audit.py",
                "--candidate-id",
                "validation_preledger_candidate",
                "--candidate-label",
                "Validation Pre-Ledger Candidate",
                "--candidate-role",
                "review_candidate_not_anchor",
                "--candidate-raw",
                audit_proof["raw"],
                "--candidate-cutout",
                audit_proof["cutout"],
                "--candidate-board",
                audit_proof["board_preview"],
                "--output-dir",
                rel(preledger_audit_dir),
            ],
            report,
        )
        assert_audit_roles(preledger_audit_dir / "foreground_detail_metrics.csv", report)
        assert_audit_outputs(preledger_audit_dir, report)
        compile_art_tools(report)
        report.append("## Godot Validation")
        report.append("")
        report.append("- Not run by this Python runner. Repo rules require Godot validation through MCP only, usually `tests/rga_testing/validation/RoleMatrixProbe.tscn` followed by `get_debug_output()` and `errors=[]`.")
        report.append("")
        report.append("## Result")
        report.append("")
        report.append("- PASS: art workflow docs, proof policy, packet generation, role-labeled audits, candidate style triage, cutout orange-fringe audit, completion audit, review queue, review packet, review-decision dry run, and art-tool syntax are coherent.")
        report_path = write_report(output_dir, report)
        print(f"PASS: wrote {rel(report_path)}")
        return 0
    except Exception as exc:
        report.append("## Result")
        report.append("")
        report.append(f"- FAIL: {exc}")
        report_path = write_report(output_dir, report)
        print(f"FAIL: {exc}")
        print(f"report={rel(report_path)}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
