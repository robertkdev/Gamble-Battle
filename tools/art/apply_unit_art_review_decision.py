from __future__ import annotations

import argparse
import copy
import json
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
VALID_DECISIONS = {"accept", "reject", "request_revision"}
ANCHOR_ROLES = {"primary_anchor", "secondary_contrast_anchor", "small_asset_material_reference"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def find_proof(data: dict[str, Any], proof_id: str) -> dict[str, Any]:
    for proof in data.get("proofs", []):
        if isinstance(proof, dict) and proof.get("id") == proof_id:
            return proof
    raise ValueError(f"unknown proof id: {proof_id}")


def append_review_history(proof: dict[str, Any], decision: str, reason: str) -> None:
    history = proof.setdefault("review_history", [])
    if not isinstance(history, list):
        history = []
        proof["review_history"] = history
    history.append({
        "date": date.today().isoformat(),
        "decision": decision,
        "reason": reason,
    })


def update_decision_notes(proof: dict[str, Any], decision: str, reason: str) -> None:
    existing = str(proof.get("decision_notes", "")).strip()
    note = f"Review decision {date.today().isoformat()}: {decision} - {reason}"
    proof["decision_notes"] = f"{existing} {note}".strip() if existing else note


def apply_decision(
    data: dict[str, Any],
    proof_id: str,
    decision: str,
    reason: str,
    next_unit_id: str | None,
    next_reason: str | None,
) -> dict[str, Any]:
    if decision not in VALID_DECISIONS:
        raise ValueError(f"decision must be one of {sorted(VALID_DECISIONS)}")
    if not reason.strip():
        raise ValueError("review reason is required")

    proof = find_proof(data, proof_id)
    status = str(proof.get("status", ""))
    if status != "current_candidate":
        raise ValueError(f"proof {proof_id} is {status}; only current_candidate proofs can be reviewed by this helper")

    append_review_history(proof, decision, reason)
    update_decision_notes(proof, decision, reason)

    if decision == "accept":
        proof["status"] = "accepted"
        if proof.get("reference_role") == "review_candidate_not_anchor":
            proof["reference_role"] = "narrow_proof_only"
        if proof.get("reference_role") in ANCHOR_ROLES:
            raise ValueError("review helper does not promote proofs into global style anchors")
    elif decision == "reject":
        proof["status"] = "rejected"
        proof["reference_role"] = "negative_example"
        proof["failure_reason"] = reason
        style_gate = str(proof.get("style_gate", "")).strip()
        if not style_gate.lower().startswith("fail"):
            proof["style_gate"] = f"Fail after human review: {reason}. Previous candidate note: {style_gate}"
    elif decision == "request_revision":
        proof["status"] = "current_candidate"
        proof["reference_role"] = "review_candidate_not_anchor"
        proof["revision_request"] = reason

    if next_unit_id:
        data["next_recommended_stress_test"] = {
            "unit_id": next_unit_id,
            "reason": next_reason or f"Next gate selected after {proof_id} review decision: {decision}.",
        }

    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--proof-id", required=True)
    parser.add_argument("--decision", required=True, choices=sorted(VALID_DECISIONS))
    parser.add_argument("--reason", required=True)
    parser.add_argument("--next-unit-id")
    parser.add_argument("--next-reason")
    parser.add_argument("--proof-matrix", type=Path, default=PROOF_MATRIX_PATH)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    path = args.proof_matrix if args.proof_matrix.is_absolute() else ROOT / args.proof_matrix
    original = load_json(path)
    updated = apply_decision(
        copy.deepcopy(original),
        args.proof_id,
        args.decision,
        args.reason,
        args.next_unit_id,
        args.next_reason,
    )
    proof = find_proof(updated, args.proof_id)
    print(f"proof_id={proof['id']}")
    print(f"decision={args.decision}")
    print(f"status={proof.get('status')}")
    print(f"reference_role={proof.get('reference_role')}")
    print(f"next_unit={updated.get('next_recommended_stress_test', {}).get('unit_id')}")
    if args.dry_run:
        print("dry_run=true")
        return 0
    write_json(path, updated)
    print(f"updated={path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
