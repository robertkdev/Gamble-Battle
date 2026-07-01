# Unit Art Cutout Orange-Fringe Audit

- Date: 2026-07-01
- CSV: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_negative_control_accept_guard/cutout_orange_fringe_audit/unit_art_cutout_orange_fringe_audit.csv`
- Review sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_negative_control_accept_guard/cutout_orange_fringe_audit/unit_art_cutout_orange_fringe_review_sheet.png`
- Purpose: objectively catch safety-orange background contamination in transparent cutouts before a proof is accepted or used as visual context.
- Scope: cutout quality only. This does not approve style, matte finish, identity, or board readability.
- Input rule: the gate reads only each cutout's RGBA pixels. It does not load raw art, board previews, Vellum, Paisley, the token, or any other reference image.

## Objective Background-Contamination Gate

- Edge band radius: `4` px.
- Pass threshold: edge-orange pixels <= `50`, edge-orange ratio <= `0.0600%`, and soft-alpha orange pixels <= `20`.
- The gate does not compare to Vellum, Paisley, the token, or any other reference image. It tests each cutout against the known safety-orange background color family directly.
- Interior orange/gold pixels are counted but do not fail the audit by themselves; the fail gate is edge/soft-alpha residue because that is the visible background-contamination risk.

## Summary

- Rows audited: `23`
- Rows flagged for orange-fringe cleanup: `1`
- Accepted/reference rows flagged: `0`
- Current-candidate rows flagged: `0`

## Flagged Rows

| id | proof status | edge orange | edge ratio | soft orange | issue |
| --- | --- | ---: | ---: | ---: | --- |
| `creep_unit_refit_rejected` | `rejected` | 75 | 0.0456% | 6 | edge_background_orange_contamination |

## Decision Rule

- Accepted/reference rows must have no measurable safety-orange background contamination above the objective gate. If an accepted proof fails here, re-run cutout cleanup before using it as a reference.
- Current candidates that fail can stay in the ledger as review candidates, but they need an edge-orange-clean pass before acceptance or live asset replacement.
- Review the PNG sheet before trusting the metric when the character has intentional orange materials near the silhouette.
