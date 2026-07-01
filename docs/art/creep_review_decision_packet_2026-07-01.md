# Creep Review Decision Packet

- Generated: 2026-07-01
- Proof id: `creep_vellum_primary_detail_refit`
- Status: `current_candidate`
- Reference role: `review_candidate_not_anchor`
- Visual decision sheet: `outputs/art_pipeline/style_validation/workflow_validation_rawkey_2026_07_01/review_packet/creep_vellum_primary_detail_refit_review_decision_sheet.png`
- Board-scale decision sheet: `outputs/art_pipeline/style_validation/workflow_validation_rawkey_2026_07_01/review_packet/creep_vellum_primary_detail_refit_board_scale_decision_sheet.png`
- Scorecard template: `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json`
- Raw: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_board_preview.png`
- Vellum pairwise audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/vellum_first_pairwise_raw_comparison.png`
- Reference ladder audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/reference_ladder_raw_comparison.png`
- Active revision request: User critique requires another Creep pass: restore the original smooth alien face and uninterrupted gray-blue skin while pushing the finish closer to Vellum-level matte gothic dry detail; current candidate still does not fully meet the Vellum matte/detail target.
- Revision prompt packet: `docs/art/creep_revision_prompt_packet_2026_07_01/creep.md`
- Latest scorecard: `board_scale_read=revise, creep_identity=revise, cutout_quality=pass, de_shined_material=revise, detail_richness=revise, reference_role=pass, vellum_veto=revise`

## Decision

Creep is the next revision gate. Do not generate Veyra or broader roster batches until a new Creep pass resolves the active revision request.

Active revision request: User critique requires another Creep pass: restore the original smooth alien face and uninterrupted gray-blue skin while pushing the finish closer to Vellum-level matte gothic dry detail; current candidate still does not fully meet the Vellum matte/detail target.

Use `docs/art/creep_revision_prompt_packet_2026_07_01/creep.md` for the next Creep generation pass.

Do not approve the previous candidate as-is. Use it as a comparison target for what to improve: smoother alien identity, drier Vellum-level material, and more convincing matte gothic detail without becoming low-detail or corpse-like.

Approve only if the candidate passes Vellum-first visual review as a dry, detailed, smooth-alien horror unit. Approval keeps it as a narrow proof, not a global style anchor.

Reject or request revision if it reads shiny/sweaty, corpse/flayed, too low-detail, too generic creature-concept, too cartoony, or not readable at board scale.

## Vellum-First Scoring Contract

- Judge the raw candidate beside Vellum first for dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability.
- Paisley only checks whether brighter or stranger units can keep the same dry gothic richness. The token only checks small-asset material language.
- Later accepted proofs can explain a narrow silhouette, material, or cutout risk, but they cannot rescue a candidate that is weaker than Vellum on the core style target.
- If the candidate matches the newer passing pool but loses Vellum's dry detail richness, request a revision or reject it.
- Acceptance records this as a narrow proof only. It does not add Creep to the global anchor pool.

## Decision Scorecard

| Gate | Evidence to inspect | Pass only if | Revise or reject if |
| --- | --- | --- | --- |
| Vellum veto | Vellum pairwise audit and reference ladder audit | Candidate is at least as convincing as Vellum on dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability. | Candidate only matches the newer passing pool, looks weaker than Vellum, or needs another prompt pass to restore the target. |
| Creep identity | Source image, raw, and visual decision sheet | Smooth oval alien head, hollow dark eye sockets, gray-blue smooth skin, humanoid assassin stance, and black blade/tendril ring are recognizable. | It becomes a corpse, flayed anatomy monster, generic creature, unreadable tendril knot, or loses the planned smooth-alien read. |
| De-shined material | Raw, Vellum pairwise audit, and board-scale decision sheet | Skin and tendrils read dry, chalky, absorptive, low-sheen, and hand-painted. | Any area reads sweaty, wet, glossy, plastic, latex, polished leather, shiny black blade, or slick creature concept. |
| Detail richness | Raw, reference ladder audit, and candidate triage | De-shining preserves Vellum-level tactile dry detail, dry surface breakup, occult material marks, and readable grouped complexity; Paisley remains secondary contrast context only. | The result becomes low-detail, over-smoothed, palette-only, cartoony, or chaotic micro-detail. |
| Board-scale read | Board-scale decision sheet and board preview | At 96 px, the smooth head, torso, hands/feet, and blade-tendril ring survive without hiding style problems. | The board view loses the identity, hides a shiny/weak raw, or looks readable only because detail collapsed. |
| Cutout quality | Cutout review sheet and orange-fringe audit | Checker, black, white, and audit review have no unacceptable safety-orange edge residue and no missing identity-critical tendrils. | Fringe, spill, missing tendrils, or alpha damage would affect board readability. |
| Reference role | Proof ledger and decision helper output | If approved, it remains a narrow horror-side proof only. | Approval would be treated as a global style anchor or permission to replace live art. |

Scorecard rule: approve only if every gate is Pass. Request revision if one or more gates are close but fixable. Reject if the core identity, material, or Vellum-veto gate fails. Do not continue to Veyra or broader roster generation on a partial pass.

Use `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json` as the worksheet. It defaults to `revise` so it cannot accidentally approve the candidate; edit every gate after side-by-side review before applying the decision.

## Human Reply Contract

- Reply `approve Creep` only if the candidate survives the Vellum-first scoring contract.
- Reply `revise Creep: <needed change>` if it is close but needs a concrete correction such as less shine, more Vellum-level dry detail, or stronger smooth-alien identity.
- Reply `reject Creep: <reason>` if the current direction should become a negative example.

## Apply The Decision

```powershell
python tools\art\apply_unit_art_review_decision.py --proof-id creep_vellum_primary_detail_refit --decision accept --reason "<human-approved reason>" --next-unit-id veyra --scorecard-json docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json
python tools\art\apply_unit_art_review_decision.py --proof-id creep_vellum_primary_detail_refit --decision reject --reason "<concrete failure reason>" --scorecard-json docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json
python tools\art\apply_unit_art_review_decision.py --proof-id creep_vellum_primary_detail_refit --decision request_revision --reason "<needed change>" --scorecard-json docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json
```

## Prior Creep Lessons

- `creep_hard_matte_smooth_alien_refit` / `rejected`: The body/head and serrated tendrils still carried slick creature-concept highlights and anatomical surface modeling; identity restoration was not enough to meet the matte gothic non-shiny gate.
- `creep_smooth_alien_matte_match_refit` / `rejected`: Clean/readable but too simplified: the smooth body lost the layered dry texture, tactile surface breakup, small gothic accents, and hand-painted material richness that make Vellum and Paisley work. Detail score was also visibly and metrically far below the reference pair.
- `creep_smooth_alien_refit` / `rejected`: Solved more of the original smooth alien face/skin problem than the first rejected proof, but still carried slick head/body highlights and did not lock into the hard matte gothic finish.
- `creep_unit_refit_rejected` / `rejected`: Lost original smooth oval alien face and smooth gray-blue alien skin; leaned into exposed anatomy, corpse texture, and wet/dead-flesh horror.
