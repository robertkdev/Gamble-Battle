# RGA Counter Plan vs Current Implementation - 2026-07-02

Status: corrected after the full planned roster catch-up. Creep is a formal playable unit in the target set. Sari is a normal playable unit with `Exile` and `Scholar` traits.

## Summary Verdict

The planned roster side of the counter-web work is now caught up through cost 5, but the counter web itself is still not implemented as first-class structured data.

What is implemented:

- The live roster has 51 playable units.
- The target roster is now a corrected 51-row plan, including Creep as a formal cost-3 Assassin row.
- Sari is a cost-1 playable Marksman with `Exile`/`Scholar`, `marksman.sustained_dps`, and `long_range`, `on_hit_effect`, `ramp` evidence.
- Creep is a cost-3 playable Assassin with `Exile`/`Executioner`, `assassin.backline_elimination`, and `access_backline`, `aoe`, `damage_reduction` evidence.
- The planned cost-1 through cost-5 batches are live: Knoll, Pilfer, Miri, Cinder, Rooket, Velour, Caldera, Ivara, Noxley, Quorra, Juno Vale, Kett, Egress, Marble, Prisma, Sable, Ravel, Draxelle, Orielle, Bastionne, Vesper, Gable, Saffron, Omenry, Meridian, Malachor, Quillith, and Nullora.
- Cost balance validation sees `units=51` with live tier shape `1:14 2:13 3:12 4:8 5:4`.
- RGA focused smokes cover the planned batches, and the planned-batch smoke includes both Sari and Creep.
- The ability/RGA layer already supports telemetry for role/goal/approach tags, focused scenario labels, counterplay pressure, cooldown pressure, zone exposure, redirect threat swaps, reset events, DoT ticks, execute evidence, ramp state, untargetable windows, and focused 6v6 smokes.

What is still not implemented:

- The target matrix's board archetypes, counter-boards, beats/loses-to statements, and proof intents exist only in docs.
- There is no executable `data/counters` layer, `CounterRecipes`, `TargetingCountersMatrix`, or equivalent counter-profile schema.
- RGA opponent selection is still mostly role/scenario driven; it does not consume the planned approach and goal counter matrix as a matchup generator.
- No ten-unit board-archetype tests exist for Bastion Siege, Dive Reset, Zone Control, Attrition Engine, Wombo Engage, Control Prison, Wide Trait Engine, or Anti-Meta Flex.

## Source Plan

The plan being compared is:

- `docs/rga_counter_matrix_2026-06-28.md`
- `docs/endgame_roster_plan_2026-06-28.md`

The corrected target plan now calls for:

- 51 total target playable units.
- Cost shape: 14 cost-1, 13 cost-2, 12 cost-3, 8 cost-4, 4 cost-5.
- Role shape: 9 tank, 8 brawler, 7 assassin, 9 marksman, 9 mage, 9 support.
- All 22 primary goals used, with no goal above 3 copies.
- All 22 approaches used, with 152 total approach assignments.
- Every unit row carrying role, goal, approaches, approach mode, board archetype, counter-board, beats, loses-to, and proof intent.
- Eight abstract endgame board archetypes with predators, prey, and close matchups.

## Live Roster Snapshot

Current playable units: 51.

Target-matrix progress: 51 of 51 rows live.

Current live cost shape:

| Cost | Current playable | Target matrix | Read |
| --- | ---: | ---: | --- |
| 1 | 14 | 14 | At target. |
| 2 | 13 | 13 | At target. |
| 3 | 12 | 12 | At target, including playable Creep. |
| 4 | 8 | 8 | At target. |
| 5 | 4 | 4 | At target. |
| Total | 51 | 51 | Full target roster live. |

Current live role shape:

| Role | Current playable | Target matrix | Read |
| --- | ---: | ---: | --- |
| Tank | 9 | 9 | At target. |
| Brawler | 8 | 8 | At target. |
| Assassin | 7 | 7 | At target, including Creep. |
| Marksman | 9 | 9 | At target. |
| Mage | 9 | 9 | At target. |
| Support | 9 | 9 | At target. |
| Total | 51 | 51 | Full target roster live. |

## Current Unit Alignment

The correction to the previous comparison is simple:

- Sari is not traitless. She is `Exile`/`Scholar` and is already represented in the target matrix as `marksman.sustained_dps`: `long_range`, `on_hit_effect`, `ramp`.
- Creep is represented as a formal cost-3 target row: `assassin.backline_elimination`: `access_backline`, `aoe`, `damage_reduction`.
- Terminology distinction: capital-C `Creep` is the playable roster unit at `data/units/creep.tres`. Lowercase creep-round NPCs are reward enemies under `data/other_units/creeps/`, and the reward code classifies those by creeps-folder path plus cost 0.
- The old hidden duplicate Creep resource under `data/other_units/other/` has been removed so the `creep` ID now refers to the playable roster unit only.

## RGA Harness Catch-Up Already Done

The RGA harness is ready for counter-web implementation work, even though the counter web is not yet structured data.

Implemented RGA support includes:

- `RoleMatrixProbe.tscn` and `RoleMatrixProbe6v6.tscn`.
- Targeted 6v6 scenes for the current live roster.
- Focused smoke scenes for the new roster batches.
- Catalog gates for role, goal, and approach semantics.
- `ApproachCatalogCoverage.tscn` for 22-goal/22-approach vocabulary coverage.
- Counterplay labels for `counterplay`, `cleanse`, and `high_tenacity_cleanse`.
- Counterplay response shell using Totem and Veyra.
- Role-level counter opponent selection in `tests/rga_testing/validation/opponent_selectors.gd`.
- Positive controls for zone, redirect, reset, execute, ramp, DoT, untargetable, cooldown pressure, counterplay pressure, amp output, AoE, Wombo, fortification, skirmish dive, and sustain windows.
- Scheduled planned-area ticks in `AbilitySystem`, giving zone/DoT kits a common event path.

## RGA Harness Gaps Against The Counter Plan

The missing RGA pieces are orchestration and contract layers, not raw metric vocabulary.

| Planned idea | Current state | Gap |
| --- | --- | --- |
| Approach counter matrix | Exists in Markdown. | No executable data structure consumed by RGA. |
| Goal counter matrix | Exists in Markdown. | No goal-level matchup selector or expected outcome generator. |
| Unit beats/loses-to statements | Exists only in target matrix docs. | Not stored in `UnitIdentity` or any companion resource. |
| Board archetypes | Exists only as abstract docs. | No team-builder presets, board tests, or RGA expected outcomes. |
| Counter-board field | Exists only in target matrix docs. | No runtime/test representation. |
| Proof intent | Exists only as prose. | Not compiled into expected span checks per unit. |
| Ten-unit max-team board tests | Planned in docs. | RGA focused probes are primarily 1v1 and 6v6, not 10-slot archetype-vs-archetype checks. |

## Recommended Catch-Up Sequence

1. Codify the counter-web contract.

   Add either a companion counter-profile resource or a structured `data/counters` layer that can represent board archetype, counter-board, beats, loses-to, and proof intent without bloating `UnitIdentity`.

2. Add a docs/data validation gate.

   A small validation scene should verify that the target matrix has 51 rows, all 22 goals, all 22 approaches, the target role/cost counts, and required fields for board, counter-board, beats, loses-to, and proof intent.

3. Convert proof intents into expected span checks.

   Current targeted 6v6 probes already support `expected_span_checks`. The next RGA catch-up should turn target rows into explicit unit contracts.

4. Extend opponent selection beyond role counters.

   `RGAOpponentSelectors.select_counters()` currently selects mostly by role. Add an approach/goal-aware selector that can choose hard answers, soft answers, prey, race matchups, and tax matchups from the counter matrix.

5. Add board-archetype team builders.

   Implement deterministic test builders for Bastion Siege, Dive Reset, Zone Control, Attrition Engine, Wombo Engage, Control Prison, Wide Trait Engine, and Anti-Meta Flex. Start with 6v6 versions, then expand to 10-unit endgame tests after progression supports it cleanly.

## Bottom Line

The roster catch-up is done, and the corrected target set is 51 playable units with Sari and Creep both treated as normal roster members. The next useful implementation milestone is no longer "add missing units." It is making the counter matrix executable so RGA can select and evaluate matchups from the counter web instead of only reading Markdown.
