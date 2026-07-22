# Phase 2 repair subagent ownership

Task root: `019f858f-005e-77a2-ad04-4d8888019935`

| Worker | Authority | Exact owned paths | Expected output | Validation |
|---|---|---|---|---|
| comparison-board worker | edit | `tools/art/render_phase2_face_board.py`, `tools/art/render_phase2_comparison_boards.py`, `docs/art/phase2_calibration/phase2_face_board.png`, `docs/art/phase2_calibration/comparisons/` | deterministic face and comparison boards using current masters/derivatives and existing anchors | run both scripts; verify image dimensions and source hashes |
| documentation-audit worker | edit | `docs/art/phase2_calibration/phase2_calibration_bible.md`, `docs/art/phase2_calibration/phase2_calibration_manifest.json`, `docs/art/phase2_calibration/phase2_unit_psychology_records.json`, `docs/art/phase2_calibration/prompts/*.md` | remove stale demographic/body contradictions and preserve Board decisions | parse JSON; report exact changed paths and stale phrases retained only as historical warnings |
| provenance-validator worker | edit | `tools/art/validate_phase2_review_evidence.py`, `docs/art/phase2_calibration/phase2_review_evidence_manifest.json` | deterministic master/silhouette/face/96 provenance manifest and validation | run validator successfully; do not edit art or records |

Workers may not edit any other path, run Git state-changing commands, update the canonical brain, or touch the original checkout.
