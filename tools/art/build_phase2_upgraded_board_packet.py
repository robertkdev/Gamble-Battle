#!/usr/bin/env python3
"""Build the blind Board-of-Agents v2 packet for Phase 2 unit concepts."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROUND = ROOT / "docs/art/phase2_calibration/board/round_7_upgraded"
BENCHMARKS = ROOT / "docs/art/phase2_calibration/benchmarks"
VALIDATOR = Path.home() / ".codex/skills/board-of-agents/scripts/validate_audit.py"
CRITERIA_PATH = ROOT / "docs/art/unit_art_board_reference_criteria.md"
UNITS = ("korath", "veyra", "cashmere", "pilfer", "nyxa", "creep", "knoll", "quillith", "kett", "luna", "sable", "malachor")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def locator(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_validator():
    spec = importlib.util.spec_from_file_location("board_audit_validator", VALIDATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot import {VALIDATOR}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    board = load_validator()
    ROUND.mkdir(parents=True, exist_ok=True)

    surfaces = [
        {"id": "master_concepts", "class": "CHARACTER", "critical": True, "required_inspection_modes": ["FULL_SIZE"]},
        {"id": "silhouette_exploration", "class": "CHARACTER", "critical": True, "required_inspection_modes": ["SILHOUETTE"]},
        {"id": "face_psychology", "class": "CHARACTER", "critical": True, "required_inspection_modes": ["FACE_ENLARGEMENT"]},
        {"id": "native_96_read", "class": "CHARACTER", "critical": True, "required_inspection_modes": ["NATIVE_96"]},
        {"id": "roster_style_convergence", "class": "CHARACTER", "critical": True, "required_inspection_modes": ["SIDE_BY_SIDE"]},
    ]
    all_surfaces = [item["id"] for item in surfaces]

    criterion_specs = [
        ("C01", "Every unit must read as a fighter at or near peak combat condition.", ["master_concepts", "face_psychology"]),
        ("C02", "Every unit must read as a villain, dangerous antagonist, or deliberately horrific combat entity.", ["master_concepts", "face_psychology", "silhouette_exploration"]),
        ("C03", "Body, equipment, posture, and protection logic must visibly support the unit's gameplay role without generic fantasy armor.", ["master_concepts", "silhouette_exploration"]),
        ("C04", "Each unit must have a complete ten-field survival-psychology record that is visibly expressed by face and pose.", ["master_concepts", "face_psychology"]),
        ("C05", "A visible supernatural price, bargain, corruption, compulsion, scar, addiction, punishment, debt, or bodily consequence is mandatory.", ["master_concepts", "face_psychology"]),
        ("C06", "Each unit must be a unique roster member rather than a reuse of one face, body, costume, anatomy, prop, or emotional template.", ["roster_style_convergence", "silhouette_exploration"]),
        ("C07", "Every unit must stay inside one permitted adult peak-condition or deliberate-horror visual lane; cute mascots and ordinary vulnerable age lanes are forbidden.", ["master_concepts", "silhouette_exploration", "face_psychology"]),
        ("C08", "A non-horrific female unit must read as an unmistakably adult, conventionally attractive, lean or toned, feminine, combat-capable woman with unit-specific appeal and threat.", ["master_concepts", "face_psychology", "roster_style_convergence"]),
        ("C09", "Female frontliners must visibly explain survivability through unit-specific protection rather than a bulky male-coded body.", ["master_concepts", "silhouette_exploration"]),
        ("C10", "The same-master face enlargement and body pose must communicate a specific want, fear, contradiction, survival strategy, and villainous intent without lore rescue.", ["face_psychology", "master_concepts"]),
        ("C11", "Horror and threat must read as hostile, predatory, coercive, alien, spiritually ruined, or dangerously beautiful, never cute, soft, harmless, whimsical, or cartoon-goofy.", ["master_concepts", "silhouette_exploration", "native_96_read"]),
        ("C12", "Finish must be dry, detailed, premium western gothic board-game illustration with grounded realism, rejecting anime, gacha, porcelain, glossy plastic, wet-skin, and clean heroic fantasy drift.", ["master_concepts", "roster_style_convergence"]),
        ("C13", "Each unit requires three genuinely different silhouettes, one definitive full-body master, and face and 96-pixel derivatives from that unchanged master.", ["silhouette_exploration", "master_concepts", "face_psychology", "native_96_read"]),
        ("C14", "The unchanged master must remain identifiable at native 96 pixels and must be compared against its nearest roster neighbors.", ["native_96_read", "roster_style_convergence"]),
        ("C15", "One art-primary trait, separate secondary channels, one dominant prop or anatomy idea, role silhouette, and supernatural cost must read without floating-effect or accessory clutter.", ["master_concepts", "silhouette_exploration", "native_96_read"]),
        ("C16", "The active roster must avoid convergence in faces, ages, bodies, garments, armor, props, anatomy, palettes, tease placement, and villain emotion families.", ["roster_style_convergence", "face_psychology", "silhouette_exploration"]),
        ("C17", "The evidence packet must include silhouettes, selected masters, same-master face enlargements, deterministic 96-pixel checks, psychology, role and trait construction, Vellum-first style comparison, and roster-neighbor comparisons.", all_surfaces),
        ("C18", "No concept may be approved with a failed gate; readiness requires unanimous professional review, no surviving blocker, controlled cross-examination, and later explicit user approval.", all_surfaces),
    ]

    criteria = []
    segments = []
    authority_records = []
    for index, (cid, text, criterion_surfaces) in enumerate(criterion_specs, 1):
        source_locator = f"{locator(CRITERIA_PATH)}#board-criterion-{index:02d}"
        record = {
            "id": cid,
            "source_locator": source_locator,
            "text": text,
            "critical": True,
            "applicability": "ALWAYS",
            "applicability_rule": "Evaluate every Phase 2 unit; record conditional lane gates explicitly when relevant.",
            "surfaces": criterion_surfaces,
            "required_surface_classes": ["CHARACTER"],
            "required_evidence": "Direct visual inspection of every mapped frozen artifact plus the psychology specification and calibrated benchmark comparison.",
        }
        criteria.append(record)
        segment_id = f"AS{index:02d}"
        segments.append({"id": segment_id, "source_locator": source_locator, "text": text, "criterion_id": cid})
        authority_records.append({**record, "authority_segment_ids": [segment_id]})

    dimensions = [
        {"id": "D_MASTER_CHARACTER_DESIGN", "critical": True, "surfaces": ["master_concepts"], "applicability": "APPLICABLE", "applicability_reason": "Definitive character design and visible contract read."},
        {"id": "D_SILHOUETTE_LANGUAGE", "critical": True, "surfaces": ["silhouette_exploration"], "applicability": "APPLICABLE", "applicability_reason": "Distinct threat and role silhouette at a glance."},
        {"id": "D_FACE_PSYCHOLOGY", "critical": True, "surfaces": ["face_psychology"], "applicability": "APPLICABLE", "applicability_reason": "Specific psychology must survive face enlargement."},
        {"id": "D_NATIVE_96_LEGIBILITY", "critical": True, "surfaces": ["native_96_read"], "applicability": "APPLICABLE", "applicability_reason": "Production-scale unit recognition is mandatory."},
        {"id": "D_ROSTER_CONVERGENCE_CONTROL", "critical": True, "surfaces": ["roster_style_convergence"], "applicability": "APPLICABLE", "applicability_reason": "The 12-unit cut must remain individually recognizable and stylistically coherent."},
    ]
    dimensions.extend(
        {"id": did, "critical": True, "surfaces": all_surfaces, "applicability": "APPLICABLE", "applicability_reason": label}
        for did, label in board.UNIVERSAL_DIMENSIONS.items()
    )
    all_dimensions = [item["id"] for item in dimensions]

    artifact_specs: list[tuple[Path, list[str], str, list[str], list[str]]] = []
    for unit in UNITS:
        base = ROOT / f"assets/concepts/phase2_calibration/{unit}"
        artifact_specs.extend([
            (base / f"{unit}_master.png", ["master_concepts"], "PRODUCT_ARTIFACT", ["FULL_SIZE"], [f"{unit} complete full-body master"]),
            (base / f"{unit}_silhouettes.png", ["silhouette_exploration"], "PRODUCT_ARTIFACT", ["SILHOUETTE"], [f"{unit} three silhouette candidates"]),
            (base / f"{unit}_face.png", ["face_psychology"], "PRODUCT_ARTIFACT", ["FACE_ENLARGEMENT"], [f"{unit} same-master face crop"]),
            (base / f"{unit}_96px.png", ["native_96_read"], "PRODUCT_ARTIFACT", ["NATIVE_96"], [f"{unit} exact native 96-pixel derivative"]),
        ])
    artifact_specs.extend([
        (ROOT / "docs/art/phase2_calibration/phase2_calibration_contact_sheet.png", ["roster_style_convergence"], "AUTHORITATIVE_CAPTURE", ["SIDE_BY_SIDE"], ["all 12 masters and silhouettes"]),
        (ROOT / "docs/art/phase2_calibration/phase2_face_board.png", ["face_psychology", "roster_style_convergence"], "AUTHORITATIVE_CAPTURE", ["FACE_ENLARGEMENT", "SIDE_BY_SIDE"], ["all 12 face crops"]),
        (ROOT / "docs/art/phase2_calibration/phase2_calibration_96px_board.png", ["native_96_read", "roster_style_convergence"], "AUTHORITATIVE_CAPTURE", ["NATIVE_96", "SIDE_BY_SIDE"], ["all 12 exact 96-pixel derivatives"]),
        (ROOT / "docs/art/phase2_calibration/comparisons/phase2_master_comparison.png", ["roster_style_convergence"], "AUTHORITATIVE_CAPTURE", ["SIDE_BY_SIDE"], ["role-grouped master comparison"]),
        (ROOT / "docs/art/phase2_calibration/comparisons/phase2_vellum_first_comparison.png", ["roster_style_convergence", "master_concepts"], "AUTHORITATIVE_CAPTURE", ["SIDE_BY_SIDE", "FULL_SIZE"], ["Vellum-first material and finish comparison"]),
    ])

    cut_artifacts = []
    raw_evidence = []
    for index, (path, artifact_surfaces, kind, modes, regions) in enumerate(artifact_specs, 1):
        if not path.is_file():
            raise FileNotFoundError(path)
        digest = sha256(path)
        loc = locator(path)
        cut_artifacts.append({"locator": loc, "sha256": digest, "surfaces": artifact_surfaces})
        raw_evidence.append({"id": f"E{index:03d}", "locator": loc, "sha256": digest, "surface": artifact_surfaces[0], "kind": kind, "inspection_modes": modes, "observed_regions": regions})
        for surface in artifact_surfaces[1:]:
            raw_evidence.append({"id": f"E{index:03d}_{surface}", "locator": f"{loc}#{surface}", "sha256": digest, "surface": surface, "kind": kind, "inspection_modes": modes, "observed_regions": regions})

    psychology_path = ROOT / "docs/art/phase2_calibration/phase2_unit_psychology_records.json"
    raw_evidence.append({"id": "E_PSYCHOLOGY_SPEC", "locator": locator(psychology_path), "sha256": sha256(psychology_path), "surface": "face_psychology", "kind": "SPECIFICATION", "inspection_modes": ["FACE_ENLARGEMENT"], "observed_regions": ["all 12 ten-field psychology records"]})

    benchmark_specs = [
        ("B_RIOT_BRIAR", "riot_briar_shipped.jpg", "SHIPPED_PEER", "Shipped villain-woman splash illustration", "Adult female threat, specific restraint device, face attitude, silhouette staging, and release finish.", "Wide cinematic splash rather than isolated transparent board-game master; use for professional finish and character-specific threat, not composition matching."),
        ("B_RIOT_BELVETH", "riot_belveth_shipped.jpg", "INDEPENDENT_PROFESSIONAL", "Shipped nonhuman villain splash illustration", "Nonhuman majesty, immediately hostile silhouette, embodied anatomy, palette control, and premium finish.", "Wide cinematic splash and larger environment contribution; use for nonhuman threat and finish, not exact body-plan or transparent-presentation matching."),
        ("B_RIOT_CAMILLE", "riot_camille_shipped.jpg", "ASPIRATIONAL_PEER", "Shipped adult female villain-action illustration", "Elegant adult femininity, role-specific anatomy and equipment, dangerous intent, clean silhouette, and controlled premium finish.", "Action splash with environmental motion rather than neutral full-body board presentation; use as aspirational clarity and craft ceiling."),
        ("B_VELLUM", "vellum_user_approved_raw.png", "USER_SUPPLIED_REFERENCE", "User-approved isolated western-gothic character master", "Project veto anchor for dry material, detail density, grounded realism, adult villain presence, and premium board-game illustration.", "Single internal style anchor with bright chroma-key background; does not independently establish professional market floor."),
        ("B_MORWEN", "morwen_user_approved.png", "USER_SUPPLIED_REFERENCE", "User-approved isolated adult female villain master", "Project anchor for hot-adult-woman read, specific predatory psychology, fit feminine body design, and danger without bulky armor.", "Single internal female anchor and rear three-quarter pose; must not become a repeated body, tease, or pose template."),
    ]
    benchmarks = []
    for bid, name, source_class, artifact_class, relevance, differences in benchmark_specs:
        path = BENCHMARKS / name
        benchmarks.append({
            "id": bid,
            "locator": locator(path),
            "sha256": sha256(path),
            "source_class": source_class,
            "surfaces": all_surfaces,
            "artifact_class": artifact_class,
            "artifact_surface_classes": ["CHARACTER"],
            "relevance": relevance,
            "constraint_differences": differences,
            "anchored_dimension_ids": all_dimensions,
        })

    objective_text = "Work on phase 2 and use the upgraded board-of-agents. Break if you end up in an endless loop or if you catch the board missing important stuff."
    packet = {
        "schema_version": board.SCHEMA_VERSION,
        "record_kind": "audit_packet",
        "lineage_id": "gamble-battle-phase2-round7-upgraded",
        "objective": {"locator": "thread:019f8be6-4ca5-7213-bfe1-135ae50eb18b:user-request", "verbatim": objective_text},
        "acceptance_envelope": {
            "version": "phase2-2026-07-21-v1",
            "approval_locator": "thread:019f8be6-4ca5-7213-bfe1-135ae50eb18b:user-request",
            "approval_sha256": hashlib.sha256(objective_text.encode("utf-8")).hexdigest(),
            "target_band": "PROFESSIONAL",
            "audience": "Adult strategy-game players and the user as final creative authority",
            "phase": "Phase 2 real-unit calibration concept lock",
            "domain": "VISUAL",
            "constraints": [
                "Inspect all 12 units and every frozen artifact, not only the five replaced masters.",
                "Board approval never replaces explicit final user approval.",
                "Stop if required authority, evidence, surfaces, or criteria are omitted.",
                "Do not repeat a review cycle without decision-changing product or evidence changes.",
            ],
        },
        "authority_segments": segments,
        "cut": {"id": "phase2-cut-9d03d7c", "artifacts": cut_artifacts},
        "surfaces": surfaces,
        "criteria": criteria,
        "criteria_authority": [{
            "locator": locator(CRITERIA_PATH),
            "sha256": sha256(CRITERIA_PATH),
            "criterion_ids": [record["id"] for record in criteria],
            "criteria": authority_records,
            "records_sha256": board.canonical_sha256(authority_records),
        }],
        "dimensions": dimensions,
        "reviewer_count": 3,
        "raw_evidence": raw_evidence,
        "blind_round_exclusions": {key: True for key in board.BLIND_EXCLUSIONS},
        "benchmarks": benchmarks,
        "skill_hashes": board.local_skill_hashes(),
        "evidence_order": [item["id"] for item in raw_evidence],
        "evidence_transforms": [],
        "authority_context_sha256": "0" * 64,
    }
    packet["authority_context_sha256"] = board.canonical_sha256(board.authority_context_from_packet(packet))
    authority_context = board.authority_context_from_packet(packet)

    errors = board.validate(packet)
    errors.extend(board.validate_authority_context(authority_context))
    if errors:
        raise RuntimeError("\n".join(errors))

    (ROUND / "audit_packet.json").write_text(json.dumps(packet, indent=2) + "\n", encoding="utf-8")
    (ROUND / "authority_context.json").write_text(json.dumps(authority_context, indent=2) + "\n", encoding="utf-8")
    print(f"PASS packet evidence={len(raw_evidence)} artifacts={len(cut_artifacts)} criteria={len(criteria)} dimensions={len(dimensions)} benchmarks={len(benchmarks)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
