# Totem Review Decision Packet

- Generated: 2026-07-01
- Status: `research_candidate`
- Reference role: `review_candidate_not_anchor`
- Candidate: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v22_original_silhouette_matte_raw_candidate.png`
- Fallback candidate: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v19_tall_idol_matte_raw_candidate.png`
- Older fallback candidate: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v17b_residual_outline_buried_vertical_grain_raw_candidate.png`
- Oldest fallback candidate: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v16b_pair_region_subdued_broken_center_raw_candidate.png`
- Decision zoom sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_decision_zoom.png`
- Source-identity review sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v22_source_identity_review.png`
- Prior source-identity review sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v19_source_identity_review.png`
- V17 comparison sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17.png`
- Negative-control sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v15.png`
- Research note: `docs/art/unit_art_creep_process_research_2026-07-01.md`
- Preliminary artwork audit: `docs/art/totem_preliminary_artwork_audit_2026-07-01.md`
- Scorecard template: `docs/art/totem_review_decision_packet_2026-07-01_scorecard_template.json`

## Decision

Totem is in human review, not accepted.

Current recommendation: review v22 as the best current research candidate for the matte gothic Totem route, with v19 kept as the fallback if v22's central turquoise chest mark or square-frame rendering feels too strong. Keep v17b and v16b as older fallbacks if the v19-v22 branch feels too far from the original Totem identity.

The new v22 source-identity sheet exposes the main tradeoff: v22 has the strongest identity/material compromise so far because it returns to a square raw frame and keeps more of the original mask, arm rhythm, and protective stance while preserving the dry bark finish. Its remaining risk is the central turquoise chest strength. v19 keeps slightly stronger chest cleanup but has portrait-frame and tall-idol drift risk.

No live asset has been replaced. If a candidate is approved, the next step is a separate cutout/edge pass and proof-ledger decision path, not immediate promotion into the passing pool.

Read `docs/art/totem_preliminary_artwork_audit_2026-07-01.md` before choosing a cutout pass. It is not an approval; it records the current strengths, watchpoints, and evidence limits.

## Vellum-First Scoring Contract

- Judge beside Vellum first for dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability.
- Check the source-identity review sheet before accepting any Totem candidate. The original/live Totem is the identity reference only, not the style target.
- v22 may pass only if the bark still feels detailed and matte, the square raw frame is useful, and the central turquoise chest does not become a new emblem problem.
- v19 remains the fallback if v22's chest mark feels too strong or its square-frame rendering feels less premium.
- v17b remains the older fallback if the v19-v22 branch feels too far from original Totem identity.
- v16b remains the oldest fallback if v17b's chest correction feels too surgical.
- v14b and v15 are evidence, not alternatives: v14b leaves too much paired chest-symbol read; v15 proves bark-clone patching creates visible artifacts.
- Acceptance records a narrow Totem proof only. It does not make Totem, Creep, or any research candidate a global style anchor.

## Decision Scorecard

| Gate | Evidence to inspect | Pass only if | Revise or reject if |
| --- | --- | --- | --- |
| Vellum veto | Vellum crop/full-body in the decision zoom sheet | Candidate feels dry, detailed, grounded, and matte in the same family as Vellum. | Candidate is merely palette-matched, lower-detail, shiny, plasticky, or too game-card clean. |
| Totem identity | Source-identity review sheet, candidate raw, fallback raw, and board-scale reads | Bark crown, glowing eyes, carved wooden face, guardian stance, clawed hands/feet, and turquoise totem cues survive. | It becomes generic armor, leafy druid, wooden toy, castle/emblem object, or loses Totem identity. |
| De-shined bark material | Candidate raw and identity/material crop | Bark reads ancient, dry, rough, chalky, splintered, and absorptive. | Any varnish, polished wood, wet sheen, lacquer, glossy armor, or slick render remains. |
| Detail richness | Vellum and Totem chest crops | Chest correction preserves bark grain and dry detail. | The fix smears, clones, flattens, or over-darkens the chest below Vellum-level detail. |
| Chest-symbol correction | v14b, v16b, v17b, v19, v22 comparison | v22 meaningfully reduces paired breastplate/cup memory without becoming a new large emblem. | Paired chest ornaments still dominate, the central cue becomes too strong, or the correction looks visibly edited. |
| Board-scale read | 112 px / 88 px / 64 px / 48 px reads | Readability survives without hiding a weak full-size raw. | Board scale only works because detail collapsed or because defects are hidden. |
| Cutout readiness | Not yet run for this research candidate | Gate is `N/A` until human chooses a candidate for cutout. | Do not approve final asset before a dedicated cutout/edge pass. |
| Reference role | This packet and research note | Candidate remains a review candidate, not an anchor. | Any decision treats Totem as a passing-pool anchor without explicit approval. |

Scorecard rule: approve a next cutout pass only if every visual gate passes and cutout readiness remains explicitly pending. Request revision if one or more gates are close but fixable. Reject if Vellum veto, Totem identity, dry material, or detail richness fails.

## Human Reply Contract

- Reply `use Totem v22 for cutout pass` if v22 is the preferred research candidate.
- Reply `use Totem v19 fallback for cutout pass` if v22's chest mark or square-frame rendering is worse.
- Reply `use Totem v17b older fallback for cutout pass` if v19/v22 have too much identity drift.
- Reply `use Totem v16b oldest fallback for cutout pass` if v17b also feels too worked.
- Reply `revise Totem: <needed change>` only if there is a new visible target not already covered by v22, v19, v17b, or v16b.
- Reply `reject Totem route: <reason>` if this route should become a negative example.

## Apply The Decision

Do not run `apply_unit_art_review_decision.py` from this packet yet. These Totem outputs are research artifacts, not proof-ledger entries.

If a human chooses v22, v19, v17b, or v16b, first make a separate cutout/edge pass, then create or update the proof-ledger entry and review packet for that proof artifact.

## Prior Totem Lessons

- v14b: useful texture-preserving route, but upper chest symbols still read like paired ornaments.
- v15: negative control; bark-clone correction broke the paired read but introduced patch seams and orange-side haze.
- v16b: safer fallback; strong paired-symbol reduction without v15 patching, but faint circular outline memory remains.
- v17b: prior best research candidate; narrow residual-outline reduction over v16b while preserving bark texture.
- v18: negative control; prompt drifted into a green-background castle/emblem object and failed full-body unit identity.
- v19: prior best research candidate; stronger matte bark and paired-chest reduction than v17b, with the main risk being portrait-frame/taller humanoid-idol identity drift from original Totem.
- v20: identity-pullback attempt that kept matte bark but did not solve the tall-idol elongation.
- v21: identity-pullback attempt that improved some head/shoulder/stance cues but did not beat v19 and enlarged the central turquoise chest mark.
- v22: current best research candidate pending human review; square raw frame, stronger original mask/arm/stance rhythm, dry matte bark, and softened paired chest read. Main risk is whether the central turquoise chest mark is too strong.
