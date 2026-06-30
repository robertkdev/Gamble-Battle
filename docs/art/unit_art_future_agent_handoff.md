# Gamble Battle Unit Art Future Agent Handoff

Use this when a new Codex agent has no conversation history and needs to continue the Gamble Battle unit-art workflow without drifting away from the approved direction.

## Current State

- The larger art-workflow goal is active, not complete.
- Vellum is the only primary/ultimate character style anchor.
- Paisley is the secondary contrast anchor.
- The Vellum contract token is the small-asset material reference.
- Later passing/current proofs are narrow coverage examples only. Do not average them into the target style.
- The current Creep pass is a review candidate only: `creep_vellum_primary_detail_refit_2026_06_30`.
- Do not generate Veyra or broader roster batches until the user approves or rejects the Creep review candidate.
- Do not replace any live `assets/units/*.png` file without explicit user approval.

## First Files To Read

Read these in order:

1. `docs/art/unit_art_style_workflow.md`
2. `docs/art/unit_art_workflow_completion_audit_2026-06-30.md`
3. `docs/art/unit_art_proof_matrix.json`
4. `docs/art/unit_art_roster_prompt_matrix.json`
5. `docs/art/unit_art_style_drift_audit_2026-06-30.md`

The completion audit is the current truth for remaining blockers. At the latest audit, 23 roster entries were checked: 3 accepted unit proofs, 14 current-candidate unit proofs needing human approval, and 6 roster entries with no visual proof (`berebell`, `cashmere`, `mortem`, `nyxa`, `repo`, `veyra`).

## Non-Negotiable Style Rules

- Compare every serious candidate side by side against Vellum first.
- Matte does not mean low-detail. De-shining must preserve tactile dry detail, layered costume/material storytelling, scratches, dust, worn edges, and hand-painted surface breakup.
- Reject sweaty skin, wet shine, glossy leather, latex, plastic, polished metal, chrome, clean fantasy render, cartoon/comic style, toy proportions, anime/gacha, and cinematic rim-light polish.
- Use flat solid safety-orange `#f84401` for cutout-bound raw generations.
- Keep the board-scale read at 96 px: head, torso, hands, weapon/prop, and main magic shape must survive.

## Reference Roles

The proof ledger has explicit `reference_role` values:

- `primary_anchor`: Vellum raw anchor only, from `style_contract.reference_policy.primary_anchor`.
- `secondary_contrast_anchor`: Paisley only.
- `small_asset_material_reference`: the Vellum contract token only.
- `narrow_proof_only`: ordinary accepted/current proof coverage for a specific silhouette, material, or cutout risk.
- `review_candidate_not_anchor`: unresolved review candidates such as the latest Creep pass.
- `negative_example`: rejected examples that should teach failure modes, not style targets.

Do not promote a proof into a broader style anchor unless the user explicitly says to.

## Current Next Gate

The next decision is human review of:

- Raw: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_board_preview.png`
- Vellum-first audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/raw_anchor_vs_later_contact_sheet.png`

The Creep candidate improves the under-detailed smooth-creature failure, but it is not accepted and is not a live replacement.

## Standard Validation Command

Run this before handoff:

```powershell
python tools\art\run_unit_art_workflow_validation.py --output-dir outputs\art_pipeline\style_validation\workflow_validation_<date>
```

That command validates the proof policy, completion audit, workflow docs, all 23 generated roster packets, generated packet reference hierarchy, role-labeled style audits, and art-tool syntax.

Godot validation is separate because this repo requires MCP-only Godot execution. Run:

```text
mcp godot run_project projectPath="C:\Users\Flipm\Documents\gamble-battle" scene="tests/rga_testing/validation/RoleMatrixProbe.tscn"
mcp godot get_debug_output
```

Require `errors=[]` before handoff.

## Normal Unit Flow

1. Read the completion audit and proof ledger.
2. Confirm the unit is the correct next gate.
3. Generate a prompt packet with `tools/art/build_unit_roster_prompt_packet.py`.
4. Generate raw candidates without weakening the Vellum-first dry material rules.
5. Reject glossy or textured-background raws before cutout.
6. Run the refined BiRefNet foreground-ML/despill cutout command from the packet.
7. Build or inspect the board preview.
8. Run `tools/art/build_unit_style_drift_audit.py --proof-id <proof_id>`.
9. Update the proof ledger, completion audit, test log, and brain notes.
10. Run the standard validation command plus MCP Godot validation.

## Completion Standard

Do not mark the larger goal complete until current evidence proves:

- every roster entry is either accepted or intentionally scoped out by the user,
- candidate review gates are resolved,
- missing visual proofs are resolved or explicitly deferred,
- non-character assets have more than the single token proof where needed,
- generated prompt packets and style-drift audits still enforce Vellum-first comparison,
- the standard runner and MCP Godot validation pass,
- and the canonical brain is synced with the final state.
