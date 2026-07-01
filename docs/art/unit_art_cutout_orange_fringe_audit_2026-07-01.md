# Unit Art Cutout Orange-Fringe Audit

- Date: 2026-07-01
- CSV: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_cutout_edgecleaned_candidates/cutout_orange_fringe_audit/unit_art_cutout_orange_fringe_audit.csv`
- Review sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_cutout_edgecleaned_candidates/cutout_orange_fringe_audit/unit_art_cutout_orange_fringe_review_sheet.png`
- Purpose: quickly catch safety-orange fringe on transparent cutouts before a proof is accepted or used as visual context.
- Scope: cutout quality only. This does not approve style, matte finish, identity, or board readability.

## Vellum/Paisley Cutout Cleanliness Baseline

- Edge band radius: `4` px.
- Pass threshold: edge-orange pixels <= `50`, edge-orange ratio <= `0.0600%`, and soft-alpha orange pixels <= `20`.
- Vellum is included from the prompt-case anchor cutout. Paisley and the token are included from the proof ledger.
- Interior orange/gold pixels are counted but do not fail the audit by themselves; the gate is edge/soft-alpha residue because that is the visible fringe risk.

## Summary

- Rows audited: `24`
- Rows flagged for orange-fringe cleanup: `1`
- Accepted/reference rows flagged: `0`
- Current-candidate rows flagged: `0`

## Flagged Rows

| id | proof status | edge orange | edge ratio | soft orange | issue |
| --- | --- | ---: | ---: | ---: | --- |
| `creep_unit_refit_rejected` | `rejected` | 75 | 0.0456% | 6 | edge_orange_pixels_above_vellum_baseline |

## Decision Rule

- Accepted/reference rows should stay under the Vellum/Paisley baseline. If an accepted proof fails here, re-run cutout cleanup before using it as a reference.
- Current candidates that fail can stay in the ledger as review candidates, but they need an edge-orange-clean pass before acceptance or live asset replacement.
- Review the PNG sheet before trusting the metric when the character has intentional orange materials near the silhouette.
