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
VELLUM_BOARD_REFERENCE = "outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_cutout_cleanliness_comparison.png"
CREEP_REVISION_PROMPT_PACKET = "docs/art/creep_revision_prompt_packet_2026_07_01/creep.md"
SCORECARD_TEMPLATE_GATES = {
    "vellum_veto": "Candidate survives the first side-by-side comparison against Vellum on dry material, detail richness, grounded realism, silhouette mood, and board-scale readability.",
    "creep_identity": "Candidate still reads as the planned smooth alien/demon assassin, not a corpse, flayed anatomy monster, generic creature, or unreadable tendril knot.",
    "de_shined_material": "Skin, tendrils, clothing, and blades read dry, chalky, absorptive, low-sheen, and hand-painted beside Vellum.",
    "detail_richness": "De-shining preserves Vellum-level tactile dry detail, dry surface breakup, occult material marks, and readable grouped complexity; Paisley is secondary contrast context only.",
    "board_scale_read": "The 96 px board preview keeps the smooth head, torso, hands/feet, and blade-tendril ring without hiding style problems.",
    "cutout_quality": "Checker, black, white, and orange-fringe audit review show no unacceptable safety-orange edge residue and no missing identity-critical tendrils.",
    "reference_role": "If approved, the proof remains narrow horror-side coverage only and does not change the global anchor hierarchy.",
}


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
    background: tuple[int, int, int] = (248, 68, 1),
) -> None:
    font = load_font(18)
    small = load_font(13)
    tile = fit_image(image_path, size, background)
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
    draw.text((18, 76), "Anchor priority: Vellum can veto the candidate; later passing proofs cannot average away the target.", font=small, fill=(230, 205, 135))

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
        "Does the candidate pass beside Vellum before considering any newer accepted or current proofs?",
        "Does Creep still read as the planned smooth alien/demon assassin, not a generic corpse or flayed anatomy monster?",
        "Does the skin/tendril finish look dry, chalky, absorptive, and hand-painted beside Vellum?",
        "Does it preserve enough Vellum-level tactile dry detail without becoming chaotic at board scale?",
        "Is there any sweaty, glossy, wet, latex, polished, or shiny creature-concept finish?",
        "Are later passing proofs being used only for narrow risk context, not as an averaged style pool?",
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


def write_board_decision_sheet(
    output_path: Path,
    proof_data: dict[str, Any],
    proof: dict[str, Any],
) -> None:
    paisley = find_proof(proof_data, "paisley_goth_bubble_refit")
    width = 1600
    height = 980
    sheet = Image.new("RGB", (width, height), (18, 18, 20))
    draw = ImageDraw.Draw(sheet)
    title = load_font(28)
    font = load_font(18)
    small = load_font(14)
    draw.text((18, 18), f"{proof.get('display_name', proof.get('subject_id'))} Board-Scale Decision Sheet", font=title, fill=(255, 222, 120))
    draw.text((18, 56), "Board read is part of the Vellum veto. Small-scale readability cannot rescue shiny or low-detail material.", font=small, fill=(230, 205, 135))

    tiles = [
        (VELLUM_BOARD_REFERENCE, "REF Vellum", "board/cutout reference", (255, 222, 120)),
        (str(paisley.get("board_preview", "")), "REF Paisley", "secondary board context", (230, 205, 135)),
        (str(proof.get("review", "")), "Creep Cutout Review", "checker/black/white", (210, 220, 255)),
        (str(proof.get("board_preview", "")), "Creep Board Preview", "96 px readability", (255, 170, 130)),
    ]
    tile_size = (360, 280)
    for index, item in enumerate(tiles):
        x = 18 + index * 390
        draw_tile(sheet, draw, item[0], item[1], item[2], (x, 110), tile_size, item[3], (26, 26, 29))

    y = 470
    draw.text((18, y), "Board-Scale Questions", font=title, fill=(255, 222, 120))
    questions = [
        "At 96 px, can you still read Creep's smooth oval head, torso, hands/feet, and blade-tendril ring?",
        "Does Creep keep enough Vellum-level dry surface breakup at small scale, or does de-shining make him too smooth/plain?",
        "Does the board preview avoid glossy creature skin, wet tendrils, shiny black blades, and plastic highlights?",
        "Does the silhouette feel like the planned creepy humanoid/demon assassin, not a generic corpse or unreadable tendril knot?",
        "Does the cutout avoid visible orange fringe, orange-fringe audit flags, or missing identity-critical tendrils on checker, black, and white?",
    ]
    text_y = y + 46
    for question in questions:
        for line in wrap_text(f"- {question}", 126):
            draw.text((18, text_y), line, font=font, fill=(220, 220, 225))
            text_y += 26
        text_y += 5

    draw.text((18, text_y + 24), "Decision rule", font=title, fill=(255, 222, 120))
    rule_lines = [
        "Approve only if both raw-scale Vellum comparison and board-scale read pass.",
        "If the board preview reads but the raw still looks shiny, low-detail, cartoony, or weaker than Vellum, request revision.",
        "If the raw passes but the board preview loses the head/body/tendrils, request revision before any live asset swap.",
    ]
    text_y += 72
    for line in rule_lines:
        draw.text((18, text_y), f"- {line}", font=font, fill=(220, 220, 225))
        text_y += 28

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def write_scorecard_template(path: Path, proof: dict[str, Any], report_date: str) -> None:
    template: dict[str, Any] = {
        "proof_id": proof.get("id"),
        "subject_id": proof.get("subject_id"),
        "generated": report_date,
        "instructions": [
            "Judge the candidate side by side against Vellum first.",
            "Use pass only when the gate survives Vellum-first review.",
            "Use revise for close or fixable issues.",
            "Use reject for core failures.",
            "Acceptance is blocked unless every scorecard value is pass.",
        ],
        "allowed_values": ["pass", "revise", "reject"],
        "scorecard": {gate: "revise" for gate in SCORECARD_TEMPLATE_GATES},
        "gate_notes": SCORECARD_TEMPLATE_GATES,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(template, indent=2) + "\n", encoding="utf-8")


def format_latest_scorecard(proof: dict[str, Any]) -> str:
    scorecard = proof.get("latest_scorecard")
    if not isinstance(scorecard, dict) or not scorecard:
        return ""
    parts = [f"{gate}={value}" for gate, value in sorted(scorecard.items())]
    return ", ".join(parts)


def write_markdown(
    path: Path,
    proof: dict[str, Any],
    related: list[dict[str, Any]],
    visual_path: Path,
    board_decision_path: Path,
    scorecard_template_path: Path,
    report_date: str,
) -> None:
    style_audit = str(proof.get("style_audit", ""))
    pairwise_audit = style_audit.replace("raw_anchor_vs_later_contact_sheet.png", "vellum_first_pairwise_raw_comparison.png")
    reference_ladder_audit = style_audit.replace("raw_anchor_vs_later_contact_sheet.png", "reference_ladder_raw_comparison.png")
    scorecard_template_rel = rel(scorecard_template_path)
    revision_request = str(proof.get("revision_request", "")).strip()
    revision_prompt_packet = CREEP_REVISION_PROMPT_PACKET if proof.get("subject_id") == "creep" and revision_request else ""
    latest_scorecard = format_latest_scorecard(proof)
    lines: list[str] = [
        f"# {proof.get('display_name', proof.get('subject_id'))} Review Decision Packet",
        "",
        f"- Generated: {report_date}",
        f"- Proof id: `{proof.get('id')}`",
        f"- Status: `{proof.get('status')}`",
        f"- Reference role: `{proof.get('reference_role')}`",
        f"- Visual decision sheet: `{rel(visual_path)}`",
        f"- Board-scale decision sheet: `{rel(board_decision_path)}`",
        f"- Scorecard template: `{scorecard_template_rel}`",
        f"- Raw: `{proof.get('raw')}`",
        f"- Board preview: `{proof.get('board_preview')}`",
        f"- Vellum pairwise audit: `{pairwise_audit}`",
        f"- Reference ladder audit: `{reference_ladder_audit}`",
    ]
    if revision_request:
        lines.append(f"- Active revision request: {revision_request}")
    if revision_prompt_packet:
        lines.append(f"- Revision prompt packet: `{revision_prompt_packet}`")
    if latest_scorecard:
        lines.append(f"- Latest scorecard: `{latest_scorecard}`")
    lines.extend([
        "",
        "## Decision",
        "",
    ])
    if revision_request:
        lines.extend([
            "Creep is the next revision gate. Do not generate Veyra or broader roster batches until a new Creep pass resolves the active revision request.",
            "",
            f"Active revision request: {revision_request}",
            "",
            f"Use `{revision_prompt_packet}` for the next Creep generation pass.",
            "",
            "Do not approve the previous candidate as-is. Use it as a comparison target for what to improve: smoother alien identity, drier Vellum-level material, and more convincing matte gothic detail without becoming low-detail or corpse-like.",
        ])
    else:
        lines.append("Creep is the next human-review gate. Do not generate Veyra or broader roster batches until this is approved, rejected, or sent back for revision.")
    lines.extend([
        "",
        "Approve only if the candidate passes Vellum-first visual review as a dry, detailed, smooth-alien horror unit. Approval keeps it as a narrow proof, not a global style anchor.",
        "",
        "Reject or request revision if it reads shiny/sweaty, corpse/flayed, too low-detail, too generic creature-concept, too cartoony, or not readable at board scale.",
        "",
        "## Vellum-First Scoring Contract",
        "",
        "- Judge the raw candidate beside Vellum first for dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability.",
        "- Paisley only checks whether brighter or stranger units can keep the same dry gothic richness. The token only checks small-asset material language.",
        "- Later accepted proofs can explain a narrow silhouette, material, or cutout risk, but they cannot rescue a candidate that is weaker than Vellum on the core style target.",
        "- If the candidate matches the newer passing pool but loses Vellum's dry detail richness, request a revision or reject it.",
        "- Acceptance records this as a narrow proof only. It does not add Creep to the global anchor pool.",
        "",
        "## Decision Scorecard",
        "",
        "| Gate | Evidence to inspect | Pass only if | Revise or reject if |",
        "| --- | --- | --- | --- |",
        "| Vellum veto | Vellum pairwise audit and reference ladder audit | Candidate is at least as convincing as Vellum on dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability. | Candidate only matches the newer passing pool, looks weaker than Vellum, or needs another prompt pass to restore the target. |",
        "| Creep identity | Source image, raw, and visual decision sheet | Smooth oval alien head, hollow dark eye sockets, gray-blue smooth skin, humanoid assassin stance, and black blade/tendril ring are recognizable. | It becomes a corpse, flayed anatomy monster, generic creature, unreadable tendril knot, or loses the planned smooth-alien read. |",
        "| De-shined material | Raw, Vellum pairwise audit, and board-scale decision sheet | Skin and tendrils read dry, chalky, absorptive, low-sheen, and hand-painted. | Any area reads sweaty, wet, glossy, plastic, latex, polished leather, shiny black blade, or slick creature concept. |",
        "| Detail richness | Raw, reference ladder audit, and candidate triage | De-shining preserves Vellum-level tactile dry detail, dry surface breakup, occult material marks, and readable grouped complexity; Paisley remains secondary contrast context only. | The result becomes low-detail, over-smoothed, palette-only, cartoony, or chaotic micro-detail. |",
        "| Board-scale read | Board-scale decision sheet and board preview | At 96 px, the smooth head, torso, hands/feet, and blade-tendril ring survive without hiding style problems. | The board view loses the identity, hides a shiny/weak raw, or looks readable only because detail collapsed. |",
        "| Cutout quality | Cutout review sheet and orange-fringe audit | Checker, black, white, and audit review have no unacceptable safety-orange edge residue and no missing identity-critical tendrils. | Fringe, spill, missing tendrils, or alpha damage would affect board readability. |",
        "| Reference role | Proof ledger and decision helper output | If approved, it remains a narrow horror-side proof only. | Approval would be treated as a global style anchor or permission to replace live art. |",
        "",
        "Scorecard rule: approve only if every gate is Pass. Request revision if one or more gates are close but fixable. Reject if the core identity, material, or Vellum-veto gate fails. Do not continue to Veyra or broader roster generation on a partial pass.",
        "",
        f"Use `{scorecard_template_rel}` as the worksheet. It defaults to `revise` so it cannot accidentally approve the candidate; edit every gate after side-by-side review before applying the decision.",
        "",
        "## Human Reply Contract",
        "",
        "- Reply `approve Creep` only if the candidate survives the Vellum-first scoring contract.",
        "- Reply `revise Creep: <needed change>` if it is close but needs a concrete correction such as less shine, more Vellum-level dry detail, or stronger smooth-alien identity.",
        "- Reply `reject Creep: <reason>` if the current direction should become a negative example.",
        "",
        "## Apply The Decision",
        "",
        "```powershell",
        f'python tools\\art\\apply_unit_art_review_decision.py --proof-id {proof.get("id")} --decision accept --reason "<human-approved reason>" --next-unit-id veyra --scorecard-json {scorecard_template_rel}',
        f'python tools\\art\\apply_unit_art_review_decision.py --proof-id {proof.get("id")} --decision reject --reason "<concrete failure reason>" --scorecard-json {scorecard_template_rel}',
        f'python tools\\art\\apply_unit_art_review_decision.py --proof-id {proof.get("id")} --decision request_revision --reason "<needed change>" --scorecard-json {scorecard_template_rel}',
        "```",
        "",
        "## Prior Creep Lessons",
        "",
    ])
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
    board_decision_path = output_dir / f"{args.proof_id}_board_scale_decision_sheet.png"
    scorecard_template_path = output_dir / f"{args.proof_id}_scorecard_template.json"
    md_path = output_dir / f"{args.proof_id}_review_decision_packet.md"
    write_visual_packet(visual_path, proof_data, proof, related)
    write_board_decision_sheet(board_decision_path, proof_data, proof)
    write_scorecard_template(scorecard_template_path, proof, args.report_date)
    write_markdown(md_path, proof, related, visual_path, board_decision_path, scorecard_template_path, args.report_date)
    if args.docs_output:
        docs_path = args.docs_output if args.docs_output.is_absolute() else ROOT / args.docs_output
        docs_scorecard_template_path = docs_path.with_name(f"{docs_path.stem}_scorecard_template.json")
        write_scorecard_template(docs_scorecard_template_path, proof, args.report_date)
        write_markdown(docs_path, proof, related, visual_path, board_decision_path, docs_scorecard_template_path, args.report_date)
        print(rel(docs_path))
        print(rel(docs_scorecard_template_path))
    print(rel(md_path))
    print(rel(visual_path))
    print(rel(board_decision_path))
    print(rel(scorecard_template_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
