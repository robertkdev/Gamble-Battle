# Unit Art Candidate Style Triage

- Generated: 2026-07-01
- Metrics source: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_cutout_review_sheets/style_drift_audit_all_current/foreground_detail_metrics.csv`
- Visual review sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_cutout_review_sheets/candidate_style_triage/candidate_style_triage_review_sheet.png`
- Style negative-control sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_cutout_review_sheets/candidate_style_triage/style_negative_control_review_sheet.png`
- Primary rule: Vellum is the ultimate character reference. Metrics are proxies only; visual side-by-side review decides.
- Passing-pool rule: accepted/current proofs remain narrow evidence by `reference_role` unless the user explicitly promotes one.

## Summary

- Non-reference rows reviewed: 16
- Human negative-control failures: 1
- Required style negative controls: 1
- High-risk re-review rows: 5
- Review-gate rows: 1
- Prompt-context quarantined rows: 15
- Metric false-positive controls: 1
- Hot-highlight matte-review rows: 2

Human negative-control failures are hard fails recorded from visual review. They prove the audit can reject a candidate that has palette/detail but still misses Vellum's dry gothic finish.

Required style negative controls are expected to fail every run. Totem is the current required negative control; if it stops failing, the style audit is broken or the ledger has changed without a new human promotion decision.

Metric false-positive controls are required failures whose edge/detail and contrast proxies are near or above Vellum. They prove that proxy metrics cannot approve style by themselves.

Hot-highlight matte-review rows have enough near-white foreground pixels to deserve visual review for possible sheen, pale-material glare, or board-scale hot spots. This is a proxy warning only; pale parchment, bone, ivory, or holy materials can be valid if they still read dry beside Vellum.

High-risk here means the candidate is materially below Paisley or Vellum on edge/contrast proxies and should not be allowed to pull the target style, even if the image has a clean cutout or matches the palette.

Prompt-context quarantine is the machine-readable guardrail for the user's warning about the passing pool getting muddy. Quarantined rows must not be used as prompt/style context until they pass a fresh Vellum-first visual review or receive an explicit user promotion/reclassification.

Small-asset context rows are not character palette references. The token can inform small non-character material treatment, but it cannot pull unit character color, silhouette, or style decisions away from Vellum.

## Required Style Negative Controls

- `Totem` / `totem_dry_wood_guardian_refit`: expected to fail style triage; actual stance `style_audit_failed_negative_control`.

## Human Negative-Control Failures

- `Totem` / `totem_dry_wood_guardian_refit`: candidate_not_accepted, required_style_negative_control, human_style_fail_negative_control, user says Totem should fail: palette/detail matched but Vellum-level matte gothic finish did not, metric_false_positive_style_sentinel (edge vs Vellum 0.45, contrast vs Vellum 0.48).

## Metric False-Positive Controls

- `Totem` / `totem_dry_wood_guardian_refit`: proxy metrics look acceptable (edge vs Vellum 0.45, contrast vs Vellum 0.48), but visual review still fails it for missing the matte gothic target.

## Hot-Highlight Matte Review

- `Kythera` / `kythera_mummy_goth_refit`: hot highlight ratio 0.796%, delta vs Vellum 0.796%, p99 luma 220.00; review beside Vellum to confirm this is dry pale material rather than sheen.
- `Korath` / `korath_haloed_tank_refit`: hot highlight ratio 0.686%, delta vs Vellum 0.686%, p99 luma 221.00; review beside Vellum to confirm this is dry pale material rather than sheen.

## Highest Risk Rows

- `Morrak` / `morrak_polearm_executioner_refit`: edge_detail_below_vellum, contrast_far_below_paisley, candidate_not_accepted (edge vs Vellum -5.07, contrast vs Vellum -6.57).
- `Teller` / `teller_contract_mogul_refit`: edge_detail_far_below_paisley, candidate_not_accepted (edge vs Vellum -11.24, contrast vs Vellum -1.54).
- `Bo` / `bo_large_brute_refit`: edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted (edge vs Vellum -10.74, contrast vs Vellum -4.92).
- `Axiom` / `axiom_compact_scholar_refit`: edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted (edge vs Vellum -10.35, contrast vs Vellum -4.89).
- `Sari` / `sari_spectral_tendril_refit`: edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted (edge vs Vellum -9.39, contrast vs Vellum -6.37).

## Prompt-Context Quarantine

- `Creep` / `creep_vellum_primary_detail_refit`: `blocked_current_candidate`; stance `next_gate_human_review_required`; human_review_gate, candidate_not_accepted.
- `Grint` / `grint_hard_matte_refit`: `blocked_until_vellum_pairwise_review`; stance `needs_vellum_pairwise_visual_review`; edge_detail_below_vellum, contrast_below_vellum.
- `Korath` / `korath_haloed_tank_refit`: `blocked_current_candidate`; stance `metrics_do_not_replace_visual_review`; hot_highlight_matte_review, candidate_not_accepted.
- `Luna` / `luna_bright_caster_refit`: `blocked_current_candidate`; stance `metrics_do_not_replace_visual_review`; candidate_not_accepted.
- `Morrak` / `morrak_polearm_executioner_refit`: `blocked_current_candidate`; stance `high_risk_re_review_before_acceptance`; edge_detail_below_vellum, contrast_far_below_paisley, candidate_not_accepted.
- `Teller` / `teller_contract_mogul_refit`: `blocked_current_candidate`; stance `high_risk_re_review_before_acceptance`; edge_detail_far_below_paisley, candidate_not_accepted.
- `Bo` / `bo_large_brute_refit`: `blocked_current_candidate`; stance `high_risk_re_review_before_acceptance`; edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted.
- `Axiom` / `axiom_compact_scholar_refit`: `blocked_current_candidate`; stance `high_risk_re_review_before_acceptance`; edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted.
- `Volt` / `volt_attached_energy_refit`: `blocked_current_candidate`; stance `needs_vellum_pairwise_visual_review`; edge_detail_below_vellum, candidate_not_accepted.
- `Vykos` / `vykos_pale_sanguine_refit`: `blocked_current_candidate`; stance `needs_vellum_pairwise_visual_review`; edge_detail_below_vellum, candidate_not_accepted.
- `Brute` / `brute_guardian_bulk_refit`: `blocked_current_candidate`; stance `needs_vellum_pairwise_visual_review`; edge_detail_below_vellum, very_muted_color_proxy, candidate_not_accepted.
- `Bonko` / `bonko_wiry_raider_refit`: `blocked_current_candidate`; stance `metrics_do_not_replace_visual_review`; candidate_not_accepted.
- `Hexeon` / `hexeon_time_blade_refit`: `blocked_current_candidate`; stance `metrics_do_not_replace_visual_review`; very_muted_color_proxy, candidate_not_accepted.
- `Totem` / `totem_dry_wood_guardian_refit`: `blocked_style_negative_control`; stance `style_audit_failed_negative_control`; candidate_not_accepted, required_style_negative_control, human_style_fail_negative_control, user says Totem should fail: palette/detail matched but Vellum-level matte gothic finish did not, metric_false_positive_style_sentinel.
- `Sari` / `sari_spectral_tendril_refit`: `blocked_current_candidate`; stance `high_risk_re_review_before_acceptance`; edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted.

## Full Triage Table

| Label | Proof | Status | Role | Prompt context | Edge vs Vellum | Contrast vs Vellum | Hot highlight % | Flags | Stance |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | --- | --- |
| REF Vellum raw | `vellum_raw_anchor` | `reference` | `primary_anchor` | `primary_anchor` | 0.00 | 0.00 | 0.000 | none | ultimate_reference |
| REF Paisley | `paisley_goth_bubble_refit` | `accepted` | `secondary_contrast_anchor` | `reference_context_only` | -2.85 | -0.34 | 0.001 | none | reference_context_not_primary |
| REF Token | `ability_token_contract_mark` | `accepted` | `small_asset_material_reference` | `small_asset_context_only_not_character_palette` | 7.80 | 20.53 | 0.013 | none | reference_context_not_primary |
| Kythera | `kythera_mummy_goth_refit` | `accepted` | `narrow_proof_only` | `narrow_context_only_not_anchor` | 13.96 | 17.94 | 0.796 | hot_highlight_matte_review | metrics_do_not_replace_visual_review |
| Creep | `creep_vellum_primary_detail_refit` | `current_candidate` | `review_candidate_not_anchor` | `blocked_current_candidate` | 0.73 | 2.56 | 0.001 | human_review_gate, candidate_not_accepted | next_gate_human_review_required |
| Grint | `grint_hard_matte_refit` | `accepted` | `narrow_proof_only` | `blocked_until_vellum_pairwise_review` | -5.38 | -3.60 | 0.005 | edge_detail_below_vellum, contrast_below_vellum | needs_vellum_pairwise_visual_review |
| Korath | `korath_haloed_tank_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | 17.73 | 21.12 | 0.686 | hot_highlight_matte_review, candidate_not_accepted | metrics_do_not_replace_visual_review |
| Luna | `luna_bright_caster_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | 6.93 | 3.87 | 0.020 | candidate_not_accepted | metrics_do_not_replace_visual_review |
| Morrak | `morrak_polearm_executioner_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -5.07 | -6.57 | 0.005 | edge_detail_below_vellum, contrast_far_below_paisley, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Teller | `teller_contract_mogul_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -11.24 | -1.54 | 0.031 | edge_detail_far_below_paisley, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Bo | `bo_large_brute_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -10.74 | -4.92 | 0.000 | edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Axiom | `axiom_compact_scholar_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -10.35 | -4.89 | 0.005 | edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Volt | `volt_attached_energy_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -5.45 | 9.62 | 0.250 | edge_detail_below_vellum, candidate_not_accepted | needs_vellum_pairwise_visual_review |
| Vykos | `vykos_pale_sanguine_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -3.73 | 17.06 | 0.084 | edge_detail_below_vellum, candidate_not_accepted | needs_vellum_pairwise_visual_review |
| Brute | `brute_guardian_bulk_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -5.06 | 0.22 | 0.045 | edge_detail_below_vellum, very_muted_color_proxy, candidate_not_accepted | needs_vellum_pairwise_visual_review |
| Bonko | `bonko_wiry_raider_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -1.42 | 7.23 | 0.074 | candidate_not_accepted | metrics_do_not_replace_visual_review |
| Hexeon | `hexeon_time_blade_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | 4.05 | 1.64 | 0.011 | very_muted_color_proxy, candidate_not_accepted | metrics_do_not_replace_visual_review |
| Totem | `totem_dry_wood_guardian_refit` | `current_candidate` | `narrow_proof_only` | `blocked_style_negative_control` | 0.45 | 0.48 | 0.007 | candidate_not_accepted, required_style_negative_control, human_style_fail_negative_control, user says Totem should fail: palette/detail matched but Vellum-level matte gothic finish did not, metric_false_positive_style_sentinel | style_audit_failed_negative_control |
| Sari | `sari_spectral_tendril_refit` | `current_candidate` | `narrow_proof_only` | `blocked_current_candidate` | -9.39 | -6.37 | 0.008 | edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted | high_risk_re_review_before_acceptance |

## Use

- Start visual review from the Vellum pairwise sheet, not this table.
- Use the visual review sheet as a shortcut for the rows most likely to drift away from Vellum.
- If a row is high-risk or prompt-context quarantined, compare it beside Vellum before accepting or using it as prompt context.
- If a high-risk row is already accepted, keep it quarantined from prompt influence and do not let it influence the global target without explicit user review.
- If a row is a current candidate, leave it out of live assets until the user approves it.
