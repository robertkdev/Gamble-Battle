# Totem Preliminary Artwork Audit

- Date: 2026-07-01
- Status: preliminary artwork audit, not approval.
- Candidate under review: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v17b_residual_outline_buried_vertical_grain_raw_candidate.png`
- Fallback: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v16b_pair_region_subdued_broken_center_raw_candidate.png`
- Source-identity sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_source_identity_review.png`
- Decision zoom sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_decision_zoom.png`
- Review packet: `docs/art/totem_review_decision_packet_2026-07-01.md`

## Verdict

v17b is still the current best Totem research candidate, but it is not accepted and does not unlock cutout or proof-ledger promotion.

The strongest reason to keep v17b in review is that it fixes the main Totem failure more directly than v16b: the paired chest-cup / breastplate memory is weaker while bark texture remains readable and the v15 patch artifacts are avoided. The strongest reason not to approve it automatically is that the Vellum veto still needs human review: v17b may be dry enough and detailed enough, but it must not become a merely palette-matched wood creature with less Vellum-level material richness.

Do not make v18 unless review identifies a new visible target. Current next decision remains one of:

- use v17b for a cutout pass
- use v16b fallback for a cutout pass
- revise Totem with a specific new visible target
- reject this route with a concrete reason

## Gate Read

| Gate | Preliminary read | Why |
| --- | --- | --- |
| Vellum veto | Human review required | v17b is dry and gothic, but Vellum remains the material/detail authority. Do not pass v17b just because it matches palette or looks less glossy. |
| Source identity | Close, watch silhouette | Original Totem identity mostly survives: bark crown, cyan eyes, carved face, guardian stance, clawed hands/feet, and turquoise cues. Watch that v17b is broader and more monster-like than the original tall idol. |
| De-shined bark material | Candidate strength | v17b reads closer to ancient dry bark than polished wood armor. No obvious varnished shine is visible in the review sheets, but human review should still check the upper torso and shoulders at full size. |
| Detail richness | Watch | Bark grain and dry texture survive better than the inpaint and bark-clone controls. The chest correction is darker and more suppressed, so compare the chest crop against Vellum before accepting. |
| Chest-symbol correction | Candidate strength | v17b weakens the paired chest-outline memory more than v16b without the v15 patch/orange-haze artifact. v17d scored lower on residue proxies but is a hard-removal control, not the preferred candidate. |
| Board-scale read | Candidate strength | At 112 px / 88 px / 64 px / 48 px, v17b keeps head, shoulders, torso mass, hands, feet, and wood-guardian read. Board readability cannot rescue a weak full-size raw. |
| Cutout readiness | Not applicable | Cutout is intentionally not run until a human chooses v17b or v16b. |
| Reference role | Pass | v17b is a review candidate only, not a style anchor or passing-pool target. |

## Evidence Notes

The residual-outline stats use the v17 mask and are the best evidence for the final chest-symbol tradeoff:

- v16b baseline under the v17 residual mask: `pair_pigment=402`, `pair_darkline=18736`, `pair_residue_union=19031`
- v17b: `pair_pigment=214`, `pair_darkline=16710`, `pair_residue_union=16885`
- v17d hard-removal control: `pair_pigment=156`, `pair_darkline=15543`, `pair_residue_union=15667`

Read: v17d removes more measured residue, but the purpose is not to erase all Totem chest language. v17b is the better review candidate because it reduces the paired-symbol memory while preserving more natural bark/body continuity.

Earlier stats explain why the current route moved past prior controls:

- v14b kept texture but still left too much paired upper-chest symbol read.
- v15 bark-clone controls broke the paired read but introduced visible patch seams and orange-side haze.
- v16b reduced the paired symbols strongly without v15 patching, but faint circular outline memory remained.

## Human Review Watchpoints

- Does v17b still feel like Totem, not a generic bark brute or monster?
- Does the broader, more jagged v17b silhouette lose too much of the original tall protective idol read?
- Is the chest correction visibly edited, over-darkened, or lower-detail beside Vellum?
- Does any bark/shoulder highlight read like polished carved armor rather than dry bark?
- At board scale, is the small turquoise cue enough to preserve Totem identity without returning to paired chest cups?

## Decision Boundary

This audit does not change the proof ledger. It should be used before the user chooses a cutout pass. If v17b or v16b is chosen, the next artifact must be a separate cutout/edge pass and a proof-specific review packet.
