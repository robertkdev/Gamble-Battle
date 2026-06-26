# Starter First-Shop Choice Matrix - 2026-06-26

Source: `tests/visual/FirstShopChoiceQualitySmoke.tscn`, rerun through MCP on 2026-06-26 after the starter-aware opening-shop guard landed.

The smoke targets the four current starter lines whose default all-starter replay reached first shop but did not clearly advance beyond Stage 2. For each starter it forces a deterministic five-offer first shop, buys/deploys each slot through the real Main-scene flow, then starts and resolves the second fight.

Validation:
- `FirstShopChoiceQualitySmoke: PASS starters=4 trials=20 advanced=10`
- `FirstShopOfferQualitySamplingSmoke: PASS samples=240 bo_good=60/60(1.000) no_good=0 bonko_good=60/60(1.000) no_good=0 cashmere_good=60/60(1.000) no_good=0 repo_good=60/60(1.000) no_good=0`
- `AllStarterMainFlowSmoke: PASS starters=12 first_shop=11 retry=1 deployed=11 second_resolved=11`
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
- A later default all-starter replay after the opening-shop guard saw Repo advance with Bonko as the first clicked helper. Bonko was not part of this forced Repo matrix, so the table should be read as a tested slice, not a complete map of every viable Repo helper.
- Axiom as first helper remains risky in this evidence: it failed for Bonko and Repo, and the broader first-shop audit also flagged pure support as poor first-body help.

## Current Starter-Aware Offer Sampling

`FirstShopOfferQualitySamplingSmoke` samples 240 deterministic starter-aware opening shops through `ShopRoller.roll_opening_for_starter`, then checks whether each soft-fail starter sees at least one known advancing helper from the matrix above. The real `AllStarterMainFlowSmoke` also asserts that the production post-opener first shop for Bo, Bonko, Cashmere, and Repo includes one of those known advancing helpers.

| Starter | Known advancing helpers used by guard | Good shops | No-good shops | Rate |
| --- | --- | ---: | ---: | ---: |
| Bo | Berebell, Grint | 60/60 | 0 | 1.000 |
| Bonko | Morrak, Grint, Mortem, Korath | 60/60 | 0 | 1.000 |
| Cashmere | Brute, Bonko | 60/60 | 0 | 1.000 |
| Repo | Sari | 60/60 | 0 | 1.000 |

Read: the first post-opener level-1 shop is now starter-aware for these soft-fail starters. It preserves normal random shop shape, but if the roll lacks a known advancing helper it replaces one slot with a helper from `ShopConfig.FIRST_SHOP_HELPERS_BY_STARTER`. Normal later rerolls stay generic. Repo still has only one proven advancing helper in this forced matrix, but Sari is now guaranteed to appear in Repo's first post-opener shop.

The refreshed default `AllStarterMainFlowAudit` run after this guard advanced 9 of 11 first-shop starters beyond Stage 2, held Bo+Brute at Stage 2 with 2 gold, held Korath+Repo at Stage 2 with 1 gold, and kept Axiom as the 2-gold retry starter. This proves the availability guard improved current pacing, while also showing that the first visible/first-clicked card can still be strategically weak even when a better helper appears elsewhere in the shop.

## Tuning Direction

- Preserve at least one immediate-damage or high-impact body helper in every first shop for these soft-fail starters.
- If onboarding should protect a naive first click, the next contract is first-slot/default-card quality, not just offer availability.
- Avoid making pure support the most attractive first buy when the board has only one combat unit.
- Treat Repo's first-shop table as the priority tuning target if broader choice quality is needed: marksman damage worked in this forced slice, and a later default replay also advanced with Bonko, while support and defensive tank options failed. The opening-shop safeguard prevents the current one-helper Repo guard table from becoming a random-offer dead end.
- Treat duplicate or near-duplicate first-shop roles carefully. Bo double-Cashmere and Repo multiple frontliners gave the player several choices that looked distinct enough to click but did not advance.
