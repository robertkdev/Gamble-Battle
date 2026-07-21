#!/usr/bin/env python3
"""Render the Phase 1 trait bible into Markdown and a non-production atlas."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import shutil
import textwrap
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "docs" / "art" / "trait_visual_bible_phase1.json"
DEFAULT_MARKDOWN = ROOT / "docs" / "art" / "trait_visual_bible_phase1.md"
DEFAULT_SVG = ROOT / "docs" / "art" / "trait_visual_bible_phase1.svg"
DEFAULT_PNG = ROOT / "docs" / "art" / "trait_visual_bible_phase1.png"
DEFAULT_CAPTURE = ROOT / "outputs" / "visual_debug" / "trait_visual_bible_phase1" / "captures.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    parser.add_argument("--markdown", default=str(DEFAULT_MARKDOWN))
    parser.add_argument("--svg", default=str(DEFAULT_SVG))
    parser.add_argument("--png", default=str(DEFAULT_PNG))
    parser.add_argument("--capture-manifest", default=None)
    return parser.parse_args()


def load_data(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value: dict[str, Any] = json.load(handle)
    return value


def bullets(values: list[str]) -> str:
    return "\n".join(f"- {value}" for value in values)


def palette_text(values: list[dict[str, str]]) -> str:
    return "; ".join(f"{value['name']} `{value['hex']}`" for value in values)


def render_markdown(data: dict[str, Any]) -> str:
    rules = data["world_system"]
    lines = [
        "# Gamble Battle — Phase 1 World and Trait Visual Bible",
        "",
        "> Status: **Phase 1 concept-art authority.** This document defines visual grammar only. It creates no unit design and authorizes no shop card, headshot, sprite sheet, animation sheet, or VFX asset.",
        "",
        "![Non-production trait reference atlas](trait_visual_bible_phase1.png)",
        "",
        "The atlas is a review diagram of palette, form, surface, motion, and cost. It is not a trait icon sheet or production art.",
        "",
        "## Authority and sources",
        "",
        f"- Live Google design document revision: `{data['source_authority']['google_doc_revision']}`.",
        f"- Live trait resources: `{data['source_authority']['trait_resource_path']}` (22/22 catalog parity).",
        "- Historical art attempts are evidence for failure modes, not authority over current mechanics.",
        "- Runtime and repository data remain authoritative when mechanics change.",
        "",
        "## World system",
        "",
        f"**Thesis:** {rules['thesis']}",
        "",
        "### Shared finish",
        "",
        bullets(rules["shared_finish"]),
        "",
        "### Permanent lessons from prior passes",
        "",
        bullets(rules["prior_pass_lessons"]),
        "",
        "### Trait-channel hierarchy",
        "",
        bullets(rules["trait_channel_hierarchy"]),
        "",
        "### Roster-wide prohibitions",
        "",
        bullets(rules["roster_wide_prohibitions"]),
        "",
        "### Phase 1 exit tests",
        "",
        bullets(data["exit_tests"]),
        "",
        "## Trait cards",
        "",
    ]

    for entry in data["traits"]:
        refs = entry["compact_visual_references"]
        lines.extend(
            [
                f"### {entry['trait']}",
                "",
                f"**Mechanics anchor:** {entry['mechanics_anchor']}",
                "",
                f"**Core fantasy:** {entry['core_fantasy']}",
                "",
                f"**Emotional tone:** {entry['emotional_tone']}",
                "",
                f"**Silhouette verbs:** {', '.join(entry['silhouette_verbs'])}.",
                "",
                f"**Silhouette language:** {entry['silhouette_language']}",
                "",
                "**Garment/anatomy families:**",
                "",
                bullets(entry["garment_anatomy_families"]),
                "",
                f"**Palette:** {palette_text(entry['palette'])}.",
                "",
                f"**Patterns:** {', '.join(entry['patterns'])}.",
                "",
                f"**Materials:** {', '.join(entry['materials'])}.",
                "",
                f"**Magic behavior:** {entry['magic_behavior']}",
                "",
                f"**Supernatural cost:** {entry['supernatural_cost']}",
                "",
                "**Allowed variations:**",
                "",
                bullets(entry["allowed_variations"]),
                "",
                "**Forbidden clichés:**",
                "",
                bullets(entry["forbidden_cliches"]),
                "",
                "**Combination rules:**",
                "",
                bullets(entry["combination_rules"]),
                "",
                "**Compact visual references:**",
                "",
                f"- Form: {refs['form']}",
                f"- Surface: {refs['surface']}",
                f"- Motion: {refs['motion']}",
                f"- Cost mark: {refs['cost_mark']}",
                "",
                f"**Prop-free definition:** {entry['prop_free_definition']}",
                "",
            ]
        )

    lines.extend(
        [
            "## Combination quick rules",
            "",
            bullets(data["combination_quick_rules"]),
            "",
            "## Evidence retained from earlier art passes",
            "",
            bullets(data["source_evidence"]),
            "",
            "## Phase boundary",
            "",
            "Phase 1 stops here. Silhouettes for actual roster units, full-body masters, face enlargements, and 96px unit checks begin only in Phase 2.",
            "",
        ]
    )
    return "\n".join(lines)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def wrapped(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, width: int, font: ImageFont.ImageFont, fill: str, spacing: int = 6) -> int:
    lines = textwrap.wrap(text, width=width, break_long_words=False)
    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=font, fill=fill)
        box = draw.textbbox((x, y), line, font=font)
        y += box[3] - box[1] + spacing
    return y


def fitted_font(text: str, max_width: int, *, maximum: int = 18, minimum: int = 13) -> ImageFont.ImageFont:
    """Return the largest atlas font that keeps a short label inside its swatch."""
    probe_image = Image.new("RGB", (1, 1))
    probe = ImageDraw.Draw(probe_image)
    for size in range(maximum, minimum - 1, -1):
        font = load_font(size)
        if probe.textlength(text, font=font) <= max_width:
            return font
    return load_font(minimum)


def render_png(data: dict[str, Any], path: Path) -> None:
    width = 2400
    margin = 70
    gutter = 34
    columns = 2
    card_width = (width - (margin * 2) - gutter) // columns
    card_height = 430
    header_height = 210
    rows = (len(data["traits"]) + columns - 1) // columns
    height = header_height + rows * (card_height + gutter) + margin
    image = Image.new("RGB", (width, height), "#18171A")
    draw = ImageDraw.Draw(image)
    title_font = load_font(54, bold=True)
    subtitle_font = load_font(28)
    name_font = load_font(34, bold=True)
    label_font = load_font(21, bold=True)
    body_font = load_font(21)
    small_font = load_font(18)

    draw.text((margin, 44), "Gamble Battle — Phase 1 Trait Reference Atlas", font=title_font, fill="#F2E9DA")
    draw.text(
        (margin, 116),
        "NON-PRODUCTION REVIEW DIAGRAM • palette / form / surface / motion / supernatural cost",
        font=subtitle_font,
        fill="#BFAE9D",
    )
    draw.text(
        (margin, 158),
        "No unit concepts, trait icons, shop cards, portraits, sprites, animation sheets, or VFX assets.",
        font=small_font,
        fill="#8E8581",
    )

    for index, entry in enumerate(data["traits"]):
        row = index // columns
        col = index % columns
        x = margin + col * (card_width + gutter)
        y = header_height + row * (card_height + gutter)
        draw.rounded_rectangle(
            (x, y, x + card_width, y + card_height),
            radius=22,
            fill="#242126",
            outline="#5A5057",
            width=2,
        )
        draw.text((x + 28, y + 24), entry["trait"], font=name_font, fill="#F3E8D8")
        verbs = " • ".join(verb.upper() for verb in entry["silhouette_verbs"])
        draw.text((x + 28, y + 72), verbs, font=label_font, fill="#CBB89E")

        swatch_y = y + 112
        swatch_width = 112
        for swatch_index, swatch in enumerate(entry["palette"]):
            sx = x + 28 + swatch_index * (swatch_width + 10)
            draw.rounded_rectangle(
                (sx, swatch_y, sx + swatch_width, swatch_y + 34),
                radius=7,
                fill=swatch["hex"],
                outline="#6B6268",
            )
            palette_name = swatch["name"]
            palette_font = fitted_font(palette_name, swatch_width - 4)
            palette_width = draw.textlength(palette_name, font=palette_font)
            draw.text(
                (sx + (swatch_width - palette_width) / 2, swatch_y + 42),
                palette_name,
                font=palette_font,
                fill="#B9AFAC",
            )

        refs = entry["compact_visual_references"]
        text_y = y + 198
        for label, value in [
            ("FORM", refs["form"]),
            ("SURFACE", refs["surface"]),
            ("MOTION", refs["motion"]),
            ("COST", refs["cost_mark"]),
        ]:
            draw.text((x + 28, text_y), label, font=label_font, fill="#A99A8E")
            text_y = wrapped(draw, (x + 148, text_y), value, 72, body_font, "#E3D9D1", spacing=3)
            text_y += 4

        definition = entry["prop_free_definition"]
        wrapped(draw, (x + 28, y + card_height - 68), definition, 95, small_font, "#9D9397", spacing=2)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def render_svg(data: dict[str, Any], path: Path) -> None:
    card_width = 1140
    card_height = 310
    columns = 2
    margin = 60
    gutter = 28
    rows = (len(data["traits"]) + columns - 1) // columns
    width = margin * 2 + columns * card_width + gutter
    height = 190 + rows * (card_height + gutter) + margin
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#18171A"/>',
        '<style>text{font-family:Arial,sans-serif}.title{font-size:48px;font-weight:700;fill:#F2E9DA}.sub{font-size:22px;fill:#BFAE9D}.name{font-size:30px;font-weight:700;fill:#F3E8D8}.label{font-size:17px;font-weight:700;fill:#A99A8E}.body{font-size:17px;fill:#E3D9D1}.small{font-size:15px;fill:#9D9397}</style>',
        '<text x="60" y="70" class="title">Gamble Battle — Phase 1 Trait Reference Atlas</text>',
        '<text x="60" y="112" class="sub">NON-PRODUCTION REVIEW DIAGRAM • palette / form / surface / motion / supernatural cost</text>',
        '<text x="60" y="146" class="small">No unit concepts, trait icons, shop cards, portraits, sprites, animation sheets, or VFX assets.</text>',
    ]
    for index, entry in enumerate(data["traits"]):
        row = index // columns
        col = index % columns
        x = margin + col * (card_width + gutter)
        y = 170 + row * (card_height + gutter)
        parts.append(f'<rect x="{x}" y="{y}" width="{card_width}" height="{card_height}" rx="18" fill="#242126" stroke="#5A5057" stroke-width="2"/>')
        parts.append(f'<text x="{x + 24}" y="{y + 42}" class="name">{html.escape(entry["trait"])}</text>')
        verbs = " • ".join(verb.upper() for verb in entry["silhouette_verbs"])
        parts.append(f'<text x="{x + 24}" y="{y + 72}" class="label">{html.escape(verbs)}</text>')
        for swatch_index, swatch in enumerate(entry["palette"]):
            sx = x + 24 + swatch_index * 126
            parts.append(f'<rect x="{sx}" y="{y + 92}" width="112" height="28" rx="6" fill="{swatch["hex"]}" stroke="#6B6268"/>')
            palette_name = html.escape(swatch["name"])
            fit = ' textLength="108" lengthAdjust="spacingAndGlyphs"' if len(swatch["name"]) > 13 else ""
            parts.append(f'<text x="{sx + 56}" y="{y + 141}" class="small" text-anchor="middle"{fit}>{palette_name}</text>')
        refs = entry["compact_visual_references"]
        fields = [("FORM", refs["form"]), ("SURFACE", refs["surface"]), ("MOTION", refs["motion"]), ("COST", refs["cost_mark"])]
        for line_index, (label, value) in enumerate(fields):
            ly = y + 182 + line_index * 26
            parts.append(f'<text x="{x + 24}" y="{ly}" class="label">{label}</text>')
            parts.append(f'<text x="{x + 130}" y="{ly}" class="body">{html.escape(value[:100])}</text>')
    parts.append("</svg>")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(parts), encoding="utf-8")


def write_capture_manifest(source: Path, png: Path, manifest: Path) -> None:
    staged = manifest.parent / "staged" / png.name
    staged.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(png, staged)
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    payload = {
        "captures": [
            {
                "path": f"staged/{png.name}",
                "event": "reference_atlas",
                "metadata": {
                    "runtime": "Deterministic Pillow document render",
                    "source": source.as_posix(),
                    "source_sha256": source_hash,
                    "build": "codex/019f8507-c8f-phase1-trait-bible",
                },
                "state": "atlas",
                "label": "Phase 1 trait visual reference atlas",
                "role": "frame",
                "camera": "document",
                "group": "overview",
                "viewport": "document-2400px",
                "layer": "final",
            }
        ]
    }
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    source = Path(args.source).resolve()
    markdown = Path(args.markdown).resolve()
    svg = Path(args.svg).resolve()
    png = Path(args.png).resolve()
    data = load_data(source)
    markdown.write_text(render_markdown(data), encoding="utf-8", newline="\n")
    render_svg(data, svg)
    render_png(data, png)
    if args.capture_manifest:
        write_capture_manifest(source, png, Path(args.capture_manifest).resolve())
    print(f"Rendered {len(data['traits'])} trait cards")
    print(f"markdown={markdown}")
    print(f"svg={svg}")
    print(f"png={png}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
