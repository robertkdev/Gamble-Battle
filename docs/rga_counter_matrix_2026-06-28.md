# RGA Counter Matrix - 2026-06-28

Status: planning only. This document does not implement units, abilities, traits, shop odds, scripts, scenes, or balance numbers.

## Sources Checked

- Current identity keys: `scripts/game/identity/identity_keys.gd`
- Current goal and approach resources: `data/identity/goals/*.tres`, `data/identity/approaches/*.tres`
- Current live unit identity map: `docs/unit_identity_map.md`
- Endgame roster plan: `docs/endgame_roster_plan_2026-06-28.md`
- RGA testing docs and scenario notes: `tests/rga_testing/README.md`, `tests/rga_testing/validation/README.md`, `docs/rga/test_notes_2026-06-23.md`

## Design Goal

The RGA system should make combat feel like a readable experiment:

- The player should be able to predict broad cause and effect from scouting, traits, roles, goals, approaches, items, and formation.
- The exact fight should still have uncertainty because targeting, cast timing, positioning, thresholds, resets, and overlapping zones create emergent outcomes.
- Every strong plan needs at least one visible answer, and every answer needs something that pressures it.
- The best counters should usually change timing, target access, or board geometry, not only increase or reduce stats.

## Specificity Rule

Keep the top-level RGA layer broad, then make each unit specific.

- Role should stay broad: Tank, Mage, Support, and the other primary roles.
- Goal should be moderately specific: peel carry, area denial, tank shredding, formation breaking.
- Approach should stay readable: `burst`, `zone`, `debuff`, `sustain`, `redirect`.
- Unit kit should be precise: target rule, timing window, counter, and proof hook.

Write specificity as `approach + mode` before adding new approach IDs. Examples: `debuff: anti-heal`, `peel: cleanse`, `zone: delayed trap`, `disrupt: mana tax`, or `burst: delayed isolated target`.

Only promote a mode into a new top-level approach if at least three units need it and it creates a meaningfully different counter relationship.

## Counter Strength Legend

- Hard: Usually flips the matchup if the counter is present and positioned/timed correctly.
- Soft: Helps, but does not solve the matchup alone.
- Race: Wins by ending the fight before the opponent's plan matters.
- Tax: Does not stop the plan, but forces worse placement, target choice, or timing.

## Approach Counter Matrix

| Approach | Pressures | Strong answers | Soft answers | Design note |
| --- | --- | --- | --- | --- |
| `access_backline` | Long-range carries, support engines, exposed amp pieces | `peel`, `zone`, `redirect`, `lockdown` | `damage_reduction`, `sustain`, `reposition` | Backline access should be powerful but readable. The defender should be able to bait it with carry placement or body-blocking. |
| `amp` | Slow front-to-back fights, wide boards, stat races | `disrupt`, `lockdown`, `debuff`, `access_backline` | `aoe`, `burst`, `zone` | Amp should create a priority target. If the amplifier cannot be threatened, it becomes invisible math. |
| `aoe` | Clumped teams, peel balls, support/tank stacks | Spread formation, `access_backline`, `long_range`, `damage_reduction` | `sustain`, `cc_immunity`, `reposition` | AoE should punish clumping, not erase every formation equally. |
| `burst` | Fragile carries, ramp units, sustain before it starts | `damage_reduction`, `redirect`, `untargetable`, `peel` | `sustain`, `cc_immunity`, `zone` | Burst needs a telegraph or target rule so the opponent can bait, split, or protect. |
| `cc_immunity` | `lockdown`, `disrupt`, debuff-heavy openers | `dot`, `ramp`, `execute`, delayed `burst` | `zone`, `long_range`, baiting low-value control | Immunity should answer control windows, not invalidate all control for the whole fight. |
| `damage_reduction` | Burst, on-hit pressure, engage openers | `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits | `execute`, `long_range`, `zone` | Mitigation is healthiest when it buys time rather than permanently solving damage. |
| `debuff` | Sustain, mitigation, amp engines, ramp carries | `cc_immunity`, cleanse via `peel`, `untargetable`, killing the debuffer | `sustain`, `long_range`, `reposition` | Debuffs should create a counterplay burden: cleanse them, dodge them, or remove the source. |
| `disrupt` | Channels, ramp, positioning plans, backline access | `cc_immunity`, `long_range`, `zone`, `sustain` | `reposition`, `damage_reduction` | Disrupt should break plans briefly. If it lasts too long, it becomes `lockdown`. |
| `dot` | Damage reduction, untargetable windows after application, long fights | `sustain`, cleanse via `peel`, `burst`, `execute` | `damage_reduction`, `cc_immunity` when application is controllable | DoT should make fights feel like clocks are running, not like delayed burst with no answer. |
| `engage` | Long-range siege, ramp engines, exposed backlines | `zone`, `peel`, `redirect`, `lockdown` | `damage_reduction`, `reposition`, `cc_immunity` | Engage is chess-like when one tile changes who gets caught. |
| `execute` | Sustain walls, low-health tanks, reset targets | `peel`, `sustain` above threshold, `untargetable`, `lockdown` | `damage_reduction`, `redirect` | Execute should punish failing health thresholds, not bypass all defensive play. |
| `lockdown` | Carries, divers, ramp units, single high-value threats | `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range` | `zone`, `damage_reduction`, `sustain` | Lockdown should be high agency on both sides: choose the right target or bait the cast. |
| `long_range` | Slow frontlines, zone casters, exposed carries | `access_backline`, `engage`, `zone`, `redirect` | `damage_reduction`, `sustain`, `reposition` | Range is most interesting when it wins lanes but loses if the line is breached. |
| `on_hit_effect` | High-health targets, extended front-to-back fights | `disrupt`, `lockdown`, `burst`, `zone` | `damage_reduction`, `debuff` | On-hit wants uptime; counters should attack uptime, not only damage per hit. |
| `peel` | Dive, burst, execute, single-target lockdown | `aoe`, `zone`, `support.formation_breaking`, `debuff` | `long_range`, `amp`, `disrupt` | Peel should protect a plan but invite flank, AoE, or formation-breaking answers. |
| `ramp` | Sustain, mitigation, low-pressure boards | `burst`, `execute`, `lockdown`, `engage` | `debuff`, `zone`, `dot` | Ramp makes the fight an experiment because the same board can win or lose based on timing. |
| `redirect` | Backline access, execute, long-range focus, pick burst | `aoe`, `zone`, `debuff`, `disrupt` | Tank shredding, `dot`, `long_range` retargeting | Redirect should create target-choice puzzles. AoE and formation-breaking should punish overreliance. |
| `reposition` | Zones, skillshot-like casts, engage, focus fire | `lockdown`, `zone`, `long_range`, `aoe` | `disrupt`, `debuff` | Reposition should be visible movement with risk, not free immunity. |
| `reset_mechanic` | Weak backlines, low-health teams, chaotic fights | Deny first kill with `peel`, `sustain`, `redirect`, `lockdown` | `damage_reduction`, `zone`, `untargetable` | Reset units need a first-kill gate so the defender can build around denial. |
| `sustain` | DoT, poke, moderate front-to-back damage | `execute`, `burst`, `debuff`, tank shredding | `lockdown`, `ramp`, `zone` | Sustain is healthy when it wins medium damage and loses to threshold or anti-heal style pressure. |
| `untargetable` | Burst, lockdown, execute, committed abilities | `zone`, `aoe`, pre-applied `dot`, delayed `ramp` | `long_range` after re-entry, baited casts | Untargetable should dodge a window, not erase the cost of bad positioning. |
| `zone` | Dive, engage, melee ramp, clumped peel balls | `long_range`, `reposition`, `untargetable`, killing the zone source | `sustain`, `damage_reduction`, edge-pathing | Zone is the most board-game-like approach. It should make tile choices matter before the fight starts. |

## Goal Counter Matrix

| Primary goal | What it tries to beat | Main counters | Required readable weakness |
| --- | --- | --- | --- |
| `tank.frontline_absorb` | Burst and front-to-back pressure | Tank shredding, `debuff`, `dot`, `access_backline`, `zone` | The tank can be bypassed, shredded, or punished for clumping. |
| `tank.team_fortification` | Burst, engage, wide incoming damage | `aoe`, `zone`, `support.formation_breaking`, `debuff` | Fortified allies should be strong together but vulnerable to formation pressure. |
| `tank.initiate_fight` | Long range, ramp, exposed carries | `zone`, `peel`, `redirect`, `cc_immunity`, `lockdown` | The engage target and angle should be scoutable. |
| `tank.single_target_lockdown` | One carry, diver, or ramp unit | `cc_immunity`, `peel`, `untargetable`, `long_range` | The locked target should be baitable or cleansable. |
| `brawler.attrition_dps` | Slow frontline fights | `burst`, `execute`, `zone`, `lockdown`, anti-sustain `debuff` | The brawler should lose when denied uptime. |
| `brawler.frontline_disruption` | Static frontlines, clustered tanks | `cc_immunity`, `peel`, `long_range`, `burst` | The disruption source should be punishable before it repeats. |
| `brawler.skirmish_dive` | Fragile backlines without hard commit | `zone`, `lockdown`, `peel`, `redirect` | Repeated access should have predictable entry paths or timing. |
| `assassin.backline_elimination` | Exposed carries and support engines | `peel`, `redirect`, `zone`, `lockdown`, `untargetable` | The defender should be able to protect or bait the carry. |
| `assassin.cleanup_execution` | Low-health teams and reset chains | `sustain`, `peel`, `redirect`, `lockdown` | Denying the first kill should meaningfully weaken the assassin. |
| `assassin.disrupt_and_escape` | Backline engines and slow casters | `zone`, `lockdown`, `peel`, `long_range` punishment | Escape should be strong only if the assassin actually creates disruption. |
| `marksman.sustained_dps` | Tanks and long front-to-back fights | `access_backline`, `engage`, `burst`, `lockdown`, `zone` | The marksman needs uptime and should care about protection and spacing. |
| `marksman.backline_siege` | Carries and fragile backline units from range | `engage`, `access_backline`, `zone`, `redirect` | The siege line should collapse if breached. |
| `marksman.tank_shredding` | Tanks, mitigation, sustain frontlines | `access_backline`, `burst`, `lockdown`, `long_range` counter-siege | Shred should require uptime and target access. |
| `mage.wombo_combo_burst` | Clumps and engage setups | Spread formation, `disrupt`, `cc_immunity`, `damage_reduction`, `reposition` | Wombo needs setup. If setup is denied, damage should drop. |
| `mage.area_denial_zone` | Dive, clumps, melee carries, static boards | `long_range`, `reposition`, `untargetable`, `burst` source kill | The zone source or zone edge should be playable around. |
| `mage.pick_burst` | Isolated targets and exposed carries | `peel`, `damage_reduction`, `untargetable`, `redirect`, `cc_immunity` | Isolation should be the mistake being punished. |
| `mage.sustained_dps` | Long fights where magic damage keeps ticking | `burst`, `pick`, `lockdown`, `engage`, `long_range` | The mage should need time or repeated casts. |
| `support.peel_carry` | Dive, execute, burst, lockdown | `aoe`, `zone`, `support.formation_breaking`, `debuff` | Protecting one carry should create a formation weakness. |
| `support.team_amplification` | Stat races and wide team plans | `disrupt`, `lockdown`, `access_backline`, `debuff`, `aoe` | The amplifier should be a visible pressure point. |
| `support.enemy_lockdown` | Divers, carries, and reset units | `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range` | Lockdown should be targetable, baitable, or cleanseable. |
| `support.initiate_fight` | Long-range or slow setup teams | `zone`, `redirect`, `lockdown`, `damage_reduction` | The enabled engage should have a visible lane or recipient. |
| `support.formation_breaking` | Clumps, peel balls, front-to-back lines | `cc_immunity`, `reposition`, spread formation, `burst` source kill | Formation breaking should be strongest against greedy placement. |

## Counter Loops

These loops are the main chess-like relationships the roster should create.

| Loop | Pressure | Answer | Answer to the answer |
| --- | --- | --- | --- |
| Backline loop | `long_range`, `amp`, carry engines | `access_backline`, `engage` | `peel`, `redirect`, `zone`, `lockdown` |
| Control loop | `lockdown`, `disrupt`, `debuff` | `cc_immunity`, cleanse via `peel`, `untargetable` | `dot`, `ramp`, delayed `burst`, `execute` |
| Frontline loop | `damage_reduction`, `sustain`, `redirect` | Tank shredding, `debuff`, `dot`, `ramp` | `burst`, `execute`, `lockdown`, backline access |
| Formation loop | `peel`, fortification, clumps | `aoe`, `zone`, formation breaking | Spread, `long_range`, `reposition`, source kill |
| Timing loop | `ramp`, `reset_mechanic`, delayed casts | `burst`, `engage`, `lockdown` | `damage_reduction`, `untargetable`, `peel`, baiting |

## Coverage Targets For The 50-Unit Plan

Current plus planned approach counts are skewed toward stat modifiers and output. The final roster does not need equal counts, but it should hit minimum counterplay coverage so the board has enough tactical levers.

| Approach | Current planned count | Target range | Planning action |
| --- | ---: | ---: | --- |
| `zone` | 2 | 5-6 | Add 3-4 more. This is the biggest board-game lever. |
| `redirect` | 1 | 3-4 | Add 2-3 more. Needed to answer dive, pick, and siege. |
| `untargetable` | 1 | 3-4 | Add 2-3 more. Needed as a true timing answer. |
| `dot` | 1 | 3-4 | Add 2-3 more. Needed to pressure mitigation and timing dodges. |
| `engage` | 4 | 6-7 | Add 2-3 more. Needed to stop long-range and amp engines. |
| `disrupt` | 4 | 7-8 | Add 3-4 more. Needed to break ramp, casts, and formation plans. |
| `lockdown` | 3 | 5-6 | Add 2-3 more. Needed to counter carries, divers, and resets. |
| `cc_immunity` | 3 | 4-5 | Add 1-2 more. Needed so control does not become oppressive. |
| `reset_mechanic` | 3 | 4-5 | Add 1-2 more. Needed for comeback and cleanup volatility. |
| `on_hit_effect` | 3 | 5-6 | Add 2-3 more. Needed so marksman/brawler uptime has texture. |
| `access_backline` | 4 | 5-6 | Add 1-2 more. Needed, but should stay special. |
| `reposition` | 5 | 6-7 | Add 1-2 more. Needed for zone and engage counterplay. |
| `burst` | 15 | 10-13 | Reduce or make more conditional. Too much generic burst flattens fights. |
| `damage_reduction` | 14 | 10-12 | Reduce or tie to positioning/timing. Too much mitigation makes fights muddy. |
| `amp` | 12 | 8-10 | Reduce generic amp. Keep only if the amplifier is targetable or positional. |
| `sustain` | 11 | 8-10 | Reduce generic sustain. Prefer sustain with threshold, target, or anti-heal answers. |

## Roster Planning Rules

Use these rules when designing or retagging units:

1. Every unit needs a "beats" statement and a "loses to" statement.
2. Any cost-4 or cost-5 unit needs at least one hard counter and one soft counter in existing vocabulary.
3. Any `burst`, `execute`, or `backline` unit needs a visible delay, target rule, threshold, or positioning tell.
4. Any `amp`, `sustain`, or `damage_reduction` unit needs a way for the enemy to pressure the source or punish the formation.
5. Any `zone`, `redirect`, `lockdown`, or `untargetable` unit should create an obvious before-fight placement question.
6. If moving one unit by one tile would not plausibly change the fight, the planned kit is probably too stat-driven.

## Immediate Plan Corrections

The next roster design pass should keep the 50-unit cost counts but retag/reconcept several planned identities:

- Move at least one support from `support.team_amplification` to `support.enemy_lockdown`.
- Move at least one support from `support.team_amplification` to `support.formation_breaking`.
- Move at least one support to `support.initiate_fight`.
- Move one mage to `mage.area_denial_zone`.
- Move one tank to `tank.single_target_lockdown`.
- Add at least two more `redirect` sources outside current Korath-style tank absorb.
- Add more `dot` and `untargetable` so timing counters are not only burst and shields.

The goal is not perfect symmetry. The goal is a counter web where scouting produces real decisions, and each battle still feels like an experiment because timing, tile placement, thresholds, and target selection can change the result.
