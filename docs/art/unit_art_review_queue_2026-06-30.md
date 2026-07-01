# Unit Art Review Queue

- Generated: 2026-07-01
- Current candidates needing review: 14
- Next gate unit: `creep`
- Next gate reason: Revise Creep before Veyra or broader roster work; user wants smooth alien identity restored and Vellum-level matte gothic detail locked harder.
- Candidate style triage: `docs/art/unit_art_candidate_style_triage_2026-07-01.md`
- Current gate decision packet: `docs/art/creep_review_decision_packet_2026-07-01.md`
- Current gate scorecard template: `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json`

## Review Rules

- Review Vellum side by side first at raw scale and board scale. Use the reference-ladder sheet to see Vellum, Paisley, token, and candidate in one row; Paisley and token remain secondary/narrow references.
- Do not let the growing passing pool muddy the target. Passing means narrow evidence, not a new average style.
- Use candidate style triage as a warning layer only. It can flag likely drift, but final decisions still require visual Vellum-first review.
- Approving a candidate can make it an accepted proof for its coverage group, but does not promote it to a global style anchor.
- Rejection needs a concrete reason that can become a future negative prompt or failure gate.
- Do not replace live `assets/units/*.png` files from this queue without explicit user approval.
- Do not continue to Veyra or broader roster generation until the next gate is resolved.

## Decision Commands

After the user decides, apply the review result through `tools/art/apply_unit_art_review_decision.py` instead of hand-editing the proof ledger.

For the current Creep gate, fill out the tracked scorecard worksheet first. It defaults every gate to `revise`; approval only works after every Vellum-first gate is deliberately changed to `pass`.

```powershell
python tools\art\apply_unit_art_review_decision.py --proof-id <proof_id> --decision accept --reason "<human-approved reason>" --next-unit-id <next_unit_id> --scorecard-json <scorecard_template_json>
python tools\art\apply_unit_art_review_decision.py --proof-id <proof_id> --decision reject --reason "<concrete failure reason>" --scorecard-json <scorecard_template_json>
python tools\art\apply_unit_art_review_decision.py --proof-id <proof_id> --decision request_revision --reason "<needed change>" --scorecard-json <scorecard_template_json>
```

Accepting a review candidate requires every scorecard gate to be recorded as `pass`, and records it as an accepted narrow proof only. The helper does not promote candidates into global style anchors; Vellum stays the primary/ultimate reference unless the user explicitly says otherwise. If a proof has no tracked scorecard template yet, rebuild its review packet before applying a decision.

## Next Gate

### Creep (`creep`)

- Priority: `next_gate`
- Proof id: `creep_vellum_primary_detail_refit`
- Reference role: `review_candidate_not_anchor`
- Coverage: `other_unit, goth_horror_anchor, monster_assassin, detached_effects`
- Raw: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_board_preview.png`
- Style audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/raw_anchor_vs_later_contact_sheet.png`
- Vellum pairwise audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/vellum_first_pairwise_raw_comparison.png`
- Reference ladder audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/reference_ladder_raw_comparison.png`
- Scorecard template: `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json`
- Active revision request: User critique requires another Creep pass: restore the original smooth alien face and uninterrupted gray-blue skin while pushing the finish closer to Vellum-level matte gothic dry detail; current candidate still does not fully meet the Vellum matte/detail target.
- Decision needed: revise before approval.

## Candidate Backlog

### Axiom (`axiom`)

- Priority: `candidate_backlog`
- Proof id: `axiom_compact_scholar_refit`
- Reference role: `narrow_proof_only`
- Coverage: `humanoid_mage, small_narrow`
- Raw: `outputs/art_pipeline/style_validation/axiom_compact_scholar_refit_2026_06_30/axiom_compact_scholar_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/axiom_compact_scholar_refit_2026_06_30/axiom_compact_scholar_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Bo (`bo`)

- Priority: `candidate_backlog`
- Proof id: `bo_large_brute_refit`
- Reference role: `narrow_proof_only`
- Coverage: `large_tank, monster_assassin, weapon_heavy, goth_horror_anchor`
- Raw: `outputs/art_pipeline/style_validation/bo_large_brute_refit_2026_06_30/bo_large_brute_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/bo_large_brute_refit_2026_06_30/bo_large_brute_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Bonko (`bonko`)

- Priority: `candidate_backlog`
- Proof id: `bonko_wiry_raider_refit`
- Reference role: `narrow_proof_only`
- Coverage: `monster_assassin, weapon_heavy, small_narrow`
- Raw: `outputs/art_pipeline/style_validation/bonko_wiry_raider_refit_2026_06_30/bonko_wiry_raider_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/bonko_wiry_raider_refit_2026_06_30/bonko_wiry_raider_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Brute (`brute`)

- Priority: `candidate_backlog`
- Proof id: `brute_guardian_bulk_refit`
- Reference role: `narrow_proof_only`
- Coverage: `large_tank, guardian_bulk, stone_bone_construct`
- Raw: `outputs/art_pipeline/style_validation/brute_guardian_bulk_refit_2026_06_30/brute_guardian_bulk_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/brute_guardian_bulk_refit_2026_06_30/brute_guardian_bulk_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Hexeon (`hexeon`)

- Priority: `candidate_backlog`
- Proof id: `hexeon_time_blade_refit`
- Reference role: `narrow_proof_only`
- Coverage: `monster_assassin, detached_effects`
- Raw: `outputs/art_pipeline/style_validation/hexeon_time_blade_refit_2026_06_30/hexeon_time_blade_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/hexeon_time_blade_refit_2026_06_30/hexeon_time_blade_refit_board_preview_edgeclean.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Korath (`korath`)

- Priority: `candidate_backlog`
- Proof id: `korath_haloed_tank_refit`
- Reference role: `narrow_proof_only`
- Coverage: `large_tank`
- Raw: `outputs/art_pipeline/style_validation/korath_haloed_tank_refit_2026_06_30/korath_haloed_tank_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/korath_haloed_tank_refit_2026_06_30/korath_haloed_tank_refit_board_preview_edgeclean.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Luna (`luna`)

- Priority: `candidate_backlog`
- Proof id: `luna_bright_caster_refit`
- Reference role: `narrow_proof_only`
- Coverage: `humanoid_mage, detached_effects`
- Raw: `outputs/art_pipeline/style_validation/luna_bright_caster_refit_2026_06_30/luna_bright_caster_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/luna_bright_caster_refit_2026_06_30/luna_bright_caster_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Morrak (`morrak`)

- Priority: `candidate_backlog`
- Proof id: `morrak_polearm_executioner_refit`
- Reference role: `narrow_proof_only`
- Coverage: `monster_assassin, weapon_heavy`
- Raw: `outputs/art_pipeline/style_validation/morrak_polearm_executioner_refit_2026_06_30/morrak_polearm_executioner_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/morrak_polearm_executioner_refit_2026_06_30/morrak_polearm_executioner_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Sari (`sari`)

- Priority: `candidate_backlog`
- Proof id: `sari_spectral_tendril_refit`
- Reference role: `narrow_proof_only`
- Coverage: `monster_assassin, small_narrow, detached_effects`
- Raw: `outputs/art_pipeline/style_validation/sari_spectral_tendril_refit_2026_06_30/sari_spectral_tendril_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/sari_spectral_tendril_refit_2026_06_30/sari_spectral_tendril_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Teller (`teller`)

- Priority: `candidate_backlog`
- Proof id: `teller_contract_mogul_refit`
- Reference role: `narrow_proof_only`
- Coverage: `humanoid_mage, weapon_heavy, small_narrow`
- Raw: `outputs/art_pipeline/style_validation/teller_contract_mogul_refit_2026_06_30/teller_contract_mogul_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/teller_contract_mogul_refit_2026_06_30/teller_contract_mogul_refit_board_preview_edgeclean.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Totem (`totem`)

- Priority: `candidate_backlog`
- Proof id: `totem_dry_wood_guardian_refit`
- Reference role: `narrow_proof_only`
- Coverage: `large_tank, humanoid_mage, guardian_bulk, stone_bone_construct`
- Raw: `outputs/art_pipeline/style_validation/totem_dry_wood_guardian_refit_2026_06_30/totem_dry_wood_guardian_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/totem_dry_wood_guardian_refit_2026_06_30/totem_dry_wood_guardian_refit_board_preview.png`
- Active revision request: Revise Totem before any acceptance: keep the bark idol identity but move away from clean fantasy carved armor / stylized game-creature detail and toward Vellum-level dry gothic material richness, dirtier hand-painted surface breakup, heavier shadow, and less polished/heroic rendering.
- Decision needed: revise before approval.

### Volt (`volt`)

- Priority: `candidate_backlog`
- Proof id: `volt_attached_energy_refit`
- Reference role: `narrow_proof_only`
- Coverage: `humanoid_mage, detached_effects`
- Raw: `outputs/art_pipeline/style_validation/volt_attached_energy_refit_2026_06_30/volt_attached_energy_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/volt_attached_energy_refit_2026_06_30/volt_attached_energy_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

### Vykos (`vykos`)

- Priority: `candidate_backlog`
- Proof id: `vykos_pale_sanguine_refit`
- Reference role: `narrow_proof_only`
- Coverage: `large_tank, monster_assassin, weapon_heavy, goth_horror_anchor`
- Raw: `outputs/art_pipeline/style_validation/vykos_pale_sanguine_refit_2026_06_30/vykos_pale_sanguine_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/vykos_pale_sanguine_refit_2026_06_30/vykos_pale_sanguine_refit_board_preview.png`
- Decision needed: approve as accepted proof, reject with reason, or request revision.

## Approval Checklist

- The raw reads as high-detail dry gothic illustration beside Vellum, not just as a dark palette match.
- Skin/materials are matte, dry, absorptive, dusty, or cloth/parchment/bone/dull-metal-like, not sweaty, wet, glossy, plastic, latex, or polished.
- Unit identity remains recognizable from the source sprite.
- Board preview keeps head, torso, hands, weapon/prop, and main effect readable at 96 px.
- Cutout/review sheet and orange-fringe audit have no unacceptable safety-orange edge residue or missing identity-critical detached effects.
- The proof ledger `reference_role` remains correct after the decision.

## Rejection Checklist

When rejecting, record which concrete failure happened:

- too glossy or sweaty
- too cartoon/comic/toy-like
- too low-detail or smooth after de-shining
- wrong identity or silhouette
- wrong detail type: wet anatomy, shiny armor, generic fantasy sculpting, or noisy chaos
- bad orange background, orange-fringe audit failure, or alpha/cutout failure
- poor 96 px board read
