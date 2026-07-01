# Totem Review Decision Packet

- Generated: 2026-07-01
- Status: `research_candidate`
- Reference role: `review_candidate_not_anchor`
- Candidate: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v17b_residual_outline_buried_vertical_grain_raw_candidate.png`
- Fallback candidate: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_v16b_pair_region_subdued_broken_center_raw_candidate.png`
- Decision zoom sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_decision_zoom.png`
- Source-identity review sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17_source_identity_review.png`
- V17 comparison sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v17.png`
- Negative-control sheet: `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v15.png`
- Research note: `docs/art/unit_art_creep_process_research_2026-07-01.md`
- Preliminary artwork audit: `docs/art/totem_preliminary_artwork_audit_2026-07-01.md`
- Scorecard template: `docs/art/totem_review_decision_packet_2026-07-01_scorecard_template.json`

## Decision

Totem is in human review, not accepted.

Current recommendation: review v17b as the best current research candidate, with v16b kept as the safer fallback if v17b feels overworked in the chest.

Do not create v18 unless human review identifies a new visible target. The current decision zoom already exposes the main tradeoff: v17b has the weakest paired chest-outline memory; v16b is slightly safer and less intervention-heavy.

No live asset has been replaced. If a candidate is approved, the next step is a separate cutout/edge pass and proof-ledger decision path, not immediate promotion into the passing pool.

Read `docs/art/totem_preliminary_artwork_audit_2026-07-01.md` before choosing a cutout pass. It is not an approval; it records the current strengths, watchpoints, and evidence limits.

## Vellum-First Scoring Contract

- Judge beside Vellum first for dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability.
- Check the source-identity review sheet before accepting either Totem candidate. The original/live Totem is the identity reference only, not the style target.
- v17b may pass only if the bark still feels detailed and matte rather than overworked, patched, smeared, glossy, or low-detail.
- v16b remains the fallback if v17b's chest correction feels too surgical.
- v14b and v15 are evidence, not alternatives: v14b leaves too much paired chest-symbol read; v15 proves bark-clone patching creates visible artifacts.
- Acceptance records a narrow Totem proof only. It does not make Totem, Creep, or any research candidate a global style anchor.

## Decision Scorecard

| Gate | Evidence to inspect | Pass only if | Revise or reject if |
| --- | --- | --- | --- |
| Vellum veto | Vellum crop/full-body in the decision zoom sheet | Candidate feels dry, detailed, grounded, and matte in the same family as Vellum. | Candidate is merely palette-matched, lower-detail, shiny, plasticky, or too game-card clean. |
| Totem identity | Source-identity review sheet, candidate raw, fallback raw, and board-scale reads | Bark crown, glowing eyes, carved wooden face, guardian stance, clawed hands/feet, and turquoise totem cues survive. | It becomes generic armor, leafy druid, wooden toy, or loses Totem identity. |
| De-shined bark material | Candidate raw and chest crop | Bark reads ancient, dry, rough, chalky, splintered, and absorptive. | Any varnish, polished wood, wet sheen, lacquer, glossy armor, or slick render remains. |
| Detail richness | Vellum and Totem chest crops | Chest correction preserves bark grain and dry detail. | The fix smears, clones, flattens, or over-darkens the chest below Vellum-level detail. |
| Chest-symbol correction | v14b, v16b, v17b comparison | v17b meaningfully reduces paired breastplate/cup memory without looking patched. | Paired chest ornaments still dominate, or the correction looks visibly edited. |
| Board-scale read | 112 px / 88 px / 64 px / 48 px reads | Readability survives without hiding a weak full-size raw. | Board scale only works because detail collapsed or because defects are hidden. |
| Cutout readiness | Not yet run for this research candidate | Gate is `N/A` until human chooses a candidate for cutout. | Do not approve final asset before a dedicated cutout/edge pass. |
| Reference role | This packet and research note | Candidate remains a review candidate, not an anchor. | Any decision treats Totem as a passing-pool anchor without explicit approval. |

Scorecard rule: approve a next cutout pass only if every visual gate passes and cutout readiness remains explicitly pending. Request revision if one or more gates are close but fixable. Reject if Vellum veto, Totem identity, dry material, or detail richness fails.

## Human Reply Contract

- Reply `use Totem v17b for cutout pass` if v17b is the preferred research candidate.
- Reply `use Totem v16b fallback for cutout pass` if v16b is safer.
- Reply `revise Totem: <needed change>` only if there is a new visible target not already covered by v16b/v17b.
- Reply `reject Totem route: <reason>` if this route should become a negative example.

## Apply The Decision

Do not run `apply_unit_art_review_decision.py` from this packet yet. These Totem outputs are research artifacts, not proof-ledger entries.

If a human chooses v17b or v16b, first make a separate cutout/edge pass, then create or update the proof-ledger entry and review packet for that proof artifact.

## Prior Totem Lessons

- v14b: useful texture-preserving route, but upper chest symbols still read like paired ornaments.
- v15: negative control; bark-clone correction broke the paired read but introduced patch seams and orange-side haze.
- v16b: safer fallback; strong paired-symbol reduction without v15 patching, but faint circular outline memory remains.
- v17b: current best research candidate; narrow residual-outline reduction over v16b while preserving bark texture.
