# Totem Preliminary Artwork Audit

- Date: 2026-07-01
- Status: preliminary artwork audit, not approval.
- Candidate under review: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v22_original_silhouette_matte_raw_candidate.png`
- Fallback: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v19_tall_idol_matte_raw_candidate.png`
- Older fallback: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v17b_residual_outline_buried_vertical_grain_raw_candidate.png`
- Oldest fallback: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v16b_pair_region_subdued_broken_center_raw_candidate.png`
- Source-identity sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v22_source_identity_review.png`
- Prior source-identity sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v19_source_identity_review.png`
- Decision zoom sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_decision_zoom.png`
- Review packet: `docs/art/totem_review_decision_packet_2026-07-01.md`

## Verdict

v22 is the current best Totem research candidate, but it is not accepted and does not unlock cutout or proof-ledger promotion.

The strongest reason to keep v22 in review is that it is the best identity/material compromise from the v19-v22 branch: square raw frame, original mask/arm/stance rhythm, dry matte bark, and a softened paired chest read. The strongest reason not to approve it automatically is that the central turquoise chest mark may be too strong and must not become a new emblem-like failure.

Current next decision remains one of:

- use v22 for a cutout pass
- use v19 fallback for a cutout pass
- use v17b older fallback for a cutout pass
- use v16b oldest fallback for a cutout pass
- revise Totem with a specific new visible target
- reject this route with a concrete reason

## Gate Read

| Gate | Preliminary read | Why |
| --- | --- | --- |
| Vellum veto | Human review required | v22 is dry and gothic, but Vellum remains the material/detail authority. Do not pass v22 just because it matches palette or looks less glossy. |
| Source identity | Candidate strength, still review | v22 keeps more original Totem cues than v19: square raw frame, mask, stance, arm rhythm, clawed hands/feet, and turquoise cues. Watch that it still belongs to the v19 tall-idol family. |
| De-shined bark material | Candidate strength | v22 reads closer to ancient dry bark than polished wood armor. No obvious varnished shine is visible in the review sheet, but human review should still check the upper torso and shoulders at full size. |
| Detail richness | Candidate strength, still compare | Bark grain and dry texture survive better than the inpaint and bark-clone controls. Compare the identity/material crop against Vellum before accepting so "less shiny" does not become lower-detail. |
| Chest-symbol correction | Candidate strength with watchpoint | v22 weakens the paired chest-outline memory while keeping a Totem cue. Watch that the central turquoise mark does not become a new large emblem. |
| Board-scale read | Candidate strength | At 112 px / 88 px / 64 px / 48 px, v22 keeps head, shoulders, torso mass, hands, feet, and wood-guardian read. Board readability cannot rescue a weak full-size raw. |
| Cutout readiness | Not applicable | Cutout is intentionally not run until a human chooses v22, v19, v17b, or v16b. |
| Reference role | Pass | v22 is a review candidate only, not a style anchor or passing-pool target. |

## Evidence Notes

The residual-outline stats use the v17 mask and remain useful for the v16b/v17b tradeoff:

- v16b baseline under the v17 residual mask: `pair_pigment=402`, `pair_darkline=18736`, `pair_residue_union=19031`
- v17b: `pair_pigment=214`, `pair_darkline=16710`, `pair_residue_union=16885`
- v17d hard-removal control: `pair_pigment=156`, `pair_darkline=15543`, `pair_residue_union=15667`

Read: v17d removes more measured residue, but the purpose is not to erase all Totem chest language. v17b was the better review candidate inside that measured family because it reduced paired-symbol memory while preserving more natural bark/body continuity. v19-v22 are separate visual-review candidates because they change proportions and chest composition enough that the old v17 mask should not be used as proof.

Earlier stats explain why the current route moved past prior controls:

- v14b kept texture but still left too much paired upper-chest symbol read.
- v15 bark-clone controls broke the paired read but introduced visible patch seams and orange-side haze.
- v16b reduced the paired symbols strongly without v15 patching, but faint circular outline memory remained.
- v18 failed as a prompt route because it became a green-background castle/emblem object instead of a full-body Totem unit.
- v19 restored the full-body unit and moved the route forward on matte bark, dry detail, and paired-chest reduction; its watchpoint is portrait-frame/tall humanoid-idol drift.
- v20 and v21 tested identity pullback but did not beat v19: v20 stayed too tall-idol, while v21 improved some source cues but enlarged the central turquoise chest mark.
- v22 is the best current compromise: closer square-frame/source identity than v19 and still dry/matte, with central turquoise strength as the main watchpoint.

## Human Review Watchpoints

- Does v22 still feel like Totem, not a generic bark idol, bark brute, or monster?
- Does the central turquoise mark stay as a broken Totem cue rather than a new large emblem?
- Is the chest correction visibly edited, over-darkened, or lower-detail beside Vellum?
- Does any bark/shoulder highlight read like polished carved armor rather than dry bark?
- At board scale, is the small turquoise cue enough to preserve Totem identity without returning to paired chest cups?

## Decision Boundary

This audit does not change the proof ledger. It should be used before the user chooses a cutout pass. If v22, v19, v17b, or v16b is chosen, the next artifact must be a separate cutout/edge pass and a proof-specific review packet.
