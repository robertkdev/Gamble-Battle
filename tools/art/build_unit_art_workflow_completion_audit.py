from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
ROSTER_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_roster_prompt_matrix.json"
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"workflow_completion_audit_{date.today().strftime('%Y_%m_%d')}"

STATUS_PRIORITY = {
    "accepted": 3,
    "current_candidate": 2,
    "rejected": 1,
    "missing": 0,
}


def rel(path: Path | str) -> str:
    path_obj = Path(path)
    if not path_obj.is_absolute():
        path_obj = ROOT / path_obj
    try:
        return path_obj.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path_obj)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def roster_entries(roster_data: dict[str, Any]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for section in ("units", "other_units"):
        for entry in roster_data.get(section, []):
            item = dict(entry)
            item["matrix_section"] = section
            entries.append(item)
    return entries


def best_proof_for_unit(proofs_by_subject: dict[str, list[dict[str, Any]]], unit_id: str) -> dict[str, Any] | None:
    proofs = proofs_by_subject.get(unit_id, [])
    if not proofs:
        return None
    indexed = list(enumerate(proofs))
    indexed.sort(key=lambda item: (STATUS_PRIORITY.get(str(item[1].get("status")), 0), item[0]))
    return indexed[-1][1]


def artifact_state(proof: dict[str, Any] | None) -> str:
    if proof is None:
        return "missing"
    required_paths = ["raw", "cutout", "review", "board_preview"]
    missing = [
        field
        for field in required_paths
        if not isinstance(proof.get(field), str) or not (ROOT / proof[field]).exists()
    ]
    if missing:
        return "missing " + ", ".join(missing)
    return "present"


def row_for_unit(unit: dict[str, Any], proof: dict[str, Any] | None) -> dict[str, str]:
    if proof is None:
        return {
            "unit_id": str(unit.get("id", "")),
            "display_name": str(unit.get("display_name", "")),
            "matrix_section": str(unit.get("matrix_section", "")),
            "coverage_group": ", ".join(unit.get("coverage_group", [])),
            "proof_id": "",
            "proof_status": "missing",
            "reference_role": "",
            "artifact_state": "missing",
            "completion_state": "needs visual proof",
        }
    status = str(proof.get("status", ""))
    reference_role = str(proof.get("reference_role", ""))
    if status == "accepted":
        completion_state = "accepted proof"
    elif status == "current_candidate":
        completion_state = "candidate needs human approval"
    elif status == "rejected":
        completion_state = "only rejected proof"
    else:
        completion_state = "unknown proof state"
    return {
        "unit_id": str(unit.get("id", "")),
        "display_name": str(unit.get("display_name", "")),
        "matrix_section": str(unit.get("matrix_section", "")),
        "coverage_group": ", ".join(unit.get("coverage_group", [])),
        "proof_id": str(proof.get("id", "")),
        "proof_status": status,
        "reference_role": reference_role,
        "artifact_state": artifact_state(proof),
        "completion_state": completion_state,
    }


def proof_counts(proofs: list[dict[str, Any]], field: str) -> Counter[str]:
    return Counter(str(proof.get(field, "")) for proof in proofs)


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()) if rows else [])
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(
    path: Path,
    rows: list[dict[str, str]],
    proof_data: dict[str, Any],
    roster_data: dict[str, Any],
    asset_rows: list[dict[str, str]],
) -> None:
    status_counts = Counter(row["proof_status"] for row in rows)
    completion_counts = Counter(row["completion_state"] for row in rows)
    proofs = [proof for proof in proof_data.get("proofs", []) if isinstance(proof, dict)]
    role_counts = proof_counts(proofs, "reference_role")
    coverage_groups = sorted(roster_data.get("coverage_groups", {}).keys())
    covered_groups = sorted({
        group
        for proof in proofs
        if proof.get("status") in {"accepted", "current_candidate"}
        for group in proof.get("coverage_group", [])
    })
    missing_proof_units = [row["unit_id"] for row in rows if row["proof_status"] == "missing"]
    candidate_units = [row["unit_id"] for row in rows if row["proof_status"] == "current_candidate"]
    rejected_only_units = [row["unit_id"] for row in rows if row["proof_status"] == "rejected"]
    coverage_gaps = proof_data.get("coverage_gaps", [])
    next_test = proof_data.get("next_recommended_stress_test", {})

    verdict_reasons: list[str] = []
    if missing_proof_units:
        verdict_reasons.append(f"{len(missing_proof_units)} roster entries have no visual proof")
    if candidate_units:
        verdict_reasons.append(f"{len(candidate_units)} roster entries are still current candidates, not accepted proofs")
    if rejected_only_units:
        verdict_reasons.append(f"{len(rejected_only_units)} roster entries only have rejected proofs")
    if coverage_gaps:
        verdict_reasons.append(f"{len(coverage_gaps)} coverage gaps remain in the proof ledger")
    if next_test.get("unit_id"):
        verdict_reasons.append(f"next recommended stress test remains `{next_test.get('unit_id')}`")
    verdict = "INCOMPLETE" if verdict_reasons else "COMPLETE"

    lines: list[str] = [
        "# Unit Art Workflow Completion Audit",
        "",
        f"- Generated: {date.today().isoformat()}",
        f"- Roster entries audited: {len(rows)}",
        f"- Playable units in matrix: {len(roster_data.get('units', []))}",
        f"- Other art-bearing units in matrix: {len(roster_data.get('other_units', []))}",
        f"- Proof entries: {len(proofs)}",
        f"- Verdict: **{verdict}**",
        "",
    ]
    if verdict_reasons:
        lines.append("Completion blockers:")
        for reason in verdict_reasons:
            lines.append(f"- {reason}.")
        lines.append("")

    lines.extend([
        "## Counts",
        "",
        f"- Unit proof statuses: `{dict(sorted(status_counts.items()))}`",
        f"- Unit completion states: `{dict(sorted(completion_counts.items()))}`",
        f"- Proof reference roles: `{dict(sorted(role_counts.items()))}`",
        f"- Coverage groups defined: `{', '.join(coverage_groups)}`",
        f"- Coverage groups currently represented by accepted/current proofs: `{', '.join(covered_groups)}`",
        "",
        "## Roster Coverage",
        "",
        "| Unit | Name | Section | Proof | Status | Role | Completion |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ])
    for row in rows:
        proof_id = row["proof_id"] or "-"
        lines.append(
            f"| `{row['unit_id']}` | {row['display_name']} | `{row['matrix_section']}` | "
            f"`{proof_id}` | `{row['proof_status']}` | `{row['reference_role'] or '-'}` | {row['completion_state']} |"
        )

    lines.extend([
        "",
        "## Asset Coverage",
        "",
        "| Asset | Proof | Status | Role | Completion |",
        "| --- | --- | --- | --- | --- |",
    ])
    for row in asset_rows:
        lines.append(
            f"| `{row['asset_id']}` | `{row['proof_id']}` | `{row['proof_status']}` | "
            f"`{row['reference_role']}` | {row['completion_state']} |"
        )

    lines.extend([
        "",
        "## Remaining Proof Ledger Gaps",
        "",
    ])
    for gap in coverage_gaps:
        lines.append(f"- `{gap.get('id', '')}`: {gap.get('risk', '')}")
    if next_test:
        lines.extend([
            "",
            "## Next Gate",
            "",
            f"- Unit id: `{next_test.get('unit_id', '')}`",
            f"- Reason: {next_test.get('reason', '')}",
        ])
    lines.extend([
        "",
        "## Interpretation",
        "",
        "This audit is intentionally conservative. A `current_candidate` can prove that the workflow made progress, but it is not an accepted style proof, live replacement, or global style anchor. The larger workflow goal should stay active until the missing roster proofs, candidate review gates, and asset-class gaps are resolved or explicitly scoped down by the user.",
        "",
    ])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def asset_rows(proof_data: dict[str, Any]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for proof in proof_data.get("proofs", []):
        if not isinstance(proof, dict) or proof.get("subject_type") != "asset":
            continue
        status = str(proof.get("status", ""))
        if status == "accepted":
            completion_state = "accepted asset proof"
        elif status == "current_candidate":
            completion_state = "candidate asset proof"
        elif status == "rejected":
            completion_state = "rejected asset proof"
        else:
            completion_state = "unknown asset proof"
        rows.append({
            "asset_id": str(proof.get("subject_id", "")),
            "proof_id": str(proof.get("id", "")),
            "proof_status": status,
            "reference_role": str(proof.get("reference_role", "")),
            "completion_state": completion_state,
        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--docs-output", type=Path)
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    roster_data = load_json(ROSTER_MATRIX_PATH)
    proof_data = load_json(PROOF_MATRIX_PATH)
    proofs_by_subject: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for proof in proof_data.get("proofs", []):
        if isinstance(proof, dict) and proof.get("subject_type") == "unit":
            proofs_by_subject[str(proof.get("subject_id", ""))].append(proof)

    rows = [
        row_for_unit(unit, best_proof_for_unit(proofs_by_subject, str(unit.get("id", ""))))
        for unit in roster_entries(roster_data)
    ]
    assets = asset_rows(proof_data)
    csv_path = output_dir / "unit_art_workflow_completion_audit.csv"
    md_path = output_dir / "unit_art_workflow_completion_audit.md"
    write_csv(csv_path, rows)
    write_markdown(md_path, rows, proof_data, roster_data, assets)
    if args.docs_output:
        docs_path = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        write_markdown(docs_path, rows, proof_data, roster_data, assets)

    print(md_path)
    print(csv_path)
    if args.docs_output:
        print(args.docs_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
