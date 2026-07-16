# Gamble Battle Endless Economy Blueprint

Date: 2026-07-16
Status: research and implementation blueprint; no gameplay behavior changed

## Decision

Keep ordinary units priced at 1–5 gold. Do not ask the unit shop alone to absorb an exponential bankroll.

Build the endless economy around a fixed, chapter-indexed reference curve and a new class of large purchases: chapter contracts, donor fees, targeted scouting, command research, item awakenings, and battlefield rule changes. These purchases must create qualitative combat escalation rather than an infinite ladder of tiny stat upgrades.

The first tuning target is:

- Normal projected win probability: 60–75%, centered near 68%.
- Normal wager: a minority of bankroll, roughly 20–35%.
- All-in: an exceptional desperation or conviction play.
- Major economic decision: once per five-fight chapter.
- Run structure: endless and resumable across sessions.
- Defeat persistence: identity, history, records, and cosmetics only; no compounding combat power.
- Primary score: total money earned, with depth, peak bankroll, biggest wager, and richest fight as supporting records.

## Research Translation

The TFT mode was **Tocker's Trials**, released for patch 14.17 on August 27, 2024 and scheduled to rotate out with patch 14.19 on September 24. It was not technically endless: Riot described 30 rounds, six bosses, three lives, solo play without timers, a high score, and a separate Chaos mode. The important lesson is not literal infinity. It is the escalating boss cadence, player-controlled planning time, and permission to create enemy boards outside normal PvP constraints.

The Last Flame exposes an endless continuation after its acts and builds escalation from hero, item, and synergy combinations. Hadean Tactics' Eternal Rift adds a persistent-in-run structure, custom hero skills for sale, save/load support, survivor recruitment, and rotating challenge variants. These reinforce a shared direction for Gamble Battle: when the ordinary roster loop matures, unlock new upgrade vocabularies instead of extending the same purchase forever.

Incremental games commonly pair exponentially increasing production with exponentially increasing costs, then introduce qualitative breakpoints, automation, or prestige layers when the old scale becomes routine. Gamble Battle should use the exponential curve and breakpoints, but not the conventional permanent-power prestige loop. Defeat should preserve identity and history while restoring the next run's combat baseline.

## Why Base Unit Prices Stay 1–5

The current game has five cost tiers and a 1.5x stat multiplier per unit level. Comparing candidate fixed price schedules against that power multiplier gives:

| Candidate | Prices | Price/power CV | Extra doublings from 5-gold top tier | Decision |
|---|---:|---:|---:|---|
| Current | 1 / 2 / 3 / 4 / 5 | 0.1303 | 0.00 | Keep |
| Moderate | 1 / 2 / 4 / 7 / 11 | 0.2662 | 1.14 | Reject as the main sink |
| Broad | 1 / 3 / 10 / 30 / 100 | 0.9469 | 4.32 | Reject as the main sink |

The wider schedules provide only a few doublings of runway and make value per gold substantially less consistent. They would also make a strong unit's identity harder to separate from its sticker price.

Ordinary unit prices should remain a readable recruitment vocabulary. Late-game units become economically important because they can be named donors, catalysts, or identity requirements for expensive contracts.

## Independent Money Curve

The initial reference bankroll is:

`B(chapter) = 3 × 1.22^(chapter − 1)`

This is not a prediction of the player's current wallet. It is the desired content budget for a healthy run and the common ruler used to tune enemy power, rewards, and prices.

Player-facing prices are rounded to readable 1-2-5 bands:

- Standard chapter contract: approximately 20% of `B(chapter)`.
- Bold chapter contract: approximately 32% of `B(chapter)`, always promoted to a visibly higher price band than the standard offer.
- Targeted scouting/reroll: approximately 1% of `B(chapter)`, minimum 2.
- XP or Command Research: approximately 2% of `B(chapter)`, minimum 4.
- Donor contract fee: approximately 4% of `B(chapter)`, minimum 5.

Nothing in these formulas reads the player's current bankroll. A rich player is not silently charged more, and a poor player is not secretly subsidized. Affordability changes because of the player's decisions and performance, not a rubber-band price.

Selected milestones:

| Chapter | Reference bankroll | Standard contract | Bold contract | Scout/reroll | XP/command | Donor fee |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 1 | 2 | 2 | 4 | 5 |
| 5 | 6.65 | 1 | 2 | 2 | 4 | 5 |
| 10 | 17.96 | 4 | 6 | 2 | 4 | 5 |
| 20 | 131.21 | 20 | 50 | 2 | 4 | 5 |
| 40 | 7,000.91 | 1,000 | 2,000 | 50 | 100 | 200 |
| 60 | 373,552.17 | 50,000 | 100,000 | 5,000 | 5,000 | 10,000 |
| 80 | 19,931,862.29 | 5,000,000 | 10,000,000 | 200,000 | 500,000 | 1,000,000 |

The checked-in CSV is authoritative for exact rounded milestones.

## Odds and Payout Proposal

Use projected win probability to quote a gross payout:

`gross payout multiplier = clamp((1 + 0.45) / projected_win_probability, 1.05, 4.0)`

At the 68% target, this is a 2.1324x gross return on the wager.

The `0.45` term is deliberately not described as fair-market odds. It is a provisional growth subsidy/player edge chosen by the simulation so that ordinary strategies can both spend and survive. It must be recalibrated against a larger combat-odds sample and real player behavior.

Recommended wager UX:

- Default recommendation: fractional-Kelly-inspired, clamped to 10–35% of bankroll.
- Normal presentation: projected win probability, gross return, loss amount, and bankroll after win/loss.
- All-in: separated from the normal slider flow and presented as exceptional.
- Never promise deterministic results from a probability estimate.

## The Five-Fight Chapter Market

Every five fights, present three mutually exclusive offers. The player chooses one; the others expire.

### Champion Contract

Changes one unit's identity or kit:

- Ability gains a second phase.
- Kill, cast, crit, shield break, or death creates a chain reaction.
- Unit splits, transforms, mounts, possesses, or consumes a donor.
- Targeting rule changes.
- One stat converts into another behavior.
- A trait becomes unit-specific and exaggerated.

### Stable Contract

Changes team construction:

- Trait threshold or trait rule rewrite.
- Formation slot, bench function, reserve deployment, or support link.
- One archetype gains a shared trigger.
- A donor unit permanently teaches a bounded team rule.
- Command points, reserve summons, or once-per-fight tactical actions.

### Pit Contract

Changes the fight, wager, or reward environment:

- Add a visible hazard or boss modifier for better odds/reward.
- Let the player select one of several enemy mutators.
- Introduce bounty targets, side objectives, or escalating crowd conditions.
- Trade safer projected odds for a richer payout.
- Add a readable arena-wide rule that affects both teams.

All three offers use fixed chapter prices. The player's bankroll affects which choices are affordable, not what they cost.

## What Happens to Existing Progression

### Chapters 1–5

Preserve the familiar loop:

- Buy ordinary 1–5 gold units.
- Reroll for 2.
- Buy XP for 4.
- Combine duplicates normally.
- Introduce the first contract as a tutorial, free choice, or low-price chapter capstone.

### Midgame

Contracts become the primary source of qualitative escalation. The shop still sells playable units, but distinct units can also appear as named contract donors. Duplicate requirements should be bounded and purposeful rather than asking for hundreds of copies.

### Level 14 and Level-4 Unit Cap

The current level and promotion endpoints become conversion points:

- XP purchase becomes Command Research.
- Normal duplicate combining stops at level 4.
- Additional copies do not feed an infinite stat ladder.
- The shop shifts toward targeted donors, contract catalysts, scouting, command upgrades, and limited awakenings.

### Deep Endless

Keep board cap and visual grammar bounded. Make fights crazier through:

- Multi-stage bosses.
- Summon waves and reserve deployments.
- Transformations and phase changes.
- Death, cast, crit, shield, and displacement chains.
- Arena hazards with clear telegraphs.
- Trait rules that alter targeting or timing.
- Readable battlefield-wide payoffs.
- Rare contract combinations that create emergent spectacles.

The goal is more events and more consequential interactions, not simply more bodies or unreadable particles.

## Upgrade Path Catalog

These are option families, not a commitment to implement all of them.

### Unit Identity

- Ability branch A/B.
- Trigger graft from a donor.
- New target-selection rule.
- Form change at health threshold.
- Kill-spree evolution.
- Death inheritance.
- Summon replacement.
- Trait inversion.
- Damage-type conversion.
- Bounded item-slot mutation.

### Team and Formation

- Frontline/backline link.
- Adjacency circuits.
- Reserve bench enters on trigger.
- Shared ultimate meter.
- Trait threshold reduction with a drawback.
- One duplicated trait counts as another.
- Teamwide combo counter.
- Formation shape bonus.
- Commander aura with limited range.
- Rotating captain role.

### Items

- One awakening branch per completed item.
- Item set bonuses.
- Item fusion requiring distinct components.
- Trigger-based item evolution.
- Consumable arena preparations.
- Cursed items with payout bonuses.
- Bounded item duplication through a rare contract.

### Economy and Betting

- Odds-based payout quote.
- Bounty side bet.
- Parlay across a five-fight chapter.
- Insurance that reduces loss but costs expected value.
- Cash-out after selected fights.
- Voluntary enemy mutator for improved payout.
- Contract debt with a future penalty.
- Sponsor objective with a fixed reward.

### Enemy and Arena

- Boss phase packages.
- Mirror team with one mutation.
- Reinforcement timers.
- Environmental lanes.
- Destructible cover or objectives.
- Shared rage clock.
- Sudden-death field.
- Elite affix sets.
- Chapter-specific enemy ecology.
- Player-selected nemesis evolution.

### Command Layer

- Once-per-fight tactical command.
- Reserve deployment.
- Retarget order.
- Temporary formation shift.
- Protected unit designation.
- Ability timing hold/release.
- Limited rewind or bailout.
- Chapter-specific command loadout.

## Simulation Findings

The model selected:

- Target win probability: 68%.
- Payout subsidy: 45%.
- Standard contract share: 20% of the reference bankroll.
- 5,000 simulations per policy.
- 40 modeled chapters.

| Policy | Survival | Median ending bank | Median total earned | Median contracts | Mean win odds | Mean wager |
|---|---:|---:|---:|---:|---:|---:|
| Odds-aware | 70.18% | 3,523.62 | 31,809.88 | 28 | 67.01% | 29.17% |
| Fixed 25% | 70.24% | 1,396.54 | 15,162.99 | 21 | 66.35% | 26.91% |
| Conservative | 81.66% | 1,081.82 | 8,502.50 | 13 | 60.86% | 18.43% |
| Wait for 10x price | 61.34% | 14.14 | 540.66 | 2 | 46.76% | 16.08% |
| All-in | 0% | 0.46 | 15.63 | 0 | 74.60% | 97.87% |

This does not prove final balance. It shows the proposed parameters can create the intended ordering:

- Ordinary minority-wager policies remain viable.
- Conservative play buys survival at the cost of growth.
- Hoarding until the player has ten times the next price is not dominant.
- Repeated all-in behavior is not the normal optimal strategy.

The very large upper-tail bankrolls are a warning, not a success metric. Deep endless arithmetic needs arbitrary-precision or mantissa/exponent display, and extreme lucky runs need sinks that remain meaningful.

## Score and Persistence

Use total money earned as the main economic score because current bankroll discourages spending.

Recommended run record:

- Total money earned.
- Deepest chapter.
- Richest single fight.
- Biggest wager won.
- Peak bankroll.
- Contracts completed.
- Named champions and their mutation history.
- Nemesis/boss history.

After defeat, persist identity and history:

- Hall of champions.
- Build lineage.
- Contract discoveries.
- Cosmetics, titles, and records.
- Optional unlocked choice variety.

Do not persist raw combat power, bankroll multipliers, permanent starting stats, or exponential meta-currency bonuses.

## Required Prototypes Before Gameplay Implementation

1. Expand win-probability calibration well beyond the current 144 saved samples, especially below 25% and above 75%.
2. Prototype three chapter markets at chapters 5, 20, and 40 using fixed prices from the CSV.
3. Prototype one contract from each family and evaluate whether the fight is visibly different without reading tooltips.
4. Run price sensitivity for 18%, 20%, 22%, and 24% standard contract shares.
5. Test the odds quote and wager UI with players who do not know Kelly betting.
6. Test whether total money earned actually encourages spending.
7. Test multi-session save/resume and the identity-only defeat reset.
8. Establish performance and readability budgets for summons, chain reactions, transformations, and hazards.

## Evidence and Reproduction

- Executable notebook: `analysis/endless_economy/endless_economy_model.ipynb`
- Simulation/model source: `analysis/endless_economy/economy_model.py`
- Live-code baseline snapshot: `analysis/endless_economy/live_baseline.json`
- Full 80-chapter table: `analysis/endless_economy/recommended_curve.csv`
- Policy results: `analysis/endless_economy/policy_summary.csv`
- Decision report: `analysis/endless_economy/report.html`

The baseline snapshot records which values came from the live dirty checkout and which values are explicit design assumptions. The notebook can be re-executed without changing game code.

External reference points:

- [Riot Games: New TFT Workshop Mode — Tocker's Trials](https://teamfighttactics.leagueoflegends.com/en-gb/news/game-updates/new-tft-workshop-mode-tockers-trials/)
- [Riot Games: Magic n' Mayhem Learnings](https://teamfighttactics.leagueoflegends.com/en-ph/news/dev/dev-tft-magic-n-mayhem-learnings/)
- [The Last Flame official announcements](https://steamcommunity.com/app/1830970/announcements/?l=english)
- [Hadean Tactics / Eternal Rift](https://emberfishgames.com/hadean-tactics)
