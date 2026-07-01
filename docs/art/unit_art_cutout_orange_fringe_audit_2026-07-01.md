# Unit Art Cutout Orange-Fringe Audit

- Date: 2026-07-01
- CSV: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_raw_field/cutout_orange_fringe_audit/unit_art_cutout_orange_fringe_audit.csv`
- Manifest: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_raw_field/cutout_orange_fringe_audit/unit_art_cutout_orange_fringe_audit_manifest.json`
- Review sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_raw_field/cutout_orange_fringe_audit/unit_art_cutout_orange_fringe_review_sheet.png`
- Purpose: objectively catch safety-orange background contamination in transparent cutouts before a proof is accepted or used as visual context.
- Scope: cutout quality only. This does not approve style, matte finish, identity, or board readability.
- Input rule: cutout-only mode reads only each cutout's RGBA pixels. It cannot prove internal raw-background holes after cleanup has recolored pixels.

## Objective Background-Contamination Gate

- Edge band radius: `4` px.
- Pass threshold: edge-orange pixels <= `50`, edge-orange ratio <= `0.0600%`, soft-alpha orange pixels <= `20`, raw-key/background-field visible pixels <= `0` when a raw source is supplied, and visual background-fringe pixels <= `None` when that threshold is enabled.
- Raw-key/background-field check: pixels within `64` RGB units of reserved safety-orange `#f84401` or inside the border-connected raw orange background field must not remain visible in the cutout alpha matte.
- Visual-fringe check: raw-backed perfect-exit mode also fails measured orange/red or cool-blue background-field residue at raw background pixels on alpha edges or soft matte pixels, then renders those pixels in the review overlay.
- The gate does not compare to Vellum, Paisley, the token, or any other reference image. It tests cutout contamination against the known safety-orange background contract directly.
- Manifest rule: `reference_images_loaded`, `raw_images_loaded`, `board_preview_images_loaded`, and `style_anchor_images_loaded` must all be `false` for cutout-only runs.
- Interior orange/gold pixels in the cutout are counted but do not fail by themselves. Raw-backed mode fails reserved raw background-key or border-connected background-field pixels anywhere and edge/soft visual background-field residue at the matte boundary.

## Summary

- Rows audited: `23`
- Rows flagged for orange-fringe cleanup: `1`
- Protected ledger rows flagged: `0`
- Current-candidate rows flagged: `0`

## Flagged Rows

| id | proof status | edge orange | edge ratio | soft orange | raw-key visible | visual fringe | issue |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| `creep_unit_refit_rejected` | `rejected` | 75 | 0.0456% | 6 | 0 | 5071 | edge_background_orange_contamination |

## Decision Rule

- Protected ledger rows, meaning accepted proofs and anchor/status rows from the proof ledger, must have no measurable safety-orange background contamination above the active objective gate. If one fails here, re-run cutout cleanup before using it as a technical cutout example.
- Current candidates that fail can stay in the ledger as review candidates, but they need an edge-orange/raw-background-field clean pass before acceptance or live asset replacement.
- Perfect-exit claims must use raw-backed mode with strict-zero thresholds so opaque or soft internal background holes, darker orange/red background-field residue, and cool blue spill cannot hide behind recolored cutout RGB.
- Review the PNG sheet before trusting the metric when the character has intentional orange materials near the silhouette.
