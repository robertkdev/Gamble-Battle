# Starter First-Shop Choice Matrix - 2026-06-26

Source: `tests/visual/FirstShopChoiceQualitySmoke.tscn`, rerun through MCP on 2026-06-26 after expanding the starter-aware opening-shop guard to first-slot helper quality.

The smoke targets current starter lines where a naive first visible/first-clicked shop card can determine whether the run cleanly advances beyond Stage 2. For each starter it forces a deterministic five-offer first shop, buys/deploys each slot through the real Main-scene flow, then starts and resolves the second fight.

Validation:
- `FirstShopChoiceQualitySmoke: PASS starters=7 trials=35 advanced=24`
- `FirstShopOfferQualitySamplingSmoke: PASS samples=240` with every guarded starter at `first_good=1.000`
- `AllStarterMainFlowSmoke: PASS starters=12 first_shop=11 retry=1 deployed=11 second_resolved=11`
- `AllStarterMainFlowAudit: OK starters=12`, refreshed default replay: `advanced=11`, `held=0`, `retry=1`
- `AxiomRetryChoiceQualitySmoke: PASS trials=5 advanced=5`; `AxiomRetryEconomySmoke: OK`
- `errors: []`

Acceptance threshold:
- Every target starter must have at least one helper choice that advances beyond Stage 2.
- The opening-shop guard must place a known advancing helper in slot 0 for guarded starters.
- `advanced` count is telemetry, not the pass threshold. It can vary with deterministic helper-set edits and combat tuning, but the matrix below records this run's observed choice quality.

## Matrix

| Starter | Slot | Helper | Helper role | Helper goal | Advanced beyond Stage 2 | Stage after second |
| --- | ---: | --- | --- | --- | --- | ---: |
| Bo | 0 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Bo | 1 | Cashmere | mage | `mage.pick_burst` | no | 2 |
| Bo | 2 | Cashmere | mage | `mage.pick_burst` | no | 2 |
| Bo | 3 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Bo | 4 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
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
| Korath | 0 | Brute | tank | `tank.frontline_absorb` | no | 2 |
| Korath | 1 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Korath | 2 | Sari | marksman | `marksman.sustained_dps` | yes | 3 |
| Korath | 3 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |
| Korath | 4 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Mortem | 0 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |
| Mortem | 1 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Mortem | 2 | Sari | marksman | `marksman.sustained_dps` | yes | 3 |
| Mortem | 3 | Brute | tank | `tank.frontline_absorb` | no | 2 |
| Mortem | 4 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Repo | 0 | Axiom | support | `support.team_amplification` | no | 2 |
| Repo | 1 | Sari | marksman | `marksman.sustained_dps` | yes | 3 |
| Repo | 2 | Mortem | brawler | `brawler.attrition_dps` | no | 2 |
| Repo | 3 | Korath | tank | `tank.frontline_absorb` | no | 2 |
| Repo | 4 | Brute | tank | `tank.frontline_absorb` | no | 2 |
| Sari | 0 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Sari | 1 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Sari | 2 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
| Sari | 3 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Sari | 4 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |

## Read

- Overall: 24 of 35 forced first-shop helper choices advanced beyond Stage 2.
- Bo has three advancing helpers in this set: Berebell, Grint, and Brute. Cashmere duplicates did not advance.
- Bonko has four advancing helpers: Morrak, Grint, Mortem, and Korath. Axiom failed again as a first helper.
- Cashmere advances with Brute and Bonko. Defensive Korath/Repo pairings still do not cleanly advance this line.
- Korath now has four proven first-shop helpers: Bonko, Sari, Morrak, and Berebell. Brute did not advance.
- Mortem now has four proven first-shop helpers: Morrak, Bonko, Sari, and Berebell. Brute did not advance.
- Repo remains the narrowest tested table: only Sari advanced in this committed matrix.
- Sari is the healthiest newly covered line: all five tested helpers advanced.
- Axiom as first helper remains risky when the board has only one combat unit. It failed for Bonko and Repo in this matrix.

## Current Starter-Aware Offer Sampling

`FirstShopOfferQualitySamplingSmoke` samples 240 deterministic starter-aware opening shops through `ShopRoller.roll_opening_for_starter`, then checks whether each guarded starter sees a known advancing helper in slot 0. The real `AllStarterMainFlowSmoke` also asserts that the production post-opener first shop for every guarded starter starts with a known advancing helper.

| Starter | Known advancing helpers used by guard | First-slot good shops | First-slot no-good shops | Rate |
| --- | --- | ---: | ---: | ---: |
| Bo | Berebell, Grint | 35/35 | 0 | 1.000 |
| Bonko | Morrak, Grint, Mortem, Korath | 35/35 | 0 | 1.000 |
| Cashmere | Brute, Bonko | 34/34 | 0 | 1.000 |
| Korath | Bonko, Sari, Morrak, Berebell | 34/34 | 0 | 1.000 |
| Mortem | Morrak, Bonko, Sari, Berebell | 34/34 | 0 | 1.000 |
| Repo | Sari | 34/34 | 0 | 1.000 |
| Sari | Bonko, Grint, Brute, Berebell, Morrak | 34/34 | 0 | 1.000 |

Read: the first post-opener level-1 shop is now starter-aware for seven tested first-shop-sensitive starters. It preserves normal random shop shape, but if a known advancing helper appears later in the roll it swaps that helper into slot 0; if no known helper appears, it inserts/replaces slot 0 with a configured helper from `ShopConfig.FIRST_SHOP_HELPERS_BY_STARTER`. Normal later rerolls stay generic.

The refreshed default `AllStarterMainFlowAudit` run after the first-slot guard advanced all 11 starters that reached first shop beyond Stage 2, kept Axiom as the expected 2-gold retry starter, and had no held Stage 2 default-click lines.

## Axiom Retry Guard

Axiom remains the one current level-1 starter that enters the Chapter 1 Stage 1 retry state instead of the normal post-victory first shop. The retry shop now uses the same configured-helper slot-0 guard after the opener bet has resolved to 0, while the initial forced-fight placeholder remains separate.

`AxiomRetryChoiceQualitySmoke` forces the configured retry helper set through the real Main-scene buy, bench-to-board deploy, and retry fight. The current guard list is:

| Starter | Slot | Helper | Helper role | Helper goal | Advanced beyond Stage 1 |
| --- | ---: | --- | --- | --- | --- |
| Axiom | 0 | Bonko | brawler | `brawler.attrition_dps` | yes |
| Axiom | 1 | Grint | tank | `tank.initiate_fight` | yes |
| Axiom | 2 | Sari | marksman | `marksman.sustained_dps` | yes |
| Axiom | 3 | Morrak | brawler | `brawler.attrition_dps` | yes |
| Axiom | 4 | Berebell | brawler | `brawler.attrition_dps` | yes |

`AxiomRetryEconomySmoke` covers the production path: Axiom loses the forced opener, recovers to 2 gold, sees a configured helper in slot 0, buys/deploys it while preserving 1 gold, wins the retry fight, and returns to a full Stage 2 planning shop.

## Tuning Direction

- Preserve an immediate-damage, high-impact body, or proven frontline stabilizer in slot 0 for first-shop-sensitive starters.
- Avoid pure support as the default first buy when the board has only one combat unit.
- Continue treating Repo as the priority tuning target if broader choice quality is needed. Its current guard is intentionally conservative because Sari is the only proven advancing helper in this committed matrix.
- Treat duplicate or near-duplicate first-shop roles carefully. Several options look distinct enough to click but still fail to advance when they duplicate defensive coverage or lack immediate damage.
