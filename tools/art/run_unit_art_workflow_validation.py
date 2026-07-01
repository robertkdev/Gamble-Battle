from __future__ import annotations

import argparse
import csv
import json
import py_compile
import subprocess
import sys
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"workflow_validation_{date.today().strftime('%Y_%m_%d')}"

ART_TOOLS = [
    ROOT / "tools" / "art" / "apply_unit_art_review_decision.py",
    ROOT / "tools" / "art" / "build_unit_art_board_preview.py",
    ROOT / "tools" / "art" / "build_unit_art_prompt_packet.py",
    ROOT / "tools" / "art" / "build_unit_art_candidate_triage.py",
    ROOT / "tools" / "art" / "build_unit_art_review_queue.py",
    ROOT / "tools" / "art" / "build_unit_roster_contact_sheet.py",
    ROOT / "tools" / "art" / "build_unit_art_workflow_completion_audit.py",
    ROOT / "tools" / "art" / "build_unit_roster_prompt_packet.py",
    ROOT / "tools" / "art" / "build_unit_style_drift_audit.py",
    ROOT / "tools" / "art" / "combine_unit_alpha_masks.py",
    ROOT / "tools" / "art" / "run_unit_art_workflow_validation.py",
    ROOT / "tools" / "art" / "validate_unit_art_workflow_doc.py",
]

REFERENCE_ROLE_EXPECTATIONS = {
    "REF Vellum raw": "primary_anchor",
    "REF Paisley": "secondary_contrast_anchor",
    "REF Token": "small_asset_material_reference",
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
    ]
    failures: list[str] = []
    for path in unit_packets:
        text = path.read_text(encoding="utf-8")
        missing = [snippet for snippet in required if snippet not in text]
        if missing:
            failures.append(f"{rel(path)} missing {missing}")
    if failures:
        raise RuntimeError("; ".join(failures))
    report.append("## Packet Reference Hierarchy")
    report.append("")
    report.append(f"- PASS `{rel(packet_dir)}` contains {len(unit_packets)} unit packets with Vellum-first reference hierarchy sections.")
    report.append("")


def assert_audit_roles(csv_path: Path, report: list[str]) -> None:
    rows = list(csv.DictReader(csv_path.open(encoding="utf-8")))
    if len(rows) < 4:
        raise RuntimeError(f"style audit CSV too small: {rel(csv_path)}")
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
    report.append(f"- Non-reference roles present: `{', '.join(sorted(ordinary_roles))}`.")
    report.append("")


def assert_audit_outputs(audit_dir: Path, report: list[str]) -> None:
    required = [
        "raw_anchor_vs_later_contact_sheet.png",
        "vellum_first_pairwise_raw_comparison.png",
        "board_preview_drift_contact_sheet.png",
        "foreground_detail_metrics.csv",
    ]
    missing = [name for name in required if not (audit_dir / name).exists()]
    if missing:
        raise RuntimeError(f"{rel(audit_dir)} missing style audit outputs: {missing}")
    report.append("## Vellum Pairwise Audit Output")
    report.append("")
    report.append(f"- PASS `{rel(audit_dir)}` includes the mandatory Vellum-first pairwise comparison sheet.")
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
    report.append("")


def assert_completion_audit(audit_path: Path, report: list[str]) -> None:
    text = audit_path.read_text(encoding="utf-8")
    required = [
        "Verdict: **INCOMPLETE**",
        "candidate needs human approval",
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


def assert_candidate_triage(triage_path: Path, report: list[str]) -> None:
    text = triage_path.read_text(encoding="utf-8")
    required = [
        "Vellum is the ultimate character reference",
        "Passing-pool rule",
        "Visual review sheet",
        "Highest Risk Rows",
        "high_risk_re_review_before_acceptance",
        "Start visual review from the Vellum pairwise sheet",
    ]
    missing = [snippet for snippet in required if snippet not in text]
    if missing:
        raise RuntimeError(f"{rel(triage_path)} missing candidate triage snippets: {missing}")
    review_sheet = triage_path.with_name("candidate_style_triage_review_sheet.png")
    if not review_sheet.exists():
        raise RuntimeError(f"{rel(triage_path.parent)} missing candidate style triage review sheet")
    report.append("## Candidate Style Triage")
    report.append("")
    report.append(f"- PASS `{rel(triage_path)}` flags candidate-pool drift risks against Vellum/Paisley metrics.")
    report.append(f"- PASS `{rel(review_sheet)}` exists for focused visual review.")
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
    completion_audit_dir = output_dir / "workflow_completion_audit"
    review_queue_dir = output_dir / "review_queue"
    candidate_triage_dir = output_dir / "candidate_style_triage"
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
        compile_art_tools(report)
        report.append("## Godot Validation")
        report.append("")
        report.append("- Not run by this Python runner. Repo rules require Godot validation through MCP only, usually `tests/rga_testing/validation/RoleMatrixProbe.tscn` followed by `get_debug_output()` and `errors=[]`.")
        report.append("")
        report.append("## Result")
        report.append("")
        report.append("- PASS: art workflow docs, proof policy, packet generation, role-labeled audits, candidate style triage, completion audit, review queue, review-decision dry run, and art-tool syntax are coherent.")
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
