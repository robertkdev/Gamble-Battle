# RGA Counter Plan vs Current Implementation - 2026-07-01

Status: comparison only. This document does not implement units, abilities, identities, shop odds, RGA metrics, scenes, or balance numbers.

## Summary Verdict

The counter-web plan is still mostly a design target, not a live implementation.

What is implemented:

- The live roster still has 22 playable units.
- The live identity vocabulary has all 6 roles, 22 primary goals, and 22 approaches.
- The RGA harness has substantial telemetry and validation support for approaches, goals, accepted-miss triage, scenario labels, and focused 6v6 probes.
- Several later RGA improvements already caught up with parts of the counter idea at the telemetry layer: counterplay pressure, cooldown pressure, zone exposure, redirect threat swaps, reset events, DoT ticks, execute bonus evidence, ramp state, untargetable windows, and focused scenario-pack smokes.

What is not implemented:

- The planned 50-unit roster is not implemented.
- Cost 4 and cost 5 shop exposure is not implemented.
- The target matrix's board archetypes, counter-boards, beats/loses-to statements, and proof intents exist only in docs.
- There is no executable `data/counters` layer, `CounterRecipes`, `TargetingCountersMatrix`, or equivalent counter-profile schema.
- RGA opponent selection is still mostly role/scenario driven; it does not consume the planned approach and goal counter matrix as a matchup generator.
- No ten-unit board-archetype tests exist for Bastion Siege, Dive Reset, Zone Control, Attrition Engine, Wombo Engage, Control Prison, Wide Trait Engine, or Anti-Meta Flex.

## Source Plan

The plan being compared is:

- `docs/rga_counter_matrix_2026-06-28.md`
- `docs/endgame_roster_plan_2026-06-28.md`

The target plan called for:

- 50 total playable units.
- Cost shape: 14 cost-1, 13 cost-2, 11 cost-3, 8 cost-4, 4 cost-5.
- Role shape: 9 tank, 8 brawler, 6 assassin, 9 marksman, 9 mage, 9 support.
- All 22 primary goals used, with no goal above 3 copies.
- All 22 approaches used, with 149 total approach assignments.
- Every unit row carrying role, goal, approaches, approach mode, board archetype, counter-board, beats, loses-to, and proof intent.
- Eight abstract endgame board archetypes with predators, prey, and close matchups.

## Live Roster Snapshot

Current playable units: 22.

Current cost shape:

| Cost | Current | Target | Delta |
| --- | ---: | ---: | ---: |
| 1 | 12 | 14 | +2 |
| 2 | 9 | 13 | +4 |
| 3 | 1 | 11 | +10 |
| 4 | 0 | 8 | +8 |
| 5 | 0 | 4 | +4 |

Current role shape:

| Role | Current | Target | Delta |
| --- | ---: | ---: | ---: |
| Tank | 6 | 9 | +3 |
| Brawler | 6 | 8 | +2 |
| Assassin | 1 | 6 | +5 |
| Marksman | 3 | 9 | +6 |
| Mage | 4 | 9 | +5 |
| Support | 2 | 9 | +7 |

The biggest role gaps are support, marksman, assassin, and mage. This matches the original planning concern: the current roster is still dominated by low-cost frontline and brawler content, while the target counter web needs more backline, support, and late-game pivot pieces.

## Goal Coverage Gap

Current live goal counts compared to the target matrix:

| Goal | Current | Target | Delta |
| --- | ---: | ---: | ---: |
| `tank.frontline_absorb` | 3 | 3 | 0 |
| `tank.team_fortification` | 2 | 2 | 0 |
| `tank.initiate_fight` | 1 | 2 | +1 |
| `tank.single_target_lockdown` | 0 | 2 | +2 |
| `brawler.attrition_dps` | 5 | 3 | -2 |
| `brawler.frontline_disruption` | 0 | 3 | +3 |
| `brawler.skirmish_dive` | 1 | 2 | +1 |
| `assassin.backline_elimination` | 1 | 2 | +1 |
| `assassin.cleanup_execution` | 0 | 2 | +2 |
| `assassin.disrupt_and_escape` | 0 | 2 | +2 |
| `marksman.sustained_dps` | 2 | 3 | +1 |
| `marksman.backline_siege` | 1 | 3 | +2 |
| `marksman.tank_shredding` | 0 | 3 | +3 |
| `mage.wombo_combo_burst` | 2 | 3 | +1 |
| `mage.area_denial_zone` | 0 | 3 | +3 |
| `mage.pick_burst` | 2 | 2 | 0 |
| `mage.sustained_dps` | 0 | 1 | +1 |
| `support.team_amplification` | 1 | 2 | +1 |
| `support.peel_carry` | 1 | 2 | +1 |
| `support.enemy_lockdown` | 0 | 2 | +2 |
| `support.initiate_fight` | 0 | 1 | +1 |
| `support.formation_breaking` | 0 | 2 | +2 |

Important read:

- `tank.frontline_absorb`, `tank.team_fortification`, and `mage.pick_burst` are already at target count.
- `brawler.attrition_dps` is over target by 2.
- Ten target goals are not represented by any playable unit yet.
- The most important missing counter-web goals are `marksman.tank_shredding`, `mage.area_denial_zone`, `support.enemy_lockdown`, `support.formation_breaking`, `tank.single_target_lockdown`, and the two missing assassin goals.

## Approach Coverage Gap

Current approach counts compared to the target matrix:

| Approach | Current | Target | Delta |
| --- | ---: | ---: | ---: |
| `access_backline` | 1 | 6 | +5 |
| `amp` | 2 | 8 | +6 |
| `aoe` | 5 | 8 | +3 |
| `burst` | 8 | 9 | +1 |
| `cc_immunity` | 2 | 5 | +3 |
| `damage_reduction` | 8 | 8 | 0 |
| `debuff` | 3 | 8 | +5 |
| `disrupt` | 2 | 8 | +6 |
| `dot` | 0 | 5 | +5 |
| `engage` | 3 | 7 | +4 |
| `execute` | 2 | 6 | +4 |
| `lockdown` | 2 | 6 | +4 |
| `long_range` | 4 | 8 | +4 |
| `on_hit_effect` | 0 | 6 | +6 |
| `peel` | 3 | 8 | +5 |
| `ramp` | 4 | 8 | +4 |
| `redirect` | 1 | 5 | +4 |
| `reposition` | 3 | 6 | +3 |
| `reset_mechanic` | 0 | 5 | +5 |
| `sustain` | 4 | 8 | +4 |
| `untargetable` | 0 | 5 | +5 |
| `zone` | 0 | 6 | +6 |

Important read:

- `damage_reduction` is already at the target count.
- `burst` is close to target, but that does not mean the target burst design is implemented; many planned burst rows require specific target rules, delays, reset logic, or counter windows.
- `dot`, `on_hit_effect`, `reset_mechanic`, `untargetable`, and `zone` have executable metric support, but no live playable unit currently carries those tags.
- The biggest counter-web holes are `zone`, `disrupt`, `amp`, `on_hit_effect`, `access_backline`, `debuff`, `dot`, `peel`, `reset_mechanic`, and `untargetable`.

## Current Unit Alignment

Seven current units match their target matrix role, goal, and approach tags:

| Unit | Target/live identity |
| --- | --- |
| Axiom | `support.team_amplification`: `amp`, `peel`, `sustain` |
| Berebell | `brawler.attrition_dps`: `sustain`, `reposition`, `burst` |
| Brute | `tank.frontline_absorb`: `engage`, `damage_reduction`, `lockdown` |
| Hexeon | `assassin.backline_elimination`: `access_backline`, `burst`, `execute` |
| Teller | `marksman.sustained_dps`: `long_range`, `burst`, `aoe` |
| Totem | `support.peel_carry`: `peel`, `cc_immunity`, `amp` |
| Veyra | `tank.team_fortification`: `damage_reduction`, `cc_immunity`, `ramp` |

Fifteen current units do not match the target matrix exactly:

| Unit | Target matrix | Live implementation |
| --- | --- | --- |
| Korath | `damage_reduction`, `redirect`, `sustain` | `damage_reduction`, `engage`, `redirect` |
| Repo | `damage_reduction`, `redirect`, `cc_immunity` | `damage_reduction` |
| Kythera | `damage_reduction`, `debuff`, `amp` | `damage_reduction`, `debuff` |
| Grint | `engage`, `disrupt`, `debuff` | `engage`, `debuff`, `damage_reduction` |
| Bonko | `sustain`, `ramp`, `on_hit_effect` | `sustain`, `ramp` |
| Vykos | `damage_reduction`, `reposition` | `sustain`, `burst`, `damage_reduction` |
| Bo | `disrupt`, `reposition`, `access_backline` | `disrupt`, `reposition` |
| Mortem | `brawler.skirmish_dive`: `access_backline`, `reposition`, `burst` | `brawler.attrition_dps`: `reposition`, `burst`, `disrupt` |
| Morrak | `brawler.frontline_disruption`: `disrupt`, `aoe`, `execute` | `brawler.attrition_dps`: `damage_reduction`, `execute`, `aoe` |
| Sari | `long_range`, `on_hit_effect`, `ramp` | `long_range`, `debuff`, `ramp` |
| Nyxa | `long_range`, `zone`, `burst` | `long_range`, `ramp`, `aoe` |
| Luna | `aoe`, `burst`, `reset_mechanic` | `aoe`, `burst`, `long_range` |
| Paisley | `aoe`, `peel`, `amp` | `aoe`, `peel` |
| Cashmere | `burst`, `execute`, `reset_mechanic` | `burst` |
| Volt | `burst`, `lockdown`, `dot` | `burst`, `lockdown` |

This is the practical crux: the target matrix retagged several current units as part of the future counter web, but most of those retags were not applied to live identity resources. Some should not be applied until their real kit telemetry can prove the target behavior.

## Planned Units Still Absent

All 28 planned additions are absent as playable unit resources:

| Cost | Planned units |
| ---: | --- |
| 1 | Knoll, Pilfer |
| 2 | Miri, Cinder, Rooket, Velour |
| 3 | Caldera, Kett, Quorra, Juno Vale, Egress, Marble, Prisma, Sable, Ivara, Noxley |
| 4 | Ravel, Draxelle, Orielle, Bastionne, Vesper, Gable, Saffron, Omenry |
| 5 | Meridian, Malachor, Quillith, Nullora |

This means the plan's most important missing counter tools are also absent as content:

- Tank shredding: Rooket, Ivara, Sable.
- Area-denial zone: Cinder, Prisma, Orielle.
- Single-target lockdown tanks: Bastionne, Malachor.
- Assassin cleanup and disruption: Egress, Vesper, Pilfer, Quorra, Nullora.
- Support enemy lockdown and formation breaking: Knoll, Velour, Juno Vale, Ravel.
- Cost-5 rule-bending capstones: Meridian, Malachor, Quillith, Nullora.

## RGA Harness Catch-Up Already Done

The RGA harness is not empty or naive anymore. It has caught up with a lot of the mechanical proof surface that the counter plan needs.

Implemented RGA support includes:

- `RoleMatrixProbe.tscn` and `RoleMatrixProbe6v6.tscn`.
- Targeted 6v6 scenes for the current live roster.
- Catalog gates for role, goal, and approach semantics.
- `ApproachCatalogCoverage.tscn` for 22-goal/22-approach vocabulary coverage.
- Counterplay labels for `counterplay`, `cleanse`, and `high_tenacity_cleanse`.
- Counterplay response shell using Totem and Veyra.
- Role-level counter opponent selection in `tests/rga_testing/validation/opponent_selectors.gd`.
- Positive controls for zone, redirect, reset, execute, ramp, DoT, untargetable, cooldown pressure, counterplay pressure, amp output, AoE, Wombo, fortification, skirmish dive, and sustain windows.
- Accepted-miss reporting and guard coverage, currently centered on Totem peel-carry save/interrupt residuals.

That means the harness is ready for a counter-web implementation pass, but the target counter web is not yet a first-class input.

## RGA Harness Gaps Against The Counter Plan

The missing RGA pieces are mostly orchestration and contract layers, not raw metric vocabulary.

| Planned idea | Current state | Gap |
| --- | --- | --- |
| Approach counter matrix | Exists in Markdown. | No executable data structure consumed by RGA. |
| Goal counter matrix | Exists in Markdown. | No goal-level matchup selector or expected outcome generator. |
| Unit beats/loses-to statements | Exists only in target matrix docs. | Not stored in `UnitIdentity` or any companion resource. |
| Board archetypes | Exists only as abstract docs. | No team-builder presets, board tests, or RGA expected outcomes. |
| Counter-board field | Exists only in target matrix docs. | No runtime/test representation. |
| Proof intent | Exists only as prose. | Not compiled into expected span checks per unit. |
| Cost 4/5 counterplay rules | Exists only in docs. | Shop supports only costs 1-3. |
| Current unit retags | Planned for future matrix. | Mostly not applied to live resources, and some need kit/telemetry work first. |
| Ten-unit max-team board tests | Planned in docs. | RGA focused probes are primarily 1v1 and 6v6, not 10-slot archetype-vs-archetype checks. |

## Shop And Progression Gap

`scripts/game/shop/shop_config.gd` still exposes:

- `MAX_LEVEL := 6`
- `VALID_COSTS := [1, 2, 3]`
- `ODDS_BY_LEVEL` only for costs 1, 2, and 3.

The docs explicitly warned not to add the 50-unit target directly as resources until cost 4/5 exposure, max level, XP curve, and odds are decided. That warning is still current.

## Recommended Catch-Up Sequence

1. Codify the counter-web contract before adding many units.

   Add either a companion counter-profile resource or a structured `data/counters` layer that can represent board archetype, counter-board, beats, loses-to, and proof intent without bloating `UnitIdentity`. Do not make RGA parse Markdown as the only source of truth.

2. Add a docs/data validation gate.

   A small validation scene should verify that the target matrix has 50 rows, all 22 goals, all 22 approaches, the target role/cost counts, and required fields for board, counter-board, beats, loses-to, and proof intent. This preserves the planning artifact while implementation proceeds.

3. Reconcile the 22 current units before adding the 28 planned units.

   For each mismatch above, decide whether the target matrix is still the intended future identity or whether the live kit proves a better identity. Do not retag a current unit just to satisfy the matrix unless the real ability and RGA telemetry can pass the intended role, goal, and approaches.

4. Convert proof intents into expected span checks.

   Current targeted 6v6 probes already support `expected_span_checks`. The next RGA catch-up should turn target rows into explicit unit contracts, starting with the seven already-aligned current units and then the 15 mismatch units after kit decisions are made.

5. Extend opponent selection beyond role counters.

   `RGAOpponentSelectors.select_counters()` currently selects mostly by role. Add an approach/goal-aware selector that can choose hard answers, soft answers, prey, race matchups, and tax matchups from the counter matrix.

6. Add board-archetype team builders.

   Implement deterministic test builders for Bastion Siege, Dive Reset, Zone Control, Attrition Engine, Wombo Engage, Control Prison, Wide Trait Engine, and Anti-Meta Flex. Start with 6v6 versions while current team size and content are limited, then expand to 10-unit endgame tests after content and progression support exist.

7. Add content in cost-band batches.

   After current-unit reconciliation, add planned units by cost band:

   - Cost 1 and 2 first: Knoll, Pilfer, Miri, Cinder, Rooket, Velour.
   - Then cost 3 cores.
   - Only then cost 4/5, after shop odds and max-level design are implemented.

8. Keep the accepted-miss audit separate.

   The current accepted-miss system is useful and should not be confused with the counter-web backlog. Totem's peel-save/interrupt residuals are live scenario/content debt; the counter-web work is a broader data and orchestration gap.

## Bottom Line

The RGA metric layer has advanced enough to support the counters idea, but the counter idea itself is still not implemented as a system. The next useful implementation milestone is not "add all 28 units." It is:

1. Turn the counter matrix into structured, testable data.
2. Reconcile the 22 current units against that data.
3. Make RGA select and evaluate matchups from the counter web.
4. Then add planned units in batches with proof-intent checks.
