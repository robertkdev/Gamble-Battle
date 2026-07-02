# RGA Counter Plan vs Current Implementation - 2026-07-01

Status: updated after the first planned content batch. This document now compares the target counter-web plan against the live implementation after adding Knoll, Pilfer, Miri, Cinder, Rooket, Velour, Sari's traits/on-hit identity, and playable Creep.

## Summary Verdict

The counter-web plan is now partially implemented as content, but still mostly missing as a first-class RGA/counter-system.

What is implemented:

- The live roster now has 29 playable units.
- The planned cost-1 and cost-2 batch is live: Knoll, Pilfer, Miri, Cinder, Rooket, and Velour.
- Sari now has Exile/Scholar traits and a live `on_hit_effect` identity hook.
- Creep is playable at cost 3 by user request, using the existing Creep identity and ability surface.
- The live identity vocabulary has all 6 roles, 22 primary goals, and 22 approaches.
- The RGA harness has substantial telemetry and validation support for approaches, goals, accepted-miss triage, scenario labels, and focused 6v6 probes.
- Several later RGA improvements already caught up with parts of the counter idea at the telemetry layer: counterplay pressure, cooldown pressure, zone exposure, redirect threat swaps, reset events, DoT ticks, execute bonus evidence, ramp state, untargetable windows, and focused scenario-pack smokes.

What is not implemented:

- The planned 50-unit roster is not complete; 22 target-matrix units remain absent.
- Creep is now playable but is not yet represented as a formal row in the 50-unit counter matrix, so the target roster needs a follow-up decision.
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

Current playable units: 29.

Current cost shape:

| Cost | Current | Target | Delta |
| --- | ---: | ---: | ---: |
| 1 | 14 | 14 | 0 |
| 2 | 13 | 13 | 0 |
| 3 | 2 | 11 | +9 |
| 4 | 0 | 8 | +8 |
| 5 | 0 | 4 | +4 |

Current role shape:

| Role | Current | Target | Delta |
| --- | ---: | ---: | ---: |
| Tank | 6 | 9 | +3 |
| Brawler | 6 | 8 | +2 |
| Assassin | 3 | 6 | +3 |
| Marksman | 4 | 9 | +5 |
| Mage | 5 | 9 | +4 |
| Support | 5 | 9 | +4 |

The first batch fixed the cost-1 and cost-2 count gaps, and it reduced the assassin, mage, marksman, and support role deficits. The live roster is still missing most mid-game and late-game counter-web pieces, especially cost 3-5 content.

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
| `assassin.backline_elimination` | 2 | 2 | 0 |
| `assassin.cleanup_execution` | 0 | 2 | +2 |
| `assassin.disrupt_and_escape` | 1 | 2 | +1 |
| `marksman.sustained_dps` | 2 | 3 | +1 |
| `marksman.backline_siege` | 1 | 3 | +2 |
| `marksman.tank_shredding` | 1 | 3 | +2 |
| `mage.wombo_combo_burst` | 2 | 3 | +1 |
| `mage.area_denial_zone` | 1 | 3 | +2 |
| `mage.pick_burst` | 2 | 2 | 0 |
| `mage.sustained_dps` | 0 | 1 | +1 |
| `support.team_amplification` | 1 | 2 | +1 |
| `support.peel_carry` | 1 | 2 | +1 |
| `support.enemy_lockdown` | 2 | 2 | 0 |
| `support.initiate_fight` | 1 | 1 | 0 |
| `support.formation_breaking` | 0 | 2 | +2 |

Important read:

- `tank.frontline_absorb`, `tank.team_fortification`, `assassin.backline_elimination`, `mage.pick_burst`, `support.enemy_lockdown`, and `support.initiate_fight` are now at target count.
- `brawler.attrition_dps` is over target by 2.
- Five target goals are not represented by any playable unit yet: `tank.single_target_lockdown`, `brawler.frontline_disruption`, `assassin.cleanup_execution`, `mage.sustained_dps`, and `support.formation_breaking`.
- The most important remaining counter-web goal gaps are cost-3-plus disruption/frontline breaking, cleanup assassins, premium lockdown tanks, sustained mage DPS, and formation-breaking supports.

## Approach Coverage Gap

Current approach counts compared to the target matrix:

| Approach | Current | Target | Delta |
| --- | ---: | ---: | ---: |
| `access_backline` | 3 | 6 | +3 |
| `amp` | 3 | 8 | +5 |
| `aoe` | 7 | 8 | +1 |
| `burst` | 8 | 9 | +1 |
| `cc_immunity` | 3 | 5 | +2 |
| `damage_reduction` | 10 | 8 | -2 |
| `debuff` | 4 | 8 | +4 |
| `disrupt` | 3 | 8 | +5 |
| `dot` | 1 | 5 | +4 |
| `engage` | 4 | 7 | +3 |
| `execute` | 2 | 6 | +4 |
| `lockdown` | 4 | 6 | +2 |
| `long_range` | 4 | 8 | +4 |
| `on_hit_effect` | 1 | 6 | +5 |
| `peel` | 5 | 8 | +3 |
| `ramp` | 3 | 8 | +5 |
| `redirect` | 1 | 5 | +4 |
| `reposition` | 4 | 6 | +2 |
| `reset_mechanic` | 0 | 5 | +5 |
| `sustain` | 4 | 8 | +4 |
| `untargetable` | 1 | 5 | +4 |
| `zone` | 1 | 6 | +5 |

Important read:

- `damage_reduction` is now over the target count because playable Creep uses the existing Creep identity outside the target matrix.
- `burst` is close to target, but that does not mean the target burst design is implemented; many planned burst rows require specific target rules, delays, reset logic, or counter windows.
- `dot`, `on_hit_effect`, `untargetable`, and `zone` now have at least one live carrier. `reset_mechanic` is still unrepresented.
- The biggest counter-web holes are still `amp`, `disrupt`, `ramp`, `zone`, `on_hit_effect`, `redirect`, `dot`, `execute`, `sustain`, `reset_mechanic`, and `untargetable`.

## Current Unit Alignment

Fourteen live units match their target matrix role, goal, and approach tags:

| Unit | Target/live identity |
| --- | --- |
| Axiom | `support.team_amplification`: `amp`, `peel`, `sustain` |
| Berebell | `brawler.attrition_dps`: `sustain`, `reposition`, `burst` |
| Brute | `tank.frontline_absorb`: `engage`, `damage_reduction`, `lockdown` |
| Hexeon | `assassin.backline_elimination`: `access_backline`, `burst`, `execute` |
| Knoll | `support.enemy_lockdown`: `lockdown`, `debuff`, `disrupt` |
| Miri | `support.initiate_fight`: `engage`, `amp`, `peel` |
| Pilfer | `assassin.disrupt_and_escape`: `access_backline`, `untargetable`, `reposition` |
| Rooket | `marksman.tank_shredding`: `damage_reduction`, `debuff`, `cc_immunity` |
| Sari | `marksman.sustained_dps`: `long_range`, `on_hit_effect`, `ramp` |
| Teller | `marksman.sustained_dps`: `long_range`, `burst`, `aoe` |
| Totem | `support.peel_carry`: `peel`, `cc_immunity`, `amp` |
| Velour | `support.enemy_lockdown`: `lockdown`, `peel`, `sustain` |
| Veyra | `tank.team_fortification`: `damage_reduction`, `cc_immunity`, `ramp` |
| Cinder | `mage.area_denial_zone`: `zone`, `aoe`, `dot` |

Fourteen current units do not match the target matrix exactly:

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
| Nyxa | `long_range`, `zone`, `burst` | `long_range`, `ramp`, `aoe` |
| Luna | `aoe`, `burst`, `reset_mechanic` | `aoe`, `burst`, `long_range` |
| Paisley | `aoe`, `peel`, `amp` | `aoe`, `peel` |
| Cashmere | `burst`, `execute`, `reset_mechanic` | `burst` |
| Volt | `burst`, `lockdown`, `dot` | `burst`, `lockdown` |

This is the practical crux: the target matrix retagged several current units as part of the future counter web, but most of those retags were not applied to live identity resources. Some should not be applied until their real kit telemetry can prove the target behavior.

Playable outside target matrix:

| Unit | Live implementation | Reconciliation needed |
| --- | --- | --- |
| Creep | `assassin.backline_elimination`: `access_backline`, `aoe`, `damage_reduction` | Decide whether Creep becomes a formal target-matrix row, replaces a planned assassin, or remains an extra playable oddity outside the 50-unit set. |

## Planned Units Still Absent

Twenty-two target-matrix additions are still absent as playable unit resources:

| Cost | Planned units |
| ---: | --- |
| 1 | None |
| 2 | None |
| 3 | Caldera, Kett, Quorra, Juno Vale, Egress, Marble, Prisma, Sable, Ivara, Noxley |
| 4 | Ravel, Draxelle, Orielle, Bastionne, Vesper, Gable, Saffron, Omenry |
| 5 | Meridian, Malachor, Quillith, Nullora |

This means the plan's most important missing counter tools are also absent as content:

- Tank shredding: Ivara and Sable still absent; Rooket is live.
- Area-denial zone: Prisma and Orielle still absent; Cinder is live.
- Single-target lockdown tanks: Bastionne, Malachor.
- Assassin cleanup and premium dive: Egress, Vesper, Quorra, and Nullora still absent; Pilfer is live, and Creep adds an extra backline-elimination diver outside the target matrix.
- Support formation breaking remains absent; Knoll, Velour, and Miri are live, while Juno Vale and Ravel are still absent.
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

3. Reconcile the live roster against the target matrix before adding the remaining planned units.

   For each mismatch above, decide whether the target matrix is still the intended future identity or whether the live kit proves a better identity. Do not retag a current unit just to satisfy the matrix unless the real ability and RGA telemetry can pass the intended role, goal, and approaches. Creep also needs an explicit target-matrix decision because it is playable now but outside the 50-unit plan.

4. Convert proof intents into expected span checks.

   Current targeted 6v6 probes already support `expected_span_checks`. The next RGA catch-up should turn target rows into explicit unit contracts, starting with the fourteen aligned live units and then the mismatch/outside-matrix units after kit decisions are made.

5. Extend opponent selection beyond role counters.

   `RGAOpponentSelectors.select_counters()` currently selects mostly by role. Add an approach/goal-aware selector that can choose hard answers, soft answers, prey, race matchups, and tax matchups from the counter matrix.

6. Add board-archetype team builders.

   Implement deterministic test builders for Bastion Siege, Dive Reset, Zone Control, Attrition Engine, Wombo Engage, Control Prison, Wide Trait Engine, and Anti-Meta Flex. Start with 6v6 versions while current team size and content are limited, then expand to 10-unit endgame tests after content and progression support exist.

7. Add content in cost-band batches.

   After current-unit reconciliation, add planned units by cost band:

   - Cost 1 and 2 first: Knoll, Pilfer, Miri, Cinder, Rooket, Velour. Done in the 2026-07-01 content checkpoint.
   - Then cost 3 cores, including a decision on how playable Creep interacts with the target matrix.
   - Only then cost 4/5, after shop odds and max-level design are implemented.

8. Keep the accepted-miss audit separate.

   The current accepted-miss system is useful and should not be confused with the counter-web backlog. Totem's peel-save/interrupt residuals are live scenario/content debt; the counter-web work is a broader data and orchestration gap.

## Bottom Line

The RGA metric layer has advanced enough to support the counters idea, and the first planned content batch is live, but the counter idea itself is still not implemented as a system. The next useful implementation milestone is not "keep adding units one by one." It is:

1. Turn the counter matrix into structured, testable data.
2. Reconcile the live roster and playable Creep against that data.
3. Make RGA select and evaluate matchups from the counter web.
4. Then add the remaining planned units in batches with proof-intent checks.
