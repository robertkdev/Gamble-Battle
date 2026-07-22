#!/usr/bin/env python3
"""Render deterministic Phase 2 review derivatives from the master concepts."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

from render_phase2_comparison_boards import render as render_comparison_boards
from render_phase2_face_board import render as render_face_board


ROOT = Path(__file__).resolve().parents[2]
PACKET = ROOT / "docs" / "art" / "phase2_calibration"
ASSETS = ROOT / "assets" / "concepts" / "phase2_calibration"
MANIFEST = PACKET / "phase2_calibration_manifest.json"
CONTACT_SHEET = PACKET / "phase2_calibration_contact_sheet.png"
BOARD_96 = PACKET / "phase2_calibration_96px_board.png"
FACE_BOARD = PACKET / "phase2_face_board.png"
COMPARISONS = PACKET / "comparisons"
MASTER_COMPARISON = COMPARISONS / "phase2_master_comparison.png"
ROLE_96_LINEUP = COMPARISONS / "phase2_96px_lineup.png"
VELLUM_COMPARISON = COMPARISONS / "phase2_vellum_first_comparison.png"
BACKGROUND = (22, 20, 23)
PANEL = (34, 31, 35)
INK = (234, 225, 211)
MUTED = (172, 160, 151)
ACCENT = (139, 90, 77)


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    windows = Path("C:/Windows/Fonts")
    name = "arialbd.ttf" if bold else "arial.ttf"
    candidate = windows / name
    if candidate.exists():
        return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def contain(image: Image.Image, size: tuple[int, int], background: tuple[int, int, int]) -> Image.Image:
    source = image.convert("RGB")
    fitted = ImageOps.contain(source, size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, background)
    x = (size[0] - fitted.width) // 2
    y = (size[1] - fitted.height) // 2
    canvas.paste(fitted, (x, y))
    return canvas


def master_path(unit_id: str) -> Path:
    return ASSETS / unit_id / f"{unit_id}_master.png"


def silhouettes_path(unit_id: str) -> Path:
    return ASSETS / unit_id / f"{unit_id}_silhouettes.png"


def check_path(unit_id: str) -> Path:
    return ASSETS / unit_id / f"{unit_id}_96px.png"


def elide(draw: ImageDraw.ImageDraw, value: str, selected_font: ImageFont.ImageFont, max_width: int) -> str:
    if draw.textbbox((0, 0), value, font=selected_font)[2] <= max_width:
        return value
    shortened = value
    while shortened and draw.textbbox((0, 0), shortened + "…", font=selected_font)[2] > max_width:
        shortened = shortened[:-1]
    return shortened.rstrip("/") + "…"


def write_capture_manifest(path: Path) -> None:
    staged = path.parent / "staged"
    staged.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()
    captures = []
    definitions = [
        (CONTACT_SHEET, "phase2_contact_sheet", "all_masters_and_silhouettes", "overview", "Phase 2 masters and silhouette options"),
        (BOARD_96, "phase2_96px_board", "derived_board_read", "board_read", "Unchanged masters contained at 96 pixels"),
        (FACE_BOARD, "phase2_face_psychology_board", "same_master_face_psychology", "face_psychology", "Same-master face crops against the survival-psychology records"),
        (MASTER_COMPARISON, "phase2_master_comparison", "role_grouped_master_convergence", "convergence", "Role-grouped full-body master comparison"),
        (ROLE_96_LINEUP, "phase2_role_96px_lineup", "role_grouped_96px_convergence", "convergence", "Role-grouped exact 96 pixel lineup"),
        (VELLUM_COMPARISON, "phase2_approved_vellum_comparison", "approved_vellum_first_style_check", "style_anchor", "Approved hard-matte Vellum anchor against the twelve calibration masters"),
    ]
    for source, event, state, group, label in definitions:
        shutil.copy2(source, staged / source.name)
        captures.append(
            {
                "path": f"staged/{source.name}",
                "event": event,
                "metadata": {
                    "runtime": "Deterministic Pillow review packet",
                    "source": MANIFEST.relative_to(ROOT).as_posix(),
                    "source_sha256": source_hash,
                    "build": "codex/019f858f-005-phase1-trait-bible-repair",
                },
                "state": state,
                "label": label,
                "role": "frame",
                "camera": "document",
                "group": group,
                "viewport": "review-board",
                "layer": "final",
            }
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"captures": captures}, indent=2) + "\n", encoding="utf-8")


def render(capture_manifest: Path | None = None) -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    units = data["units"]

    for unit in units:
        unit_id = unit["id"]
        master = Image.open(master_path(unit_id))
        derived = contain(master, (96, 96), BACKGROUND)
        check_path(unit_id).parent.mkdir(parents=True, exist_ok=True)
        derived.save(check_path(unit_id), optimize=True)

    cell_w, cell_h = 440, 650
    columns, rows = 4, 3
    contact = Image.new("RGB", (columns * cell_w, rows * cell_h + 88), BACKGROUND)
    draw = ImageDraw.Draw(contact)
    draw.text((24, 18), "GAMBLE BATTLE — PHASE 2 REAL-UNIT CALIBRATION", fill=INK, font=font(28, True))
    draw.text((24, 54), "12 definitive masters • 12 rough silhouette triptychs • all 22 traits", fill=MUTED, font=font(17))

    for index, unit in enumerate(units):
        col, row = index % columns, index // columns
        x, y = col * cell_w, row * cell_h + 88
        draw.rounded_rectangle((x + 8, y + 8, x + cell_w - 8, y + cell_h - 8), 14, fill=PANEL, outline=(69, 61, 65), width=2)
        draw.text((x + 22, y + 18), unit["id"].upper(), fill=INK, font=font(22, True))
        trait_line = f'{unit["role"]}  •  ' + " / ".join(unit["traits"])
        draw.text((x + 22, y + 48), trait_line, fill=MUTED, font=font(15))
        master = contain(Image.open(master_path(unit["id"])), (400, 430), (26, 24, 27))
        contact.paste(master, (x + 20, y + 76))
        draw.rectangle((x + 20, y + 516, x + 420, y + 517), fill=ACCENT)
        silhouette = contain(Image.open(silhouettes_path(unit["id"])), (400, 104), (222, 215, 201))
        contact.paste(silhouette, (x + 20, y + 528))
        draw.rounded_rectangle((x + 26, y + 599, x + 122, y + 626), 6, fill=(42, 37, 40), outline=ACCENT)
        draw.text((x + 35, y + 605), f'SELECTED {unit["selected_silhouette"]}', fill=INK, font=font(12, True))
    contact.save(CONTACT_SHEET, optimize=True)

    board_cell_w, board_cell_h = 270, 160
    board = Image.new("RGB", (columns * board_cell_w, rows * board_cell_h + 78), BACKGROUND)
    bdraw = ImageDraw.Draw(board)
    bdraw.text((20, 14), "DERIVED 96 PX BOARD READ — NO REDRAWING", fill=INK, font=font(25, True))
    bdraw.text((20, 47), "Entire master contained inside each 96×96 check", fill=MUTED, font=font(15))
    for index, unit in enumerate(units):
        col, row = index % columns, index // columns
        x, y = col * board_cell_w, row * board_cell_h + 78
        bdraw.rounded_rectangle((x + 7, y + 7, x + board_cell_w - 7, y + board_cell_h - 7), 10, fill=PANEL, outline=(69, 61, 65))
        check = Image.open(check_path(unit["id"])).convert("RGB")
        board.paste(check, (x + 17, y + 26))
        bdraw.text((x + 126, y + 24), unit["id"].upper(), fill=INK, font=font(18, True))
        bdraw.text((x + 126, y + 49), unit["role"], fill=MUTED, font=font(14))
        trait_font = font(13)
        traits = elide(bdraw, "/".join(unit["traits"]), trait_font, 132)
        bdraw.text((x + 126, y + 72), traits, fill=(204, 180, 166), font=trait_font)
        primary = f'PRIMARY: {unit["art_primary"]}'
        bdraw.text((x + 126, y + 99), primary, fill=INK, font=font(11, True))
    board.save(BOARD_96, optimize=True)
    render_face_board(FACE_BOARD)
    render_comparison_boards(COMPARISONS)
    if capture_manifest is not None:
        write_capture_manifest(capture_manifest)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture-manifest", default=None)
    arguments = parser.parse_args()
    render(Path(arguments.capture_manifest).resolve() if arguments.capture_manifest else None)
