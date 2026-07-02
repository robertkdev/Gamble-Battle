# RGA Counter Plan vs Current Implementation - 2026-07-02

Status: updated after the first planned content batch, Sari/Creep reconciliation, and the planned cost-3 counter batch.

## Summary Verdict

The counter-web plan is now substantially caught up as roster content through cost 3, but it is still not implemented as a first-class counter system.

What is implemented:

- The live roster now has 39 playable units.
- Thirty-eight of the 50 target-matrix rows are live.
- Creep is playable at cost 3 by user request, outside the 50-unit target matrix for now.
- The planned cost-1 and cost-2 batch is live: Knoll, Pilfer, Miri, Cinder, Rooket, and Velour.
- Sari now has Exile/Scholar traits and a live sustained-DPS/on-hit identity.
- The planned cost-3 target batch is live: Caldera, Ivara, Noxley, Quorra, Juno Vale, Kett, Egress, Marble, Prisma, and Sable.
- Cost balance validation sees `units=39` with live tier shape `1:14 2:13 3:12`.
- The RGA focused cost-3 batch smoke passes for all ten new cost-3 target units.
- The ability system now supports planned area tick events used by zone/DoT counter kits.
- The RGA harness already has telemetry and validation support for role/goal/approach tags, focused scenario labels, counterplay pressure, cooldown pressure, zone exposure, redirect threat swaps, reset events, DoT ticks, execute evidence, ramp state, untargetable windows, and focused 6v6 smokes.

What is not implemented:

- Twelve target-matrix units remain absent: all eight cost-4 units and all four cost-5 units.
- Creep is playable but is not represented as a formal target-matrix row, so the target roster still needs a decision: fold Creep in, replace a planned assassin, or keep Creep as an extra 51st-style roster oddity.
- Cost 4 and cost 5 shop exposure is not implemented.
- The target matrix's board archetypes, counter-boards, beats/loses-to statements, and proof intents exist only in docs.
- There is no executable `data/counters` layer, `CounterRecipes`, `TargetingCountersMatrix`, or equivalent counter-profile schema.
- RGA opponent selection is still mostly role/scenario driven; it does not consume the planned approach and goal counter matrix as a matchup generator.
- No ten-unit board-archetype tests exist for Bastion Siege, Dive Reset, Zone Control, Attrition Engine, Wombo Engage, Control Prison, Wide Trait Engine, or Anti-Meta Flex.
- Some probes still pass through alternate evidence paths while individual diagnostic lines show `FAIL` or `DIAG`, especially around anti-DoT uptime, redirect/zone share lines, and frontline-pressure submetrics. Those are useful telemetry gaps, not current cost-3 blockers.

## Source Plan

The plan being compared is:

- `docs/rga_counter_matrix_2026-06-28.md`
- `docs/endgame_roster_plan_2026-06-28.md`

The target plan called for:

- 50 total target-matrix playable units.
- Cost shape: 14 cost-1, 13 cost-2, 11 cost-3, 8 cost-4, 4 cost-5.
- Role shape: 9 tank, 8 brawler, 6 assassin, 9 marksman, 9 mage, 9 support.
- All 22 primary goals used, with no goal above 3 copies.
- All 22 approaches used, with 149 total approach assignments.
- Every unit row carrying role, goal, approaches, approach mode, board archetype, counter-board, beats, loses-to, and proof intent.
- Eight abstract endgame board archetypes with predators, prey, and close matchups.

## Live Roster Snapshot

Current playable units: 39.

Target-matrix progress: 38 of 50 rows live, plus playable Creep outside the target matrix.

Current live cost shape:

| Cost | Current playable | Target matrix | Read |
| --- | ---: | ---: | --- |
| 1 | 14 | 14 | At target. |
| 2 | 13 | 13 | At target. |
| 3 | 12 | 11 | One over target because playable Creep is outside the target matrix. |
| 4 | 0 | 8 | Missing. |
| 5 | 0 | 4 | Missing. |
| Total | 39 | 50 | Thirty-eight target rows live plus Creep. |

Current live role shape:

| Role | Current playable | Target matrix | Remaining target gap |
| --- | ---: | ---: | ---: |
| Tank | 7 | 9 | +2 |
| Brawler | 7 | 8 | +1 |
| Assassin | 5 | 6 | +1 if Creep is counted, +2 against target rows only |
| Marksman | 7 | 9 | +2 |
| Mage | 7 | 9 | +2 |
| Support | 6 | 9 | +3 |
| Total | 39 | 50 | +11 live-count gap, +12 target-row gap because Creep is extra |

The first batch closed the cost-1 and cost-2 gaps. The cost-3 batch closed the planned cost-3 target rows. The remaining target roster work is now the late-game layer: cost 4 and cost 5, plus the Creep target-matrix decision.

## Goal Coverage Gap

Current live goal counts compared to the target matrix:

| Goal | Current playable | Target | Delta |
| --- | ---: | ---: | ---: |
| `tank.frontline_absorb` | 3 | 3 | 0 |
| `tank.team_fortification` | 2 | 2 | 0 |
| `tank.initiate_fight` | 2 | 2 | 0 |
| `tank.single_target_lockdown` | 0 | 2 | +2 |
| `brawler.attrition_dps` | 5 | 3 | -2 |
| `brawler.frontline_disruption` | 1 | 3 | +2 |
| `brawler.skirmish_dive` | 1 | 2 | +1 |
| `assassin.backline_elimination` | 2 | 2 | 0 |
| `assassin.cleanup_execution` | 1 | 2 | +1 |
| `assassin.disrupt_and_escape` | 2 | 2 | 0 |
| `marksman.sustained_dps` | 2 | 3 | +1 |
| `marksman.backline_siege` | 2 | 3 | +1 |
| `marksman.tank_shredding` | 3 | 3 | 0 |
| `mage.wombo_combo_burst` | 2 | 3 | +1 |
| `mage.area_denial_zone` | 2 | 3 | +1 |
| `mage.pick_burst` | 2 | 2 | 0 |
| `mage.sustained_dps` | 1 | 1 | 0 |
| `support.team_amplification` | 1 | 2 | +1 |
| `support.peel_carry` | 1 | 2 | +1 |
| `support.enemy_lockdown` | 2 | 2 | 0 |
| `support.initiate_fight` | 1 | 1 | 0 |
| `support.formation_breaking` | 1 | 2 | +1 |

Important read:

- The cost-3 batch filled `tank.initiate_fight`, `brawler.frontline_disruption`, `assassin.cleanup_execution`, `assassin.disrupt_and_escape`, `marksman.backline_siege`, `marksman.tank_shredding`, `mage.area_denial_zone`, `mage.sustained_dps`, and `support.formation_breaking`.
- `tank.single_target_lockdown` remains completely absent because both rows are late-game tanks: Bastionne and Malachor.
- `brawler.attrition_dps` remains over target because several original live units still carry attrition identities that the target matrix intends to retag later.
- Counting Creep makes `assassin.backline_elimination` look full, but the target-matrix capstone Nullora is still absent.

## Approach Coverage Gap

Current approach counts compared to the target matrix:

| Approach | Current playable | Target | Delta |
| --- | ---: | ---: | ---: |
| `access_backline` | 4 | 6 | +2 |
| `amp` | 4 | 8 | +4 |
| `aoe` | 9 | 8 | -1 |
| `burst` | 8 | 9 | +1 |
| `cc_immunity` | 3 | 5 | +2 |
| `damage_reduction` | 10 | 8 | -2 |
| `debuff` | 8 | 8 | 0 |
| `disrupt` | 4 | 8 | +4 |
| `dot` | 3 | 5 | +2 |
| `engage` | 6 | 7 | +1 |
| `execute` | 3 | 6 | +3 |
| `lockdown` | 4 | 6 | +2 |
| `long_range` | 7 | 8 | +1 |
| `on_hit_effect` | 3 | 6 | +3 |
| `peel` | 6 | 8 | +2 |
| `ramp` | 5 | 8 | +3 |
| `redirect` | 2 | 5 | +3 |
| `reposition` | 4 | 6 | +2 |
| `reset_mechanic` | 1 | 5 | +4 |
| `sustain` | 5 | 8 | +3 |
| `untargetable` | 3 | 5 | +2 |
| `zone` | 4 | 6 | +2 |

Important read:

- `debuff` is now exactly at target and the major cost-3 counter tags are no longer empty.
- `aoe` and `damage_reduction` are over target in live resources, partly because playable Creep remains outside the matrix and several current units have not been retagged to future target identities.
- The biggest remaining approach holes are `amp`, `disrupt`, `reset_mechanic`, `execute`, `on_hit_effect`, `ramp`, `redirect`, and `sustain`. Most of those remaining copies belong to the cost-4/cost-5 rows or to future retags of old units.

## Current Unit Alignment

Twenty-four live units match their target matrix role, goal, and approach tags:

| Unit | Target/live identity |
| --- | --- |
| Axiom | `support.team_amplification`: `amp`, `peel`, `sustain` |
| Berebell | `brawler.attrition_dps`: `sustain`, `reposition`, `burst` |
| Brute | `tank.frontline_absorb`: `engage`, `damage_reduction`, `lockdown` |
| Caldera | `tank.initiate_fight`: `engage`, `zone`, `aoe` |
| Cinder | `mage.area_denial_zone`: `zone`, `aoe`, `dot` |
| Egress | `assassin.cleanup_execution`: `execute`, `reset_mechanic`, `untargetable` |
| Hexeon | `assassin.backline_elimination`: `access_backline`, `burst`, `execute` |
| Ivara | `marksman.tank_shredding`: `long_range`, `debuff`, `engage` |
| Juno Vale | `support.formation_breaking`: `zone`, `disrupt`, `redirect` |
| Kett | `brawler.frontline_disruption`: `on_hit_effect`, `ramp`, `debuff` |
| Knoll | `support.enemy_lockdown`: `lockdown`, `debuff`, `disrupt` |
| Marble | `marksman.backline_siege`: `long_range`, `peel`, `debuff` |
| Miri | `support.initiate_fight`: `engage`, `amp`, `peel` |
| Noxley | `mage.sustained_dps`: `dot`, `sustain`, `ramp` |
| Pilfer | `assassin.disrupt_and_escape`: `access_backline`, `untargetable`, `reposition` |
| Prisma | `mage.area_denial_zone`: `zone`, `amp`, `aoe` |
| Quorra | `assassin.disrupt_and_escape`: `access_backline`, `dot`, `untargetable` |
| Rooket | `marksman.tank_shredding`: `damage_reduction`, `debuff`, `cc_immunity` |
| Sable | `marksman.tank_shredding`: `long_range`, `debuff`, `on_hit_effect` |
| Sari | `marksman.sustained_dps`: `long_range`, `on_hit_effect`, `ramp` |
| Teller | `marksman.sustained_dps`: `long_range`, `burst`, `aoe` |
| Totem | `support.peel_carry`: `peel`, `cc_immunity`, `amp` |
| Velour | `support.enemy_lockdown`: `lockdown`, `peel`, `sustain` |
| Veyra | `tank.team_fortification`: `damage_reduction`, `cc_immunity`, `ramp` |

Fourteen current units still do not match the target matrix exactly:

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

Playable outside target matrix:

| Unit | Live implementation | Reconciliation needed |
| --- | --- | --- |
| Creep | `assassin.backline_elimination`: `access_backline`, `aoe`, `damage_reduction` | Decide whether Creep becomes a formal target-matrix row, replaces a planned assassin, or remains an extra playable oddity outside the 50-unit set. |

## Planned Units Still Absent

Twelve target-matrix additions are still absent as playable unit resources:

| Cost | Planned units |
| ---: | --- |
| 4 | Ravel, Draxelle, Orielle, Bastionne, Vesper, Gable, Saffron, Omenry |
| 5 | Meridian, Malachor, Quillith, Nullora |

This means the remaining missing counter tools are concentrated in late game:

- Single-target lockdown tanks: Bastionne and Malachor.
- Premium formation breaking: Ravel.
- Premium brawler disruption and scaling: Draxelle.
- Premium spell-zone denial and mana-spend payoff: Orielle.
- Delayed cleanup assassin and capstone assassin: Vesper and Nullora.
- Late-game economy/cartel marksman: Gable.
- Premium peel/sustain/Catalyst support: Saffron.
- Wide-board, item-evolution, and mana capstones: Meridian and Quillith.

## RGA Harness Catch-Up Already Done

The RGA harness is ready for counter-web implementation work, even though the counter web is not yet structured data.

Implemented RGA support includes:

- `RoleMatrixProbe.tscn` and `RoleMatrixProbe6v6.tscn`.
- Targeted 6v6 scenes for the current live roster.
- Focused cost-3 smoke scenes for the new cost-3 batch.
- Catalog gates for role, goal, and approach semantics.
- `ApproachCatalogCoverage.tscn` for 22-goal/22-approach vocabulary coverage.
- Counterplay labels for `counterplay`, `cleanse`, and `high_tenacity_cleanse`.
- Counterplay response shell using Totem and Veyra.
- Role-level counter opponent selection in `tests/rga_testing/validation/opponent_selectors.gd`.
- Positive controls for zone, redirect, reset, execute, ramp, DoT, untargetable, cooldown pressure, counterplay pressure, amp output, AoE, Wombo, fortification, skirmish dive, and sustain windows.
- Scheduled planned-area ticks in `AbilitySystem`, giving zone/DoT kits a common event path.
- Accepted-miss reporting and guard coverage, currently centered on Totem peel-carry save/interrupt residuals.

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

The docs explicitly warned not to add the full 50-unit target directly as resources until cost 4/5 exposure, max level, XP curve, and odds are decided. That warning is still current.

## Recommended Catch-Up Sequence

1. Codify the counter-web contract before adding cost-4/cost-5 units.

   Add either a companion counter-profile resource or a structured `data/counters` layer that can represent board archetype, counter-board, beats, loses-to, and proof intent without bloating `UnitIdentity`. Do not make RGA parse Markdown as the only source of truth.

2. Add a docs/data validation gate.

   A small validation scene should verify that the target matrix has 50 rows, all 22 goals, all 22 approaches, the target role/cost counts, and required fields for board, counter-board, beats, loses-to, and proof intent. This preserves the planning artifact while implementation proceeds.

3. Reconcile Creep and the fourteen mismatched current units.

   Creep must become a target row, replace a planned row, or stay intentionally outside the target set. For each mismatch, decide whether the target matrix is still the intended future identity or whether the live kit proves a better identity. Do not retag a current unit just to satisfy the matrix unless the real ability and RGA telemetry can pass the intended role, goal, and approaches.

4. Convert proof intents into expected span checks.

   Current targeted 6v6 probes already support `expected_span_checks`. The next RGA catch-up should turn target rows into explicit unit contracts, starting with the twenty-four aligned live units, then the mismatch/outside-matrix units after kit decisions are made.

5. Extend opponent selection beyond role counters.

   `RGAOpponentSelectors.select_counters()` currently selects mostly by role. Add an approach/goal-aware selector that can choose hard answers, soft answers, prey, race matchups, and tax matchups from the counter matrix.

6. Add board-archetype team builders.

   Implement deterministic test builders for Bastion Siege, Dive Reset, Zone Control, Attrition Engine, Wombo Engage, Control Prison, Wide Trait Engine, and Anti-Meta Flex. Start with 6v6 versions while current team size and content are limited, then expand to 10-unit endgame tests after content and progression support exist.

7. Decide cost-4/cost-5 progression before adding late-game units.

   Shop odds, max level, XP curve, and late-game board expectations should land before Ravel, Draxelle, Orielle, Bastionne, Vesper, Gable, Saffron, Omenry, Meridian, Malachor, Quillith, or Nullora enter the live pool.

8. Keep the accepted-miss audit separate.

   The current accepted-miss system is useful and should not be confused with the counter-web backlog. Totem's peel-save/interrupt residuals are live scenario/content debt; the counter-web work is a broader data and orchestration gap.

## Bottom Line

The RGA metric layer has advanced enough to support the counters idea, and the planned roster has caught up through cost 3. The next useful implementation milestone is no longer "add the missing cost-3 cores." It is:

1. Turn the counter matrix into structured, testable data.
2. Reconcile playable Creep and the current-unit mismatches against that data.
3. Make RGA select and evaluate matchups from the counter web.
4. Decide cost-4/cost-5 progression, then add the remaining late-game rows with proof-intent checks.
