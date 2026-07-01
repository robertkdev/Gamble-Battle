# Creep Builtin Revision Candidate V3 - 2026-07-01

Status: pre-ledger review candidate, not an accepted proof, not a live replacement.

## Files

- Raw: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v3_2026_07_01/creep_builtin_revision_candidate_v3_raw.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v3_2026_07_01/creep_builtin_revision_candidate_v3_cutout_birefnet_foregroundml_despill_edgeclean.png`
- Mask: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v3_2026_07_01/creep_builtin_revision_candidate_v3_mask_birefnet_foregroundml_despill_edgeclean.png`
- Cutout review: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v3_2026_07_01/creep_builtin_revision_candidate_v3_review_birefnet_foregroundml_despill_edgeclean.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v3_2026_07_01/creep_builtin_revision_candidate_v3_board_preview.png`
- Review sheet: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v3_2026_07_01/creep_builtin_revision_candidate_v3_review_sheet.png`
- Objective cutout audit: `outputs/art_pipeline/style_validation/cutout_orange_fringe_audit_2026_07_01_creep_builtin_revision_candidate_v3/unit_art_cutout_orange_fringe_audit.md`
- Vellum-first style audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_07_01_creep_builtin_revision_candidate_v3/reference_ladder_raw_comparison.png`

## Audit Result

- Built-in image generation route.
- Raw background practical check: border mean approximately `[249.72, 66.23, 1.54]`, border standard deviation approximately `[1.18, 1.76, 0.81]`, and `99.9988%` of sampled border pixels were within RGB distance 12 of `#f84401`.
- BiRefNet foreground-ML/despill/edge-orange-clean completed with `edge_orange_cleaned=1`.
- Standalone objective orange-fringe audit passed: `rows=1`, `flagged=0`, `accepted_or_reference_flagged=0`.
- Board preview is readable at 96 px and the flat scythe-ring silhouette survives on checker, black, and white.
- Foreground metrics for v3: entropy `6.757`, edge mean `26.63`, gray std `34.35`, colorfulness `7.25`.
- For comparison, Vellum edge mean is `31.92`, Paisley is `29.07`, and the prior Creep current candidate is `32.65`.

## Art Read

This is the best current Creep direction for the specific tendril-material failure. It changes the earlier ribbed tube tendrils into flatter matte black scythe-ribbons and keeps the smooth alien head/body read better than the corpse-style failures.

It is still not an accepted proof. The remaining concern is that the torso and limbs keep some anatomical striation and the detail proxy is below Vellum/Paisley. Human review should decide whether the smoother, less tube-like identity improvement outweighs the lower Vellum-level dry-detail score, or whether another pass should keep v3's flat scythe-ribbon ring while adding more dry surface richness without returning to ribs/tubes/shine.

## Telegram

- Review sheet sent as message `130`.
- Raw candidate sent as message `131`.
