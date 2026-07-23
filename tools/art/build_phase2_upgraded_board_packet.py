#!/usr/bin/env python3
"""Build the blind Board-of-Agents v2 packet for Phase 2 unit concepts."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROUND = ROOT / "docs/art/phase2_calibration/board/round_8_fixed"
BENCHMARKS = ROOT / "docs/art/phase2_calibration/benchmarks"
VALIDATOR = Path.home() / ".codex/skills/board-of-agents/scripts/validate_audit.py"
CRITERIA_PATH = ROOT / "docs/art/unit_art_board_reference_criteria.md"
UNITS = ("korath", "veyra", "cashmere", "pilfer", "nyxa", "creep", "knoll", "quillith", "kett", "luna", "sable", "malachor")

STRUCTURAL_AUTHORITY_LINES = {
    "Appeal may come from:",
    "Reject:",
    "Fail the concept for:",
    "For each unit:",
    "The Board does not vote without:",
}

SECTION_SURFACES = {
    0: ["master_concepts", "silhouette_exploration", "face_psychology", "native_96_read", "roster_style_convergence"],
    1: ["master_concepts", "silhouette_exploration", "face_psychology", "native_96_read", "roster_style_convergence"],
    2: ["master_concepts", "silhouette_exploration", "face_psychology"],
    3: ["master_concepts", "face_psychology"],
    4: ["master_concepts", "face_psychology", "roster_style_convergence"],
    5: ["master_concepts", "face_psychology", "roster_style_convergence"],
    6: ["master_concepts", "silhouette_exploration"],
    7: ["master_concepts", "face_psychology"],
    8: ["master_concepts", "face_psychology"],
    9: ["face_psychology", "roster_style_convergence"],
    10: ["master_concepts", "face_psychology", "roster_style_convergence"],
    11: ["master_concepts", "silhouette_exploration", "native_96_read"],
    12: ["master_concepts", "face_psychology"],
    13: ["master_concepts", "roster_style_convergence"],
    14: ["master_concepts", "silhouette_exploration", "face_psychology", "native_96_read", "roster_style_convergence"],
    15: ["master_concepts", "silhouette_exploration", "face_psychology", "roster_style_convergence"],
    16: ["master_concepts", "silhouette_exploration", "face_psychology", "native_96_read", "roster_style_convergence"],
    17: ["master_concepts", "silhouette_exploration", "face_psychology", "native_96_read", "roster_style_convergence"],
    18: ["audit_record_contract"],
}


def authority_line_classification(line_number: int, text: str) -> str:
    stripped = text.strip()
    if not stripped:
        return "BLANK"
    if stripped.startswith("#"):
        return "MARKDOWN_HEADING"
    if line_number in {3, 5}:
        return "SOURCE_METADATA"
    if stripped in STRUCTURAL_AUTHORITY_LINES:
        return "STRUCTURAL_LABEL"
    return "PACKET_CRITERION"


def build_authority_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    section = 0
    for line_number, text in enumerate(CRITERIA_PATH.read_text(encoding="utf-8").splitlines(), 1):
        stripped = text.strip()
        if stripped.startswith("## "):
            try:
                section = int(stripped.split(".", 1)[0].removeprefix("## "))
            except ValueError:
                pass
        rows.append({
            "line": line_number,
            "text": text,
            "section": section,
            "classification": authority_line_classification(line_number, text),
        })
    return rows


def criterion_surfaces(line_number: int, section: int, text: str) -> list[str]:
    if 279 <= line_number <= 292:
        return ["audit_record_contract"]
    if section == 16:
        if line_number == 241:
            return ["silhouette_exploration"]
        if line_number == 242:
            return ["master_concepts"]
        if line_number == 243:
            return ["face_psychology"]
        if line_number == 244:
            return ["native_96_read"]
        if line_number == 245:
            return ["face_psychology"]
        if line_number in {248, 249, 250}:
            return ["roster_style_convergence"]
    if section == 17:
        upper = text.upper()
        if "96PX" in upper or "96 PX" in upper:
            return ["native_96_read"]
        if "PSYCHOLOGY" in upper or "FACE AND POSE" in upper:
            return ["face_psychology", "master_concepts"]
        if "ROSTER-DISTINCT" in upper:
            return ["roster_style_convergence"]
        if "BOARD" in upper or "REVIEW" in upper or "VALIDAT" in upper or "APPROVAL" in upper or "PROVENANCE" in upper or "TEMPLATE" in upper:
            return ["audit_record_contract"]
    return list(SECTION_SURFACES.get(section, ["audit_record_contract"]))


def criterion_applicability(line_number: int, section: int, text: str) -> tuple[str, str]:
    lower = text.casefold()
    if section == 2 and 26 <= line_number <= 29:
        return "CONDITIONAL", "Applies when at least one reviewed unit is assigned this visual lane."
    if section == 4:
        return "CONDITIONAL", "Applies to reviewed female units not assigned a deliberately horrific lane."
    if section == 5:
        return "CONDITIONAL", "Applies to reviewed units assigned the hot-adult-woman lane; optional techniques apply only when used."
    if section == 6 and ("female frontliner" in lower or "female tank" in lower):
        return "CONDITIONAL", "Applies to reviewed female frontliners."
    if section == 9 and 139 <= line_number <= 163:
        return "CONDITIONAL", "Applies when a reviewed humanoid uses this villain emotion family."
    if section == 10:
        return "CONDITIONAL", "Applies when the named specificity anchor is used for calibration."
    if "deliberate horror exception" in lower:
        return "CONDITIONAL", "Applies when a reviewed unit uses a deliberate horror exception."
    if "blessed" in lower:
        return "CONDITIONAL", "Applies to reviewed Blessed units."
    if line_number in {269, 270}:
        return "CONDITIONAL", "Applies to reviewed female units not assigned a deliberately horrific lane."
    if line_number == 271:
        return "CONDITIONAL", "Applies to reviewed female frontliners."
    if line_number == 286:
        return "CONDITIONAL", "Applies only when recording final user approval after a ready Board result."
    return "ALWAYS", "Applies to the complete current Phase 2 review cut and its audit evidence."


def criterion_critical(line_number: int, section: int) -> bool:
    if section == 10 or line_number == 107 or 68 <= line_number <= 75:
        return False
    return True


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
        {"id": "audit_record_contract", "class": "DOCUMENT", "critical": False, "required_inspection_modes": ["DIRECT"]},
    ]
    all_surfaces = [item["id"] for item in surfaces]
    visual_surfaces = [item["id"] for item in surfaces if item["class"] == "CHARACTER"]
    surface_class_by_id = {item["id"]: item["class"] for item in surfaces}
    authority_rows = build_authority_rows()
    criteria = []
    segments = []
    authority_records = []
    coverage_entries = []
    for row in authority_rows:
        line_number = int(row["line"])
        text = str(row["text"])
        classification = str(row["classification"])
        section = int(row["section"])
        if classification != "PACKET_CRITERION":
            if classification != "BLANK":
                coverage_entries.append({"line": line_number, "text": text, "classification": classification})
            continue
        cid = f"UA-L{line_number:03d}"
        segment_id = f"AS-L{line_number:03d}"
        source_locator = f"{locator(CRITERIA_PATH)}#L{line_number}"
        criterion_surface_ids = criterion_surfaces(line_number, section, text)
        applicability, applicability_rule = criterion_applicability(line_number, section, text)
        required_classes = sorted({surface_class_by_id[sid] for sid in criterion_surface_ids})
        record = {
            "id": cid,
            "source_locator": source_locator,
            "text": text,
            "critical": criterion_critical(line_number, section),
            "applicability": applicability,
            "applicability_rule": applicability_rule,
            "surfaces": criterion_surface_ids,
            "required_surface_classes": required_classes,
            "required_evidence": "Direct inspection of all frozen evidence mapped to the named surfaces, with the exact source clause applied losslessly.",
        }
        criteria.append(record)
        segments.append({"id": segment_id, "source_locator": source_locator, "text": text, "criterion_id": cid})
        authority_records.append({**record, "authority_segment_ids": [segment_id]})
        coverage_entries.append({"line": line_number, "text": text, "classification": classification, "criterion_id": cid, "authority_segment_id": segment_id})

    coverage = {
        "schema_version": "phase2-authority-coverage-v1",
        "source_locator": locator(CRITERIA_PATH),
        "source_sha256": sha256(CRITERIA_PATH),
        "entries": coverage_entries,
    }
    coverage["entries_sha256"] = board.canonical_sha256(coverage_entries)
    coverage_path = ROUND / "authority_coverage.json"
    ROUND.mkdir(parents=True, exist_ok=True)
    coverage_path.write_text(json.dumps(coverage, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    dimensions = [
        {"id": "D_MASTER_CHARACTER_DESIGN", "critical": True, "surfaces": ["master_concepts"], "applicability": "APPLICABLE", "applicability_reason": "Definitive character design and visible contract read."},
        {"id": "D_SILHOUETTE_LANGUAGE", "critical": True, "surfaces": ["silhouette_exploration"], "applicability": "APPLICABLE", "applicability_reason": "Distinct threat and role silhouette at a glance."},
        {"id": "D_FACE_PSYCHOLOGY", "critical": True, "surfaces": ["face_psychology"], "applicability": "APPLICABLE", "applicability_reason": "Specific psychology must survive face enlargement."},
        {"id": "D_NATIVE_96_LEGIBILITY", "critical": True, "surfaces": ["native_96_read"], "applicability": "APPLICABLE", "applicability_reason": "Production-scale unit recognition is mandatory."},
        {"id": "D_ROSTER_CONVERGENCE_CONTROL", "critical": True, "surfaces": ["roster_style_convergence"], "applicability": "APPLICABLE", "applicability_reason": "The 12-unit cut must remain individually recognizable and stylistically coherent."},
    ]
    dimensions.extend(
        {"id": did, "critical": True, "surfaces": visual_surfaces, "applicability": "APPLICABLE", "applicability_reason": label}
        for did, label in board.UNIVERSAL_DIMENSIONS.items()
    )
    all_dimensions = [item["id"] for item in dimensions]

    audit_contract_dir = ROOT / "docs/art/phase2_calibration/audit_contract"
    audit_contract_dir.mkdir(parents=True, exist_ok=True)
    template_alias = audit_contract_dir / "unit_template.json"
    validator_alias = audit_contract_dir / "unit_validator.py"
    shutil.copyfile(ROOT / "docs/art/unit_art_board_review_template.json", template_alias)
    shutil.copyfile(ROOT / "tools/art/validate_unit_art_board_review.py", validator_alias)

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
        (template_alias, ["audit_record_contract"], "PRODUCT_ARTIFACT", ["DIRECT"], ["three-seat unit-art audit record template"]),
        (validator_alias, ["audit_record_contract"], "PRODUCT_ARTIFACT", ["DIRECT"], ["unit-art semantic review validator"]),
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
            "surfaces": visual_surfaces,
            "artifact_class": artifact_class,
            "artifact_surface_classes": ["CHARACTER"],
            "relevance": relevance,
            "constraint_differences": differences,
            "anchored_dimension_ids": all_dimensions,
        })

    objective_text = "Work on phase 2 and use the upgraded board-of-agents. Break if you end up in an endless loop or if you catch the board missing important stuff. Fix the failed Board transport and authority-coverage gaps without weakening the audit."
    packet = {
        "schema_version": board.SCHEMA_VERSION,
        "record_kind": "audit_packet",
        "lineage_id": "gamble-battle-phase2-round8-fixed",
        "objective": {"locator": "thread:019f8be6-4ca5-7213-bfe1-135ae50eb18b:user-request", "verbatim": objective_text},
        "acceptance_envelope": {
            "version": "phase2-2026-07-21-v1.1-manifest-repair",
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
                "Every material product or audit-procedure clause in the canonical source must be losslessly mapped or structurally classified by the deterministic coverage gate.",
                "Use chunked same-reviewer sealing so no primary record depends on one oversized response stream.",
            ],
        },
        "authority_segments": segments,
        "cut": {"id": "phase2-art-cut-9d03d7c", "artifacts": cut_artifacts},
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
    print(f"PASS packet evidence={len(raw_evidence)} artifacts={len(cut_artifacts)} criteria={len(criteria)} dimensions={len(dimensions)} benchmarks={len(benchmarks)} coverage={len(coverage_entries)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
