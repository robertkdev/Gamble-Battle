# Creep Builtin Revision Candidate V5 - 2026-07-01

Status: user-approved Creep final for the current art direction and live replacement as of 2026-07-02.

## Files

- Raw: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v5_2026_07_01/creep_builtin_revision_candidate_v5_raw.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v5_2026_07_01/creep_builtin_revision_candidate_v5_cutout_birefnet_foregroundml_despill_edgeclean.png`
- Mask: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v5_2026_07_01/creep_builtin_revision_candidate_v5_mask_birefnet_foregroundml_despill_edgeclean.png`
- Cutout review: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v5_2026_07_01/creep_builtin_revision_candidate_v5_review_birefnet_foregroundml_despill_edgeclean.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v5_2026_07_01/creep_builtin_revision_candidate_v5_board_preview.png`
- Review sheet: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v5_2026_07_01/creep_builtin_revision_candidate_v5_review_sheet.png`
- Objective cutout audit: `outputs/art_pipeline/style_validation/cutout_orange_fringe_audit_2026_07_01_creep_builtin_revision_candidate_v5/unit_art_cutout_orange_fringe_audit.md`
- Vellum-first style audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_07_01_creep_builtin_revision_candidate_v5/reference_ladder_raw_comparison.png`

## Audit Result

- Built-in image generation route.
- Raw background practical check: the 4 px border sample was `99.16%` within RGB distance 12 of the safety-orange key and `100%` within distance 20; 8 px, 16 px, and 32 px border samples were also `100%` within distance 20.
- Raw non-orange foreground bounds left `130` px, top `104` px, right `120` px, bottom `95` px on a `1254` px square canvas, improving the tight v4 ring margins.
- BiRefNet foreground-ML/despill/edge-orange-clean completed with `edge_orange_cleaned=0`.
- Standalone objective orange-fringe audit passed: `rows=1`, `flagged=0`, `accepted_or_reference_flagged=0`. This audit read only the v5 cutout RGBA pixels and did not compare against Vellum, Paisley, the token, or any other reference image.
- Board preview is readable at 96 px and the broad black scythe-ring silhouette survives on checker, black, and white.
- Foreground metrics for v5: entropy `6.909`, edge mean `31.38`, gray std `38.06`, colorfulness `8.35`, foreground pixels `303383`.
- For comparison, Vellum edge mean is `31.92`, Paisley is `29.07`, prior current Creep is `32.65`, v4 was `32.35`, and v3 was `26.63`.

## Art Read

V5 is now the strongest current Creep candidate. It preserves the v4 improvement of flatter matte black scythe-ribbon tendrils, removes the distracting orange flecks on the ring, and restores safer cutout-bound padding while staying near Vellum's dry-detail proxy.

It is now accepted for Creep specifically after user review on 2026-07-02. The accepted reason is not that it becomes the global style target over Vellum, but that it is the strongest current expression of Creep's dissociated smooth-alien horror identity inside the matte gothic direction. Treat it as the approved Creep live asset and as a narrow creepy-humanoid/demon/cursed-unit reference.

Do not use the Bloodborne/porcelain hybrid experiment as a replacement unless the user explicitly reverses this decision. The hybrid is useful for studying Victorian horror polish, but it makes Creep more ornate and less brutally dissociated than v5.

## Live Promotion

- Live asset replaced: `assets/units/creep.png`
- Source cutout used: `outputs/art_pipeline/style_validation/creep_builtin_revision_candidate_v5_2026_07_01/creep_builtin_revision_candidate_v5_cutout_birefnet_foregroundml_despill_edgeclean.png`
- Decision: accepted for Creep and promoted into the game.
- Scope: Creep-specific final/live asset; narrow horror reference. Vellum remains the ultimate finish/detail/material anchor.

## Telegram

- Raw candidate sent as message `134`.
- Review sheet sent as message `135`.
- Live promoted Creep asset sent as message `532`.
- Hybrid research-only Creep variant sent as message `533`.
