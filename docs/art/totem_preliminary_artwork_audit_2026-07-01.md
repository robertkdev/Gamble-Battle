# Totem Preliminary Artwork Audit

- Date: 2026-07-01
- Status: preliminary artwork audit, not approval.
- Candidate under review: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v19_tall_idol_matte_raw_candidate.png`
- Fallback: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v17b_residual_outline_buried_vertical_grain_raw_candidate.png`
- Older fallback: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v16b_pair_region_subdued_broken_center_raw_candidate.png`
- Source-identity sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v19_source_identity_review.png`
- Prior source-identity sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_source_identity_review.png`
- Decision zoom sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_decision_zoom.png`
- Review packet: `docs/art/totem_review_decision_packet_2026-07-01.md`

## Verdict

v19 is the current best Totem research candidate, but it is not accepted and does not unlock cutout or proof-ledger promotion.

The strongest reason to keep v19 in review is that it fixes the main Totem failure more directly than v17b: the paired chest-cup / breastplate memory is weaker, the bark texture remains readable, the finish is dry/matte, and the v15 patch artifacts are avoided. The strongest reason not to approve it automatically is identity drift: v19 pushes Totem further into a tall humanoid idol, so human review must decide whether that still feels like Totem or whether v17b's prior silhouette is safer.

Current next decision remains one of:

- use v19 for a cutout pass
- use v17b fallback for a cutout pass
- use v16b older fallback for a cutout pass
- revise Totem with a specific new visible target
- reject this route with a concrete reason

## Gate Read

| Gate | Preliminary read | Why |
| --- | --- | --- |
| Vellum veto | Human review required | v19 is dry and gothic, but Vellum remains the material/detail authority. Do not pass v19 just because it matches palette or looks less glossy. |
| Source identity | Close, watch silhouette | Original Totem identity mostly survives: bark crown, cyan eyes, carved face, guardian stance, clawed hands/feet, and turquoise cues. Watch that v19 is taller, more humanoid, and more idol-like than the original source and v17b. |
| De-shined bark material | Candidate strength | v19 reads closer to ancient dry bark than polished wood armor. No obvious varnished shine is visible in the review sheet, but human review should still check the upper torso and shoulders at full size. |
| Detail richness | Candidate strength, still compare | Bark grain and dry texture survive better than the inpaint and bark-clone controls. Compare the identity/material crop against Vellum before accepting so "less shiny" does not become lower-detail. |
| Chest-symbol correction | Candidate strength | v19 weakens the paired chest-outline memory more than v17b without the v15 patch/orange-haze artifact. The current read is visual only because v19 changed proportions enough that the old v17 residual mask is not a direct metric. |
| Board-scale read | Candidate strength | At 112 px / 88 px / 64 px / 48 px, v19 keeps head, shoulders, torso mass, hands, feet, and wood-guardian read. Board readability cannot rescue a weak full-size raw. |
| Cutout readiness | Not applicable | Cutout is intentionally not run until a human chooses v19, v17b, or v16b. |
| Reference role | Pass | v19 is a review candidate only, not a style anchor or passing-pool target. |

## Evidence Notes

The residual-outline stats use the v17 mask and remain useful for the v16b/v17b tradeoff:

- v16b baseline under the v17 residual mask: `pair_pigment=402`, `pair_darkline=18736`, `pair_residue_union=19031`
- v17b: `pair_pigment=214`, `pair_darkline=16710`, `pair_residue_union=16885`
- v17d hard-removal control: `pair_pigment=156`, `pair_darkline=15543`, `pair_residue_union=15667`

Read: v17d removes more measured residue, but the purpose is not to erase all Totem chest language. v17b was the better review candidate inside that measured family because it reduced paired-symbol memory while preserving more natural bark/body continuity. v19 is now a separate visual-review candidate because it changes proportions and chest composition enough that the old v17 mask should not be used as proof.

Earlier stats explain why the current route moved past prior controls:

- v14b kept texture but still left too much paired upper-chest symbol read.
- v15 bark-clone controls broke the paired read but introduced visible patch seams and orange-side haze.
- v16b reduced the paired symbols strongly without v15 patching, but faint circular outline memory remained.
- v18 failed as a prompt route because it became a green-background castle/emblem object instead of a full-body Totem unit.
- v19 restored the full-body unit and moved the route forward on matte bark, dry detail, and paired-chest reduction; its new watchpoint is identity drift into a taller humanoid idol.

## Human Review Watchpoints

- Does v19 still feel like Totem, not a generic bark idol, bark brute, or monster?
- Does the taller, more humanoid v19 silhouette lose too much of the original protective wooden guardian read?
- Is the chest correction visibly edited, over-darkened, or lower-detail beside Vellum?
- Does any bark/shoulder highlight read like polished carved armor rather than dry bark?
- At board scale, is the small turquoise cue enough to preserve Totem identity without returning to paired chest cups?

## Decision Boundary

This audit does not change the proof ledger. It should be used before the user chooses a cutout pass. If v19, v17b, or v16b is chosen, the next artifact must be a separate cutout/edge pass and a proof-specific review packet.
