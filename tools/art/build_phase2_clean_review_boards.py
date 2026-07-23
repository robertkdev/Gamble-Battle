from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "docs/art/phase2_calibration/clean_review"
PSYCHOLOGY_PATH = ROOT / "docs/art/phase2_calibration/phase2_unit_psychology_records.json"
EVIDENCE_PATH = ROOT / "docs/art/phase2_calibration/phase2_review_evidence_manifest.json"

SEPARATOR_RGB = (18, 18, 20)
CELL_RGB = (36, 36, 38)
MASTER_CELL = 480
FACE_CELL = 480
LARGE_GUTTER = 16
NATIVE_CELL = 96
NATIVE_GUTTER = 8
PNG_COMPRESS_LEVEL = 9


def read_json(path: Path) -> dict[str, Any]:
    value: Any = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected an object in {path}")
    return value


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixel_sha256(image: Image.Image) -> str:
    canonical: Image.Image = image.convert("RGBA")
    header: bytes = f"RGBA:{canonical.width}x{canonical.height}:".encode("ascii")
    return hashlib.sha256(header + canonical.tobytes()).hexdigest()


def relative_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_rgb(path: Path) -> Image.Image:
    with Image.open(path) as source:
        return source.convert("RGB")


def asset_record(unit_id: str, asset: dict[str, Any]) -> dict[str, Any]:
    path = ROOT / str(asset["path"])
    if not path.is_file():
        raise FileNotFoundError(path)
    image = load_rgb(path)
    expected_dimensions = [int(value) for value in asset["dimensions"]]
    if list(image.size) != expected_dimensions:
        raise ValueError(
            f"{unit_id} {asset['path']} dimensions changed: "
            f"{list(image.size)} != {expected_dimensions}"
        )
    actual_sha256 = file_sha256(path)
    if actual_sha256 != asset["sha256"]:
        raise ValueError(
            f"{unit_id} {asset['path']} hash changed: "
            f"{actual_sha256} != {asset['sha256']}"
        )
    return {
        "unit_id": unit_id,
        "path": relative_path(path),
        "sha256": actual_sha256,
        "pixel_sha256": pixel_sha256(image),
        "dimensions": list(image.size),
        "mode": image.mode,
    }


def paste_contained(
    board: Image.Image,
    source: Image.Image,
    cell_x: int,
    cell_y: int,
    cell_size: int,
) -> dict[str, Any]:
    scaled: Image.Image = source.copy()
    scaled.thumbnail((cell_size, cell_size), Image.Resampling.LANCZOS)
    paste_x = cell_x + (cell_size - scaled.width) // 2
    paste_y = cell_y + (cell_size - scaled.height) // 2
    board.paste(scaled, (paste_x, paste_y))
    return {
        "cell_xywh": [cell_x, cell_y, cell_size, cell_size],
        "paste_xywh": [paste_x, paste_y, scaled.width, scaled.height],
        "operation": "full_source_contain",
        "resampling": "LANCZOS",
    }


def paste_native_96(
    board: Image.Image,
    source: Image.Image,
    cell_x: int,
    cell_y: int,
) -> dict[str, Any]:
    if source.size != (NATIVE_CELL, NATIVE_CELL):
        raise ValueError(f"Native review image must be 96x96, got {source.size}")
    before: str = pixel_sha256(source)
    board.paste(source, (cell_x, cell_y))
    pasted = board.crop((cell_x, cell_y, cell_x + NATIVE_CELL, cell_y + NATIVE_CELL))
    after: str = pixel_sha256(pasted)
    if before != after:
        raise ValueError("Native 96x96 pixels changed during board assembly")
    return {
        "cell_xywh": [cell_x, cell_y, NATIVE_CELL, NATIVE_CELL],
        "paste_xywh": [cell_x, cell_y, NATIVE_CELL, NATIVE_CELL],
        "operation": "native_pixel_paste",
        "resampling": "none",
        "source_pixel_sha256": before,
        "pasted_pixel_sha256": after,
    }


def save_board(
    output_path: Path,
    board: Image.Image,
    kind: str,
    order: list[str],
    sources: list[dict[str, Any]],
    placements: list[dict[str, Any]],
    target: str | None = None,
    neighbors: list[str] | None = None,
) -> dict[str, Any]:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    board.save(
        output_path,
        format="PNG",
        optimize=False,
        compress_level=PNG_COMPRESS_LEVEL,
    )
    with Image.open(output_path) as reopened:
        actual_size = list(reopened.size)
        actual_mode = reopened.mode
    if actual_size != list(board.size) or actual_mode != "RGB":
        raise ValueError(f"Saved board validation failed for {output_path}")

    record: dict[str, Any] = {
        "kind": kind,
        "path": relative_path(output_path),
        "sha256": file_sha256(output_path),
        "pixel_sha256": pixel_sha256(board),
        "dimensions": list(board.size),
        "mode": "RGB",
        "order": order,
        "sources": sources,
        "placements": placements,
    }
    if target is not None:
        record["target"] = target
    if neighbors is not None:
        record["neighbors"] = neighbors
    return record


def build_grid_board(
    output_path: Path,
    kind: str,
    order: list[str],
    asset_kind: str,
    assets: dict[str, dict[str, dict[str, Any]]],
    columns: int,
    cell_size: int,
    gutter: int,
    native_pixels: bool,
    target: str | None = None,
    neighbors: list[str] | None = None,
) -> dict[str, Any]:
    rows: int = (len(order) + columns - 1) // columns
    width: int = columns * cell_size + (columns - 1) * gutter
    height: int = rows * cell_size + (rows - 1) * gutter
    board = Image.new("RGB", (width, height), SEPARATOR_RGB)

    sources: list[dict[str, Any]] = []
    placements: list[dict[str, Any]] = []
    for index, unit_id in enumerate(order):
        column: int = index % columns
        row: int = index // columns
        cell_x: int = column * (cell_size + gutter)
        cell_y: int = row * (cell_size + gutter)
        board.paste(
            CELL_RGB,
            (cell_x, cell_y, cell_x + cell_size, cell_y + cell_size),
        )

        source_record = assets[unit_id][asset_kind]
        source = load_rgb(ROOT / source_record["path"])
        if native_pixels:
            placement = paste_native_96(board, source, cell_x, cell_y)
        else:
            placement = paste_contained(board, source, cell_x, cell_y, cell_size)
        placement["unit_id"] = unit_id
        placement["source_path"] = source_record["path"]
        sources.append(source_record)
        placements.append(placement)

    return save_board(
        output_path=output_path,
        board=board,
        kind=kind,
        order=order,
        sources=sources,
        placements=placements,
        target=target,
        neighbors=neighbors,
    )


def main() -> None:
    psychology = read_json(PSYCHOLOGY_PATH)
    evidence = read_json(EVIDENCE_PATH)
    psychology_units = psychology.get("units")
    evidence_units = evidence.get("units")
    if not isinstance(psychology_units, dict) or not isinstance(evidence_units, list):
        raise ValueError("Phase 2 source records have an unexpected structure")

    unit_order: list[str] = list(psychology_units.keys())
    evidence_order: list[str] = [str(unit["id"]) for unit in evidence_units]
    if unit_order != evidence_order:
        raise ValueError(
            "Psychology and evidence unit order differs: "
            f"{unit_order} != {evidence_order}"
        )
    if len(unit_order) != 12 or len(set(unit_order)) != 12:
        raise ValueError("Clean review requires exactly twelve unique Phase 2 units")

    assets: dict[str, dict[str, dict[str, Any]]] = {}
    for unit in evidence_units:
        unit_id = str(unit["id"])
        unit_assets = unit["assets"]
        assets[unit_id] = {
            "master": asset_record(unit_id, unit_assets["master"]),
            "face": asset_record(unit_id, unit_assets["face"]),
            "board_96px": asset_record(unit_id, unit_assets["board_96px"]),
        }

    neighbors_by_unit: dict[str, list[str]] = {}
    for unit_id in unit_order:
        raw_neighbors = psychology_units[unit_id].get("nearest_neighbors")
        if not isinstance(raw_neighbors, list):
            raise ValueError(f"{unit_id} nearest_neighbors must be a list")
        neighbors: list[str] = [str(value).lower() for value in raw_neighbors]
        if len(neighbors) != 3 or len(set(neighbors)) != 3:
            raise ValueError(f"{unit_id} must have exactly three unique neighbors")
        if unit_id in neighbors or any(value not in assets for value in neighbors):
            raise ValueError(f"{unit_id} has an invalid nearest-neighbor set")
        neighbors_by_unit[unit_id] = neighbors

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    boards: list[dict[str, Any]] = []
    boards.append(
        build_grid_board(
            OUTPUT_DIR / "roster_masters.png",
            "roster_masters",
            unit_order,
            "master",
            assets,
            columns=4,
            cell_size=MASTER_CELL,
            gutter=LARGE_GUTTER,
            native_pixels=False,
        )
    )
    boards.append(
        build_grid_board(
            OUTPUT_DIR / "roster_faces.png",
            "roster_faces",
            unit_order,
            "face",
            assets,
            columns=4,
            cell_size=FACE_CELL,
            gutter=LARGE_GUTTER,
            native_pixels=False,
        )
    )
    boards.append(
        build_grid_board(
            OUTPUT_DIR / "roster_native_96.png",
            "roster_native_96",
            unit_order,
            "board_96px",
            assets,
            columns=4,
            cell_size=NATIVE_CELL,
            gutter=NATIVE_GUTTER,
            native_pixels=True,
        )
    )

    for unit_id in unit_order:
        neighbors = neighbors_by_unit[unit_id]
        comparison_order = [unit_id, *neighbors]
        boards.append(
            build_grid_board(
                OUTPUT_DIR / f"{unit_id}_nearest_master.png",
                "nearest_neighbor_masters",
                comparison_order,
                "master",
                assets,
                columns=4,
                cell_size=MASTER_CELL,
                gutter=LARGE_GUTTER,
                native_pixels=False,
                target=unit_id,
                neighbors=neighbors,
            )
        )
        boards.append(
            build_grid_board(
                OUTPUT_DIR / f"{unit_id}_nearest_native_96.png",
                "nearest_neighbor_native_96",
                comparison_order,
                "board_96px",
                assets,
                columns=4,
                cell_size=NATIVE_CELL,
                gutter=NATIVE_GUTTER,
                native_pixels=True,
                target=unit_id,
                neighbors=neighbors,
            )
        )

    expected_paths = {record["path"] for record in boards}
    actual_paths = {
        relative_path(path) for path in OUTPUT_DIR.glob("*.png") if path.is_file()
    }
    if actual_paths != expected_paths:
        raise ValueError(
            "Unexpected clean-review board set: "
            f"missing={sorted(expected_paths - actual_paths)} "
            f"extra={sorted(actual_paths - expected_paths)}"
        )

    manifest = {
        "schema_version": "1.0.0",
        "purpose": "content-neutral Phase 2 visual review evidence",
        "source_records": [
            {
                "path": relative_path(PSYCHOLOGY_PATH),
                "sha256": file_sha256(PSYCHOLOGY_PATH),
            },
            {
                "path": relative_path(EVIDENCE_PATH),
                "sha256": file_sha256(EVIDENCE_PATH),
            },
        ],
        "unit_order": unit_order,
        "neighbors_by_unit": neighbors_by_unit,
        "generation_settings": {
            "pixel_annotations": "none",
            "embedded_names": False,
            "embedded_roles": False,
            "embedded_traits": False,
            "embedded_psychology": False,
            "embedded_verdicts": False,
            "embedded_selected_options": False,
            "embedded_captions": False,
            "separator_rgb": list(SEPARATOR_RGB),
            "cell_rgb": list(CELL_RGB),
            "master_and_face_transform": {
                "operation": "full_source_contain",
                "resampling": "Pillow Image.Resampling.LANCZOS",
                "cell_dimensions": [MASTER_CELL, MASTER_CELL],
                "gutter_px": LARGE_GUTTER,
                "equalization_rule": (
                    "Every full source is fit inside the same square cell; "
                    "aspect ratio is preserved and no crop is applied."
                ),
            },
            "native_96_transform": {
                "operation": "native_pixel_paste",
                "resampling": "none",
                "cell_dimensions": [NATIVE_CELL, NATIVE_CELL],
                "gutter_px": NATIVE_GUTTER,
                "verification": (
                    "Canonical RGBA pixel hashes before and after paste must match."
                ),
            },
            "png": {
                "mode": "RGB",
                "optimize": False,
                "compress_level": PNG_COMPRESS_LEVEL,
            },
        },
        "board_count": len(boards),
        "boards": boards,
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print(
        "PASS: clean Phase 2 review boards "
        f"units={len(unit_order)} boards={len(boards)} "
        f"manifest={relative_path(manifest_path)}"
    )


if __name__ == "__main__":
    main()
