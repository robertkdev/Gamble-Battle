#!/usr/bin/env python3
"""Structural and deterministic-derivative validation for Phase 2."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops

from render_phase2_calibration_packet import BACKGROUND, BOARD_96, CONTACT_SHEET, MANIFEST, ROOT, check_path, contain, master_path, silhouettes_path


EXPECTED_TRAITS = {
    "Aegis", "Arcanist", "Blessed", "Bulwark", "Cartel", "Catalyst", "Chronomancer", "Executioner",
    "Exile", "Fortified", "Harmony", "Kaleidoscope", "Liaison", "Mentor", "Mogul", "Overload",
    "Sanguine", "Scholar", "Striker", "Titan", "Trader", "Vindicator",
}
EXPECTED_ROLES = {"Tank", "Mage", "Assassin", "Marksman", "Support", "Brawler"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate() -> dict[str, object]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    units = data["units"]
    errors: list[str] = []
    warnings: list[str] = []
    evidence: dict[str, object] = {}

    if len(units) != 12:
        errors.append(f"expected 12 units, found {len(units)}")
    ids = [unit["id"] for unit in units]
    if len(ids) != len(set(ids)):
        errors.append("duplicate unit ids")

    traits = {trait for unit in units for trait in unit["traits"]}
    roles = {unit["role"] for unit in units}
    if traits != EXPECTED_TRAITS:
        errors.append(f"trait coverage mismatch: missing={sorted(EXPECTED_TRAITS - traits)} extra={sorted(traits - EXPECTED_TRAITS)}")
    if roles != EXPECTED_ROLES:
        errors.append(f"role coverage mismatch: missing={sorted(EXPECTED_ROLES - roles)} extra={sorted(roles - EXPECTED_ROLES)}")
    if sum(len(unit["traits"]) == 3 for unit in units) < 2:
        errors.append("fewer than two three-trait calibration units")
    if "korath" not in ids or "Blessed" not in next(unit for unit in units if unit["id"] == "korath")["traits"]:
        errors.append("Blessed calibration unit Korath missing")

    forbidden = set(data["constraints"]["forbidden_assets"])
    if forbidden != {"shop_card", "headshot", "sprite_sheet", "animation_sheet", "vfx_asset"}:
        errors.append("forbidden asset scope changed")

    image_evidence: dict[str, object] = {}
    for unit in units:
        unit_id = unit["id"]
        if len(unit["silhouettes"]) != 3:
            errors.append(f"{unit_id}: silhouette count is not three")
        if unit["selected_silhouette"] not in {"A", "B", "C"}:
            errors.append(f"{unit_id}: invalid selected silhouette")
        if unit["art_primary"] not in unit["traits"]:
            errors.append(f"{unit_id}: primary trait not assigned to unit")
        for required in ("survival_psychology", "villain_read", "primary_prop", "supernatural_cost", "board_survival"):
            if not unit.get(required):
                errors.append(f"{unit_id}: missing {required}")

        paths = [master_path(unit_id), silhouettes_path(unit_id), check_path(unit_id)]
        for path in paths:
            if not path.exists():
                errors.append(f"missing image: {path.relative_to(ROOT)}")
        if any(not path.exists() for path in paths):
            continue

        master = Image.open(paths[0]).convert("RGB")
        silhouettes = Image.open(paths[1]).convert("RGB")
        check = Image.open(paths[2]).convert("RGB")
        if min(master.size) < 768:
            warnings.append(f"{unit_id}: master below 768px minimum axis: {master.size}")
        if min(silhouettes.size) < 768:
            warnings.append(f"{unit_id}: silhouettes below 768px minimum axis: {silhouettes.size}")
        if check.size != (96, 96):
            errors.append(f"{unit_id}: 96px derivative is {check.size}")
        expected = contain(master, (96, 96), BACKGROUND)
        if ImageChops.difference(expected, check).getbbox() is not None:
            errors.append(f"{unit_id}: 96px image is not deterministic containment of master")
        image_evidence[unit_id] = {
            "master_size": master.size,
            "silhouettes_size": silhouettes.size,
            "master_sha256": sha256(paths[0]),
            "silhouettes_sha256": sha256(paths[1]),
            "check_sha256": sha256(paths[2]),
        }

    for board in (CONTACT_SHEET, BOARD_96):
        if not board.exists():
            errors.append(f"missing board: {board.relative_to(ROOT)}")

    evidence["unit_count"] = len(units)
    evidence["traits"] = sorted(traits)
    evidence["roles"] = sorted(roles)
    evidence["three_trait_units"] = [unit["id"] for unit in units if len(unit["traits"]) == 3]
    evidence["images"] = image_evidence
    return {"ok": not errors, "errors": errors, "warnings": warnings, "evidence": evidence}


if __name__ == "__main__":
    result = validate()
    print(json.dumps(result, indent=2))
    sys.exit(0 if result["ok"] else 1)
