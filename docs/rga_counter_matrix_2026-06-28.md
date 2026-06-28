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

## Iteration Loop

This matrix is balanced toward what the finished first set should create, not what the current 22-unit roster or the first 50-unit draft already contains.

| Pass | Test | Finding | Change |
| --- | --- | --- | --- |
| 0 - Current-plan read | Count current plus planned RGA tags. | Too much generic output/stat texture: `burst`, `damage_reduction`, `amp`, and `sustain` dominated. | Stop treating current counts as the desired endpoint. |
| 1 - Role layer | Ask whether each role has natural prey and natural predators. | The six roles can create a Pokemon-style opening layer, but roles alone are too coarse. | Keep role spread close to even, then let goals/approaches decide exceptions. |
| 2 - Goal layer | Require every goal to appear and avoid catch-all goals. | `support.team_amplification`, `tank.frontline_absorb`, and `brawler.attrition_dps` can become defaults. | Use every goal, with no goal above 3 copies in the target matrix. |
| 3 - Approach layer | Require every threat to have answers and every answer to have pressure. | Board geometry and timing answers were too thin. | Raise `zone`, `redirect`, `untargetable`, `dot`, `engage`, `disrupt`, and `lockdown`. |
| 4 - Board mockups | Build ten-unit boards and counter boards. | No single archetype should beat all others; every board needs a predator and prey. | Define eight archetypes with explicit counter boards and failure cases. |
| 5 - Cost/trait check | Ask whether expensive units and trait verticals create intention without becoming auto-win paths. | Cost 4/5 should bend matchups, not remove counterplay. Traits should commit a board to an intent. | Cost and trait rules are included below as constraints on the matrix. |

## Role Counter Layer

Roles are the first rock-paper-scissors layer. They should create natural expectations, but goals and approaches are allowed to overturn those expectations when the matchup is correct.

| Role | Naturally pressures | Naturally checked by | Why it is not absolute |
| --- | --- | --- | --- |
| Tank | Assassin burst, fragile engage, scattered damage | Tank shredding marksmen, debuff, DoT, backline bypass | A tank with `frontline_absorb` can lose to an assassin only if the assassin brings `execute`, `debuff`, or backline access that makes the tank irrelevant. |
| Brawler | Frontlines, low-pressure boards, exposed marksmen | Zone, lockdown, burst, long range | Brawlers win uptime fights and lose when denied contact. |
| Assassin | Marksmen, mages, support engines | Peel, redirect, zone, lockdown | Assassins are not just anti-backline; their goal decides whether they kill, disrupt, or clean up. |
| Marksman | Tanks, brawlers, long fights | Assassin access, engage, zone, lockdown | Marksmen win with uptime. If formation or protection fails, they collapse. |
| Mage | Clumps, brawlers, tanks, setup boards | Assassin access, long range, disruption, CC immunity | Mages need timing or space. Area denial beats dive, pick burst beats isolation, wombo beats clumps. |
| Support | Burst, dive, control, team inefficiency | AoE, formation breaking, backline access, debuff | Support should make one plan strong while creating a visible pressure point. |

## Target Role Counts

For a 50-unit set, roles should be close to even while preserving assassin scarcity.

| Role | Target count | Strategic job |
| --- | ---: | --- |
| Tank | 9 | Frontline structure, engage, fortification, lockdown. |
| Brawler | 8 | Midline pressure, attrition, disruption, skirmish access. |
| Assassin | 6 | Rare but decisive backline pressure, cleanup, and disruption. |
| Marksman | 9 | Uptime damage, tank shredding, siege lines. |
| Mage | 9 | Burst windows, zone control, magic damage over time. |
| Support | 9 | Peel, amplification, initiation, formation control, lockdown. |
| Total | 50 |  |

## Target Goal Counts

The goal budget intentionally uses every goal. No goal should exceed three units in the first complete set, because repeated goals should differ by approach, cost, trait, and target rule rather than becoming one default plan.

| Primary goal | Target count | Target role pressure |
| --- | ---: | --- |
| `tank.frontline_absorb` | 3 | Core tanking, body-blocking, soak tests. |
| `tank.team_fortification` | 2 | Anti-burst and wide defensive shells. |
| `tank.initiate_fight` | 2 | Frontline engage and anti-siege starts. |
| `tank.single_target_lockdown` | 2 | Anti-carry, anti-reset, anti-dive anchor. |
| `brawler.attrition_dps` | 3 | Uptime melee pressure. |
| `brawler.frontline_disruption` | 3 | Anti-frontline and anti-clump pressure. |
| `brawler.skirmish_dive` | 2 | Repeatable soft backline threat. |
| `assassin.backline_elimination` | 2 | True carry deletion. |
| `assassin.cleanup_execution` | 2 | Reset and threshold punishment. |
| `assassin.disrupt_and_escape` | 2 | Backline chaos without guaranteed kill. |
| `marksman.sustained_dps` | 3 | Classic protected carry plan. |
| `marksman.backline_siege` | 3 | Anti-support and anti-caster range plan. |
| `marksman.tank_shredding` | 3 | Anti-mitigation and anti-frontline plan. |
| `mage.wombo_combo_burst` | 3 | Engage payoff and clump punishment. |
| `mage.area_denial_zone` | 3 | Anti-dive, anti-melee, board geometry. |
| `mage.pick_burst` | 2 | Isolation punishment. |
| `mage.sustained_dps` | 1 | Rare magic clock / DoT identity. |
| `support.peel_carry` | 2 | Dive and execute answer. |
| `support.team_amplification` | 2 | Wide/team engine, not catch-all support. |
| `support.enemy_lockdown` | 2 | Control support and reset denial. |
| `support.initiate_fight` | 1 | Rare support-led engage. |
| `support.formation_breaking` | 2 | Anti-clump and anti-peel-ball tool. |
| Total | 50 |  |

## Target Approach Budget

The target budget is not equal on purpose. Damage approaches can be slightly more common because every board needs a way to win, but geometry, control, and response approaches must be common enough that boards are decided by matchup choices, not only by stats.

Target total: 149 approach assignments across 50 units, or almost exactly three approach tags per unit.

| Approach | Target count | Strategic reason |
| --- | ---: | --- |
| `access_backline` | 6 | Enough to punish siege/amp engines, still rare enough to respect positioning. |
| `amp` | 8 | Important but no longer a default support answer. |
| `aoe` | 8 | Needed to punish clumps, peel balls, and fortification. |
| `burst` | 9 | Common enough for race plans, lower than the first draft. |
| `cc_immunity` | 5 | Keeps lockdown/disrupt honest without erasing control. |
| `damage_reduction` | 8 | Defensive pillar, but not allowed to dominate. |
| `debuff` | 8 | Main anti-stat, anti-sustain, and anti-tank tool. |
| `disrupt` | 8 | Core plan-breaking approach. |
| `dot` | 5 | Clock pressure against mitigation and target denial. |
| `engage` | 7 | Needed to stop range, ramp, and greedy engines. |
| `execute` | 6 | Threshold pressure against sustain and reset setups. |
| `lockdown` | 6 | Single-target answer to carries, divers, and capstones. |
| `long_range` | 8 | Keeps melee/control honest and enables siege archetypes. |
| `on_hit_effect` | 6 | Uptime texture for marksmen and brawlers. |
| `peel` | 8 | Main anti-dive/anti-burst answer. |
| `ramp` | 8 | Timing pressure and experiment-like fight outcomes. |
| `redirect` | 5 | Target-choice puzzle and pick/dive answer. |
| `reposition` | 6 | Counterplay against zone, engage, and focus fire. |
| `reset_mechanic` | 5 | Comeback volatility and cleanup threat. |
| `sustain` | 8 | Attrition pillar with clear anti-heal/execute answers. |
| `untargetable` | 5 | Timing dodge answer to burst/lockdown/execute. |
| `zone` | 6 | Core chess-board approach; enough to matter but not clog every fight. |
| Total | 149 |  |

Category balance:

| Category | Included approaches | Target total | Why this is acceptable |
| --- | --- | ---: | --- |
| Output and timing damage | `burst`, `aoe`, `dot`, `execute`, `reset_mechanic`, `on_hit_effect`, `ramp` | 47 | Damage remains the way fights end, but it is split across burst, clocks, uptime, threshold, and reset patterns. |
| Stat and attrition modifiers | `amp`, `damage_reduction`, `debuff`, `sustain` | 32 | Broad stat tags matter without becoming the whole game. |
| Board geometry and threat access | `access_backline`, `engage`, `long_range`, `redirect`, `reposition`, `zone` | 38 | Enough tools exist for tile placement and target access to decide fights. |
| Control and control answers | `cc_immunity`, `disrupt`, `lockdown`, `peel`, `untargetable` | 32 | Control can be important without becoming oppressive because answers are budgeted beside it. |
| Total |  | 149 |  |

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

## Cost Pressure Rules

Cost should change reliability and complexity, not remove counterplay.

| Cost | Matrix job | Counterplay requirement |
| --- | --- | --- |
| 1 | Simple board materials: one main role, one clear approach, early trait glue. | Should teach a matchup but rarely hard-counter alone. |
| 2 | Soft counters and connective pieces. | Should answer common openings without invalidating higher-cost plans. |
| 3 | Archetype cores. | Should define a board's first real strategic identity. |
| 4 | Pivot and hard-counter pieces. | Should flip specific matchups when supported, but lose if splashed without a team. |
| 5 | Capstones that bend rules. | Should require board commitment and still have at least one hard counter plus one soft counter. |

## Trait Pressure Rules

Traits should add commitment and deck-building intent on top of RGA identity.

- Vertical traits should make one counter relationship stronger, not make the board generically better at everything.
- Splash traits should create pivot options, not universal best-in-slot answers.
- Economy traits should buy access to answers, not replace needing the right answer.
- Positioning traits should make board layout matter; if a trait does not create a placement or scouting decision, it is probably only stats.
- Exact-count traits should increase matchup specialization and make the player choose which counter loop to commit to.

## Ten-Unit Board Archetypes

These boards are abstract target compositions. They are not implemented units. Each board uses ten slots and assumes a normal endgame shape: some low-cost foundations, several cost-2/3 cores, two cost-4 pivots, and zero to two cost-5 capstones.

| Board | Ten-unit shape | Primary plan | Beats | Loses to | Why it needs a team |
| --- | --- | --- | --- | --- | --- |
| Bastion Siege | 2 tanks, 2 supports, 3 marksmen, 1 mage, 1 brawler, 1 flex capstone | Protect long-range sustained damage behind fortification and peel. | Dive without zone, low-range attrition, scattered burst. | Formation breaking, AoE/zone, hard engage that breaches the line. | Marksmen need tanks and peel; supports need a carry worth protecting. |
| Dive Reset | 1 tank, 2 brawlers, 3 assassins, 1 support initiate, 1 mage pick, 1 marksman shred, 1 flex | Break the backline, trigger execute/reset chains, then clean up. | Siege, wide amp engines, exposed mage boards. | Redirect, zone, peel, single-target lockdown. | Assassins need engage, shred, and cleanup thresholds; raw assassins should fail into protected carries. |
| Zone Control | 1 tank, 1 brawler, 1 assassin disruptor, 2 mages, 3 supports, 1 marksman, 1 flex capstone | Make tiles dangerous and force bad pathing. | Dive, melee ramp, clumped peel balls, support engines that need formation. | Long range, reposition, untargetable, burst source-kill. | Zones need frontline delay and control support; zone casters alone should die. |
| Attrition Engine | 2 tanks, 3 brawlers, 1 marksman, 1 mage sustained, 2 supports, 1 flex | Survive the first wave and win through sustain/ramp/on-hit value. | Diffuse burst, low-DPS tanks, control without damage. | Execute, anti-heal debuff, tank shredding, area denial that denies uptime. | Attrition needs tanks, sustain, and damage clocks; one piece cannot do all three. |
| Wombo Engage | 2 tanks, 2 brawlers, 3 mages, 1 support initiate, 1 assassin cleanup, 1 flex | Start a fight on favorable terms and detonate clumps. | Siege that cannot move, clumped fortification, greedy ramp. | Spread formation, CC immunity, redirect, reposition. | Engage needs setup, mages need timing, cleanup needs damaged targets. |
| Control Prison | 2 tanks, 1 brawler, 1 assassin, 1 marksman, 2 mages, 3 supports | Lock priority targets and win while the enemy plan is delayed. | Reset, ramp, single-carry comps, fragile dive. | Cleanse/CC immunity, DoT clocks, long-range source kill, untargetable timing. | Control needs damage follow-up; lockdown without pressure should stall, not win. |
| Wide Trait Engine | 1 tank, 1 brawler, 1 assassin, 2 marksmen, 2 mages, 3 supports | Use wide traits and amp to create many medium threats. | Single-counter boards, slow attrition, teams with only one damage type. | AoE, formation breaking, backline access to the amp source, debuff. | Wide boards need broad role coverage; trait value should not replace board logic. |
| Anti-Meta Flex | 2 tanks, 1 brawler, 1 assassin, 2 marksmen, 1 mage, 2 supports, 1 flex capstone | Scout the lobby and field specific hard counters. | Any one-note board if the right pivot is found. | Strong committed archetypes when the flex player guesses wrong. | Flex needs economy, bench planning, and enough roles to use the counter pieces. |

## Board Counter Map

| Board | Primary predators | Primary prey | Close skill matchup |
| --- | --- | --- | --- |
| Bastion Siege | Zone Control, Wombo Engage, Formation Break Wide | Attrition Engine, weak Dive Reset, low-range boards | Control Prison if cleanse/CC immunity timing is correct. |
| Dive Reset | Zone Control, Bastion Siege with redirect, Control Prison | Bastion Siege without peel, Wide Trait Engine, exposed mages | Wombo Engage if dive dodges the engage window. |
| Zone Control | Siege with long range, Anti-Meta Flex with source kill, untargetable dive | Dive Reset, Wombo Engage, Attrition Engine | Wide Trait Engine if spread positioning is strong. |
| Attrition Engine | Tank Shred Siege, Execute Dive, Zone Control | Diffuse Burst, Control Prison without damage, weak Bastion Siege | Wide Trait Engine depending on debuff access. |
| Wombo Engage | Zone Control, Spread Siege, CC Immunity Control | Bastion Siege, Wide Trait Engine, greedy ramp | Dive Reset if assassins dodge first engage. |
| Control Prison | Cleanse/CC Immunity boards, DoT Attrition, Long-Range Siege | Dive Reset, Reset chains, single-carry boards | Bastion Siege depending on cleanse and target priority. |
| Wide Trait Engine | Formation Breaking, AoE Zone, Backline Pick | Anti-Meta Flex that guesses wrong, single-counter boards, slow tanks | Attrition Engine depending on anti-heal access. |
| Anti-Meta Flex | Strong committed archetypes when misread | One-note boards when correctly scouted | Almost every matchup; it should reward scouting, not autopilot. |

## Mock Situation Tests

These are logic tests for the matrix. They describe the kind of outcome the RGA layer should allow before numeric tuning happens.

| Test | Situation | Expected outcome | Why this is chess-like |
| --- | --- | --- | --- |
| Assassin kills a tank | A `tank.frontline_absorb` unit is isolated after its support is pulled away. An assassin with `cleanup_execution`, `debuff: armor shred`, and `execute` reaches it below threshold. | Assassin can kill a unit it normally should not kill. | Role expectation is overturned by goal/approach context and board state. |
| Tank beats assassin | Same assassin dives into a tank with `single_target_lockdown` and `redirect`, while a support has `peel: cleanse/shield`. | Assassin fails to reach reset and dies. | Same role matchup flips because the defensive board has the correct answer. |
| Zone beats engage | Wombo Engage tries to pull a backline carry through a `mage.area_denial_zone` board. | Engage path crosses zone, divers split, burst timing misses. | Tile layout changes the result before the fight starts. |
| Long range beats zone | Bastion Siege positions outside zone source range and uses `marksman.backline_siege` to kill the zone caster. | Zone board loses its main geometry tool. | The counter is not more stats; it is reach and source priority. |
| Control beats reset | Dive Reset relies on first kill. Control Prison locks the reset assassin before threshold damage lands. | Reset chain never starts. | Denying the first trigger is the answer, not out-damaging every assassin. |
| Cleanse beats control | Control Prison locks the carry, but support `peel: cleanse` plus `cc_immunity` removes the window. | Carry gets enough uptime to win. | Counterplay turns one hard answer into a baited cooldown. |
| Attrition beats burst | Burst board front-loads damage into `damage_reduction` and `sustain`, then runs out of pressure. | Attrition Engine stabilizes and wins late. | Timing matters; early advantage is not enough. |
| Execute beats attrition | Attrition stabilizes at low health, but an execute unit is protected until thresholds appear. | Sustain board collapses once execute windows open. | The answer is threshold management, not raw DPS. |
| Wide engine beats single answer | Anti-Meta Flex brings one anti-carry answer, but Wide Trait Engine has three medium threats and amp spread across roles. | Flex answer is insufficient. | One counter pick should not solve a diversified board. |
| Formation breaking beats peel ball | Bastion Siege stacks around one carry. Support formation breaking displaces the peel shell and exposes the carry to AoE. | Protected carry dies despite peel tools. | The board loses because of greedy formation, not because peel is weak. |

## Matrix Validation Checklist

| Requirement | Pass condition | Result |
| --- | --- | --- |
| Roles start the rock-paper-scissors layer. | Every role has natural prey, predators, and at least one way goals/approaches can overturn the role expectation. | PASS |
| Goals preserve intent. | All 22 goals appear in the target count table, and no goal exceeds three target units. | PASS |
| Approaches support counterplay. | All 22 approaches appear in the target budget, total approach assignments are near three per unit, and no broad stat tag dominates. | PASS |
| Team comps are necessary. | Each board archetype requires multiple roles and lists why one unit cannot execute the plan alone. | PASS |
| Multiple win paths exist. | Eight archetypes have distinct prey, predators, and close matchups. | PASS |
| Cost matters without removing counters. | Cost rules define foundations, soft counters, cores, pivots, and capstones with counterplay requirements. | PASS |
| Traits add strategy without replacing it. | Trait rules require commitment, pivot pressure, positioning, or exact-count decisions. | PASS |
| Situational reversals exist. | Mock tests include cases where a normally losing role wins through the correct goal/approach and board state. | PASS |

## Planning Rules After Balance

Use these rules when designing or retagging units:

1. Every unit needs a "beats" statement and a "loses to" statement.
2. Every unit should name its strongest board archetype and at least one counter-board archetype.
3. Any cost-4 or cost-5 unit needs at least one hard counter and one soft counter in existing vocabulary.
4. Any `burst`, `execute`, or `access_backline` unit needs a visible delay, target rule, threshold, or positioning tell.
5. Any `amp`, `sustain`, or `damage_reduction` unit needs a way for the enemy to pressure the source or punish the formation.
6. Any `zone`, `redirect`, `lockdown`, or `untargetable` unit should create an obvious before-fight placement question.
7. If moving one unit by one tile would not plausibly change the fight, the planned kit is probably too stat-driven.
8. If a trait makes every matchup generically better, narrow it until it reinforces one counter loop instead.

## Immediate Plan Corrections

The next roster design pass should keep the 50-unit cost counts but retag/reconcept planned identities toward the target matrix:

- Target support goals at `peel_carry:2`, `team_amplification:2`, `enemy_lockdown:2`, `initiate_fight:1`, `formation_breaking:2`.
- Target tank goals at `frontline_absorb:3`, `team_fortification:2`, `initiate_fight:2`, `single_target_lockdown:2`.
- Target mage goals at `wombo_combo_burst:3`, `area_denial_zone:3`, `pick_burst:2`, `sustained_dps:1`.
- Add enough `zone`, `redirect`, `untargetable`, `dot`, `engage`, `disrupt`, and `lockdown` to hit the target approach budget.
- Reduce generic `burst`, `damage_reduction`, `amp`, and `sustain` by making their modes conditional and counterable rather than broadly reliable.
- Give each cost-4 and cost-5 planned unit a named counter board before implementation.

The goal is not perfect symmetry. The goal is a counter web where scouting produces real decisions, and each battle still feels like an experiment because timing, tile placement, thresholds, and target selection can change the result.
