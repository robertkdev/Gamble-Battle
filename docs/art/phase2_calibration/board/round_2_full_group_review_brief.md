# Phase 2 full-group Board review - Round 2

## Immutable review cut

Review all twelve current calibration units together and individually. Phase 2 is `READY` only if every applicable gate in `docs/art/unit_art_board_reference_criteria.md` passes, every unit meets a professional concept-art standard, and no blocker survives the single cross-examination.

Units: Korath, Veyra, Cashmere, Pilfer, Nyxa, Creep, Knoll, Quillith, Kett, Luna, Malachor, and Sable.

Authoritative evidence and frozen SHA-256 values:

- criteria: `35d4e26c43baaac050b038d4ce2bc48a1ad19e7bd8532b5d0190416592f56cf8`
- Phase 2 bible: `38c8792bf94c92c827cbb1dc812a56679fb5b64868256cdddad710173eb4d66d`
- Phase 2 manifest: `67f5d1c03856981a4147681aee9610429e233f6b643d1872f4058ae20ff942e9`
- psychology records: `e75d4dd9b3f78f0604d0e9e5dfb7252d3b2f1151f8e5fdf008affc903cba5415`
- 48-image provenance manifest: `7179040c216abe833adfdf92f23936b3c9e453d536d90a11150d013ec709ee7d`
- contact sheet: `d8a993e18e4be3fe7d266c4485dc0b3ad22a108b250dedffe02bb6db2b0a1bfa`
- compact 96 px board: `f6c6cdbd1ac94b11ba65c894743296d8bce61e11ca1d0caea4c5f2917404d880`
- face/psychology board: `485b487e243fb76580aec3cf63fb28fdfcd2ee7dafafe08c3562f9cfb3f63848`
- role-grouped master board: `40a1722616a70c12f821e0cf9ec07db83b772e0c307a4c98b1cd61b3449f7450`
- role-grouped 96 px lineup: `b5e6b98455fb84d2f755c18e379301ef3826b254dcb1998c2551e1dade50404c`
- approved-Vellum comparison: `73557a378f67b87aab62d82ccb5ff287fea134e3ac54eba493d9f48806647e12`

The approved Vellum raw anchor is `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_selected_raw.png`, SHA-256 `824b55085428af5ef7e0e760edc76400b333c90d8d71c7703aa97848e6752c18`. The comparison renders its matching final cutout, SHA-256 `6f10ecb18330ec3574a4c5950d8cf89a34fcda466f617d9387de2630607b96a0`. Do not use the older shiny background-removal Vellum experiment.

The visual-debug evidence run is `outputs/visual_debug/vdh_runs/phase2-real-unit-calibration-c0d972a0e4`; it has no missing evidence.

## Mandatory per-unit audit

For every unit, explicitly judge:

1. gameplay identity and role silhouette;
2. art-primary and secondary trait-channel separation;
3. three genuinely distinct rough silhouettes and selected-master correspondence;
4. peak-age fighter rule or unanimously justified deliberate-horror exception;
5. hot-adult-woman, lean/toned/feminine lane where applicable;
6. justified protection without forcing armor;
7. all ten survival-psychology fields;
8. face-readable feeling, want, hidden fear/refusal, active strategy, contradiction, and villainous distortion from the same-master crop;
9. threatening/scary read appropriate to the lane;
10. one dominant prop or anatomy, traceable limbs/hands/props, and no clutter;
11. visible supernatural cost;
12. dry tactile world finish against the approved hard-matte Vellum;
13. unchanged-master 96 px identity and role read;
14. individuality against the three nearest roster neighbors.

Korath additionally must pass every Blessed gate. Nyxa may bypass ordinary female-attractiveness gates only if horror/nonhuman predation visibly reads before apparent age. Sable is explicitly nonbinary/androgynous. Armor is never required except when the role and protection logic justify it.

## Group convergence audit

Reject shared black-cloak/leather uniforming, same face or body template, repeated anger/scowls, repeated corset/heel/leg-slit solutions, repeated prop classes, generic gothic demon anatomy, glossy gacha finish, or trait identities dependent on floating effects. Vellum is a quality/material benchmark, not a costume template.

## Required independent-seat output

Return strict JSON with:

- `seat`, `reviewer_id`, `role`, and `independent: true`;
- overall contract and professional verdicts;
- a 12-row unit matrix with `PASS`, `REPAIR`, or `REDESIGN`;
- for each unit, every required and conditional gate verdict;
- visible face evidence for feeling, want, fear/concealment, active strategy, villainous read, and cited cues;
- professional bands for all eight frozen critical dimensions;
- stable blocker IDs `P2R2-<UNIT>-###` or `P2R2-GROUP-###`, exact evidence paths, severity/effect, and objective closure conditions;
- rejected findings and protected dissent;
- no invented requirements and no artwork edits.

Any applicable failed gate, below-professional critical dimension, unresolved blocker, or inadequate evidence means `NOT_READY`.
