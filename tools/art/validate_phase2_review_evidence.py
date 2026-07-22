#!/usr/bin/env python3
"""Build and validate deterministic provenance for the Phase 2 review cut."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageOps


ROOT = Path(__file__).resolve().parents[2]
PACKET = ROOT / "docs" / "art" / "phase2_calibration"
ASSETS = ROOT / "assets" / "concepts" / "phase2_calibration"
EVIDENCE_MANIFEST = PACKET / "phase2_review_evidence_manifest.json"
PHASE_MANIFEST = PACKET / "phase2_calibration_manifest.json"
BOARD_BACKGROUND = (22, 20, 23)

CUT: tuple[str, ...] = (
    "korath",
    "veyra",
    "cashmere",
    "pilfer",
    "nyxa",
    "creep",
    "knoll",
    "quillith",
    "kett",
    "luna",
    "malachor",
    "sable",
)

# These are the exact crop rectangles used to render the current same-master
# face checks. Persisting them here and in the evidence manifest closes the
# provenance gap left by the one-unit render CLI.
FACE_CROPS: dict[str, tuple[int, int, int, int]] = {
    "korath": (330, 210, 380, 430),
    "veyra": (430, 180, 500, 580),
    "cashmere": (350, 35, 340, 390),
    "pilfer": (100, 70, 470, 500),
    "nyxa": (310, 390, 420, 430),
    "creep": (760, 220, 360, 420),
    "knoll": (300, 60, 380, 420),
    "quillith": (330, 45, 380, 420),
    "kett": (360, 60, 360, 390),
    "luna": (340, 45, 360, 420),
    "malachor": (300, 180, 500, 570),
    "sable": (190, 70, 420, 450),
}

RELEVANT_DOCS: tuple[str, ...] = (
    "docs/art/unit_art_board_reference_criteria.md",
    "docs/art/trait_visual_bible_phase1.json",
    "docs/art/unit_art_proof_matrix.json",
    "docs/art/unit_art_roster_prompt_matrix.json",
    "docs/art/unit_art_style_workflow.md",
    "docs/art/vellum_alignment_continuation_2026-07-01.md",
    "docs/art/phase2_calibration/phase2_calibration_bible.md",
    "docs/art/phase2_calibration/phase2_calibration_manifest.json",
    "docs/art/phase2_calibration/phase2_unit_psychology_records.json",
    "docs/art/phase2_calibration/board/round_1_full_group_review_brief.md",
    "docs/art/phase2_calibration/board/round_1_cross_exam_consolidated.md",
)

RENDER_SOURCES: tuple[str, ...] = (
    "tools/art/render_phase2_unit_derivatives.py",
    "tools/art/render_phase2_calibration_packet.py",
    "tools/art/render_phase2_face_board.py",
    "tools/art/render_phase2_comparison_boards.py",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def asset_paths(unit_id: str) -> dict[str, Path]:
    unit_dir = ASSETS / unit_id
    return {
        "silhouette": unit_dir / f"{unit_id}_silhouettes.png",
        "master": unit_dir / f"{unit_id}_master.png",
        "face": unit_dir / f"{unit_id}_face.png",
        "board_96px": unit_dir / f"{unit_id}_96px.png",
    }


def image_record(path: Path) -> dict[str, Any]:
    with Image.open(path) as image:
        return {
            "path": relative(path),
            "sha256": sha256(path),
            "dimensions": [image.width, image.height],
            "mode": image.mode,
        }


def file_record(relative_path: str) -> dict[str, Any]:
    path = ROOT / relative_path
    return {
        "path": relative_path,
        "sha256": sha256(path),
        "bytes": path.stat().st_size,
    }


def expected_face(master: Image.Image, crop: tuple[int, int, int, int]) -> Image.Image:
    x, y, width, height = crop
    if x < 0 or y < 0 or width <= 0 or height <= 0:
        raise ValueError(f"invalid face crop {crop}")
    if x + width > master.width or y + height > master.height:
        raise ValueError(f"face crop {crop} exceeds master size {master.size}")
    face = master.convert("RGB").crop((x, y, x + width, y + height))
    face.thumbnail((768, 768), Image.Resampling.LANCZOS)
    return face


def expected_board_96px(master: Image.Image) -> Image.Image:
    source = master.convert("RGB")
    fitted = ImageOps.contain(source, (96, 96), Image.Resampling.LANCZOS)
    board = Image.new("RGB", (96, 96), BOARD_BACKGROUND)
    board.paste(fitted, ((96 - fitted.width) // 2, (96 - fitted.height) // 2))
    return board


def build_manifest() -> dict[str, Any]:
    phase_data = json.loads(PHASE_MANIFEST.read_text(encoding="utf-8"))
    phase_ids = [unit["id"] for unit in phase_data.get("units", [])]
    if phase_ids != list(CUT):
        raise ValueError(f"Phase 2 cut mismatch: expected {list(CUT)}, found {phase_ids}")

    units: list[dict[str, Any]] = []
    for unit_id in CUT:
        paths = asset_paths(unit_id)
        missing = [relative(path) for path in paths.values() if not path.is_file()]
        prompt = f"docs/art/phase2_calibration/prompts/{unit_id}.md"
        if not (ROOT / prompt).is_file():
            missing.append(prompt)
        if missing:
            raise FileNotFoundError("missing Phase 2 evidence: " + ", ".join(missing))

        records = {kind: image_record(path) for kind, path in paths.items()}
        master_hash = records["master"]["sha256"]
        units.append(
            {
                "id": unit_id,
                "assets": records,
                "derivations": {
                    "face": {
                        "source_master_path": records["master"]["path"],
                        "source_master_sha256": master_hash,
                        "crop_xywh": list(FACE_CROPS[unit_id]),
                        "operation": "RGB crop, then Pillow thumbnail 768x768 LANCZOS",
                    },
                    "board_96px": {
                        "source_master_path": records["master"]["path"],
                        "source_master_sha256": master_hash,
                        "canvas": [96, 96],
                        "background_rgb": list(BOARD_BACKGROUND),
                        "operation": "RGB ImageOps.contain 96x96 LANCZOS, centered",
                    },
                },
                "prompt": file_record(prompt),
            }
        )

    return {
        "schema_version": 1,
        "phase": 2,
        "title": "Real-unit calibration review evidence",
        "generator": relative(Path(__file__)),
        "cut": list(CUT),
        "unit_count": len(CUT),
        "asset_count": len(CUT) * 4,
        "criteria_and_review_docs": [file_record(path) for path in RELEVANT_DOCS],
        "render_sources": [file_record(path) for path in RENDER_SOURCES],
        "units": units,
    }


def write_manifest() -> None:
    data = build_manifest()
    EVIDENCE_MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE_MANIFEST.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def compare_file_record(record: Any, expected_path: str, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label}: missing record")
        return
    if record.get("path") != expected_path:
        errors.append(f"{label}: path mismatch")
        return
    path = ROOT / expected_path
    if not path.is_file():
        errors.append(f"{label}: missing {expected_path}")
        return
    if record.get("sha256") != sha256(path):
        errors.append(f"{label}: stale SHA-256 for {expected_path}")
    if record.get("bytes") != path.stat().st_size:
        errors.append(f"{label}: stale byte count for {expected_path}")


def compare_image_record(
    record: Any,
    expected_path: Path,
    label: str,
    errors: list[str],
) -> None:
    expected_relative = relative(expected_path)
    if not isinstance(record, dict):
        errors.append(f"{label}: missing image record")
        return
    if record.get("path") != expected_relative:
        errors.append(f"{label}: canonical path mismatch")
        return
    if not expected_path.is_file():
        errors.append(f"{label}: missing {expected_relative}")
        return
    if record.get("sha256") != sha256(expected_path):
        errors.append(f"{label}: stale SHA-256")
    with Image.open(expected_path) as image:
        if record.get("dimensions") != [image.width, image.height]:
            errors.append(f"{label}: dimensions mismatch")
        if record.get("mode") != image.mode:
            errors.append(f"{label}: image mode mismatch")


def validate_manifest() -> dict[str, Any]:
    errors: list[str] = []
    if not EVIDENCE_MANIFEST.is_file():
        return {"ok": False, "errors": [f"missing {relative(EVIDENCE_MANIFEST)}"]}
    try:
        data = json.loads(EVIDENCE_MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"ok": False, "errors": [f"unreadable evidence manifest: {exc}"]}

    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if data.get("phase") != 2:
        errors.append("phase must be 2")
    if data.get("cut") != list(CUT):
        errors.append("12-unit cut is missing, reordered, or changed")
    if data.get("unit_count") != len(CUT):
        errors.append("unit_count mismatch")
    if data.get("asset_count") != len(CUT) * 4:
        errors.append("asset_count mismatch")

    try:
        phase_data = json.loads(PHASE_MANIFEST.read_text(encoding="utf-8"))
        phase_ids = [unit["id"] for unit in phase_data.get("units", [])]
        if phase_ids != list(CUT):
            errors.append("current Phase 2 manifest no longer matches the frozen cut")
    except (OSError, json.JSONDecodeError, TypeError, KeyError) as exc:
        errors.append(f"current Phase 2 manifest is unreadable: {exc}")

    doc_records = data.get("criteria_and_review_docs")
    if not isinstance(doc_records, list) or len(doc_records) != len(RELEVANT_DOCS):
        errors.append("criteria/review document set mismatch")
    else:
        for record, path in zip(doc_records, RELEVANT_DOCS, strict=True):
            compare_file_record(record, path, f"document {path}", errors)

    source_records = data.get("render_sources")
    if not isinstance(source_records, list) or len(source_records) != len(RENDER_SOURCES):
        errors.append("render-source set mismatch")
    else:
        for record, path in zip(source_records, RENDER_SOURCES, strict=True):
            compare_file_record(record, path, f"render source {path}", errors)

    units = data.get("units")
    if not isinstance(units, list) or len(units) != len(CUT):
        errors.append("unit evidence set mismatch")
        units = []

    for index, unit_id in enumerate(CUT):
        if index >= len(units) or not isinstance(units[index], dict):
            errors.append(f"{unit_id}: missing unit record")
            continue
        unit = units[index]
        if unit.get("id") != unit_id:
            errors.append(f"{unit_id}: unit record reordered or renamed")
            continue
        paths = asset_paths(unit_id)
        assets = unit.get("assets")
        if not isinstance(assets, dict) or set(assets) != set(paths):
            errors.append(f"{unit_id}: asset class set mismatch")
            continue
        for kind, path in paths.items():
            compare_image_record(assets.get(kind), path, f"{unit_id}/{kind}", errors)

        prompt_path = f"docs/art/phase2_calibration/prompts/{unit_id}.md"
        compare_file_record(unit.get("prompt"), prompt_path, f"{unit_id}/prompt", errors)

        if not paths["master"].is_file() or not paths["face"].is_file() or not paths["board_96px"].is_file():
            continue
        master_hash = sha256(paths["master"])
        derivations = unit.get("derivations")
        if not isinstance(derivations, dict):
            errors.append(f"{unit_id}: missing derivation metadata")
            continue
        face_meta = derivations.get("face")
        board_meta = derivations.get("board_96px")
        master_relative = relative(paths["master"])
        if not isinstance(face_meta, dict):
            errors.append(f"{unit_id}: missing face derivation metadata")
        else:
            if face_meta.get("source_master_path") != master_relative:
                errors.append(f"{unit_id}: face source master path mismatch")
            if face_meta.get("source_master_sha256") != master_hash:
                errors.append(f"{unit_id}: face source master hash is stale or mismatched")
            if face_meta.get("crop_xywh") != list(FACE_CROPS[unit_id]):
                errors.append(f"{unit_id}: face crop metadata mismatch")
        if not isinstance(board_meta, dict):
            errors.append(f"{unit_id}: missing 96px derivation metadata")
        else:
            if board_meta.get("source_master_path") != master_relative:
                errors.append(f"{unit_id}: 96px source master path mismatch")
            if board_meta.get("source_master_sha256") != master_hash:
                errors.append(f"{unit_id}: 96px source master hash is stale or mismatched")
            if board_meta.get("canvas") != [96, 96] or board_meta.get("background_rgb") != list(BOARD_BACKGROUND):
                errors.append(f"{unit_id}: 96px render metadata mismatch")

        try:
            with Image.open(paths["master"]) as master_image:
                expected_face_image = expected_face(master_image, FACE_CROPS[unit_id])
                expected_board_image = expected_board_96px(master_image)
            with Image.open(paths["face"]) as face_image:
                actual_face = face_image.convert("RGB")
            with Image.open(paths["board_96px"]) as board_image:
                actual_board = board_image.convert("RGB")
            if expected_face_image.size != actual_face.size or ImageChops.difference(expected_face_image, actual_face).getbbox() is not None:
                errors.append(f"{unit_id}: face is not the declared deterministic crop of its master")
            if expected_board_image.size != actual_board.size or ImageChops.difference(expected_board_image, actual_board).getbbox() is not None:
                errors.append(f"{unit_id}: 96px image is not deterministic containment of its master")
        except (OSError, ValueError) as exc:
            errors.append(f"{unit_id}: derivative verification failed: {exc}")

    return {
        "ok": not errors,
        "unit_count": len(CUT),
        "asset_count": len(CUT) * 4,
        "document_count": len(RELEVANT_DOCS) + len(CUT),
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-manifest", action="store_true", help="rebuild the checked evidence manifest before validating")
    parser.add_argument("--json", action="store_true", help="emit the complete machine-readable result")
    args = parser.parse_args()

    if args.write_manifest:
        try:
            write_manifest()
        except (OSError, ValueError, KeyError, TypeError) as exc:
            print(f"FAIL phase2-review-evidence build: {exc}")
            return 1

    result = validate_manifest()
    if args.json:
        print(json.dumps(result, indent=2))
    elif result["ok"]:
        print(
            "PASS phase2-review-evidence "
            f"units={result['unit_count']} assets={result['asset_count']} docs={result['document_count']}"
        )
    else:
        print(f"FAIL phase2-review-evidence errors={len(result['errors'])}")
        for error in result["errors"]:
            print(f"- {error}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
