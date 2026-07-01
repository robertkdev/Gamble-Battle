# Unit Art Candidate Style Triage

- Generated: 2026-07-01
- Metrics source: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_board_decision_sheet/style_drift_audit_all_current/foreground_detail_metrics.csv`
- Visual review sheet: `outputs/art_pipeline/style_validation/workflow_validation_2026_07_01_board_decision_sheet/candidate_style_triage/candidate_style_triage_review_sheet.png`
- Primary rule: Vellum is the ultimate character reference. Metrics are proxies only; visual side-by-side review decides.
- Passing-pool rule: accepted/current proofs remain narrow evidence by `reference_role` unless the user explicitly promotes one.

## Summary

- Non-reference rows reviewed: 16
- High-risk re-review rows: 5
- Review-gate rows: 1

High-risk here means the candidate is materially below Paisley or Vellum on edge/contrast proxies and should not be allowed to pull the target style, even if the image has a clean cutout or matches the palette.

## Highest Risk Rows

- `Morrak` / `morrak_polearm_executioner_refit`: edge_detail_below_vellum, contrast_far_below_paisley, candidate_not_accepted (edge vs Vellum -5.07, contrast vs Vellum -6.57).
- `Teller` / `teller_contract_mogul_refit`: edge_detail_far_below_paisley, candidate_not_accepted (edge vs Vellum -11.10, contrast vs Vellum -1.35).
- `Bo` / `bo_large_brute_refit`: edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted (edge vs Vellum -10.74, contrast vs Vellum -4.92).
- `Axiom` / `axiom_compact_scholar_refit`: edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted (edge vs Vellum -10.35, contrast vs Vellum -4.89).
- `Sari` / `sari_spectral_tendril_refit`: edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted (edge vs Vellum -9.39, contrast vs Vellum -6.37).

## Full Triage Table

| Label | Proof | Status | Role | Edge vs Vellum | Contrast vs Vellum | Flags | Stance |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| REF Vellum raw | `vellum_raw_anchor` | `reference` | `primary_anchor` | 0.00 | 0.00 | none | ultimate_reference |
| REF Paisley | `paisley_goth_bubble_refit` | `accepted` | `secondary_contrast_anchor` | -2.85 | -0.34 | none | reference_context_not_primary |
| REF Token | `ability_token_contract_mark` | `accepted` | `small_asset_material_reference` | 7.80 | 20.53 | none | reference_context_not_primary |
| Kythera | `kythera_mummy_goth_refit` | `accepted` | `narrow_proof_only` | 13.96 | 17.94 | metric_detail_near_or_above_vellum | metrics_do_not_replace_visual_review |
| Creep | `creep_vellum_primary_detail_refit` | `current_candidate` | `review_candidate_not_anchor` | 0.73 | 2.56 | human_review_gate, candidate_not_accepted | next_gate_human_review_required |
| Grint | `grint_hard_matte_refit` | `accepted` | `narrow_proof_only` | -5.38 | -3.60 | edge_detail_below_vellum, contrast_below_vellum | needs_vellum_pairwise_visual_review |
| Korath | `korath_haloed_tank_refit` | `current_candidate` | `narrow_proof_only` | 17.72 | 21.12 | candidate_not_accepted | metrics_do_not_replace_visual_review |
| Luna | `luna_bright_caster_refit` | `current_candidate` | `narrow_proof_only` | 6.93 | 3.87 | candidate_not_accepted | metrics_do_not_replace_visual_review |
| Morrak | `morrak_polearm_executioner_refit` | `current_candidate` | `narrow_proof_only` | -5.07 | -6.57 | edge_detail_below_vellum, contrast_far_below_paisley, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Teller | `teller_contract_mogul_refit` | `current_candidate` | `narrow_proof_only` | -11.10 | -1.35 | edge_detail_far_below_paisley, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Bo | `bo_large_brute_refit` | `current_candidate` | `narrow_proof_only` | -10.74 | -4.92 | edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Axiom | `axiom_compact_scholar_refit` | `current_candidate` | `narrow_proof_only` | -10.35 | -4.89 | edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted | high_risk_re_review_before_acceptance |
| Volt | `volt_attached_energy_refit` | `current_candidate` | `narrow_proof_only` | -5.45 | 9.62 | edge_detail_below_vellum, candidate_not_accepted | needs_vellum_pairwise_visual_review |
| Vykos | `vykos_pale_sanguine_refit` | `current_candidate` | `narrow_proof_only` | -3.73 | 17.06 | edge_detail_below_vellum, candidate_not_accepted | needs_vellum_pairwise_visual_review |
| Brute | `brute_guardian_bulk_refit` | `current_candidate` | `narrow_proof_only` | -5.06 | 0.22 | edge_detail_below_vellum, very_muted_color_proxy, candidate_not_accepted | needs_vellum_pairwise_visual_review |
| Bonko | `bonko_wiry_raider_refit` | `current_candidate` | `narrow_proof_only` | -1.42 | 7.23 | candidate_not_accepted | metrics_do_not_replace_visual_review |
| Hexeon | `hexeon_time_blade_refit` | `current_candidate` | `narrow_proof_only` | 4.03 | 1.67 | very_muted_color_proxy, candidate_not_accepted | metrics_do_not_replace_visual_review |
| Totem | `totem_dry_wood_guardian_refit` | `current_candidate` | `narrow_proof_only` | 0.45 | 0.48 | candidate_not_accepted | metrics_do_not_replace_visual_review |
| Sari | `sari_spectral_tendril_refit` | `current_candidate` | `narrow_proof_only` | -9.39 | -6.37 | edge_detail_far_below_paisley, contrast_far_below_paisley, very_muted_color_proxy, candidate_not_accepted | high_risk_re_review_before_acceptance |

## Use

- Start visual review from the Vellum pairwise sheet, not this table.
- Use the visual review sheet as a shortcut for the rows most likely to drift away from Vellum.
- If a row is high-risk, compare it beside Vellum before accepting or using it as prompt context.
- If a high-risk row is already accepted, keep it narrow and do not let it influence the global target without explicit user review.
- If a row is a current candidate, leave it out of live assets until the user approves it.
