#!/usr/bin/env python3
"""Prove the Phase 2 Board packet losslessly maps every material source line."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from build_phase2_upgraded_board_packet import ROOT, build_authority_rows


DEFAULT_ROUND = ROOT / "docs/art/phase2_calibration/board/round_8_fixed"
DEFAULT_SOURCE = ROOT / "docs/art/unit_art_board_reference_criteria.md"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise ValueError(message)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packet", type=Path, default=DEFAULT_ROUND / "audit_packet.json")
    parser.add_argument("--coverage", type=Path, default=DEFAULT_ROUND / "authority_coverage.json")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    args = parser.parse_args()

    packet = json.loads(args.packet.read_text(encoding="utf-8"))
    coverage = json.loads(args.coverage.read_text(encoding="utf-8"))
    rows = build_authority_rows()

    if coverage.get("schema_version") != "phase2-authority-coverage-v1":
        fail("coverage schema mismatch")
    if coverage.get("source_sha256") != sha256(args.source):
        fail("coverage source hash mismatch")

    expected = [row for row in rows if row["classification"] != "BLANK"]
    entries = coverage.get("entries")
    if not isinstance(entries, list) or len(entries) != len(expected):
        fail(f"coverage entry count mismatch: expected {len(expected)}, got {len(entries or [])}")

    segment_by_locator = {item["source_locator"]: item for item in packet.get("authority_segments", [])}
    criterion_by_id = {item["id"]: item for item in packet.get("criteria", [])}
    expected_criterion_locators: set[str] = set()

    for expected_row, entry in zip(expected, entries, strict=True):
        for field in ("line", "text", "classification"):
            if entry.get(field) != expected_row.get(field):
                fail(f"coverage {field} mismatch at source line {expected_row['line']}")
        line_number = int(expected_row["line"])
        if expected_row["classification"] == "PACKET_CRITERION":
            locator = f"docs/art/unit_art_board_reference_criteria.md#L{line_number}"
            expected_criterion_locators.add(locator)
            segment = segment_by_locator.get(locator)
            if segment is None:
                fail(f"material source line {line_number} is not mapped to an authority segment")
            if segment.get("text") != expected_row["text"]:
                fail(f"authority segment at line {line_number} is not lossless")
            criterion_id = segment.get("criterion_id")
            criterion = criterion_by_id.get(criterion_id)
            if criterion is None:
                fail(f"authority segment at line {line_number} has no criterion")
            if criterion.get("source_locator") != locator or criterion.get("text") != expected_row["text"]:
                fail(f"criterion at line {line_number} is not source-identical")
            if entry.get("criterion_id") != criterion_id or entry.get("authority_segment_id") != segment.get("id"):
                fail(f"coverage binding mismatch at line {line_number}")
        else:
            if "criterion_id" in entry or "authority_segment_id" in entry:
                fail(f"noncriterion source line {line_number} has a criterion binding")

    if set(segment_by_locator) != expected_criterion_locators:
        extra = sorted(set(segment_by_locator) - expected_criterion_locators)
        missing = sorted(expected_criterion_locators - set(segment_by_locator))
        fail(f"authority locator set mismatch: missing={missing} extra={extra}")

    authority = packet.get("criteria_authority", [])
    if len(authority) != 1 or authority[0].get("sha256") != sha256(args.source):
        fail("packet criteria authority does not bind the canonical source bytes")
    if len(packet.get("criteria", [])) != len(expected_criterion_locators):
        fail("packet criterion count differs from material source line count")

    print(
        "PASS phase2-board-authority-coverage "
        f"source_lines={len(rows)} material_criteria={len(expected_criterion_locators)} "
        f"structural_or_metadata={len(expected) - len(expected_criterion_locators)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
