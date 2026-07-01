from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_VELLUM = (
    "outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/"
    "vellum_10pct_real_deshine_selected_raw.png"
)
SAFETY_ORANGE = (248, 68, 1)
BG = (15, 18, 23)
CARD = (24, 29, 36)
BORDER = (62, 72, 86)
TEXT = (238, 239, 241)
MUTED = (188, 187, 183)
WARN = (255, 213, 130)
GOOD = (170, 235, 194)


def resolve(path_text: str | Path) -> Path:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    return path


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def load_font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


def load_image(path_text: str) -> Image.Image:
    path = resolve(path_text)
    if not path.exists():
        raise FileNotFoundError(rel(path))
    return Image.open(path).convert("RGBA")


def has_transparency(image: Image.Image) -> bool:
    if image.mode != "RGBA":
        return False
    return image.getchannel("A").getextrema()[0] < 255


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    box = image.getchannel("A").getbbox()
    if box is None:
        return (0, 0, image.width, image.height)
    x0, y0, x1, y1 = box
    pad = 8
    return (max(0, x0 - pad), max(0, y0 - pad), min(image.width, x1 + pad), min(image.height, y1 + pad))


def orange_backed_foreground_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            if a < 8:
                continue
            is_orange_key = r > 220 and 35 <= g <= 115 and b < 75 and r > g * 1.8
            if is_orange_key:
                continue
            xs.append(x)
            ys.append(y)
    if not xs:
        return (0, 0, image.width, image.height)
    pad = 10
    return (
        max(0, min(xs) - pad),
        max(0, min(ys) - pad),
        min(image.width, max(xs) + 1 + pad),
        min(image.height, max(ys) + 1 + pad),
    )


def full_panel(image: Image.Image, size: int) -> Image.Image:
    if not has_transparency(image):
        return image.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    crop = image.crop(alpha_bbox(image))
    canvas = Image.new("RGBA", (size, size), SAFETY_ORANGE + (255,))
    scale = min((size * 0.84) / crop.width, (size * 0.88) / crop.height)
    resized = crop.resize((max(1, int(crop.width * scale)), max(1, int(crop.height * scale))), Image.Resampling.LANCZOS)
    canvas.alpha_composite(resized, ((size - resized.width) // 2, (size - resized.height) // 2))
    return canvas.convert("RGB")


def upper_crop_panel(image: Image.Image, size: int) -> Image.Image:
    box = alpha_bbox(image) if has_transparency(image) else orange_backed_foreground_bbox(image)
    x0, y0, x1, y1 = box
    width = x1 - x0
    height = y1 - y0
    center_x = x0 + width * 0.5
    crop_width = width * 0.72
    crop_height = height * 0.54
    left = max(0, int(center_x - crop_width / 2))
    top = max(0, int(y0 + height * 0.02))
    right = min(image.width, int(center_x + crop_width / 2))
    bottom = min(image.height, int(top + crop_height))
    crop = image.crop((left, top, right, bottom))
    canvas = Image.new("RGBA", (size, size), SAFETY_ORANGE + (255,))
    scale = min(size / crop.width, size / crop.height)
    resized = crop.resize((max(1, int(crop.width * scale)), max(1, int(crop.height * scale))), Image.Resampling.LANCZOS)
    canvas.alpha_composite(resized, ((size - resized.width) // 2, (size - resized.height) // 2))
    return canvas.convert("RGB")


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, width: int) -> list[str]:
    lines: list[str] = []
    current = ""
    for word in text.split():
        candidate = word if not current else f"{current} {word}"
        if draw.textbbox((0, 0), candidate, font=font)[2] <= width:
            current = candidate
            continue
        if current:
            lines.append(current)
        current = word
    if current:
        lines.append(current)
    return lines


def draw_wrapped(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int],
    width: int,
    line_gap: int = 5,
) -> int:
    x, y = xy
    for line in wrap_text(draw, text, font, width):
        draw.text((x, y), line, font=font, fill=fill)
        y += draw.textbbox((0, 0), line, font=font)[3] + line_gap
    return y


def draw_bullets(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    bullets: list[str],
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int],
    width: int,
) -> None:
    for bullet in bullets:
        for line in wrap_text(draw, f"- {bullet}", font, width):
            draw.text((x, y), line, font=font, fill=fill)
            y += 25
        y += 3


def make_column_payload(args: argparse.Namespace) -> list[dict[str, str | list[str]]]:
    payload: list[dict[str, str | list[str]]] = [
        {
            "path": args.source_image,
            "title": f"Original {args.display_name}",
            "subtitle": "identity reference only",
            "note": args.source_note,
            "bullets": [
                "source identity, not passing style proof",
                "preserve recognizable silhouette and key motifs",
                "do not let old style override Vellum material quality",
            ],
        },
        {
            "path": args.vellum,
            "title": "Vellum ultimate reference",
            "subtitle": "material/detail authority",
            "note": args.vellum_note,
            "bullets": ["dry material veto", "detail richness veto", "matte finish veto"],
        },
    ]
    if args.fallback:
        payload.append(
            {
                "path": args.fallback,
                "title": args.fallback_label,
                "subtitle": args.fallback_role,
                "note": args.fallback_note,
                "bullets": ["fallback if candidate feels overworked", "compare identity and material tradeoffs"],
            }
        )
    payload.append(
        {
            "path": args.candidate,
            "title": args.candidate_label,
            "subtitle": args.candidate_role,
            "note": args.candidate_note,
            "bullets": ["review candidate only", "not accepted; not a global anchor", "needs proof path after human choice"],
        }
    )
    return payload


def build_sheet(args: argparse.Namespace) -> None:
    title_font = load_font(38, bold=True)
    h2_font = load_font(26, bold=True)
    body_font = load_font(17)
    small_font = load_font(14)
    columns = make_column_payload(args)
    images = [load_image(str(item["path"])) for item in columns]
    column_count = len(columns)
    width = 480 * column_count
    height = 1180
    margin = 24
    gap = 24
    column_width = (width - margin * 2 - gap * (column_count - 1)) // column_count
    sheet = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    draw.text((28, 24), f"{args.display_name} Source-Identity Review", font=title_font, fill=TEXT)
    draw.text(
        (30, 76),
        "Research only. Source identity is checked before style acceptance; Vellum remains the material/detail authority.",
        font=body_font,
        fill=MUTED,
    )
    card_top = 116
    card_height = 930
    for index, item in enumerate(columns):
        x = margin + index * (column_width + gap)
        y = card_top
        draw.rounded_rectangle((x, y, x + column_width, y + card_height), radius=8, fill=CARD, outline=BORDER, width=1)
        image = images[index]
        sheet.paste(full_panel(image, 220), (x + 18, y + 18))
        sheet.paste(upper_crop_panel(image, 184), (x + 270, y + 18))
        draw.text((x + 18, y + 244), "full", font=small_font, fill=MUTED)
        draw.text((x + 270, y + 208), "identity/material crop", font=small_font, fill=MUTED)
        draw.text((x + 18, y + 306), str(item["title"]), font=h2_font, fill=TEXT)
        subtitle_color = WARN if index < 2 else GOOD
        draw.text((x + 18, y + 342), str(item["subtitle"]), font=body_font, fill=subtitle_color)
        note_y = draw_wrapped(draw, (x + 18, y + 384), str(item["note"]), body_font, MUTED, column_width - 36, line_gap=6)
        draw.text((x + 18, note_y + 20), "board-scale identity read", font=body_font, fill=TEXT)
        scale_y = note_y + 58
        scale_x = x + 18
        for size in args.board_sizes:
            icon = full_panel(image, size)
            sheet.paste(icon, (scale_x, scale_y))
            draw.text((scale_x, scale_y + size + 5), f"{size}px", font=small_font, fill=MUTED)
            scale_x += size + 22
        draw_bullets(
            draw,
            x + 20,
            scale_y + 160,
            list(item["bullets"]),
            body_font,
            TEXT if index == column_count - 1 else MUTED,
            column_width - 40,
        )
    footer_y = 1080
    draw.rectangle((24, footer_y, width - 24, height - 28), fill=(17, 21, 27), outline=BORDER, width=1)
    footer = (
        f"Decision rule: do not promote {args.display_name} from this sheet. "
        "Human review chooses the candidate, fallback, targeted revision, or rejection. "
        "Vellum stays the ultimate material/detail reference; the original source stays the identity reference."
    )
    draw_wrapped(draw, (44, footer_y + 22), footer, body_font, TEXT, width - 88)
    output = resolve(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)
    print(rel(output))


def parse_board_sizes(text: str) -> list[int]:
    sizes = [int(part.strip()) for part in text.split(",") if part.strip()]
    if not sizes or any(size < 24 or size > 256 for size in sizes):
        raise argparse.ArgumentTypeError("board sizes must be comma-separated integers from 24 to 256")
    return sizes


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a source identity vs Vellum vs candidate review sheet.")
    parser.add_argument("--source-image", required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--candidate-label", default="Current candidate")
    parser.add_argument("--candidate-role", default="review candidate")
    parser.add_argument("--candidate-note", default="Pass only if identity survives and the material/detail read survives beside Vellum.")
    parser.add_argument("--fallback")
    parser.add_argument("--fallback-label", default="Fallback candidate")
    parser.add_argument("--fallback-role", default="fallback")
    parser.add_argument("--fallback-note", default="Use only if it preserves identity and avoids a visible overworked correction.")
    parser.add_argument("--source-note", default="Preserve the original silhouette, pose, body type, main motifs, and identity-critical details. This is not the style target.")
    parser.add_argument("--vellum", default=DEFAULT_VELLUM)
    parser.add_argument("--vellum-note", default="Dry gothic richness, grounded matte materials, heavy shadow, and high tactile detail. This vetoes style quality.")
    parser.add_argument("--board-sizes", type=parse_board_sizes, default=parse_board_sizes("112,88,64,48"))
    args = parser.parse_args()
    build_sheet(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
