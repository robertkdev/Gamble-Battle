# Creep Builtin Revision Candidate V4 - 2026-07-01

Status: current best pre-ledger review candidate, not an accepted proof, not a live replacement.

## Files

- Raw: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v4_2026_07_01/creep_builtin_revision_candidate_v4_raw.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v4_2026_07_01/creep_builtin_revision_candidate_v4_cutout_birefnet_foregroundml_despill_edgeclean.png`
- Mask: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v4_2026_07_01/creep_builtin_revision_candidate_v4_mask_birefnet_foregroundml_despill_edgeclean.png`
- Cutout review: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v4_2026_07_01/creep_builtin_revision_candidate_v4_review_birefnet_foregroundml_despill_edgeclean.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v4_2026_07_01/creep_builtin_revision_candidate_v4_board_preview.png`
- Review sheet: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v4_2026_07_01/creep_builtin_revision_candidate_v4_review_sheet.png`
- Objective cutout audit: `outputs/art_pipeline/style_validation/cutout_orange_fringe_audit_2026_07_01_creep_builtin_revision_candidate_v4/unit_art_cutout_orange_fringe_audit.md`
- Vellum-first style audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_07_01_creep_builtin_revision_candidate_v4/reference_ladder_raw_comparison.png`

## Audit Result

- Built-in image generation route.
- Raw background practical check: 4 px, 8 px, and 16 px border samples were `100%` within RGB distance 12 of the safety-orange key. The 32 px border sample included foreground because the scythe-ring sits near the edge, but the raw still has margins: left `19` px, top `65` px, right `32` px, bottom `101` px.
- BiRefNet foreground-ML/despill/edge-orange-clean completed with `edge_orange_cleaned=4`.
- Standalone objective orange-fringe audit passed: `rows=1`, `flagged=0`, `accepted_or_reference_flagged=0`.
- Board preview is readable at 96 px and the flat scythe-ring silhouette survives on checker, black, and white.
- Foreground metrics for v4: entropy `6.856`, edge mean `32.35`, gray std `35.99`, colorfulness `7.01`.
- For comparison, Vellum edge mean is `31.92`, Paisley is `29.07`, prior current Creep is `32.65`, and Creep v3 was `26.63`.

## Art Read

V4 is the strongest current Creep candidate. It preserves v3's main improvement, the flatter matte black scythe-ribbon ring, while reducing the body/limb anatomical striation and bringing the dry-detail proxy back into the Vellum range.

It is still not an accepted proof. The remaining human-review questions are whether the brighter gray-blue skin highlights still feel too shiny in context, whether the orange flecks on the black scythe-ribbons are acceptable dry chipped-paint texture or too close to background contamination, and whether the tighter ring margins are acceptable for future cutout-bound generation.

## Telegram

- Review sheet sent as message `132`.
- Raw candidate sent as message `133`.
