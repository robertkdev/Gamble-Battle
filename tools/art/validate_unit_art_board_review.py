from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TEMPLATE = ROOT / "docs" / "art" / "unit_art_board_review_template.json"

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
    "BELOW_PROFESSIONAL": 0,
    "PROFESSIONAL": 1,
    "EXCELLENT": 2,
    "CATEGORY_LEADING": 3,
}
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")


def is_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def require_text(container: dict[str, Any], key: str, label: str, failures: list[str]) -> None:
    if not is_text(container.get(key)):
        failures.append(f"{label}.{key} must be nonempty text")


def require_sha(value: Any, label: str, failures: list[str]) -> None:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        failures.append(f"{label} must be a 64-character SHA-256")


def require_artifact(value: Any, label: str, failures: list[str]) -> None:
    if not isinstance(value, dict):
        failures.append(f"{label} must be an object")
        return
    require_text(value, "path", label, failures)
    require_sha(value.get("sha256"), f"{label}.sha256", failures)


def is_blessed(unit: dict[str, Any]) -> bool:
    traits: list[str] = []
    primary = unit.get("art_primary_trait")
    if isinstance(primary, str):
        traits.append(primary)
    secondary = unit.get("secondary_trait_channels")
    if isinstance(secondary, list):
        traits.extend(item for item in secondary if isinstance(item, str))
    return any(item.strip().lower() == "blessed" for item in traits)


def expected_conditional_verdicts(unit: dict[str, Any]) -> dict[str, str]:
    female = unit.get("sex_design_category") == "female"
    horrific = unit.get("deliberately_horrific") is True
    female_non_horror = female and not horrific
    female_frontliner = female and unit.get("is_frontliner") is True
    return {
        "hot_adult_woman": "PASS" if female_non_horror else "NOT_APPLICABLE",
        "lean_toned_feminine": "PASS" if female_non_horror else "NOT_APPLICABLE",
        "frontline_protection_explained": "PASS" if female_frontliner else "NOT_APPLICABLE",
        "deliberate_horror_exception": "PASS" if horrific else "NOT_APPLICABLE",
        "blessed_special_gate": "PASS" if is_blessed(unit) else "NOT_APPLICABLE",
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
    if female and unit.get("is_frontliner") is True and unit.get("protection_logic") == "not_applicable":
        failures.append("a female frontliner must have explicit protection_logic")

    psychology = record.get("psychology")
    if not isinstance(psychology, dict):
        failures.append("psychology must be an object")
    else:
        for key in PSYCHOLOGY_FIELDS:
            require_text(psychology, key, "psychology", failures)

    evidence = record.get("evidence")
    master_sha = None
    if not isinstance(evidence, dict):
        failures.append("evidence must be an object")
    else:
        silhouette = evidence.get("silhouette_triptych")
        require_artifact(silhouette, "evidence.silhouette_triptych", failures)
        if isinstance(silhouette, dict):
            if silhouette.get("option_labels") != ["A", "B", "C"]:
                failures.append("silhouette option_labels must be exactly A, B, C")
            if silhouette.get("selected_option") not in {"A", "B", "C"}:
                failures.append("silhouette selected_option must be A, B, or C")
        master = evidence.get("selected_full_body_master")
        require_artifact(master, "evidence.selected_full_body_master", failures)
        if isinstance(master, dict):
            master_sha = master.get("sha256")
        face = evidence.get("derived_face_enlargement")
        require_artifact(face, "evidence.derived_face_enlargement", failures)
        if isinstance(face, dict):
            if face.get("source_master_sha256") != master_sha:
                failures.append("face enlargement source_master_sha256 must match selected master")
            if face.get("derivation_method") != "crop_and_scale_only":
                failures.append("face enlargement derivation_method must be crop_and_scale_only")
        board = evidence.get("derived_96px_check")
        require_artifact(board, "evidence.derived_96px_check", failures)
        if isinstance(board, dict):
            if board.get("source_master_sha256") != master_sha:
                failures.append("96px check source_master_sha256 must match selected master")
            if board.get("derivation_method") != "deterministic_containment_only":
                failures.append("96px derivation_method must be deterministic_containment_only")
            if board.get("width") != 96 or board.get("height") != 96:
                failures.append("derived 96px check must be exactly 96 by 96")
        require_artifact(evidence.get("vellum_first_comparison"), "evidence.vellum_first_comparison", failures)
        neighbors = evidence.get("three_nearest_neighbors")
        if not isinstance(neighbors, list) or len(neighbors) != 3 or any(not is_text(item) for item in neighbors):
            failures.append("evidence.three_nearest_neighbors must contain exactly three unit ids")
        boards = evidence.get("roster_comparison_boards")
        if not isinstance(boards, list) or not boards:
            failures.append("evidence.roster_comparison_boards must contain at least one artifact")
        else:
            for index, artifact in enumerate(boards):
                require_artifact(artifact, f"evidence.roster_comparison_boards[{index}]", failures)

    reviews = record.get("reviews")
    review_gate_results: list[bool] = []
    review_ready_results: list[bool] = []
    review_professional_results: list[bool] = []
    all_review_blockers: list[Any] = []
    expected_conditional = expected_conditional_verdicts(unit)
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
            require_artifact(review.get("independent_round_one_record"), f"{label}.independent_round_one_record", failures)
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
                for key, expected in expected_conditional.items():
                    if verdicts.get(key) != expected:
                        failures.append(f"{label}.verdicts.{key} must be {expected} for this unit")
                        gates_pass = False
            face_evidence = review.get("visible_face_evidence")
            if not isinstance(face_evidence, dict):
                failures.append(f"{label}.visible_face_evidence must be an object")
            else:
                for key in FACE_EVIDENCE_FIELDS:
                    require_text(face_evidence, key, f"{label}.visible_face_evidence", failures)
            professional = review.get("professional_standard")
            professional_pass = False
            if not isinstance(professional, dict):
                failures.append(f"{label}.professional_standard must be an object")
            else:
                band = professional.get("band")
                if band not in PROFESSIONAL_BANDS:
                    failures.append(f"{label}.professional_standard.band is invalid")
                else:
                    professional_pass = PROFESSIONAL_BANDS[band] >= PROFESSIONAL_BANDS["PROFESSIONAL"]
                if professional.get("evidence_confidence") not in {"HIGH", "MEDIUM", "LOW"}:
                    failures.append(f"{label}.professional_standard.evidence_confidence is invalid")
                for key in {"benchmark_comparison", "rejection_case", "excellence_gap"}:
                    require_text(professional, key, f"{label}.professional_standard", failures)
                dimensions = professional.get("critical_dimensions")
                if not isinstance(dimensions, list) or not dimensions or any(not is_text(item) for item in dimensions):
                    failures.append(f"{label}.professional_standard.critical_dimensions must be nonempty")
            blockers = review.get("blockers")
            if not isinstance(blockers, list):
                failures.append(f"{label}.blockers must be a list")
                blockers = ["INVALID"]
            elif any(not is_text(item) for item in blockers):
                failures.append(f"{label}.blockers entries must be nonempty text")
            all_review_blockers.extend(blockers)
            expected_readiness = "READY" if gates_pass and professional_pass and not blockers else "NOT_READY"
            if review.get("readiness") != expected_readiness:
                failures.append(f"{label}.readiness must be {expected_readiness} from gates, professional band, and blockers")
            cross = review.get("cross_examination")
            if not isinstance(cross, dict):
                failures.append(f"{label}.cross_examination must be an object")
            else:
                require_text(cross, "record_path", f"{label}.cross_examination", failures)
                require_sha(cross.get("record_sha256"), f"{label}.cross_examination.record_sha256", failures)
                require_text(cross, "outcome", f"{label}.cross_examination", failures)
                require_text(cross, "protected_dissent", f"{label}.cross_examination", failures)
            review_gate_results.append(gates_pass)
            review_ready_results.append(expected_readiness == "READY")
            review_professional_results.append(professional_pass)

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
        if not isinstance(user_approved, bool):
            failures.append("approval.user_approved must be boolean")
        if record.get("record_status") == "USER_APPROVED":
            if expected_board_status != "READY":
                failures.append("USER_APPROVED record requires READY Board status")
            if user_approved is not True:
                failures.append("USER_APPROVED record requires approval.user_approved=true")
            require_text(approval, "user_approval_locator", "approval", failures)
        elif user_approved is not False:
            failures.append("BOARD_REVIEWED record requires approval.user_approved=false")

    if check_files:
        failures.extend(validate_files(record))
    return failures


def validate_files(record: dict[str, Any]) -> list[str]:
    failures: list[str] = []

    def check_artifact(artifact: Any, label: str) -> None:
        if not isinstance(artifact, dict) or not is_text(artifact.get("path")):
            return
        path = ROOT / artifact["path"]
        if not path.exists() or not path.is_file():
            failures.append(f"{label}.path does not exist: {artifact['path']}")
            return
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest.lower() != str(artifact.get("sha256", "")).lower():
            failures.append(f"{label}.sha256 does not match file bytes")

    evidence = record.get("evidence", {})
    if isinstance(evidence, dict):
        for key in {
            "silhouette_triptych",
            "selected_full_body_master",
            "derived_face_enlargement",
            "derived_96px_check",
            "vellum_first_comparison",
        }:
            check_artifact(evidence.get(key), f"evidence.{key}")
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
                    {"path": cross.get("record_path"), "sha256": cross.get("record_sha256")},
                    f"reviews[{index}].cross_examination",
                )
    return failures


def build_valid_record(template: dict[str, Any]) -> dict[str, Any]:
    record = copy.deepcopy(template)
    token = "a" * 64
    record["record_status"] = "BOARD_REVIEWED"
    record["criteria_sha256"] = token
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
        evidence[key]["sha256"] = token
    evidence["silhouette_triptych"]["selected_option"] = "A"
    evidence["derived_face_enlargement"]["source_master_sha256"] = token
    evidence["derived_96px_check"]["source_master_sha256"] = token
    evidence["three_nearest_neighbors"] = ["neighbor_a", "neighbor_b", "neighbor_c"]
    evidence["roster_comparison_boards"] = [{"path": "proof/roster.png", "sha256": token}]
    expected = expected_conditional_verdicts(record["unit"])
    for index, review in enumerate(record["reviews"]):
        review["reviewer_id"] = f"reviewer-{index}"
        review["independent_round_one_record"] = {"path": f"proof/round1-{index}.json", "sha256": token}
        for key in REQUIRED_VERDICTS:
            review["verdicts"][key] = "PASS"
        review["verdicts"].update(expected)
        for key in FACE_EVIDENCE_FIELDS:
            review["visible_face_evidence"][key] = f"Visible {key.replace('_', ' ')} cue."
        review["professional_standard"].update(
            {
                "band": "PROFESSIONAL",
                "evidence_confidence": "HIGH",
                "benchmark_comparison": "Meets the frozen professional comparison.",
                "critical_dimensions": ["silhouette", "psychology", "downstream usability"],
                "rejection_case": "Strongest honest rejection case was tested and refuted.",
                "excellence_gap": "Further polish could exceed the professional target.",
            }
        )
        review["readiness"] = "READY"
        review["cross_examination"].update(
            {
                "record_path": f"proof/cross-{index}.json",
                "record_sha256": token,
                "outcome": "READY retained after peer challenge.",
                "protected_dissent": "NONE",
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
            "user_approval_locator": None,
        }
    )
    return record


def run_self_test(template: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    valid = build_valid_record(template)
    valid_failures = validate_record(valid)
    if valid_failures:
        failures.append(f"valid control failed: {valid_failures}")

    mutations: list[tuple[str, Any]] = []

    failed_gate = copy.deepcopy(valid)
    failed_gate["reviews"][0]["verdicts"]["peak_age_fighter"] = "FAIL"
    mutations.append(("failed gate with READY", failed_gate))

    empty_psychology = copy.deepcopy(valid)
    empty_psychology["psychology"]["core_wound"] = ""
    mutations.append(("empty psychology", empty_psychology))

    bypassed_female_gate = copy.deepcopy(valid)
    bypassed_female_gate["reviews"][0]["verdicts"]["hot_adult_woman"] = "NOT_APPLICABLE"
    mutations.append(("female gate bypass", bypassed_female_gate))

    bad_provenance = copy.deepcopy(valid)
    bad_provenance["evidence"]["derived_face_enlargement"]["source_master_sha256"] = "b" * 64
    mutations.append(("derivative provenance mismatch", bad_provenance))

    duplicate_reviewer = copy.deepcopy(valid)
    duplicate_reviewer["reviews"][1]["reviewer_id"] = duplicate_reviewer["reviews"][0]["reviewer_id"]
    mutations.append(("duplicate reviewer", duplicate_reviewer))

    false_aggregate = copy.deepcopy(valid)
    false_aggregate["approval"]["derived_unanimous_ready"] = False
    mutations.append(("false aggregate", false_aggregate))

    invalid_lane = copy.deepcopy(valid)
    invalid_lane["unit"]["visual_lane"] = "generic_pretty_woman"
    mutations.append(("invalid lane enum", invalid_lane))

    for name, mutated in mutations:
        if not validate_record(mutated):
            failures.append(f"negative control unexpectedly passed: {name}")
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
