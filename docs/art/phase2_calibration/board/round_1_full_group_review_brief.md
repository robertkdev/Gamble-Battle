# Phase 2 full-group Board review — Round 1

## Frozen acceptance envelope

Review all twelve current calibration units together and individually against `docs/art/unit_art_board_reference_criteria.md`. Phase 2 is approved only when every unit and the group satisfy that locked reference, the Phase 2 deliverables, and the Blessed special gate. Do not grandfather prior approvals.

Units: Korath, Veyra, Cashmere, Pilfer, Nyxa, Creep, Knoll, Quillith, Kett, Luna, Malachor, and Sable.

Authoritative evidence:

- `docs/art/unit_art_board_reference_criteria.md`
- `docs/art/phase2_calibration/phase2_calibration_bible.md`
- `docs/art/phase2_calibration/phase2_calibration_manifest.json`
- `docs/art/phase2_calibration/phase2_calibration_contact_sheet.png`
- `docs/art/phase2_calibration/phase2_calibration_96px_board.png`
- `assets/concepts/phase2_calibration/<unit>/<unit>_master.png`
- `assets/concepts/phase2_calibration/<unit>/<unit>_silhouettes.png`
- any present same-master `<unit>_face.png` and `<unit>_96px.png` derivatives

Frozen hashes:

- criteria: `35d4e26c43baaac050b038d4ce2bc48a1ad19e7bd8532b5d0190416592f56cf8`
- bible: `db6242fa868bec2551dff7ea3f82d09e760013edd709c5856252e7b694bdc1b4`
- manifest: `8a2bcd661b47a2f8f1bb632e7b6e0e8b13ed7ff90f8859c0db04b89a7448883b`
- contact sheet: `6e48fd76c2bb9ef3873c87f09076f37067ef9f4cfccbfa350a842aeeab645a2f`
- 96px board: `4e10f96bd1a9f2c84f2c016689891f20711350ff239575e331506d5b000a755e`
- canonical review-image tree (37 canonical master/silhouette/face/96px files; excludes the redundant untracked `cashmere_silhouettes_v2.png`): `46558b548588254d941ee96b1dc11c607d0a8495f2ac531388733eee0b3f64ea`

## Mandatory per-unit audit

For every unit, explicitly evaluate:

1. gameplay identity and role silhouette;
2. all assigned trait channels and channel separation;
3. three genuinely distinct rough silhouettes and selected-master correspondence;
4. peak-age fighter rule or the deliberately-horrific exception;
5. female attractiveness lane where applicable, including lean/toned/feminine rather than overly buff or masculine;
6. justified protection and no forced armor;
7. all ten survival-psychology fields, with no inference substituted for missing records;
8. face-readable psychology from a same-master enlargement, including feeling, want, concealed fear/refusal, active survival strategy, and villainous distortion;
9. threatening/scary read appropriate to lane, not merely pretty, eccentric, old, or sad;
10. one dominant prop or anatomical idea, no accessory clutter, and anatomically traceable hands/limbs/props;
11. visible supernatural price;
12. dry tactile world finish and material differentiation;
13. unchanged-master 96px role/identity read without labels;
14. individuality against the closest three roster neighbors.

For Korath, additionally enforce every Blessed gate. For deliberately horrific age exceptions, require the horror/nonhuman premise to be unmistakable before age and never use age alone as the horror mechanism.

## Known user observation to adjudicate, not assume away

Cashmere's current ledger-holding hand lacks a clearly traceable arm and can read as emerging from the book. Treat malformed or ambiguous anatomy as blocking if the pixels support that observation. The candidate was not accepted by the creator merely because it appears in this frozen cut.

## Required Board output

Return:

- contract verdict and professional-standard verdict for the group;
- `READY` only if no unrefuted blocking issue remains;
- a 12-row unit matrix with `PASS`, `REPAIR`, or `REDESIGN` and concise evidence;
- stable blocker IDs in the form `P2R1-<UNIT>-###` or `P2R1-GROUP-###`;
- severity/effect, evidence class, exact evidence paths, and objective closure condition for each blocker;
- rejected findings and protected dissent;
- group convergence findings for same-face, wardrobe, body, prop, material, emotion, and 96px repetition;
- no invented requirements and no new artwork.

This is a read-only audit. Do not edit files.
