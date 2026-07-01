from __future__ import annotations

import argparse
import csv
import json
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
ROSTER_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_roster_prompt_matrix.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"review_queue_{date.today().strftime('%Y_%m_%d')}"
CREEP_REVISION_PROMPT_PACKET = "docs/art/creep_revision_prompt_packet_2026_07_01/creep.md"


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


def roster_lookup(roster_data: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for section in ("units", "other_units"):
        for entry in roster_data.get(section, []):
            if isinstance(entry, dict):
                item = dict(entry)
                item["matrix_section"] = section
                result[str(item.get("id", ""))] = item
    return result


def candidate_priority(proof: dict[str, Any], next_unit_id: str) -> tuple[int, str]:
    if str(proof.get("subject_id", "")) == next_unit_id:
        return (0, str(proof.get("id", "")))
    if proof.get("reference_role") == "review_candidate_not_anchor":
        return (1, str(proof.get("id", "")))
    return (2, str(proof.get("id", "")))


def current_candidates(proof_data: dict[str, Any]) -> list[dict[str, Any]]:
    next_unit_id = str(proof_data.get("next_recommended_stress_test", {}).get("unit_id", ""))
    candidates = [
        proof
        for proof in proof_data.get("proofs", [])
        if isinstance(proof, dict) and proof.get("status") == "current_candidate"
    ]
    candidates.sort(key=lambda proof: candidate_priority(proof, next_unit_id))
    return candidates


def queue_rows(proof_data: dict[str, Any], roster_data: dict[str, Any]) -> list[dict[str, str]]:
    lookup = roster_lookup(roster_data)
    next_unit_id = str(proof_data.get("next_recommended_stress_test", {}).get("unit_id", ""))
    rows: list[dict[str, str]] = []
    for proof in current_candidates(proof_data):
        subject_id = str(proof.get("subject_id", ""))
        roster_entry = lookup.get(subject_id, {})
        if subject_id == next_unit_id:
            priority = "next_gate"
        elif proof.get("reference_role") == "review_candidate_not_anchor":
            priority = "review_candidate"
        else:
            priority = "candidate_backlog"
        style_audit = str(proof.get("style_audit", ""))
        pairwise_audit = ""
        reference_ladder_audit = ""
        if style_audit:
            pairwise_audit = str(Path(style_audit).with_name("vellum_first_pairwise_raw_comparison.png")).replace("\\", "/")
            reference_ladder_audit = str(Path(style_audit).with_name("reference_ladder_raw_comparison.png")).replace("\\", "/")
        rows.append({
            "priority": priority,
            "subject_id": subject_id,
            "display_name": str(proof.get("display_name", roster_entry.get("display_name", subject_id))),
            "proof_id": str(proof.get("id", "")),
            "reference_role": str(proof.get("reference_role", "")),
            "coverage_group": ", ".join(proof.get("coverage_group", [])),
            "raw": str(proof.get("raw", "")),
            "board_preview": str(proof.get("board_preview", "")),
            "style_audit": style_audit,
            "pairwise_audit": pairwise_audit,
            "reference_ladder_audit": reference_ladder_audit,
            "scorecard_template": str(proof.get("scorecard_template", "")),
            "revision_request": str(proof.get("revision_request", "")),
            "revision_prompt_packet": CREEP_REVISION_PROMPT_PACKET if subject_id == "creep" and proof.get("revision_request") else "",
            "decision_needed": "revise before approval" if proof.get("revision_request") else "approve as accepted proof, reject with reason, or request revision",
        })
    return rows


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()) if rows else ["priority"])
        writer.writeheader()
        writer.writerows(rows)


def candidate_section(row: dict[str, str]) -> list[str]:
    lines = [
        f"### {row['display_name']} (`{row['subject_id']}`)",
        "",
        f"- Priority: `{row['priority']}`",
        f"- Proof id: `{row['proof_id']}`",
        f"- Reference role: `{row['reference_role']}`",
        f"- Coverage: `{row['coverage_group']}`",
        f"- Raw: `{row['raw']}`",
        f"- Board preview: `{row['board_preview']}`",
    ]
    if row["style_audit"]:
        lines.append(f"- Style audit: `{row['style_audit']}`")
    if row["pairwise_audit"]:
        lines.append(f"- Vellum pairwise audit: `{row['pairwise_audit']}`")
    if row["reference_ladder_audit"]:
        lines.append(f"- Reference ladder audit: `{row['reference_ladder_audit']}`")
    if row["scorecard_template"]:
        lines.append(f"- Scorecard template: `{row['scorecard_template']}`")
    if row["revision_request"]:
        lines.append(f"- Active revision request: {row['revision_request']}")
    if row["revision_prompt_packet"]:
        lines.append(f"- Revision prompt packet: `{row['revision_prompt_packet']}`")
    lines.extend([
        f"- Decision needed: {row['decision_needed']}.",
        "",
    ])
    return lines


def write_markdown(path: Path, rows: list[dict[str, str]], proof_data: dict[str, Any]) -> None:
    next_test = proof_data.get("next_recommended_stress_test", {})
    next_unit_id = str(next_test.get("unit_id", ""))
    next_rows = [row for row in rows if row["priority"] == "next_gate"]
    backlog_rows = [row for row in rows if row["priority"] != "next_gate"]
    lines: list[str] = [
        "# Unit Art Review Queue",
        "",
        f"- Generated: {date.today().isoformat()}",
        f"- Current candidates needing review: {len(rows)}",
        f"- Next gate unit: `{next_unit_id}`",
        f"- Next gate reason: {next_test.get('reason', '')}",
        "- Candidate style triage: `docs/art/unit_art_candidate_style_triage_2026-07-01.md`",
        "- Current gate decision packet: `docs/art/creep_review_decision_packet_2026-07-01.md`",
        "- Current gate scorecard template: `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json`",
        "",
        "## Review Rules",
        "",
        "- Review Vellum side by side first at raw scale and board scale. Use the reference-ladder sheet to see Vellum, Paisley, token, and candidate in one row; Paisley and token remain secondary/narrow references.",
        "- Do not let the growing passing pool muddy the target. Passing means narrow evidence, not a new average style.",
        "- Use candidate style triage as a warning layer only. It can flag likely drift, but final decisions still require visual Vellum-first review.",
        "- Approving a candidate can make it an accepted proof for its coverage group, but does not promote it to a global style anchor.",
        "- Rejection needs a concrete reason that can become a future negative prompt or failure gate.",
        "- Do not replace live `assets/units/*.png` files from this queue without explicit user approval.",
        "- Do not continue to Veyra or broader roster generation until the next gate is resolved.",
        "",
        "## Decision Commands",
        "",
        "After the user decides, apply the review result through `tools/art/apply_unit_art_review_decision.py` instead of hand-editing the proof ledger.",
        "",
        "For the current Creep gate, fill out the tracked scorecard worksheet first. It defaults every gate to `revise`; approval only works after every Vellum-first gate is deliberately changed to `pass`.",
        "",
        "```powershell",
        'python tools\\art\\apply_unit_art_review_decision.py --proof-id <proof_id> --decision accept --reason "<human-approved reason>" --next-unit-id <next_unit_id> --scorecard-json <scorecard_template_json>',
        'python tools\\art\\apply_unit_art_review_decision.py --proof-id <proof_id> --decision reject --reason "<concrete failure reason>" --scorecard-json <scorecard_template_json>',
        'python tools\\art\\apply_unit_art_review_decision.py --proof-id <proof_id> --decision request_revision --reason "<needed change>" --scorecard-json <scorecard_template_json>',
        "```",
        "",
        "Accepting a review candidate requires every scorecard gate to be recorded as `pass`, and records it as an accepted narrow proof only. The helper does not promote candidates into global style anchors; Vellum stays the primary/ultimate reference unless the user explicitly says otherwise. If a proof has no tracked scorecard template yet, rebuild its review packet before applying a decision.",
        "",
        "## Next Gate",
        "",
    ]
    if next_rows:
        for row in next_rows:
            lines.extend(candidate_section(row))
    else:
        lines.append("- No current candidate matches the proof ledger next gate.")
        lines.append("")

    lines.extend([
        "## Candidate Backlog",
        "",
    ])
    for row in backlog_rows:
        lines.extend(candidate_section(row))

    lines.extend([
        "## Approval Checklist",
        "",
        "- The raw reads as high-detail dry gothic illustration beside Vellum, not just as a dark palette match.",
        "- Skin/materials are matte, dry, absorptive, dusty, or cloth/parchment/bone/dull-metal-like, not sweaty, wet, glossy, plastic, latex, or polished.",
        "- Unit identity remains recognizable from the source sprite.",
        "- Board preview keeps head, torso, hands, weapon/prop, and main effect readable at 96 px.",
        "- Cutout/review sheet and orange-fringe audit have no unacceptable safety-orange edge residue or missing identity-critical detached effects.",
        "- The proof ledger `reference_role` remains correct after the decision.",
        "",
        "## Rejection Checklist",
        "",
        "When rejecting, record which concrete failure happened:",
        "",
        "- too glossy or sweaty",
        "- too cartoon/comic/toy-like",
        "- too low-detail or smooth after de-shining",
        "- wrong identity or silhouette",
        "- wrong detail type: wet anatomy, shiny armor, generic fantasy sculpting, or noisy chaos",
        "- bad orange background, orange-fringe audit failure, or alpha/cutout failure",
        "- poor 96 px board read",
        "",
    ])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--docs-output", type=Path)
    args = parser.parse_args()

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    proof_data = load_json(PROOF_MATRIX_PATH)
    roster_data = load_json(ROSTER_MATRIX_PATH)
    rows = queue_rows(proof_data, roster_data)

    md_path = output_dir / "unit_art_review_queue.md"
    csv_path = output_dir / "unit_art_review_queue.csv"
    write_markdown(md_path, rows, proof_data)
    write_csv(csv_path, rows)
    if args.docs_output:
        docs_path = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        write_markdown(docs_path, rows, proof_data)
        print(rel(docs_path))
    print(rel(md_path))
    print(rel(csv_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
