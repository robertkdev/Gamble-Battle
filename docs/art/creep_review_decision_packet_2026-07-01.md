# Creep Review Decision Packet

- Generated: 2026-07-01
- Proof id: `creep_vellum_primary_detail_refit`
- Status: `current_candidate`
- Reference role: `review_candidate_not_anchor`
- Visual decision sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_board_decision_sheet/review_packet/creep_vellum_primary_detail_refit_review_decision_sheet.png`
- Board-scale decision sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_board_decision_sheet/review_packet/creep_vellum_primary_detail_refit_board_scale_decision_sheet.png`
- Raw: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_board_preview.png`
- Vellum pairwise audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/vellum_first_pairwise_raw_comparison.png`
- Reference ladder audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/reference_ladder_raw_comparison.png`

## Decision

Creep is the next human-review gate. Do not generate Veyra or broader roster batches until this is approved, rejected, or sent back for revision.

Approve only if the candidate passes Vellum-first visual review as a dry, detailed, smooth-alien horror unit. Approval keeps it as a narrow proof, not a global style anchor.

Reject or request revision if it reads shiny/sweaty, corpse/flayed, too low-detail, too generic creature-concept, too cartoony, or not readable at board scale.

## Vellum-First Scoring Contract

- Judge the raw candidate beside Vellum first for dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability.
- Paisley only checks whether brighter or stranger units can keep the same dry gothic richness. The token only checks small-asset material language.
- Later accepted proofs can explain a narrow silhouette, material, or cutout risk, but they cannot rescue a candidate that is weaker than Vellum on the core style target.
- If the candidate matches the newer passing pool but loses Vellum's dry detail richness, request a revision or reject it.
- Acceptance records this as a narrow proof only. It does not add Creep to the global anchor pool.

## Human Reply Contract

- Reply `approve Creep` only if the candidate survives the Vellum-first scoring contract.
- Reply `revise Creep: <needed change>` if it is close but needs a concrete correction such as less shine, more Vellum-level dry detail, or stronger smooth-alien identity.
- Reply `reject Creep: <reason>` if the current direction should become a negative example.

## Apply The Decision

```powershell
python tools\art\apply_unit_art_review_decision.py --proof-id creep_vellum_primary_detail_refit --decision accept --reason "<human-approved reason>" --next-unit-id veyra
python tools\art\apply_unit_art_review_decision.py --proof-id creep_vellum_primary_detail_refit --decision reject --reason "<concrete failure reason>"
python tools\art\apply_unit_art_review_decision.py --proof-id creep_vellum_primary_detail_refit --decision request_revision --reason "<needed change>"
```

## Prior Creep Lessons

- `creep_hard_matte_smooth_alien_refit` / `rejected`: The body/head and serrated tendrils still carried slick creature-concept highlights and anatomical surface modeling; identity restoration was not enough to meet the matte gothic non-shiny gate.
- `creep_smooth_alien_matte_match_refit` / `rejected`: Clean/readable but too simplified: the smooth body lost the layered dry texture, tactile surface breakup, small gothic accents, and hand-painted material richness that make Vellum and Paisley work. Detail score was also visibly and metrically far below the reference pair.
- `creep_smooth_alien_refit` / `rejected`: Solved more of the original smooth alien face/skin problem than the first rejected proof, but still carried slick head/body highlights and did not lock into the hard matte gothic finish.
- `creep_unit_refit_rejected` / `rejected`: Lost original smooth oval alien face and smooth gray-blue alien skin; leaned into exposed anatomy, corpse texture, and wet/dead-flesh horror.
