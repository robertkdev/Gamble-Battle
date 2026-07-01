# Unit Art Style Drift Audit - 2026-06-30

This audit pauses the proof-led generation run after human review flagged that the later candidates were drifting away from the best Vellum, Paisley, and token references.

Audit artifacts:

- Raw contact sheet: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30/raw_anchor_vs_later_contact_sheet.png`
- Vellum-first pairwise comparison sheet: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30/vellum_first_pairwise_raw_comparison.png`
- Board-preview contact sheet: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30/board_preview_drift_contact_sheet.png`
- Foreground metric table: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30/foreground_detail_metrics.csv`

Repeatable audit command:

```powershell
python tools\art\build_unit_style_drift_audit.py --proof-id <proof_id> --output-dir outputs\art_pipeline\style_validation\style_drift_audit_<date>_<unit>
```

## Correct Style Reading

The best target is not just the new palette and not just "less shiny." The best target is high-detail matte gothic rendering:

- Vellum has layered coat panels, parchment, ribbon/tendril shapes, small dry edge details, weathered leather/cloth breakup, and a hand-painted gothic illustration read.
- Paisley has similarly rich clothing texture, patterned fabric, strong pose language, detailed bubbles, and enough color contrast to feel intentional rather than palette-washed.
- The token proves a small asset can hold strong tactile detail, but it is slightly warmer and more parchment/beige dominant than Vellum and Paisley. Treat it as a material/detail proof, not the main character palette anchor.

Reference hierarchy:

1. Vellum is the ultimate character style reference. Every future promoted proof must be compared directly against Vellum first.
2. Paisley is the secondary contrast reference for brighter, stranger, or more playful units that still need the same dry gothic richness.
3. The token is a small-asset material/detail reference only.
4. Later passing proofs are narrow coverage examples, not equal anchors. Do not average the passing pool into the target style.

Every future audit should include the Vellum-first pairwise comparison sheet, not only the pooled contact sheet. The pooled sheet is useful for scanning the roster, but the pairwise sheet is the decision surface: Vellum on the left, candidate on the right, then Paisley/token/later proofs only as narrow context.

The proof matrix now encodes that hierarchy structurally through `style_contract.reference_policy` and per-proof `reference_role` values. Use `secondary_contrast_anchor` only for Paisley, `small_asset_material_reference` only for the token, `narrow_proof_only` for ordinary accepted/current proof coverage, `review_candidate_not_anchor` for unresolved candidates such as the latest Creep pass, and `negative_example` for rejected examples. A later proof can become a global anchor only if the user explicitly promotes it.

The drift came from treating "matte" as lower-detail smoothness. That is wrong for this game. The style should remove wet/specular shine while keeping dense dry texture, layered costume/material storytelling, and gothic hand-painted richness.

## Main Drift Pattern

Several later candidates match the orange-background workflow and darker palette but lose the Vellum/Paisley richness:

- They simplify surfaces into broad dark shapes instead of dry ornate material.
- They become generic dark-fantasy or creature-concept renders rather than gothic board-game illustrations.
- Monster/brute candidates often keep detail, but it is anatomy/sculpt detail instead of Vellum-like costume/material detail.
- Some candidates pass cutout and board readability while still failing the art-direction target.

This means the proof ledger's "current candidate" status should not be read as full style approval for later units unless the candidate is explicitly compared against Vellum/Paisley for detail richness, not only matte/shiny control.

## Creep Reassessment

Latest Creep candidate:

- Board preview: `outputs/art_pipeline/style_validation/creep_smooth_alien_matte_match_refit_2026_06_30/creep_smooth_alien_matte_match_refit_board_preview.png`
- Raw: `outputs/art_pipeline/style_validation/creep_smooth_alien_matte_match_refit_2026_06_30/creep_smooth_alien_matte_match_refit_raw_selected.png`

Verdict: rejected as the current best style proof.

It corrected one issue by restoring a smoother alien face/body and reducing the corpse/sweaty look, but it overcorrected into a simplified smooth creature. Compared with Vellum and Paisley, it lacks layered dry detail, tactile surface breakup, small gothic accents, and hand-painted material richness. Its foreground edge/detail proxy was also much lower than the reference pair, which matches the visual read: it is clean and readable, but too empty.

Future Creep prompts should keep the smooth alien skin and face, but add dry micro-texture and gothic material richness in non-shiny ways:

- subtle chalk pores, dry mottled skin, dust, scratches, bruised gray-blue variation, thin occult scarring, and hand-painted brush breakup
- dull ink-black tendrils with dry serrated edge texture, not glossy metal or latex
- small gothic accents that do not change identity, such as black cord wraps, tattered matte ribbons, old talisman scraps, or dry charcoal markings
- no ribs, exposed muscle, flayed anatomy, wet gore, hot head highlights, or slick creature sculpt

Post-audit Creep candidate:

- Raw: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_board_preview.png`
- Vellum-first audit sheet: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/raw_anchor_vs_later_contact_sheet.png`
- Ledger role: `review_candidate_not_anchor`

Verdict: current review candidate only. It improves the under-detailed smooth Creep failure by restoring surface breakup, dull ink tendrils, and small gothic material details, with edge/detail proxy `32.65` near Vellum `31.92` and above Paisley `29.07`. It still needs human art-direction approval before live replacement or before broader roster expansion resumes.

## Updated Rule

Before accepting any future unit proof, ask:

1. Does it match Vellum's high-detail dry gothic illustration quality first, not just the palette?
2. Does de-shining preserve tactile detail instead of smoothing the unit into a simplified model?
3. Are the details the right kind: cloth, parchment, dry paint, scratches, dust, dull metal, and gothic ornament, rather than shiny armor, wet anatomy, or generic fantasy sculpting?
4. Does the board-scale version keep the main shape without forcing the raw image to become under-detailed?
5. Is any later passing proof being used only as a narrow comparison, rather than replacing or averaging away the Vellum anchor?

If the answer is no, reject before cutout or demote the candidate even if the cutout is clean. De-shining must preserve high-detail dry rendering.
