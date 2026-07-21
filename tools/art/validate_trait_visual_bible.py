#!/usr/bin/env python3
"""Validate the Phase 1 Gamble Battle trait visual bible."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_TRAITS = [
    "Aegis",
    "Arcanist",
    "Blessed",
    "Bulwark",
    "Cartel",
    "Catalyst",
    "Chronomancer",
    "Executioner",
    "Exile",
    "Fortified",
    "Harmony",
    "Kaleidoscope",
    "Liaison",
    "Mentor",
    "Mogul",
    "Overload",
    "Sanguine",
    "Scholar",
    "Striker",
    "Titan",
    "Trader",
    "Vindicator",
]

REQUIRED_TRAIT_FIELDS = [
    "trait",
    "mechanics_anchor",
    "core_fantasy",
    "emotional_tone",
    "silhouette_verbs",
    "silhouette_language",
    "garment_anatomy_families",
    "palette",
    "patterns",
    "materials",
    "magic_behavior",
    "supernatural_cost",
    "allowed_variations",
    "forbidden_cliches",
    "combination_rules",
    "compact_visual_references",
    "prop_free_definition",
]

REQUIRED_REFERENCE_FIELDS = ["form", "surface", "motion", "cost_mark"]
PROP_DEPENDENCY_WORDS = {
    "armor",
    "axe",
    "book",
    "chain",
    "cloak",
    "coat",
    "coin",
    "corset",
    "crown",
    "dress",
    "gun",
    "halo",
    "hood",
    "rifle",
    "robe",
    "shield",
    "staff",
    "sword",
    "weapon",
    "wing",
}
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
TRES_ID = re.compile(r'^id\s*=\s*"([^"]+)"', re.MULTILINE)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--bible",
        default="docs/art/trait_visual_bible_phase1.json",
        help="Structured Phase 1 bible JSON.",
    )
    parser.add_argument(
        "--traits-dir",
        default="data/traits",
        help="Live trait-resource directory used for catalog parity.",
    )
    return parser.parse_args()


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value: dict[str, Any] = json.load(handle)
    return value


def _live_trait_ids(traits_dir: Path) -> list[str]:
    found: list[str] = []
    for path in sorted(traits_dir.glob("*.tres")):
        match = TRES_ID.search(path.read_text(encoding="utf-8"))
        if match:
            found.append(match.group(1))
    return sorted(found)


def _nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _nonempty_string_list(value: Any, minimum: int) -> bool:
    return (
        isinstance(value, list)
        and len(value) >= minimum
        and all(_nonempty_string(item) for item in value)
    )


def validate(data: dict[str, Any], traits_dir: Path) -> list[str]:
    errors: list[str] = []

    if data.get("schema_version") != 1:
        errors.append("schema_version must equal 1")
    if data.get("phase") != "Phase 1 — World and trait bible":
        errors.append("phase identifier is missing or incorrect")
    if data.get("deliverable_kind") != "written_trait_cards_with_nonproduction_visual_references":
        errors.append("deliverable_kind must preserve the Phase 1 asset boundary")

    traits = data.get("traits")
    if not isinstance(traits, list):
        return errors + ["traits must be an array"]

    names = [entry.get("trait") for entry in traits if isinstance(entry, dict)]
    if names != REQUIRED_TRAITS:
        errors.append(f"trait order/catalog mismatch: expected {REQUIRED_TRAITS}, got {names}")

    live_traits = _live_trait_ids(traits_dir)
    if live_traits != REQUIRED_TRAITS:
        errors.append(f"live data/traits catalog mismatch: expected {REQUIRED_TRAITS}, got {live_traits}")

    for index, entry in enumerate(traits):
        if not isinstance(entry, dict):
            errors.append(f"traits[{index}] must be an object")
            continue
        name = str(entry.get("trait", f"traits[{index}]"))
        missing = [field for field in REQUIRED_TRAIT_FIELDS if field not in entry]
        if missing:
            errors.append(f"{name}: missing fields {missing}")
            continue

        for field in [
            "mechanics_anchor",
            "core_fantasy",
            "emotional_tone",
            "silhouette_language",
            "magic_behavior",
            "supernatural_cost",
            "prop_free_definition",
        ]:
            if not _nonempty_string(entry[field]):
                errors.append(f"{name}: {field} must be a non-empty string")

        if not _nonempty_string_list(entry["silhouette_verbs"], 3) or len(entry["silhouette_verbs"]) != 3:
            errors.append(f"{name}: silhouette_verbs must contain exactly three verbs")
        for field, minimum in [
            ("garment_anatomy_families", 4),
            ("patterns", 3),
            ("materials", 4),
            ("allowed_variations", 5),
            ("forbidden_cliches", 4),
            ("combination_rules", 3),
        ]:
            if not _nonempty_string_list(entry[field], minimum):
                errors.append(f"{name}: {field} must contain at least {minimum} non-empty entries")

        palette = entry["palette"]
        if not isinstance(palette, list) or len(palette) != 5:
            errors.append(f"{name}: palette must contain exactly five swatches")
        else:
            for swatch in palette:
                if not isinstance(swatch, dict) or not _nonempty_string(swatch.get("name")):
                    errors.append(f"{name}: every palette swatch needs a name")
                    continue
                if not HEX_COLOR.match(str(swatch.get("hex", ""))):
                    errors.append(f"{name}: invalid palette color {swatch.get('hex')}")

        references = entry["compact_visual_references"]
        if not isinstance(references, dict):
            errors.append(f"{name}: compact_visual_references must be an object")
        else:
            for field in REQUIRED_REFERENCE_FIELDS:
                if not _nonempty_string(references.get(field)):
                    errors.append(f"{name}: visual reference {field} is missing")

        prop_free = entry["prop_free_definition"].lower()
        words = set(re.findall(r"[a-z]+", prop_free))
        forbidden_hits = sorted(words & PROP_DEPENDENCY_WORDS)
        if forbidden_hits:
            errors.append(
                f"{name}: prop_free_definition depends on forbidden nouns {forbidden_hits}"
            )
        if len(prop_free.split()) < 8:
            errors.append(f"{name}: prop_free_definition is too short to prove the exit gate")

    blessed = next((entry for entry in traits if entry.get("trait") == "Blessed"), None)
    if blessed is None or "divine favor experienced as disgrace" not in blessed["core_fantasy"].lower():
        errors.append("Blessed must preserve 'divine favor experienced as disgrace'")

    return errors


def main() -> int:
    args = _parse_args()
    bible_path = Path(args.bible).resolve()
    traits_dir = Path(args.traits_dir).resolve()
    errors = validate(_load_json(bible_path), traits_dir)
    if errors:
        print("Trait visual bible validation: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Trait visual bible validation: PASS")
    print(f"traits={len(REQUIRED_TRAITS)} catalog_parity=22/22 prop_free_exit_gate=22/22")
    return 0


if __name__ == "__main__":
    sys.exit(main())
