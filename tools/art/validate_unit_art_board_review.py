from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import struct
import tempfile
import zlib
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEMPLATE = ROOT / "docs" / "art" / "unit_art_board_review_template.json"
CRITERIA_PATH = ROOT / "docs" / "art" / "unit_art_board_reference_criteria.md"

VISUAL_LANES = {
    "hot_adult_woman",
    "peak_condition_humanoid",
    "deliberately_horrific_humanoid",
    "monster_alien_creature_horror",
}
SEX_DESIGN_CATEGORIES = {"female", "male", "androgynous", "sexless_nonhuman"}
PROTECTION_LOGIC = {
    "not_applicable",
    "armor",
    "shield_architecture",
    "reinforced_clothing",
    "protective_skin",
    "anatomical_fortification",
    "supernatural_protection",
    "other",
}
EMOTION_FAMILIES = {
    "dissociated_stone_cold",
    "evil_manipulative_demonic",
    "angry",
    "feral_animalistic",
    "nonhuman_individual_psychology",
}
REQUIRED_VERDICTS = {
    "peak_age_fighter",
    "psychology_reads_from_face",
    "face_and_pose_agree",
    "villain",
    "horror_threat",
    "supernatural_cost",
    "gameplay_identity",
    "trait_channels",
    "read_96px",
    "roster_distinct",
}
CONDITIONAL_VERDICTS = {
    "hot_adult_woman",
    "lean_toned_feminine",
    "frontline_protection_explained",
    "deliberate_horror_exception",
    "blessed_special_gate",
}
PSYCHOLOGY_FIELDS = {
    "core_wound",
    "private_want",
    "primary_fear",
    "survival_strategy",
    "villainous_distortion",
    "current_emotional_state",
    "emotional_contradiction",
    "face_direction",
    "pose_direction",
    "forbidden_read",
}
FACE_EVIDENCE_FIELDS = {
    "feeling",
    "want",
    "fear_or_concealment",
    "active_survival_strategy",
    "villainous_read",
    "cited_visual_cues",
}
PROFESSIONAL_BANDS = {
    "UNPROVEN": -1,
    "BELOW_PROFESSIONAL": 0,
    "PROFESSIONAL": 1,
    "EXCELLENT": 2,
    "CATEGORY_LEADING": 3,
}
REQUIRED_PROFESSIONAL_DIMENSIONS = {
    "audience_and_intent_fit",
    "craft_and_finish",
    "coherence_and_hierarchy",
    "distinctiveness",
    "completeness_and_downstream_usability",
    "silhouette_and_96px_readability",
    "psychology_and_villain_read",
    "production_feasibility_and_trait_clarity",
}
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
EMPTY_SENTINELS = {"none", "n/a", "na", "null", "unknown", "tbd", "todo", "x"}


def is_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def require_text(
    container: dict[str, Any],
    key: str,
    label: str,
    failures: list[str],
    min_length: int = 1,
) -> None:
    value = container.get(key)
    if not is_text(value):
        failures.append(f"{label}.{key} must be nonempty text")
        return
    normalized = value.strip()
    if normalized.lower() in EMPTY_SENTINELS or len(normalized) < min_length:
        failures.append(f"{label}.{key} must contain substantive text of at least {min_length} characters")


def require_sha(value: Any, label: str, failures: list[str]) -> None:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        failures.append(f"{label} must be a 64-character SHA-256")


def require_artifact(value: Any, label: str, expected_media_type: str, failures: list[str]) -> None:
    if not isinstance(value, dict):
        failures.append(f"{label} must be an object")
        return
    require_text(value, "path", label, failures)
    require_sha(value.get("sha256"), f"{label}.sha256", failures)
    if value.get("media_type") != expected_media_type:
        failures.append(f"{label}.media_type must be {expected_media_type}")


def is_blessed(unit: dict[str, Any]) -> bool:
    traits: list[str] = []
    primary = unit.get("art_primary_trait")
    if isinstance(primary, str):
        traits.append(primary)
    secondary = unit.get("secondary_trait_channels")
    if isinstance(secondary, list):
        traits.extend(item for item in secondary if isinstance(item, str))
    return any(item.strip().lower() == "blessed" for item in traits)


def conditional_applicability(unit: dict[str, Any]) -> dict[str, bool]:
    female = unit.get("sex_design_category") == "female"
    horrific = unit.get("deliberately_horrific") is True
    female_non_horror = female and not horrific
    female_frontliner = female and unit.get("is_frontliner") is True
    return {
        "hot_adult_woman": female_non_horror,
        "lean_toned_feminine": female_non_horror,
        "frontline_protection_explained": female_frontliner,
        "deliberate_horror_exception": horrific,
        "blessed_special_gate": is_blessed(unit),
    }


def validate_template(template: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    if template.get("schema_version") != "2.0.0":
        failures.append("schema_version must be 2.0.0")
    if template.get("record_kind") != "unit_art_board_review":
        failures.append("record_kind must be unit_art_board_review")
    if template.get("record_status") != "TEMPLATE":
        failures.append("template record_status must be TEMPLATE")
    if template.get("authority") != "docs/art/unit_art_board_reference_criteria.md":
        failures.append("authority must point to the canonical criteria")
    if template.get("criteria_version") != "2026-07-21-v1":
        failures.append("criteria_version must be 2026-07-21-v1")

    unit = template.get("unit")
    psychology = template.get("psychology")
    evidence = template.get("evidence")
    reviews = template.get("reviews")
    approval = template.get("approval")
    for key, value in {
        "unit": unit,
        "psychology": psychology,
        "evidence": evidence,
        "approval": approval,
    }.items():
        if not isinstance(value, dict):
            failures.append(f"{key} must be an object")
    if not isinstance(reviews, list) or len(reviews) != 3:
        failures.append("reviews must contain exactly three seat templates")
        return failures
    seats = [review.get("seat") for review in reviews if isinstance(review, dict)]
    if seats != ["A", "B", "C"]:
        failures.append("template review seats must be exactly A, B, C in order")
    for index, review in enumerate(reviews):
        if not isinstance(review, dict):
            failures.append(f"reviews[{index}] must be an object")
            continue
        verdicts = review.get("verdicts")
        if not isinstance(verdicts, dict):
            failures.append(f"reviews[{index}].verdicts must be an object")
            continue
        missing = sorted((REQUIRED_VERDICTS | CONDITIONAL_VERDICTS) - set(verdicts))
        if missing:
            failures.append(f"reviews[{index}].verdicts missing keys: {missing}")
        round_one = review.get("independent_round_one_record")
        if not isinstance(round_one, dict) or round_one.get("media_type") != "application/json":
            failures.append(f"reviews[{index}].independent_round_one_record must declare application/json")
        cross = review.get("cross_examination")
        if not isinstance(cross, dict):
            failures.append(f"reviews[{index}].cross_examination must be an object")
        else:
            required_cross = {
                "record_path",
                "record_sha256",
                "record_media_type",
                "verdict",
                "surviving_blockers",
                "outcome",
                "protected_dissent",
            }
            missing_cross = sorted(required_cross - set(cross))
            if missing_cross:
                failures.append(f"reviews[{index}].cross_examination missing keys: {missing_cross}")
            if cross.get("record_media_type") != "application/json":
                failures.append(f"reviews[{index}].cross_examination must declare application/json")
    if isinstance(psychology, dict):
        missing = sorted(PSYCHOLOGY_FIELDS - set(psychology))
        if missing:
            failures.append(f"psychology missing keys: {missing}")
    if isinstance(evidence, dict):
        expected = {
            "silhouette_triptych",
            "selected_full_body_master",
            "derived_face_enlargement",
            "derived_96px_check",
            "vellum_first_comparison",
            "three_nearest_neighbors",
            "roster_comparison_boards",
        }
        missing = sorted(expected - set(evidence))
        if missing:
            failures.append(f"evidence missing keys: {missing}")
        for key in {
            "silhouette_triptych",
            "selected_full_body_master",
            "derived_face_enlargement",
            "derived_96px_check",
            "vellum_first_comparison",
        }:
            artifact = evidence.get(key)
            if not isinstance(artifact, dict) or artifact.get("media_type") != "image/png":
                failures.append(f"evidence.{key} must declare image/png")
    if isinstance(approval, dict) and "user_approval_provenance" not in approval:
        failures.append("approval missing user_approval_provenance")
    return failures


def validate_record(record: dict[str, Any], check_files: bool = False) -> list[str]:
    failures: list[str] = []
    if record.get("schema_version") != "2.0.0":
        failures.append("schema_version must be 2.0.0")
    if record.get("record_kind") != "unit_art_board_review":
        failures.append("record_kind must be unit_art_board_review")
    if record.get("record_status") not in {"BOARD_REVIEWED", "USER_APPROVED"}:
        failures.append("record_status must be BOARD_REVIEWED or USER_APPROVED")
    if record.get("authority") != "docs/art/unit_art_board_reference_criteria.md":
        failures.append("authority must point to the canonical criteria")
    if record.get("criteria_version") != "2026-07-21-v1":
        failures.append("criteria_version must be 2026-07-21-v1")
    require_sha(record.get("criteria_sha256"), "criteria_sha256", failures)
    actual_criteria_sha = hashlib.sha256(CRITERIA_PATH.read_bytes()).hexdigest()
    if str(record.get("criteria_sha256", "")).lower() != actual_criteria_sha:
        failures.append("criteria_sha256 must match the canonical criteria file bytes")
    if not is_text(record.get("board_lineage_id")):
        failures.append("board_lineage_id must be nonempty")

    unit = record.get("unit")
    if not isinstance(unit, dict):
        failures.append("unit must be an object")
        return failures
    for key in {
        "id",
        "name",
        "combat_role",
        "art_primary_trait",
        "gameplay_identity",
        "strongest_preserved_hook",
        "dominant_prop_or_anatomy",
        "supernatural_cost",
    }:
        require_text(unit, key, "unit", failures)
    if not isinstance(unit.get("is_frontliner"), bool):
        failures.append("unit.is_frontliner must be boolean")
    if unit.get("sex_design_category") not in SEX_DESIGN_CATEGORIES:
        failures.append(f"unit.sex_design_category must be one of {sorted(SEX_DESIGN_CATEGORIES)}")
    if unit.get("visual_lane") not in VISUAL_LANES:
        failures.append(f"unit.visual_lane must be one of {sorted(VISUAL_LANES)}")
    if not isinstance(unit.get("deliberately_horrific"), bool):
        failures.append("unit.deliberately_horrific must be boolean")
    if unit.get("protection_logic") not in PROTECTION_LOGIC:
        failures.append(f"unit.protection_logic must be one of {sorted(PROTECTION_LOGIC)}")
    if unit.get("villain_emotion_family") not in EMOTION_FAMILIES:
        failures.append(f"unit.villain_emotion_family must be one of {sorted(EMOTION_FAMILIES)}")
    secondary = unit.get("secondary_trait_channels")
    if not isinstance(secondary, list) or any(not is_text(item) for item in secondary):
        failures.append("unit.secondary_trait_channels must be a list of nonempty trait names")

    female = unit.get("sex_design_category") == "female"
    horrific = unit.get("deliberately_horrific") is True
    lane = unit.get("visual_lane")
    if female and not horrific and lane != "hot_adult_woman":
        failures.append("a non-horrific female unit must use the hot_adult_woman visual lane")
    if lane == "hot_adult_woman" and (not female or horrific):
        failures.append("hot_adult_woman lane requires female design and deliberately_horrific=false")
    if lane in {"deliberately_horrific_humanoid", "monster_alien_creature_horror"} and not horrific:
        failures.append(f"{lane} requires deliberately_horrific=true")
    if horrific and lane not in {"deliberately_horrific_humanoid", "monster_alien_creature_horror"}:
        failures.append("deliberately_horrific=true requires a deliberate horror visual lane")
    if female and unit.get("is_frontliner") is True and unit.get("protection_logic") == "not_applicable":
        failures.append("a female frontliner must have explicit protection_logic")

    psychology = record.get("psychology")
    if not isinstance(psychology, dict):
        failures.append("psychology must be an object")
    else:
        for key in PSYCHOLOGY_FIELDS:
            require_text(psychology, key, "psychology", failures, min_length=20)

    evidence = record.get("evidence")
    master_sha = None
    visual_artifacts: list[tuple[str, dict[str, Any]]] = []
    if not isinstance(evidence, dict):
        failures.append("evidence must be an object")
    else:
        silhouette = evidence.get("silhouette_triptych")
        require_artifact(silhouette, "evidence.silhouette_triptych", "image/png", failures)
        if isinstance(silhouette, dict):
            visual_artifacts.append(("evidence.silhouette_triptych", silhouette))
            if silhouette.get("option_labels") != ["A", "B", "C"]:
                failures.append("silhouette option_labels must be exactly A, B, C")
            if silhouette.get("selected_option") not in {"A", "B", "C"}:
                failures.append("silhouette selected_option must be A, B, or C")
        master = evidence.get("selected_full_body_master")
        require_artifact(master, "evidence.selected_full_body_master", "image/png", failures)
        if isinstance(master, dict):
            visual_artifacts.append(("evidence.selected_full_body_master", master))
            master_sha = master.get("sha256")
        face = evidence.get("derived_face_enlargement")
        require_artifact(face, "evidence.derived_face_enlargement", "image/png", failures)
        if isinstance(face, dict):
            visual_artifacts.append(("evidence.derived_face_enlargement", face))
            if face.get("source_master_sha256") != master_sha:
                failures.append("face enlargement source_master_sha256 must match selected master")
            if face.get("derivation_method") != "crop_and_scale_only":
                failures.append("face enlargement derivation_method must be crop_and_scale_only")
        board = evidence.get("derived_96px_check")
        require_artifact(board, "evidence.derived_96px_check", "image/png", failures)
        if isinstance(board, dict):
            visual_artifacts.append(("evidence.derived_96px_check", board))
            if board.get("source_master_sha256") != master_sha:
                failures.append("96px check source_master_sha256 must match selected master")
            if board.get("derivation_method") != "deterministic_containment_only":
                failures.append("96px derivation_method must be deterministic_containment_only")
            if board.get("width") != 96 or board.get("height") != 96:
                failures.append("derived 96px check must be exactly 96 by 96")
        vellum = evidence.get("vellum_first_comparison")
        require_artifact(vellum, "evidence.vellum_first_comparison", "image/png", failures)
        if isinstance(vellum, dict):
            visual_artifacts.append(("evidence.vellum_first_comparison", vellum))
        neighbors = evidence.get("three_nearest_neighbors")
        if not isinstance(neighbors, list) or len(neighbors) != 3 or any(not is_text(item) for item in neighbors):
            failures.append("evidence.three_nearest_neighbors must contain exactly three unit ids")
        elif len(set(neighbors)) != 3:
            failures.append("evidence.three_nearest_neighbors must be unique")
        boards = evidence.get("roster_comparison_boards")
        if not isinstance(boards, list) or not boards:
            failures.append("evidence.roster_comparison_boards must contain at least one artifact")
        else:
            for index, artifact in enumerate(boards):
                require_artifact(artifact, f"evidence.roster_comparison_boards[{index}]", "image/png", failures)
                if isinstance(artifact, dict):
                    visual_artifacts.append((f"evidence.roster_comparison_boards[{index}]", artifact))
        visual_paths = [artifact.get("path") for _, artifact in visual_artifacts]
        visual_hashes = [artifact.get("sha256") for _, artifact in visual_artifacts]
        if len(visual_paths) != len(set(visual_paths)):
            failures.append("visual evidence artifacts must use distinct paths")
        if len(visual_hashes) != len(set(visual_hashes)):
            failures.append("visual evidence artifacts must have distinct file hashes")

    reviews = record.get("reviews")
    review_gate_results: list[bool] = []
    review_ready_results: list[bool] = []
    review_professional_results: list[bool] = []
    all_review_blockers: list[Any] = []
    review_artifacts: list[tuple[str, dict[str, Any]]] = []
    applicability = conditional_applicability(unit)
    if not isinstance(reviews, list) or len(reviews) != 3:
        failures.append("reviews must contain exactly three independent seats")
    else:
        seats = [review.get("seat") if isinstance(review, dict) else None for review in reviews]
        if sorted(seats) != ["A", "B", "C"]:
            failures.append("review seats must be exactly A, B, and C")
        reviewer_ids = [review.get("reviewer_id") if isinstance(review, dict) else None for review in reviews]
        if any(not is_text(item) for item in reviewer_ids) or len(set(reviewer_ids)) != 3:
            failures.append("reviews require three unique nonempty reviewer_id values")
        for index, review in enumerate(reviews):
            label = f"reviews[{index}]"
            if not isinstance(review, dict):
                failures.append(f"{label} must be an object")
                continue
            round_one = review.get("independent_round_one_record")
            require_artifact(round_one, f"{label}.independent_round_one_record", "application/json", failures)
            if isinstance(round_one, dict):
                review_artifacts.append((f"{label}.independent_round_one_record", round_one))
            verdicts = review.get("verdicts")
            gates_pass = True
            if not isinstance(verdicts, dict):
                failures.append(f"{label}.verdicts must be an object")
                gates_pass = False
            else:
                missing = sorted((REQUIRED_VERDICTS | CONDITIONAL_VERDICTS) - set(verdicts))
                if missing:
                    failures.append(f"{label}.verdicts missing keys: {missing}")
                    gates_pass = False
                for key in REQUIRED_VERDICTS:
                    if verdicts.get(key) not in {"PASS", "FAIL"}:
                        failures.append(f"{label}.verdicts.{key} must be PASS or FAIL")
                        gates_pass = False
                    elif verdicts.get(key) != "PASS":
                        gates_pass = False
                for key, applies in applicability.items():
                    value = verdicts.get(key)
                    if applies:
                        if value not in {"PASS", "FAIL"}:
                            failures.append(f"{label}.verdicts.{key} must be PASS or FAIL when applicable")
                            gates_pass = False
                        elif value != "PASS":
                            gates_pass = False
                    elif value != "NOT_APPLICABLE":
                        failures.append(f"{label}.verdicts.{key} must be NOT_APPLICABLE for this unit")
                        gates_pass = False
            face_evidence = review.get("visible_face_evidence")
            if not isinstance(face_evidence, dict):
                failures.append(f"{label}.visible_face_evidence must be an object")
            else:
                for key in FACE_EVIDENCE_FIELDS:
                    require_text(face_evidence, key, f"{label}.visible_face_evidence", failures, min_length=20)
            professional = review.get("professional_standard")
            professional_pass = False
            if not isinstance(professional, dict):
                failures.append(f"{label}.professional_standard must be an object")
            else:
                band = professional.get("band")
                confidence = professional.get("evidence_confidence")
                if band not in PROFESSIONAL_BANDS:
                    failures.append(f"{label}.professional_standard.band is invalid")
                if confidence not in {"HIGH", "MEDIUM", "LOW"}:
                    failures.append(f"{label}.professional_standard.evidence_confidence is invalid")
                for key in {"benchmark_comparison", "rejection_case", "excellence_gap"}:
                    require_text(professional, key, f"{label}.professional_standard", failures, min_length=40)
                dimensions = professional.get("critical_dimensions")
                dimension_bands: list[int] = []
                if not isinstance(dimensions, list) or len(dimensions) != len(REQUIRED_PROFESSIONAL_DIMENSIONS):
                    failures.append(f"{label}.professional_standard.critical_dimensions must contain the frozen dimension set")
                else:
                    dimension_names: list[Any] = []
                    for dim_index, dimension in enumerate(dimensions):
                        dim_label = f"{label}.professional_standard.critical_dimensions[{dim_index}]"
                        if not isinstance(dimension, dict):
                            failures.append(f"{dim_label} must be an object")
                            continue
                        dimension_names.append(dimension.get("dimension"))
                        if dimension.get("critical") is not True:
                            failures.append(f"{dim_label}.critical must be true")
                        dim_band = dimension.get("band")
                        if dim_band not in PROFESSIONAL_BANDS:
                            failures.append(f"{dim_label}.band is invalid")
                        else:
                            dimension_bands.append(PROFESSIONAL_BANDS[dim_band])
                        require_text(dimension, "evidence", dim_label, failures, min_length=40)
                        require_text(dimension, "benchmark_comparison", dim_label, failures, min_length=40)
                    if set(dimension_names) != REQUIRED_PROFESSIONAL_DIMENSIONS:
                        failures.append(f"{label}.professional_standard dimensions do not match the frozen set")
                if band in PROFESSIONAL_BANDS and dimension_bands:
                    expected_band_value = min(dimension_bands)
                    if PROFESSIONAL_BANDS[band] != expected_band_value:
                        failures.append(f"{label}.professional_standard.band must equal the lowest critical dimension")
                    professional_pass = expected_band_value >= PROFESSIONAL_BANDS["PROFESSIONAL"] and confidence in {"HIGH", "MEDIUM"}
            blockers = review.get("blockers")
            if not isinstance(blockers, list):
                failures.append(f"{label}.blockers must be a list")
                blockers = ["INVALID"]
            elif any(not is_text(item) for item in blockers):
                failures.append(f"{label}.blockers entries must be nonempty text")
            cross = review.get("cross_examination")
            cross_clear = False
            surviving_cross_blockers: list[Any] = []
            if not isinstance(cross, dict):
                failures.append(f"{label}.cross_examination must be an object")
            else:
                require_text(cross, "record_path", f"{label}.cross_examination", failures)
                require_sha(cross.get("record_sha256"), f"{label}.cross_examination.record_sha256", failures)
                if cross.get("record_media_type") != "application/json":
                    failures.append(f"{label}.cross_examination.record_media_type must be application/json")
                cross_artifact = {
                    "path": cross.get("record_path"),
                    "sha256": cross.get("record_sha256"),
                    "media_type": cross.get("record_media_type"),
                }
                review_artifacts.append((f"{label}.cross_examination", cross_artifact))
                if cross.get("verdict") not in {"CLEARED", "BLOCKER_RETAINED"}:
                    failures.append(f"{label}.cross_examination.verdict is invalid")
                surviving = cross.get("surviving_blockers")
                if not isinstance(surviving, list) or any(not is_text(item) for item in surviving):
                    failures.append(f"{label}.cross_examination.surviving_blockers must be a list of blocker ids")
                    surviving = ["INVALID"]
                if cross.get("verdict") == "CLEARED" and surviving:
                    failures.append(f"{label}.cross_examination CLEARED cannot retain blockers")
                if cross.get("verdict") == "BLOCKER_RETAINED" and not surviving:
                    failures.append(f"{label}.cross_examination BLOCKER_RETAINED requires surviving blockers")
                cross_clear = cross.get("verdict") == "CLEARED" and not surviving
                surviving_cross_blockers = surviving
                require_text(cross, "outcome", f"{label}.cross_examination", failures, min_length=20)
                require_text(cross, "protected_dissent", f"{label}.cross_examination", failures, min_length=4)
            all_review_blockers.extend(blockers)
            all_review_blockers.extend(surviving_cross_blockers)
            expected_readiness = "READY" if gates_pass and professional_pass and not blockers and cross_clear else "NOT_READY"
            if review.get("readiness") != expected_readiness:
                failures.append(f"{label}.readiness must be {expected_readiness} from gates, professional band, blockers, and cross-examination")
            review_gate_results.append(gates_pass)
            review_ready_results.append(expected_readiness == "READY")
            review_professional_results.append(professional_pass)
        review_paths = [artifact.get("path") for _, artifact in review_artifacts]
        review_hashes = [artifact.get("sha256") for _, artifact in review_artifacts]
        if len(review_paths) != len(set(review_paths)):
            failures.append("round-one and cross-examination records must use distinct paths for all three seats")
        if len(review_hashes) != len(set(review_hashes)):
            failures.append("round-one and cross-examination records must have distinct file hashes for all three seats")

    approval = record.get("approval")
    if not isinstance(approval, dict):
        failures.append("approval must be an object")
    else:
        computed_gates = len(review_gate_results) == 3 and all(review_gate_results)
        computed_ready = len(review_ready_results) == 3 and all(review_ready_results)
        computed_professional = len(review_professional_results) == 3 and all(review_professional_results)
        ledger = approval.get("blocker_ledger")
        if not isinstance(ledger, list) or any(not is_text(item) for item in ledger):
            failures.append("approval.blocker_ledger must be a list of nonempty blocker ids")
            ledger = ["INVALID"]
        expected_board_status = (
            "READY"
            if computed_gates and computed_ready and computed_professional and not ledger and not all_review_blockers
            else "NOT_READY"
        )
        expected_values = {
            "derived_all_required_gates_pass": computed_gates,
            "derived_unanimous_ready": computed_ready,
            "derived_unanimous_professional": computed_professional,
        }
        for key, expected in expected_values.items():
            if approval.get(key) is not expected:
                failures.append(f"approval.{key} must be derived as {expected}")
        if approval.get("board_status") != expected_board_status:
            failures.append(f"approval.board_status must be {expected_board_status}")
        user_approved = approval.get("user_approved")
        provenance = approval.get("user_approval_provenance")
        if not isinstance(user_approved, bool):
            failures.append("approval.user_approved must be boolean")
        if record.get("record_status") == "USER_APPROVED":
            if expected_board_status != "READY":
                failures.append("USER_APPROVED record requires READY Board status")
            if user_approved is not True:
                failures.append("USER_APPROVED record requires approval.user_approved=true")
            if not isinstance(provenance, dict):
                failures.append("USER_APPROVED record requires structured user_approval_provenance")
            else:
                if not isinstance(provenance.get("thread_id"), str) or not UUID_RE.fullmatch(provenance["thread_id"]):
                    failures.append("user approval thread_id must be a UUID")
                require_text(provenance, "turn_id", "approval.user_approval_provenance", failures, min_length=8)
                require_text(provenance, "approved_at_utc", "approval.user_approval_provenance", failures, min_length=20)
                require_sha(provenance.get("approval_text_sha256"), "approval.user_approval_provenance.approval_text_sha256", failures)
        else:
            if user_approved is not False:
                failures.append("BOARD_REVIEWED record requires approval.user_approved=false")
            if provenance is not None:
                failures.append("BOARD_REVIEWED record requires null user_approval_provenance")

    if check_files:
        failures.extend(validate_files(record))
    return failures


def validate_files(record: dict[str, Any]) -> list[str]:
    failures: list[str] = []

    def check_artifact(artifact: Any, label: str, expected_dimensions: tuple[int, int] | None = None) -> None:
        if not isinstance(artifact, dict) or not is_text(artifact.get("path")):
            return
        path = ROOT / artifact["path"]
        if not path.exists() or not path.is_file():
            failures.append(f"{label}.path does not exist: {artifact['path']}")
            return
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest.lower() != str(artifact.get("sha256", "")).lower():
            failures.append(f"{label}.sha256 does not match file bytes")
        media_type = artifact.get("media_type")
        if media_type == "image/png":
            if path.suffix.lower() != ".png" or len(data) < 24 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
                failures.append(f"{label} must be a valid PNG image")
                return
            width, height = struct.unpack(">II", data[16:24])
            if width <= 0 or height <= 0:
                failures.append(f"{label} PNG dimensions must be positive")
            if expected_dimensions is not None and (width, height) != expected_dimensions:
                failures.append(f"{label} image dimensions must be {expected_dimensions[0]}x{expected_dimensions[1]}")
        elif media_type == "application/json":
            if path.suffix.lower() != ".json":
                failures.append(f"{label} must use a .json review record")
                return
            try:
                parsed = json.loads(data.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                failures.append(f"{label} must contain valid UTF-8 JSON")
                return
            if not isinstance(parsed, (dict, list)) or not parsed:
                failures.append(f"{label} JSON review record must be nonempty")
        else:
            failures.append(f"{label} has unsupported media_type: {media_type}")

    evidence = record.get("evidence", {})
    if isinstance(evidence, dict):
        for key in {
            "silhouette_triptych",
            "selected_full_body_master",
            "derived_face_enlargement",
            "derived_96px_check",
            "vellum_first_comparison",
        }:
            dimensions = (96, 96) if key == "derived_96px_check" else None
            check_artifact(evidence.get(key), f"evidence.{key}", dimensions)
        boards = evidence.get("roster_comparison_boards", [])
        if isinstance(boards, list):
            for index, artifact in enumerate(boards):
                check_artifact(artifact, f"evidence.roster_comparison_boards[{index}]")
    reviews = record.get("reviews", [])
    if isinstance(reviews, list):
        for index, review in enumerate(reviews):
            if not isinstance(review, dict):
                continue
            check_artifact(review.get("independent_round_one_record"), f"reviews[{index}].independent_round_one_record")
            cross = review.get("cross_examination")
            if isinstance(cross, dict):
                check_artifact(
                    {
                        "path": cross.get("record_path"),
                        "sha256": cross.get("record_sha256"),
                        "media_type": cross.get("record_media_type"),
                    },
                    f"reviews[{index}].cross_examination",
                )
    return failures


def build_valid_record(template: dict[str, Any]) -> dict[str, Any]:
    record = copy.deepcopy(template)
    def token(label: str) -> str:
        return hashlib.sha256(label.encode("utf-8")).hexdigest()

    record["record_status"] = "BOARD_REVIEWED"
    record["criteria_sha256"] = hashlib.sha256(CRITERIA_PATH.read_bytes()).hexdigest()
    record["board_lineage_id"] = "self-test-lineage"
    record["unit"].update(
        {
            "id": "test_unit",
            "name": "Test Unit",
            "combat_role": "Tank",
            "is_frontliner": True,
            "sex_design_category": "female",
            "visual_lane": "hot_adult_woman",
            "deliberately_horrific": False,
            "art_primary_trait": "Blessed",
            "secondary_trait_channels": ["Titan"],
            "gameplay_identity": "Absorbs damage for nearby allies.",
            "strongest_preserved_hook": "Carries redirected wounds.",
            "dominant_prop_or_anatomy": "Fused penitential yoke.",
            "protection_logic": "protective_skin",
            "supernatural_cost": "Redirected wounds calcify visibly.",
            "villain_emotion_family": "dissociated_stone_cold",
        }
    )
    for key in PSYCHOLOGY_FIELDS:
        record["psychology"][key] = f"Specific {key.replace('_', ' ')} evidence."
    evidence = record["evidence"]
    for key in {
        "silhouette_triptych",
        "selected_full_body_master",
        "derived_face_enlargement",
        "derived_96px_check",
        "vellum_first_comparison",
    }:
        evidence[key]["path"] = f"proof/{key}.png"
        evidence[key]["sha256"] = token(key)
    evidence["silhouette_triptych"]["selected_option"] = "A"
    master_token = evidence["selected_full_body_master"]["sha256"]
    evidence["derived_face_enlargement"]["source_master_sha256"] = master_token
    evidence["derived_96px_check"]["source_master_sha256"] = master_token
    evidence["three_nearest_neighbors"] = ["neighbor_a", "neighbor_b", "neighbor_c"]
    evidence["roster_comparison_boards"] = [
        {"path": "proof/roster.png", "sha256": token("roster"), "media_type": "image/png"}
    ]
    applicability = conditional_applicability(record["unit"])
    for index, review in enumerate(record["reviews"]):
        review["reviewer_id"] = f"reviewer-{index}"
        review["independent_round_one_record"] = {
            "path": f"proof/round1-{index}.json",
            "sha256": token(f"round1-{index}"),
            "media_type": "application/json",
        }
        for key in REQUIRED_VERDICTS:
            review["verdicts"][key] = "PASS"
        for key, applies in applicability.items():
            review["verdicts"][key] = "PASS" if applies else "NOT_APPLICABLE"
        for key in FACE_EVIDENCE_FIELDS:
            review["visible_face_evidence"][key] = f"Visible {key.replace('_', ' ')} cue is specific and observable."
        dimensions = []
        for dimension in sorted(REQUIRED_PROFESSIONAL_DIMENSIONS):
            dimensions.append(
                {
                    "dimension": dimension,
                    "critical": True,
                    "band": "PROFESSIONAL",
                    "evidence": f"Direct evidence for {dimension} clears the declared phase standard.",
                    "benchmark_comparison": f"Comparison for {dimension} meets the frozen professional benchmark.",
                }
            )
        review["professional_standard"].update(
            {
                "band": "PROFESSIONAL",
                "evidence_confidence": "HIGH",
                "benchmark_comparison": "The full unit record meets the frozen professional comparisons for this phase.",
                "critical_dimensions": dimensions,
                "rejection_case": "The strongest honest rejection case was tested against direct evidence and refuted.",
                "excellence_gap": "Further refinement could exceed the professional target without hiding any current blocker.",
            }
        )
        review["readiness"] = "READY"
        review["cross_examination"].update(
            {
                "record_path": f"proof/cross-{index}.json",
                "record_sha256": token(f"cross-{index}"),
                "record_media_type": "application/json",
                "verdict": "CLEARED",
                "surviving_blockers": [],
                "outcome": "READY retained after peer challenge.",
                "protected_dissent": "NO_PROTECTED_DISSENT",
            }
        )
    record["approval"].update(
        {
            "derived_all_required_gates_pass": True,
            "derived_unanimous_ready": True,
            "derived_unanimous_professional": True,
            "blocker_ledger": [],
            "board_status": "READY",
            "user_approved": False,
            "user_approval_provenance": None,
        }
    )
    return record


def run_self_test(template: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    valid = build_valid_record(template)
    valid_failures = validate_record(valid)
    if valid_failures:
        failures.append(f"valid control failed: {valid_failures}")

    honest_failure = copy.deepcopy(valid)
    honest_failure["reviews"][0]["verdicts"]["hot_adult_woman"] = "FAIL"
    honest_failure["reviews"][0]["readiness"] = "NOT_READY"
    honest_failure["approval"]["derived_all_required_gates_pass"] = False
    honest_failure["approval"]["derived_unanimous_ready"] = False
    honest_failure["approval"]["board_status"] = "NOT_READY"
    honest_failures = validate_record(honest_failure)
    if honest_failures:
        failures.append(f"honest conditional FAIL control was rejected: {honest_failures}")

    mutations: list[tuple[str, Any, bool]] = []

    failed_gate = copy.deepcopy(valid)
    failed_gate["reviews"][0]["verdicts"]["peak_age_fighter"] = "FAIL"
    mutations.append(("failed gate with READY", failed_gate, False))

    empty_psychology = copy.deepcopy(valid)
    empty_psychology["psychology"]["core_wound"] = ""
    mutations.append(("empty psychology", empty_psychology, False))

    bypassed_female_gate = copy.deepcopy(valid)
    bypassed_female_gate["reviews"][0]["verdicts"]["hot_adult_woman"] = "NOT_APPLICABLE"
    mutations.append(("female gate bypass", bypassed_female_gate, False))

    bad_provenance = copy.deepcopy(valid)
    bad_provenance["evidence"]["derived_face_enlargement"]["source_master_sha256"] = "b" * 64
    mutations.append(("derivative provenance mismatch", bad_provenance, False))

    duplicate_reviewer = copy.deepcopy(valid)
    duplicate_reviewer["reviews"][1]["reviewer_id"] = duplicate_reviewer["reviews"][0]["reviewer_id"]
    mutations.append(("duplicate reviewer", duplicate_reviewer, False))

    false_aggregate = copy.deepcopy(valid)
    false_aggregate["approval"]["derived_unanimous_ready"] = False
    mutations.append(("false aggregate", false_aggregate, False))

    invalid_lane = copy.deepcopy(valid)
    invalid_lane["unit"]["visual_lane"] = "generic_pretty_woman"
    mutations.append(("invalid lane enum", invalid_lane, False))

    horror_lane_mismatch = copy.deepcopy(valid)
    horror_lane_mismatch["unit"]["deliberately_horrific"] = True
    for review in horror_lane_mismatch["reviews"]:
        review["verdicts"]["hot_adult_woman"] = "NOT_APPLICABLE"
        review["verdicts"]["lean_toned_feminine"] = "NOT_APPLICABLE"
        review["verdicts"]["deliberate_horror_exception"] = "PASS"
    mutations.append(("horror flag outside horror lane", horror_lane_mismatch, False))

    unresolved_cross = copy.deepcopy(valid)
    unresolved_cross["reviews"][0]["cross_examination"]["verdict"] = "BLOCKER_RETAINED"
    unresolved_cross["reviews"][0]["cross_examination"]["surviving_blockers"] = ["TEST-BLOCKER"]
    mutations.append(("unresolved cross-examination with READY", unresolved_cross, False))

    wrong_criteria = copy.deepcopy(valid)
    wrong_criteria["criteria_sha256"] = "b" * 64
    mutations.append(("wrong criteria hash", wrong_criteria, False))

    shared_review_evidence = copy.deepcopy(valid)
    shared_review_evidence["reviews"][1]["independent_round_one_record"] = copy.deepcopy(
        shared_review_evidence["reviews"][0]["independent_round_one_record"]
    )
    mutations.append(("shared reviewer evidence", shared_review_evidence, False))

    placeholder_professional = copy.deepcopy(valid)
    placeholder_professional["reviews"][0]["professional_standard"]["benchmark_comparison"] = "x"
    mutations.append(("placeholder professional evidence", placeholder_professional, False))

    low_confidence_ready = copy.deepcopy(valid)
    low_confidence_ready["reviews"][0]["professional_standard"]["evidence_confidence"] = "LOW"
    mutations.append(("low-confidence READY", low_confidence_ready, False))

    fake_user_approval = copy.deepcopy(valid)
    fake_user_approval["record_status"] = "USER_APPROVED"
    fake_user_approval["approval"]["user_approved"] = True
    fake_user_approval["approval"]["user_approval_provenance"] = "NONE"
    mutations.append(("unstructured user approval", fake_user_approval, False))

    for name, mutated, check_files in mutations:
        if not validate_record(mutated, check_files):
            failures.append(f"negative control unexpectedly passed: {name}")

    failures.extend(run_file_evidence_self_test(valid))
    return failures


def png_bytes(width: int, height: int, rgb: tuple[int, int, int]) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    row = b"\x00" + bytes(rgb) * width
    raw = row * height
    return PNG_SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(
        b"IDAT", zlib.compress(raw)
    ) + chunk(b"IEND", b"")


def run_file_evidence_self_test(valid: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    with tempfile.TemporaryDirectory(prefix="unit-art-board-") as temp_text:
        temp = Path(temp_text)
        record = copy.deepcopy(valid)
        evidence = record["evidence"]
        visual_keys = [
            "silhouette_triptych",
            "selected_full_body_master",
            "derived_face_enlargement",
            "derived_96px_check",
            "vellum_first_comparison",
        ]
        for index, key in enumerate(visual_keys):
            dimensions = (96, 96) if key == "derived_96px_check" else (128 + index, 160 + index)
            path = temp / f"{key}.png"
            path.write_bytes(png_bytes(dimensions[0], dimensions[1], ((index + 1) * 20, 40, 60)))
            evidence[key]["path"] = str(path)
            evidence[key]["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        master_sha = evidence["selected_full_body_master"]["sha256"]
        evidence["derived_face_enlargement"]["source_master_sha256"] = master_sha
        evidence["derived_96px_check"]["source_master_sha256"] = master_sha
        roster_path = temp / "roster.png"
        roster_path.write_bytes(png_bytes(256, 256, (180, 70, 30)))
        evidence["roster_comparison_boards"] = [
            {"path": str(roster_path), "sha256": hashlib.sha256(roster_path.read_bytes()).hexdigest(), "media_type": "image/png"}
        ]
        for index, review in enumerate(record["reviews"]):
            round_path = temp / f"round-{index}.json"
            round_path.write_text(json.dumps({"seat": index, "round": "independent", "evidence": f"review-{index}"}), encoding="utf-8")
            review["independent_round_one_record"] = {
                "path": str(round_path),
                "sha256": hashlib.sha256(round_path.read_bytes()).hexdigest(),
                "media_type": "application/json",
            }
            cross_path = temp / f"cross-{index}.json"
            cross_path.write_text(json.dumps({"seat": index, "round": "cross", "evidence": f"challenge-{index}"}), encoding="utf-8")
            review["cross_examination"]["record_path"] = str(cross_path)
            review["cross_examination"]["record_sha256"] = hashlib.sha256(cross_path.read_bytes()).hexdigest()
        valid_file_failures = validate_record(record, check_files=True)
        if valid_file_failures:
            failures.append(f"valid file-evidence control failed: {valid_file_failures}")

        nonvisual = copy.deepcopy(record)
        nonvisual_path = CRITERIA_PATH
        nonvisual_sha = hashlib.sha256(nonvisual_path.read_bytes()).hexdigest()
        for key in visual_keys:
            nonvisual["evidence"][key]["path"] = str(nonvisual_path)
            nonvisual["evidence"][key]["sha256"] = nonvisual_sha
        nonvisual["evidence"]["derived_face_enlargement"]["source_master_sha256"] = nonvisual_sha
        nonvisual["evidence"]["derived_96px_check"]["source_master_sha256"] = nonvisual_sha
        nonvisual["evidence"]["roster_comparison_boards"] = [
            {"path": str(nonvisual_path), "sha256": nonvisual_sha, "media_type": "image/png"}
        ]
        if not validate_record(nonvisual, check_files=True):
            failures.append("negative control unexpectedly passed: nonvisual files as visual evidence")
    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate Gamble Battle unit-art Board templates and completed records.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--template", type=Path, help="Validate the canonical blank template structure.")
    group.add_argument("--record", type=Path, help="Validate a completed Board record semantically.")
    parser.add_argument("--self-test", action="store_true", help="Run valid and adversarial in-memory controls.")
    parser.add_argument("--check-files", action="store_true", help="Verify referenced file existence and SHA-256 bytes.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    path = args.template if args.template is not None else args.record
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: cannot read valid JSON from {path}: {exc}")
        return 1
    failures = validate_template(data) if args.template is not None else validate_record(data, args.check_files)
    if args.self_test:
        template = data if args.template is not None else json.loads(DEFAULT_TEMPLATE.read_text(encoding="utf-8"))
        failures.extend(run_self_test(template))
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1
    mode = "template" if args.template is not None else "record"
    print(f"PASS: unit-art Board {mode} validation")
    if args.self_test:
        print("PASS: semantic negative controls")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
