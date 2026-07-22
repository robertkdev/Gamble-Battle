#!/usr/bin/env python3
"""Render the Phase 2 face and survival-psychology review board.

Every image on this board is the existing face crop derived from the unit's
definitive master. The script performs layout only; it never redraws artwork.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
PACKET = ROOT / "docs" / "art" / "phase2_calibration"
ASSETS = ROOT / "assets" / "concepts" / "phase2_calibration"
MANIFEST = PACKET / "phase2_calibration_manifest.json"
PSYCHOLOGY = PACKET / "phase2_unit_psychology_records.json"
OUTPUT = PACKET / "phase2_face_board.png"

BACKGROUND = (20, 18, 21)
PANEL = (34, 31, 35)
PANEL_EDGE = (76, 67, 71)
IMAGE_BG = (25, 23, 26)
INK = (238, 229, 216)
MUTED = (176, 164, 154)
ACCENT = (157, 96, 78)
FIELD = (210, 184, 164)


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    windows = Path("C:/Windows/Fonts")
    candidate = windows / ("arialbd.ttf" if bold else "arial.ttf")
    if candidate.exists():
        return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source = image.convert("RGB")
    fitted = ImageOps.contain(source, size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, IMAGE_BG)
    canvas.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas


def wrap_lines(
    draw: ImageDraw.ImageDraw,
    value: str,
    selected_font: ImageFont.ImageFont,
    max_width: int,
    max_lines: int,
) -> list[str]:
    words = value.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        width = draw.textbbox((0, 0), candidate, font=selected_font)[2]
        if width <= max_width:
            current = candidate
            continue
        if current:
            lines.append(current)
        current = word
        if len(lines) == max_lines:
            break
    if current and len(lines) < max_lines:
        lines.append(current)
    consumed = " ".join(lines)
    if len(consumed) < len(value.strip()) and lines:
        tail = lines[-1].rstrip(".,;:")
        while tail and draw.textbbox((0, 0), tail + "...", font=selected_font)[2] > max_width:
            tail = tail[:-1]
        lines[-1] = tail.rstrip() + "..."
    return lines


def draw_field(
    draw: ImageDraw.ImageDraw,
    position: tuple[int, int],
    label: str,
    value: str,
    width: int,
    max_lines: int,
) -> int:
    x, y = position
    label_font = font(13, True)
    body_font = font(15)
    draw.text((x, y), label, fill=FIELD, font=label_font)
    y += 17
    lines = wrap_lines(draw, value, body_font, width, max_lines)
    for line in lines:
        draw.text((x, y), line, fill=INK, font=body_font)
        y += 19
    return y + 7


def render(output: Path) -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records = json.loads(PSYCHOLOGY.read_text(encoding="utf-8"))["units"]
    units = manifest["units"]

    columns = 2
    rows = (len(units) + columns - 1) // columns
    cell_w, cell_h = 1180, 600
    header_h = 132
    board = Image.new("RGB", (columns * cell_w, header_h + rows * cell_h), BACKGROUND)
    draw = ImageDraw.Draw(board)

    draw.text((30, 22), "PHASE 2 - FACE AND SURVIVAL-PSYCHOLOGY BOARD", fill=INK, font=font(34, True))
    draw.text(
        (30, 67),
        "Same-master face crops only. Read want, fear, strategy, contradiction, and villain intent from visible evidence.",
        fill=MUTED,
        font=font(18),
    )
    draw.text(
        (30, 96),
        "Board question: does the face support the same active psychology as the definitive full-body pose?",
        fill=(202, 178, 162),
        font=font(16, True),
    )

    for index, unit in enumerate(units):
        unit_id = unit["id"]
        record = records[unit_id]
        col, row = index % columns, index // columns
        x, y = col * cell_w, header_h + row * cell_h
        draw.rounded_rectangle(
            (x + 10, y + 10, x + cell_w - 10, y + cell_h - 10),
            14,
            fill=PANEL,
            outline=PANEL_EDGE,
            width=2,
        )
        draw.text((x + 28, y + 22), unit_id.upper(), fill=INK, font=font(24, True))
        meta = f'{unit["role"]}  |  {" / ".join(unit["traits"])}  |  {record["sex_design_category"]}'
        draw.text((x + 28, y + 52), meta, fill=MUTED, font=font(14))

        face_path = ASSETS / unit_id / f"{unit_id}_face.png"
        face = contain(Image.open(face_path), (400, 492))
        board.paste(face, (x + 28, y + 86))
        draw.rectangle((x + 28, y + 86, x + 427, y + 577), outline=(65, 59, 63), width=2)

        text_x = x + 452
        text_y = y + 84
        text_width = cell_w - 490
        fields = [
            ("PRIVATE WANT", record["private_want"], 2),
            ("PRIMARY FEAR", record["primary_fear"], 2),
            ("ACTIVE SURVIVAL STRATEGY", record["survival_strategy"], 2),
            ("CURRENT EMOTION", record["current_emotional_state"], 2),
            ("CONTRADICTION", record["emotional_contradiction"], 2),
            ("VISIBLE FACE DIRECTION", record["face_direction"], 4),
            ("FORBIDDEN READ", record["forbidden_read"], 2),
        ]
        for label, value, max_lines in fields:
            text_y = draw_field(draw, (text_x, text_y), label, value, text_width, max_lines)

    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output, optimize=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    target = args.output if args.output.is_absolute() else ROOT / args.output
    render(target.resolve())
