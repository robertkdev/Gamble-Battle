#!/usr/bin/env python3
"""Assemble and seal one sharded, reviewer-authored Board primary record."""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PACKET = ROOT / "docs/art/phase2_calibration/board/round_8_fixed/audit_packet.json"
ROLE_BY_ID = {
    "A": "CONTRACT_AND_EVIDENCE_PROSECUTOR",
    "B": "PROFESSIONAL_STANDARDS_DIRECTOR",
    "C": "FAILURE_AND_ADOPTION_RED_TEAM",
}
CONTROL_KEYS = {
    "reviewer_id",
    "role",
    "session_id",
    "manifest_verification",
    "reconstructed_criterion_ids",
    "surface_class_reconstruction",
    "unmapped_material_authority",
    "primary_evidence_ids",
    "inspected_benchmark_ids",
    "contamination",
    "unknowns",
}


def canonical_sha256(value: Any) -> str:
    data = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def assemble(packet: dict[str, Any], seat_dir: Path) -> dict[str, Any]:
    control = load_json(seat_dir / "control.json")
    require(isinstance(control, dict) and set(control) == CONTROL_KEYS, "control.json keys are invalid")
    reviewer_id = control["reviewer_id"]
    require(reviewer_id in ROLE_BY_ID, "reviewer_id is invalid")
    require(control["role"] == ROLE_BY_ID[reviewer_id], "reviewer role does not match seat")
    require(isinstance(control["session_id"], str) and control["session_id"].strip(), "session_id is required")
    require(control["manifest_verification"] in {"COMPLETE", "INVALID"}, "manifest_verification is invalid")

    packet_criteria = packet["criteria"]
    criterion_ids = [item["id"] for item in packet_criteria]
    require(control["reconstructed_criterion_ids"] == criterion_ids, "reconstructed criteria must exactly preserve packet order")
    raw_ids = [item["id"] for item in packet["raw_evidence"]]
    benchmark_ids = [item["id"] for item in packet["benchmarks"]]
    require(control["primary_evidence_ids"] == raw_ids, "every raw evidence ID must be attested in packet order")
    require(control["inspected_benchmark_ids"] == benchmark_ids, "every benchmark must be attested in packet order")

    surface_reconstruction = control["surface_class_reconstruction"]
    require(isinstance(surface_reconstruction, list), "surface_class_reconstruction must be a list")
    require([item.get("surface_id") for item in surface_reconstruction] == [item["id"] for item in packet["surfaces"]], "surface reconstruction must cover every surface in packet order")

    criteria: list[dict[str, Any]] = []
    shard_paths = sorted(seat_dir.glob("criteria_*.json"))
    require(bool(shard_paths), "at least one criteria shard is required")
    for path in shard_paths:
        shard = load_json(path)
        require(isinstance(shard, list) and shard, f"{path.name} must contain a nonempty list")
        criteria.extend(shard)
    require([item.get("id") for item in criteria] == criterion_ids, "criteria shards must cover every criterion exactly once in packet order")

    dimensions = load_json(seat_dir / "dimensions.json")
    require(isinstance(dimensions, list), "dimensions.json must contain a list")
    require([item.get("id") for item in dimensions] == [item["id"] for item in packet["dimensions"]], "dimensions must cover every packet dimension in order")

    packet_hash = canonical_sha256(packet)
    payload = {
        "reviewer_id": reviewer_id,
        "role": control["role"],
        "session_id": control["session_id"],
        "cut_id": packet["cut"]["id"],
        "packet_sha256": packet_hash,
        "manifest_verification": control["manifest_verification"],
        "reconstructed_criterion_ids": criterion_ids,
        "authority_quotes": [
            {"criterion_id": item["id"], "source_locator": item["source_locator"], "verbatim": item["text"]}
            for item in packet_criteria
        ],
        "surface_class_reconstruction": surface_reconstruction,
        "unmapped_material_authority": control["unmapped_material_authority"],
        "primary_evidence_ids": raw_ids,
        "inspected_benchmark_ids": benchmark_ids,
        "evidence_receipts": [
            {
                "evidence_id": item["id"],
                "sha256": item["sha256"],
                "surface": item["surface"],
                "inspection_modes": item["inspection_modes"],
                "observed_regions": item["observed_regions"],
            }
            for item in packet["raw_evidence"]
        ],
        "criteria": criteria,
        "dimensions": dimensions,
        "contamination": control["contamination"],
        "unknowns": control["unknowns"],
    }
    return {
        "sha256": canonical_sha256(payload),
        "sealed_before_secondary": True,
        "payload": payload,
    }


def run_self_test() -> None:
    packet = {
        "cut": {"id": "cut"},
        "criteria": [{"id": "C1", "source_locator": "spec#L1", "text": "Exact"}],
        "surfaces": [{"id": "product"}],
        "dimensions": [{"id": "D1"}],
        "raw_evidence": [{"id": "E1", "sha256": "a" * 64, "surface": "product", "inspection_modes": ["DIRECT"], "observed_regions": ["whole"]}],
        "benchmarks": [{"id": "B1"}],
    }
    with tempfile.TemporaryDirectory() as temp:
        seat = Path(temp)
        control = {
            "reviewer_id": "A",
            "role": ROLE_BY_ID["A"],
            "session_id": "self-test-session",
            "manifest_verification": "COMPLETE",
            "reconstructed_criterion_ids": ["C1"],
            "surface_class_reconstruction": [{"surface_id": "product"}],
            "unmapped_material_authority": [],
            "primary_evidence_ids": ["E1"],
            "inspected_benchmark_ids": ["B1"],
            "contamination": [],
            "unknowns": [],
        }
        (seat / "control.json").write_text(json.dumps(control), encoding="utf-8")
        (seat / "criteria_001.json").write_text(json.dumps([{"id": "C1"}]), encoding="utf-8")
        (seat / "dimensions.json").write_text(json.dumps([{"id": "D1"}]), encoding="utf-8")
        sealed = assemble(packet, seat)
        require(sealed["sha256"] == canonical_sha256(sealed["payload"]), "sealed payload hash mismatch")
        control["primary_evidence_ids"] = []
        (seat / "control.json").write_text(json.dumps(control), encoding="utf-8")
        try:
            assemble(packet, seat)
        except ValueError:
            pass
        else:
            raise AssertionError("missing evidence attestation was accepted")
    print("PASS phase2-board-primary-transport self-test")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packet", type=Path, default=DEFAULT_PACKET)
    parser.add_argument("--seat-dir", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        run_self_test()
        return 0
    if args.seat_dir is None or args.output is None:
        parser.error("--seat-dir and --output are required unless --self-test is used")
    packet = load_json(args.packet)
    sealed = assemble(packet, args.seat_dir)
    args.output.write_text(json.dumps(sealed, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"SEALED reviewer={sealed['payload']['reviewer_id']} sha256={sealed['sha256']} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
