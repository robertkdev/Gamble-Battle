# Starter First-Shop Choice Matrix - 2026-06-26

Source: `tests/visual/FirstShopChoiceQualitySmoke.tscn`, rerun through MCP on 2026-06-26 after the all-starter Main-flow guard landed.

The smoke targets the four current starter lines whose default all-starter replay reached first shop but did not clearly advance beyond Stage 2. For each starter it forces a deterministic five-offer first shop, buys/deploys each slot through the real Main-scene flow, then starts and resolves the second fight.

Validation:
- `FirstShopChoiceQualitySmoke: PASS starters=4 trials=20 advanced=10`
- `FirstShopOfferQualitySamplingSmoke: PASS samples=240 bo_good=145/240(0.604) bonko_good=211/240(0.879) cashmere_good=147/240(0.613) repo_good=93/240(0.388)`
- `errors: []`

Acceptance threshold:
- Every target starter must have at least one helper choice that advances beyond Stage 2.
- `advanced` count is telemetry, not the pass threshold. It can vary with deterministic helper-set edits and combat tuning, but the matrix below records this run's observed choice quality.

## Matrix

| Starter | Slot | Helper | Helper role | Helper goal | Advanced beyond Stage 2 | Stage after second |
| --- | ---: | --- | --- | --- | --- | ---: |
| Bo | 0 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Bo | 1 | Cashmere | mage | `mage.pick_burst` | no | 2 |
| Bo | 2 | Cashmere | mage | `mage.pick_burst` | no | 2 |
| Bo | 3 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Bo | 4 | Brute | tank | `tank.frontline_absorb` | no | 2 |
| Bonko | 0 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |
| Bonko | 1 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Bonko | 2 | Mortem | brawler | `brawler.attrition_dps` | yes | 3 |
| Bonko | 3 | Axiom | support | `support.team_amplification` | no | 2 |
| Bonko | 4 | Korath | tank | `tank.frontline_absorb` | yes | 3 |
| Cashmere | 0 | Korath | tank | `tank.frontline_absorb` | no | 2 |
| Cashmere | 1 | Repo | tank | `tank.frontline_absorb` | no | 2 |
| Cashmere | 2 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
| Cashmere | 3 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Cashmere | 4 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
| Repo | 0 | Axiom | support | `support.team_amplification` | no | 2 |
| Repo | 1 | Sari | marksman | `marksman.sustained_dps` | yes | 3 |
| Repo | 2 | Mortem | brawler | `brawler.attrition_dps` | no | 2 |
| Repo | 3 | Korath | tank | `tank.frontline_absorb` | no | 2 |
| Repo | 4 | Brute | tank | `tank.frontline_absorb` | no | 2 |

## Read

- Overall: 10 of 20 forced first-shop helper choices advanced beyond Stage 2.
- Bo has two advancing helpers in this set. Berebell and Grint advanced; Cashmere duplicates and Brute did not.
- Bonko is the healthiest soft-fail line in this slice. Four of five helpers advanced; only Axiom failed.
- Cashmere has three advancing helpers. Immediate Brute/Bonko help advanced; Korath and Repo did not.
- Repo is still the weakest first-shop family. Only Sari advanced; Axiom, Mortem, Korath, and Brute left Repo at Stage 2.
- Axiom as first helper remains risky in this evidence: it failed for Bonko and Repo, and the broader first-shop audit also flagged pure support as poor first-body help.

## Current Random Offer Sampling

`FirstShopOfferQualitySamplingSmoke` samples 240 deterministic level-1 shops through the real non-starter-aware `ShopRoller`, then checks whether each soft-fail starter would see at least one known advancing helper from the matrix above.

| Starter | Known advancing helpers used by guard | Good shops | No-good shops | Rate |
| --- | --- | ---: | ---: | ---: |
| Bo | Berebell, Grint | 145/240 | 95 | 0.604 |
| Bonko | Morrak, Grint, Mortem, Korath | 211/240 | 29 | 0.879 |
| Cashmere | Brute, Bonko | 147/240 | 93 | 0.613 |
| Repo | Sari | 93/240 | 147 | 0.388 |

Read: the generic level-1 shop is not a hard mechanical blocker, but it gives Repo the thinnest safety net because the current matrix has only one proven advancing helper for Repo. This smoke is a probability guard, not a player-outcome guarantee; it should be updated if new helper pairings become proven-good or if the shop becomes starter-aware.

## Tuning Direction

- Preserve at least one immediate-damage or high-impact body helper in every first shop for these soft-fail starters.
- Avoid making pure support the most attractive first buy when the board has only one combat unit.
- Treat Repo's first-shop table as the priority tuning target: marksman damage worked, while support, brawler, and defensive tank options all failed in this slice.
- Treat duplicate or near-duplicate first-shop roles carefully. Bo double-Cashmere and Repo multiple frontliners gave the player several choices that looked distinct enough to click but did not advance.
