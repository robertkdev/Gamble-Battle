# Trait Roster Audit — 2026-07-23

Authority: live `data/units/*.tres` and `data/traits/*.tres` on the blood-economy conversion branch after Teller/Ivara removal, Cashmere→Laith, and Mogul retirement. Playable roster: 49 units. Cost distribution: 14/12/11/8/4.

The product requirement is not just “a threshold exists.” Each authored vertical has three separate acceptance contracts:

1. **Natural capstone availability:** enough distinct authored units exist to reach the maximum tier without emblems or threshold reduction.
2. **Drafting reliability:** a usable cost curve and redundancy beyond the exact threshold make deliberate commitment realistic.
3. **Intended pair fieldability:** promised paired verticals fit the board simultaneously, including necessary overlap or explicit trait-count sources.

Do not silently lower thresholds to repair underfilled verticals.

## Live math

Cost distribution uses `cost:count`.

| Trait | Thresholds | Units | Cost distribution | Natural max? | Fill state |
|---|---|---:|---|---|---|
| Aegis | 2/4/6/8 | 4 | 2:2, 3:1, 4:1 | No | Underfilled by 4 |
| Arcanist | 2/4/6/8 | 4 | 1:1, 2:2, 4:1 | No | Underfilled by 4 |
| Blessed | 2/4/6 | 5 | 1:1, 2:2, 3:1, 4:1 | No | Underfilled by 1 |
| Bulwark | 2/4 | 4 | 2:3, 4:1 | Yes | Exactly filled; no redundancy |
| Cartel | 2 | 5 | 1:3, 3:1, 4:1 | Yes | Redundant by 3 |
| Catalyst | 1 | 4 | 1:1, 3:1, 4:1, 5:1 | Yes | Redundant by 3 |
| Chronomancer | 1 | 4 | 1:1, 2:1, 3:1, 4:1 | Yes | Redundant by 3 |
| Executioner | 2/4/6/8 | 8 | 1:3, 3:3, 4:1, 5:1 | Yes | Exactly filled; no redundancy |
| Exile | 1/3/5 | 6 | 1:1, 2:1, 3:2, 4:1, 5:1 | Yes | Reasonable +1 redundancy |
| Fortified | 2/4/6/8 | 6 | 1:2, 2:2, 3:1, 5:1 | No | Underfilled by 2 |
| Harmony | 2 | 4 | 1:2, 3:1, 5:1 | Yes | Redundant by 2 |
| Kaleidoscope | 2 | 5 | 2:2, 3:2, 5:1 | Yes | Redundant by 3 |
| Liaison | 1/3/5 | 5 | 2:2, 3:1, 4:1, 5:1 | Yes | Exactly filled; no redundancy |
| Mentor | 1/2/3/4 | 4 | 1:1, 2:1, 4:1, 5:1 | Yes | Exactly filled; no redundancy |
| Overload | 2/4/6 | 5 | 2:2, 3:1, 4:1, 5:1 | No | Underfilled by 1 |
| Sanguine | 2/4/6 | 6 | 1:2, 2:2, 3:1, 5:1 | Yes | Exactly filled; no redundancy |
| Scholar | 2/4/6 | 6 | 1:2, 2:1, 3:2, 5:1 | Yes | Exactly filled; no redundancy |
| Striker | 2/4/6/8 | 4 | 1:2, 3:1, 4:1 | No | Underfilled by 4 |
| Titan | 2/4/6/8 | 5 | 1:2, 3:1, 4:1, 5:1 | No | Underfilled by 3 |
| Trader | 2/4/6 | 3 | 1:1, 2:1, 4:1 | No | Underfilled by 3 |
| Vindicator | 2/4/6 | 5 | 1:2, 2:1, 3:1, 4:1 | No | Underfilled by 1 |

Mogul is intentionally absent: it is retired, not underfilled. Sanguine remains a separate vitality/omnivamp vertical and does not inherit economy payouts.

## Board-capacity contradiction

The coordinator-verified late-game board cap is 10. Every individual listed capstone is at most 8 and is therefore individually fieldable once the roster supplies enough units.

The promised Fortified-frontline plus Arcanist-backline example is not simultaneously fieldable from roster counts alone:

`8 Fortified + 8 Arcanist - overlap <= 10`

This requires at least 6 units counted in both traits. The projected live roster has **zero** Fortified–Arcanist overlap. Adding only single-trait units cannot solve the pair contract. A future design checkpoint must explicitly choose coherent overlap units, an authored trait-count source, a capacity change, or a clearly revised pair promise. This audit does not authorize lowering either threshold.

The conversion branch contains older capacity surfaces that disagree with the coordinator-verified 10-slot baseline. Reconcile that source conflict before treating pair-fieldability as validated.

## Roster consequences

At minimum, natural availability alone requires 23 additional trait assignments across the underfilled verticals: Aegis +4, Arcanist +4, Blessed +1, Fortified +2, Overload +1, Striker +4, Titan +3, Trader +3, and Vindicator +1. Drafting reliability requires further redundancy beyond those exact fills and should prefer cost curves that do not make the vertical hinge on one premium roll.

Executioner, Bulwark, Liaison, Mentor, Sanguine, and Scholar reach maximum only at exact roster count; they satisfy natural availability but not robust drafting redundancy.

Laith remains Arcanist-only. Her secondary slot is intentionally empty, so this audit does not assign her to a needy vertical. Any earlier hypothetical Vindicator or Overload fit analysis is superseded by that lock.
