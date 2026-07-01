from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"review_packet_{date.today().strftime('%Y_%m_%d')}"


def rel(path_text: str | Path) -> str:
    path = Path(path_text)
    if not path.is_absolute():
        path = ROOT / path
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def require_path(path_text: str) -> Path:
    path = ROOT / path_text
    if not path.exists():
        raise FileNotFoundError(path_text)
    return path


def load_font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def find_proof(proof_data: dict[str, Any], proof_id: str) -> dict[str, Any]:
    for proof in proof_data.get("proofs", []):
        if isinstance(proof, dict) and proof.get("id") == proof_id:
            return proof
    raise ValueError(f"unknown proof id: {proof_id}")


def related_subject_proofs(proof_data: dict[str, Any], subject_id: str, current_id: str) -> list[dict[str, Any]]:
    proofs = [
        proof
        for proof in proof_data.get("proofs", [])
        if isinstance(proof, dict) and proof.get("subject_id") == subject_id and proof.get("id") != current_id
    ]
    status_order = {"current_candidate": 0, "rejected": 1, "accepted": 2}
    proofs.sort(key=lambda proof: (status_order.get(str(proof.get("status")), 9), str(proof.get("id", ""))))
    return proofs


def fit_image(path_text: str, size: tuple[int, int], background: tuple[int, int, int]) -> Image.Image:
    image = Image.open(require_path(path_text)).convert("RGBA")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, background + (255,))
    canvas.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return canvas.convert("RGB")


def wrap_text(text: str, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if len(candidate) <= width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_tile(
    sheet: Image.Image,
    draw: ImageDraw.ImageDraw,
    image_path: str,
    label: str,
    sublabel: str,
    xy: tuple[int, int],
    size: tuple[int, int],
    label_color: tuple[int, int, int],
) -> None:
    font = load_font(18)
    small = load_font(13)
    tile = fit_image(image_path, size, (248, 68, 1))
    sheet.paste(tile, xy)
    draw.text((xy[0], xy[1] + size[1] + 8), label[:32], font=font, fill=label_color)
    if sublabel:
        draw.text((xy[0], xy[1] + size[1] + 32), sublabel[:42], font=small, fill=(180, 180, 185))


def write_visual_packet(
    output_path: Path,
    proof_data: dict[str, Any],
    proof: dict[str, Any],
    related: list[dict[str, Any]],
) -> None:
    policy = proof_data.get("style_contract", {}).get("reference_policy", {})
    primary = policy.get("primary_anchor", {})
    paisley = find_proof(proof_data, "paisley_goth_bubble_refit")
    token = find_proof(proof_data, "ability_token_contract_mark")
    source_image = str(proof.get("source_image", ""))
    width = 1600
    height = 1900
    sheet = Image.new("RGB", (width, height), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    title = load_font(28)
    font = load_font(18)
    small = load_font(14)
    draw.text((18, 18), f"{proof.get('display_name', proof.get('subject_id'))} Review Decision Packet", font=title, fill=(255, 222, 120))
    draw.text((18, 56), "Vellum is the decision anchor. Paisley/token are context. Candidate is review-only until the user decides.", font=small, fill=(230, 205, 135))

    tile = (260, 260)
    x_positions = [18, 310, 602, 894, 1186]
    anchors = [
        (str(primary.get("path", "")), "REF Vellum", "primary/ultimate", (255, 222, 120)),
        (str(paisley.get("raw", "")), "REF Paisley", "secondary contrast", (230, 205, 135)),
        (str(token.get("raw", "")), "REF Token", "small asset only", (230, 205, 135)),
        (source_image, "Source Creep", "identity source", (210, 220, 255)),
        (str(proof.get("raw", "")), "Current Candidate", str(proof.get("reference_role", "")), (255, 170, 130)),
    ]
    for x, item in zip(x_positions, anchors):
        if item[0]:
            draw_tile(sheet, draw, item[0], item[1], item[2], (x, 100), tile, item[3])

    current_y = 450
    draw.text((18, current_y), "Candidate Evidence", font=title, fill=(255, 222, 120))
    current_y += 48
    evidence = [
        (str(proof.get("raw", "")), "Raw", "style gate"),
        (str(proof.get("cutout", "")), "Cutout", "alpha result"),
        (str(proof.get("review", "")), "Cutout Review", "checker/black/white"),
        (str(proof.get("board_preview", "")), "Board Preview", "96 px readability"),
    ]
    for index, item in enumerate(evidence):
        x = 18 + index * 390
        draw_tile(sheet, draw, item[0], item[1], item[2], (x, current_y), (350, 230), (210, 220, 255))

    current_y += 330
    text_x = 18
    draw.text((text_x, current_y), "Decision Questions", font=title, fill=(255, 222, 120))
    questions = [
        "Does Creep still read as the planned smooth alien/demon assassin, not a generic corpse or flayed anatomy monster?",
        "Does the skin/tendril finish look dry, chalky, absorptive, and hand-painted beside Vellum?",
        "Does it preserve enough Vellum/Paisley-level tactile detail without becoming chaotic at board scale?",
        "Is there any sweaty, glossy, wet, latex, polished, or shiny creature-concept finish?",
        "If accepted, will it remain a narrow horror-side proof, not a global style anchor?",
    ]
    y = current_y + 46
    for question in questions:
        for line in wrap_text(f"- {question}", 118):
            draw.text((text_x, y), line, font=font, fill=(220, 220, 225))
            y += 25
        y += 4

    current_y = y + 28
    draw.text((18, current_y), "Rejected / Superseded Creep Lessons", font=title, fill=(255, 222, 120))
    current_y += 50
    thumb = (190, 190)
    for index, old_proof in enumerate(related[:5]):
        x = 18 + index * 310
        raw = str(old_proof.get("raw", ""))
        if raw:
            draw_tile(
                sheet,
                draw,
                raw,
                str(old_proof.get("id", "")),
                str(old_proof.get("status", "")),
                (x, current_y),
                thumb,
                (255, 150, 150),
            )
        reason = str(old_proof.get("failure_reason", old_proof.get("style_gate", "")))
        text_y = current_y + 245
        for line in wrap_text(reason, 34)[:5]:
            draw.text((x, text_y), line, font=small, fill=(205, 205, 210))
            text_y += 18

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def write_markdown(
    path: Path,
    proof: dict[str, Any],
    related: list[dict[str, Any]],
    visual_path: Path,
    report_date: str,
) -> None:
    lines: list[str] = [
        f"# {proof.get('display_name', proof.get('subject_id'))} Review Decision Packet",
        "",
        f"- Generated: {report_date}",
        f"- Proof id: `{proof.get('id')}`",
        f"- Status: `{proof.get('status')}`",
        f"- Reference role: `{proof.get('reference_role')}`",
        f"- Visual decision sheet: `{rel(visual_path)}`",
        f"- Raw: `{proof.get('raw')}`",
        f"- Board preview: `{proof.get('board_preview')}`",
        f"- Vellum pairwise audit: `{str(proof.get('style_audit', '')).replace('raw_anchor_vs_later_contact_sheet.png', 'vellum_first_pairwise_raw_comparison.png')}`",
        "",
        "## Decision",
        "",
        "Creep is the next human-review gate. Do not generate Veyra or broader roster batches until this is approved, rejected, or sent back for revision.",
        "",
        "Approve only if the candidate passes Vellum-first visual review as a dry, detailed, smooth-alien horror unit. Approval keeps it as a narrow proof, not a global style anchor.",
        "",
        "Reject or request revision if it reads shiny/sweaty, corpse/flayed, too low-detail, too generic creature-concept, too cartoony, or not readable at board scale.",
        "",
        "## Apply The Decision",
        "",
        "```powershell",
        f'python tools\\art\\apply_unit_art_review_decision.py --proof-id {proof.get("id")} --decision accept --reason "<human-approved reason>" --next-unit-id veyra',
        f'python tools\\art\\apply_unit_art_review_decision.py --proof-id {proof.get("id")} --decision reject --reason "<concrete failure reason>"',
        f'python tools\\art\\apply_unit_art_review_decision.py --proof-id {proof.get("id")} --decision request_revision --reason "<needed change>"',
        "```",
        "",
        "## Prior Creep Lessons",
        "",
    ]
    for old_proof in related:
        lines.append(f"- `{old_proof.get('id')}` / `{old_proof.get('status')}`: {old_proof.get('failure_reason', old_proof.get('style_gate', ''))}")
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--proof-id", required=True)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--docs-output", type=Path)
    parser.add_argument("--report-date", default=date.today().isoformat())
    args = parser.parse_args()

    proof_data = load_json(PROOF_MATRIX_PATH)
    proof = find_proof(proof_data, args.proof_id)
    related = related_subject_proofs(proof_data, str(proof.get("subject_id", "")), str(proof.get("id", "")))
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    visual_path = output_dir / f"{args.proof_id}_review_decision_sheet.png"
    md_path = output_dir / f"{args.proof_id}_review_decision_packet.md"
    write_visual_packet(visual_path, proof_data, proof, related)
    write_markdown(md_path, proof, related, visual_path, args.report_date)
    if args.docs_output:
        docs_path = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        write_markdown(docs_path, proof, related, visual_path, args.report_date)
        print(rel(docs_path))
    print(rel(md_path))
    print(rel(visual_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
