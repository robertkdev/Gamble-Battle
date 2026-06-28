# Endgame Roster Plan - 2026-06-28

Status: planning only. No unit resources, trait resources, shop odds, abilities, scenes, or scripts were implemented in this pass.

## Sources Checked

- Live repo unit resources: `data/units/*.tres`
- Live identity resources: `data/identity/unit_identities/*.tres`
- Live ability resources: `data/abilities/*.tres`
- Live trait resources and handlers: `data/traits/*.tres`, `scripts/game/traits/effects/*.gd`
- Current shop cost surface: `scripts/game/shop/shop_config.gd`
- Current identity summary: `docs/unit_identity_map.md`
- Current role baseline cost surface: `docs/role_baselines_costs.md`
- Current RGA docs: `docs/identity_schema.md`, `docs/rga/roles.md`, `docs/rga/role_goal_approach_coverage_2026-06-23.md`, `tests/rga_testing/README.md`
- Private Google design doc, read through the signed-in browser session

## Current Roster Snapshot

Current playable units: 22.

Current cost counts:

| Cost | Current units |
| --- | ---: |
| 1 | 12 |
| 2 | 9 |
| 3 | 1 |
| 4 | 0 |
| 5 | 0 |

Current primary-role counts:

| Role | Current units |
| --- | ---: |
| Tank | 6 |
| Brawler | 6 |
| Mage | 4 |
| Marksman | 3 |
| Support | 2 |
| Assassin | 1 |

Current playable unit inventory:

| Unit | Cost | Role | Traits | Ability |
| --- | ---: | --- | --- | --- |
| Axiom | 1 | Support | Scholar, Mentor | Mentor's Reserve |
| Berebell | 1 | Brawler | Sanguine, Striker | Unstable |
| Bo | 1 | Brawler | Fortified, Executioner | Writ of Severance |
| Bonko | 1 | Brawler | Cartel, Chronomancer | Bonk |
| Brute | 1 | Tank | Titan, Fortified | Slam |
| Cashmere | 1 | Mage | Arcanist, Mogul | Arcane Ledger |
| Grint | 1 | Tank | Cartel, Harmony | Body Check |
| Korath | 1 | Tank | Titan, Blessed | Absorb & Release |
| Morrak | 1 | Brawler | Striker, Executioner | Reaping Line |
| Mortem | 1 | Brawler | Sanguine, Vindicator | Blood Feast |
| Repo | 1 | Tank | Vindicator, Executioner | Writ of Severance |
| Sari | 1 | Marksman | None currently assigned | Strike |
| Kythera | 2 | Tank | Aegis, Vindicator | Siphon |
| Luna | 2 | Mage | Liaison, Kaleidoscope | Moon Beam |
| Nyxa | 2 | Marksman | Sanguine, Chronomancer | Chaos Volley |
| Paisley | 2 | Mage | Arcanist, Kaleidoscope, Blessed | Bubbles |
| Teller | 2 | Marksman | Exile, Mogul | Margin Call |
| Totem | 2 | Support | Bulwark, Exile | Cleanse |
| Veyra | 2 | Tank | Aegis, Bulwark | Harden |
| Volt | 2 | Mage | Scholar, Overload | Arc Lock |
| Vykos | 2 | Brawler | Sanguine, Fortified | Blood Feast |
| Hexeon | 3 | Assassin | Kaleidoscope, Executioner | Prismatic Guillotine |

Current trait state:

| Trait | Current unit count | Thresholds | Planning note |
| --- | ---: | --- | --- |
| Aegis | 2 | 2, 4, 6, 8 | Needs more mid/late defensive units. |
| Arcanist | 2 | 2, 4, 6, 8 | Needs more spell carries beyond cost 2. |
| Blessed | 2 | 2, 4, 6 | Needs more healing/shield units. |
| Bulwark | 2 | 2, 4 | Low but functional. |
| Cartel | 2 | 2 | Needs higher-cost payoffs once cost 4/5 exist. |
| Catalyst | 0 | 1 | Exists in data/runtime but has no playable unit. |
| Chronomancer | 2 | 1 | Already activates, but needs a late identity. |
| Executioner | 4 | 2, 4, 6, 8 | Strong current coverage; can support assassins. |
| Exile | 2 | 1, 3, 5 | Needs exact-count build options. |
| Fortified | 3 | 2, 4, 6, 8 | Needs high-cost frontliners. |
| Harmony | 1 | 2 | Needs at least one more low-cost option. |
| Kaleidoscope | 3 | 2 | Good splash identity, needs a true endgame capstone. |
| Liaison | 1 | 1, 3, 5 | Needs several units for the positioning mini-game. |
| Mentor | 1 | 1, 2, 3, 4 | Needs more pupil/donor choices. |
| Mogul | 2 | 2, 4, 6 | Needs more economy units after opening. |
| Overload | 1 | 2, 4, 6 | Needs more casters to become real. |
| Sanguine | 4 | 2, 4, 6 | Healthy brawler identity. |
| Scholar | 2 | 2, 4, 6 | Needs higher-cost mana engines. |
| Striker | 2 | 2, 4, 6, 8 | Needs mid/late AD carries. |
| Titan | 2 | 2, 4, 6, 8 | Needs high-cost vertical finishers. |
| Trader | 0 | 2, 4, 6 | Exists in data/runtime but has no playable unit. |
| Vindicator | 3 | 2, 4, 6 | Healthy start, needs premium shred. |

## Endgame Target

The first complete endgame roster should be 50 playable units.

Why 50:

- The design doc says max team size is 10.
- The design vocabulary already references cost-1 through cost-5 payoffs.
- The repo has 22 trait resources. A 50-unit roster gives about 100 trait slots, enough for real verticals, splashes, and pivot builds without trying to make a full TFT-scale set.
- Current content already has 22 units, so 50 keeps the next milestone large enough to feel like a finished first set but small enough to plan and validate.

Final cost counts:

| Cost | Current | Target | Add |
| --- | ---: | ---: | ---: |
| 1 | 12 | 14 | 2 |
| 2 | 9 | 13 | 4 |
| 3 | 1 | 11 | 10 |
| 4 | 0 | 8 | 8 |
| 5 | 0 | 4 | 4 |
| Total | 22 | 50 | 28 |

Endgame board expectation:

- A finished run should field up to 10 units.
- A good final board should usually contain 1-2 upgraded low-cost foundations, 3-5 cost-2/cost-3 role pieces, 2-3 cost-4 premium pivots, and 0-2 cost-5 capstones.
- Trait planning should support one committed vertical plus two smaller splashes, or several 2-piece/3-piece synergies for Harmony/Kaleidoscope/Liaison style boards.
- Costs 4 and 5 should not just be "bigger numbers." They should introduce build-changing patterns: item evolution, exact-count Exile boards, high-risk assassin resets, late mana engines, and premium defensive anchors.

## Fill Loop Rules

Each new unit below is designed around one gap:

- Fill an empty or underused trait.
- Add missing cost-3, cost-4, and cost-5 shop texture.
- Give support, assassin, marksman, and mage more late-game options.
- Create a unit with a specific gameplay contribution, not just a different damage number.
- Stay compatible with the current Role/Goal/Approach vocabulary.

## Planned Additions

### Cost 1 Additions: 2 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Knoll | Support | Trader, Harmony | Tiny ledgerman in a patched velvet coat, carrying a receipt roll like a battle standard. | Receipt Mark: marks the nearest enemy. If the target dies, the team gains a temporary combat buff and the next shop gains a free-reroll token. | Gives Trader its first playable unit and gives Harmony a cheap second piece without making another bruiser. |
| Pilfer | Assassin | Catalyst, Cartel | Masked courier with mirrored coin knives and a satchel full of half-built item parts. | Pocket Swap: dashes to the farthest enemy, deals light physical damage, then steals a short buff from the target or charges Pilfer's held item if no buff exists. | Introduces Catalyst early and gives Cartel an aggressive low-cost unit that cares about item tempo. |

### Cost 2 Additions: 4 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Miri | Support | Mentor, Trader | Traveling tutor with chalk-dust sleeves, gold abacus beads, and a little folding desk shield. | Lesson Plan: selects the nearest ally without shared traits as the Student, granting mana and a small shield. If the Student gets a takedown, the next shop reroll is discounted. | Makes Mentor less Axiom-only and links early support play to economy. |
| Cinder | Mage | Overload, Arcanist | Furnace-hearted spellcaster with cracked ceramic armor and a glowing wick inside the chest. | Fuse Spark: fires a delayed magic bomb. If Cinder casts again before it explodes, both bombs merge into a larger blast. | Gives Overload a real second piece and creates a simple spell-timing fantasy. |
| Rooket | Marksman | Bulwark, Fortified | Squat trench artillery unit with a shoulder-mounted rook tower and shield plates over the barrel. | Brace Shot: roots briefly, gains damage reduction, then fires a heavy bolt that pierces the first target and slows enemies behind it. | Adds a defensive marksman, making Bulwark/Fortified less purely frontline. |
| Velour | Support | Liaison, Blessed | Soft-spoken seamstress in glowing thread armor, with ribbon charms orbiting injured allies. | Silk Knot: links the two lowest-health allies for several seconds. Healing or shielding either ally shares a percentage with the other. | Makes Liaison readable early and gives Blessed a support bridge. |

### Cost 3 Additions: 10 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Caldera | Tank | Titan, Catalyst | Basalt giant with a molten item-core embedded in one hand. | Molten Core: absorbs a portion of incoming damage, then erupts around Caldera. If holding an item, the item gains Catalyst charge when Caldera survives the cast. | Adds the first mid-game Catalyst tank and a Titan unit that wants to survive, not just engage. |
| Ivara | Marksman | Trader, Mogul | Auctioneer sniper with a long rifle shaped like a bidding gavel. | Open Bid: shoots the highest-current-HP enemy. If the shot helps kill the target, Ivara banks bonus gold after combat. | Turns economy into a marksman identity instead of only mage/support economy. |
| Noxley | Mage | Sanguine, Overload | Blood-red street magician with sparking needles floating over one arm. | Red Static: spends a small amount of current health to reduce current mana cost, then fires chain magic that heals Noxley for a fraction of damage dealt. | Gives Sanguine a caster branch and Overload a risk/reward unit. |
| Quorra | Assassin | Aegis, Chronomancer | Clockwork duelist with mirrored armor plates that tick backward after each hit. | Timeplate Lunge: blinks to a backline enemy, gains temporary Armor/MR, and slows the target's attack speed. | Adds a defensive assassin pattern: access plus survivability instead of pure burst. |
| Juno Vale | Support | Liaison, Scholar | Star-map archivist with floating geometry charts and a quill halo. | Constellation Math: links two allies with no shared traits. Linked allies gain mana over time; if both cast, nearby allies gain a smaller mana burst. | Makes Liaison and Scholar become a positioning puzzle. |
| Kett | Brawler | Striker, Cartel | Dockworker enforcer with coin-stamped brass knuckles and a broken paygate shield. | Union Breaker: punches the target three times. Each hit deals bonus physical damage based on Kett's cost and current Cartel tier. | Gives Cartel a mid-cost frontliner and Striker a tempo bruiser. |
| Egress | Assassin | Exile, Executioner | Pale escape artist wrapped in black ticket stubs, always standing one tile away from allies. | Exit Wound: strikes the lowest-health enemy. On kill, Egress becomes briefly untargetable and reappears at the nearest edge tile. | Creates exact-count Exile assassin play and gives Executioner another reset unit below capstone rarity. |
| Marble | Marksman | Fortified, Blessed | Statue-like crossbow unit with chapel-glass armor and a stone halo sight. | Sanctuary Bolt: fires a slow bolt. The first ally the bolt passes through gains a shield; the enemy hit takes physical damage and reduced attack speed. | Adds a defensive marksman that can peel without becoming a support. |
| Prisma | Mage | Kaleidoscope, Harmony | Prism-faced illusionist whose robe changes to match the team's active traits. | Color Theory: copies the smallest active trait bonus as a short self-buff, then releases a small area burst in that trait's color. | Gives Harmony and Kaleidoscope a mid-game bridge for wide boards. |
| Sable | Marksman | Vindicator, Scholar | Ink-black rifle scholar with page talismans tied to each bullet. | Footnote Piercer: fires a line shot that shreds Armor/MR and refunds mana if it hits at least two enemies. | Supports shred comps and gives Scholar a non-mage damage unit. |

### Cost 4 Additions: 8 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Ravel | Support | Mentor, Liaison | Marionette conductor with gold strings running from both hands to nearby allies. | Puppet Strings: creates two Pupil links instead of one. Linked allies share a percentage of offensive stats and gain damage reduction while near each other. | Makes positioning support a premium strategy and gives Mentor a real late-game payoff. |
| Draxelle | Brawler | Titan, Striker | Towering lancer with a chain-hook spear and growing stone plates after every cast. | Colossus Hook: pulls a distant enemy one tile closer, then cleaves. Gains Titan stacks on cast and Striker stacks on takedown. | Combines engage, scaling, and AD vertical payoff without adding another pure tank. |
| Orielle | Mage | Arcanist, Overload | Elegant debt-mage with floating IOU sigils orbiting her staff. | Spell Debt: stores a portion of mana spent by nearby allies. On cast, detonates stored debt as magic damage split across marked enemies. | Turns Overload/Arcanist into a team mana-spend payoff instead of another single nuke. |
| Bastionne | Tank | Aegis, Bulwark | Walking fortress knight with a split gate shield and ringing bell pauldrons. | No-Pass Writ: raises a gate wall, granting nearby allies Armor/MR and blocking the first crowd-control effect against them. | Creates a premium defensive anchor for Aegis/Bulwark boards. |
| Vesper | Assassin | Chronomancer, Executioner | Dusk assassin with hourglass daggers and a veil that sheds sand when she moves. | Late Fee: marks a low-health enemy. If the target remains alive after a short delay, it is stunned; if it falls below execute range, Vesper teleports in to finish it. | Adds delayed execution and counterplay instead of instant backline deletion. |
| Gable | Marksman | Trader, Cartel | Rooftop cardsharp with a folding rifle and betting slips pinned to the cloak. | Market Corner: each cast rotates between attack-speed, spell-power, and damage-amp shots based on the highest-cost ally fielded. | Makes high-cost Cartel boards feel different from low-cost reroll boards. |
| Saffron | Support | Blessed, Catalyst | Apothecary-priest with amber bottles, floating salves, and item shards sealed in wax. | Golden Poultice: heals and shields the most injured ally. If the ally holds an item, the item gains Catalyst charge; overheal becomes a small team shield. | Gives Catalyst a healing route and Blessed a premium stabilizer. |
| Omenry | Marksman | Exile, Vindicator | Lone oracle-gunner with a blindfold scope and black-feather cartridges. | Condemning Shot: targets the enemy with the fewest adjacent allies, shreds defenses, and deals bonus damage if Omenry is isolated. | Makes exact-count Exile positioning matter and adds premium armor/MR shred. |

### Cost 5 Additions: 4 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Meridian | Mage | Kaleidoscope, Liaison, Catalyst | Full-spectrum envoy with a glass crown, treaty scrolls, and orbiting item prisms. | Full Spectrum Treaty: links every ally whose traits do not overlap with Meridian, then fires a beam that gains an effect from each unique linked trait. Linked held items gain Catalyst charge. | Capstone for wide boards, Liaison puzzles, and item-evolution strategy. |
| Malachor | Tank | Titan, Fortified, Sanguine | Black-green raid boss in living armor, with cracks that glow brighter as he is damaged. | Debt of Flesh: absorbs incoming damage for several seconds, converts part of it into self-healing, then releases a shockwave whose size scales with missing health. | Endgame frontliner for health, damage reduction, and sustain verticals. |
| Quillith | Support | Scholar, Overload, Mentor | Ancient exam proctor with a floating book, quill wings, and mana chains around the wrists. | Final Exam: chooses the highest-damage ally as the Pupil. When the Pupil casts, Quillith grants mana to nearby allies; every third Pupil cast causes a free reduced-power recast. | Capstone mana engine that makes caster boards feel intentionally built. |
| Nullora | Assassin | Executioner, Exile, Harmony | Silent final-word executioner, all white mask and black script, with one oversized crescent blade. | Last Word: appears beside the enemy carry after a delay. If no allied trait has more than three units, the strike gains execute range and Nullora vanishes after the hit. | Capstone for wide/exact-count boards and the premium assassin identity. |

## Planned RGA Assignments

These are intended identities, not implemented verdicts. A later content pass should create the corresponding `UnitIdentity` resources and then prove each kit with the Role Matrix / RGA validation scenes. The `Proof intent` column states what the future ability implementation must visibly and mechanically produce for the assigned goal and approaches.

| Unit | Cost | Primary role | Primary goal | Approaches | Proof intent |
| --- | ---: | --- | --- | --- | --- |
| Knoll | 1 | support | `support.team_amplification` | `amp`, `debuff` | Marked enemies should produce source-attributed team output lift or enemy vulnerability, plus a clear economy reward after combat. |
| Pilfer | 1 | assassin | `assassin.disrupt_and_escape` | `access_backline`, `disrupt`, `reposition` | Dash should contact backline or far targets, steal/remove a useful buff, then return or move away instead of staying as a brawler. |
| Miri | 2 | support | `support.team_amplification` | `amp`, `peel`, `sustain` | Student link should grant mana/output, shield the student or self, and create source-attributed ally protection. |
| Cinder | 2 | mage | `mage.pick_burst` | `burst`, `aoe` | Delayed bombs should create a clear cast-to-peak damage window, with merged casts hitting multiple enemies when positioned well. |
| Rooket | 2 | marksman | `marksman.tank_shredding` | `long_range`, `debuff`, `damage_reduction` | Braced shot should fire from range, apply a slow or resistance shred, and prove the self-root defensive tradeoff with mitigation evidence. |
| Velour | 2 | support | `support.peel_carry` | `peel`, `sustain`, `amp` | Silk Knot should share healing/shields between threatened allies and produce ally-protection spans, not just self-survival. |
| Caldera | 3 | tank | `tank.frontline_absorb` | `damage_reduction`, `sustain`, `aoe` | Absorb window should prevent or store incoming damage, heal/survive through pressure, then convert pressure into area retaliation. |
| Ivara | 3 | marksman | `marksman.tank_shredding` | `long_range`, `debuff`, `burst` | Open Bid should prioritize high-HP/frontline targets, apply a bid-mark or shred, and show meaningful burst conversion on marked targets. |
| Noxley | 3 | mage | `mage.sustained_dps` | `dot`, `sustain`, `ramp` | Red Static should create repeated magic output over time, health-risk sustain, and stronger later casts or chain growth. |
| Quorra | 3 | assassin | `assassin.disrupt_and_escape` | `access_backline`, `debuff`, `damage_reduction` | Timeplate Lunge should reach a backline target, tax its attack speed, and give Quorra temporary defensive evidence during escape. |
| Juno Vale | 3 | support | `support.team_amplification` | `amp`, `peel`, `zone` | Constellation links should generate ally mana/output and make a visible positioning zone or constellation area that rewards linked placement. |
| Kett | 3 | brawler | `brawler.attrition_dps` | `on_hit_effect`, `ramp`, `sustain` | Repeated punches should produce on-hit or stack evidence, improve over an extended fight, and keep Kett alive through pressure. |
| Egress | 3 | assassin | `assassin.cleanup_execution` | `execute`, `reset_mechanic`, `reposition` | Low-health kills should trigger execute evidence, a reset/chain opportunity, and an immediate movement reset to the edge. |
| Marble | 3 | marksman | `marksman.sustained_dps` | `long_range`, `peel`, `debuff` | Sanctuary Bolt should keep ranged uptime while providing source-attributed ally shielding and enemy slow/debuff events. |
| Prisma | 3 | mage | `mage.wombo_combo_burst` | `burst`, `aoe`, `amp` | Color Theory should produce a team-enabled AoE burst window and scale with wide-trait team context rather than solo damage only. |
| Sable | 3 | marksman | `marksman.tank_shredding` | `long_range`, `debuff`, `on_hit_effect` | Footnote Piercer should repeatedly shred defenses from range, with basic or shot-based proc evidence attached to Sable. |
| Ravel | 4 | support | `support.team_amplification` | `amp`, `peel`, `damage_reduction` | Puppet links should transfer offensive stats, reduce linked ally damage taken, and produce direct ally-output or protection deltas. |
| Draxelle | 4 | brawler | `brawler.frontline_disruption` | `engage`, `disrupt`, `ramp` | Hook should start fights or pull priority targets, break formation, and gain measurable combat power after casts/takedowns. |
| Orielle | 4 | mage | `mage.wombo_combo_burst` | `burst`, `aoe`, `ramp` | Stored ally mana should build toward a large synchronized detonation with multi-target damage and clear late-window payoff. |
| Bastionne | 4 | tank | `tank.team_fortification` | `amp`, `damage_reduction`, `cc_immunity` | Gate wall should fortify nearby allies, prevent or reduce CC, and produce team defensive buff evidence. |
| Vesper | 4 | assassin | `assassin.cleanup_execution` | `execute`, `reset_mechanic`, `lockdown` | Delayed mark should either stun a surviving target or convert a low-health target into an execute/reset chain. |
| Gable | 4 | marksman | `marksman.sustained_dps` | `long_range`, `on_hit_effect`, `ramp` | Rotating market shots should maintain range, create shot-specific procs, and become stronger with higher-cost board context. |
| Saffron | 4 | support | `support.peel_carry` | `peel`, `sustain`, `amp` | Poultice should stabilize the carry with heal/shield evidence, convert overheal to team protection, and optionally amplify item users. |
| Omenry | 4 | marksman | `marksman.tank_shredding` | `long_range`, `debuff`, `burst` | Condemning Shot should hit from range, shred defenses, and punish isolated or exposed frontliners with burst damage. |
| Meridian | 5 | mage | `mage.wombo_combo_burst` | `aoe`, `burst`, `amp` | Treaty links should convert wide-board trait diversity into a large multi-target burst and measurable ally/team amplification. |
| Malachor | 5 | tank | `tank.frontline_absorb` | `damage_reduction`, `sustain`, `zone` | Debt of Flesh should soak focused damage, heal through it, and leave a battlefield shockwave/zone that controls space. |
| Quillith | 5 | support | `support.team_amplification` | `amp`, `peel`, `reset_mechanic` | Final Exam should amplify a carry, feed team mana, and create source-attributed recast/reset evidence tied to the Pupil. |
| Nullora | 5 | assassin | `assassin.backline_elimination` | `access_backline`, `burst`, `execute`, `untargetable` | Last Word should reach the enemy carry, deliver a short burst/execute window, and briefly vanish to avoid immediate retaliation. |

## Resulting Roster Shape

After these additions:

| Cost | Final count |
| --- | ---: |
| 1 | 14 |
| 2 | 13 |
| 3 | 11 |
| 4 | 8 |
| 5 | 4 |
| Total | 50 |

Resulting role shape:

| Role | Current | Planned additions | Final |
| --- | ---: | ---: | ---: |
| Tank | 6 | 3 | 9 |
| Brawler | 6 | 2 | 8 |
| Mage | 4 | 5 | 9 |
| Marksman | 3 | 6 | 9 |
| Support | 2 | 7 | 9 |
| Assassin | 1 | 5 | 6 |

Resulting trait coverage priorities:

- Catalyst goes from 0 to 4 units immediately, enough to make the trait real.
- Trader goes from 0 to 4 units immediately, enough to support economy builds.
- Mentor goes from 1 to 4 units, reaching the full current Mentor threshold.
- Liaison goes from 1 to 5 units, reaching the full current Liaison threshold.
- Overload goes from 1 to 5 units, making caster mana builds real.
- Harmony goes from 1 to 4 units, supporting wide boards without requiring a full vertical.
- Cost 4/5 units give Cartel meaningful high-cost payoffs.
- Assassins improve from one current unit to six total, but remain rarer than tanks/supports because backline access should be special.

## Implementation Notes For A Later Pass

- Do not add these directly as `.tres` files without first deciding whether cost 4/5 should be exposed by `ShopConfig.VALID_COSTS`, `MAX_LEVEL`, and `ODDS_BY_LEVEL`.
- Sari is currently traitless. That should be resolved separately before or during the next content pass.
- Cost 4/5 units need role-goal-approach identities and RGA expectations before they should enter the playable pool.
- Catalyst and Trader already have resource definitions and effect handlers, but their play feel should be tested as soon as the first units are implemented.
- New units should be implemented in small batches by cost band, with `CostBalanceSmoke`, `UnitStatAudit`, `RoleMatrixProbe`, and a Main-scene shop/playability smoke after each batch.
- For each implemented unit, run an RGA pass that proves the assigned primary role, primary goal, and every listed approach. Catalog support alone is not enough; live kit telemetry must match the planned identity.
