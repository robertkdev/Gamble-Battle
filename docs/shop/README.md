Shop Configuration
==================

Location: `scripts/game/shop/shop_config.gd`

Purpose
- Centralize all data-only configuration for the shop: slot count, costs, XP thresholds, lock rules, and roll odds.
- Keep logic out; other modules read these constants.

Key Constants
- `SLOT_COUNT`: number of offers per refresh (default 5).
- `ALLOW_DUPLICATES`: PVE setting allowing duplicate offers in one shop.
- `REPLACE_PURCHASE_WITH_EMPTY`: purchased slots remain as SOLD/EMPTY placeholders; layout stays stable.
- `REROLL_COST`: gold cost per shop refresh.
- `BUY_XP_COST` / `XP_PER_BUY`: gold cost and XP gain for XP purchases.
- `STARTING_LEVEL`, `MIN_LEVEL`, `MAX_LEVEL`: player level band.
- `XP_TO_REACH_LEVEL`: XP needed to go from (level-1) -> level.
- Lock rules:
  - `LOCK_PERSISTS_ACROSS_INTERMISSION`
  - `CLEAR_LOCK_ON_REROLL`
  - `CLEAR_LOCK_ON_NEW_RUN`
- `VALID_COSTS`: list of unit cost tiers supported by odds.
- `ODDS_BY_LEVEL`: map of level -> { cost -> probability }, sums to 1.0 per level.
- `DEFAULT_ROLL_LEVEL`: fallback for undefined levels.

Odds & Costs (Initial)
- Costs present: 1-cost (most units), 3-cost (few units).
- Reroll cost: 2g; Buy XP: 4g for +4 XP.
- Odds by level (minimal for current content):
  - L1: 100% 1-cost
  - L2: 95% 1-cost, 5% 3-cost
  - L3: 90% 1-cost, 10% 3-cost
  - L4: 85% 1-cost, 15% 3-cost
  - L5: 80% 1-cost, 20% 3-cost
  - L6: 75% 1-cost, 25% 3-cost

Minimal Odds (Initial Content)
- Project currently contains mostly 1-cost units with a few 3-cost.
- `ODDS_BY_LEVEL` reflects that; extend as additional cost tiers (2/4/5) are added.

Change Guidelines
- DRY/KISS: change values here; avoid scattering numbers in code.
- Design for change: expand `MAX_LEVEL`, extend `XP_TO_REACH_LEVEL`, add new costs to `VALID_COSTS` and `ODDS_BY_LEVEL`.
- Keep probabilities readable and ensure each level sums to 1.0.

Card UX Notes
- Shop shows a fixed number of slots horizontally.
- Clicking a card buys the unit if you have enough gold and bench space.
- When purchased, that slot becomes a SOLD placeholder (no shifting / no gap closing).
- If bench is full, cards show a disabled state with tooltip.
- If you cannot afford a card, the price is tinted and a tooltip indicates "Not enough gold".

Lifecycle
- New Run: `Shop.reset_run()` clears state; `PlayerProgress` resets to level 1, XP 0.
- Reroll: `Shop.reroll()` spends `REROLL_COST` gold (unless a free reroll is available) and populates `SLOT_COUNT` offers.
- Lock: `Shop.toggle_lock()` flips lock; reroll clears lock when `CLEAR_LOCK_ON_REROLL=true`.
- Buy Unit: `Shop.buy_unit(slot)` spawns the unit via `UnitFactory`, places on the bench, replaces that slot with an empty placeholder, then runs `CombineService`.
- Buy XP: `Shop.buy_xp()` spends `BUY_XP_COST` and grants `XP_PER_BUY` XP; level-ups resolve immediately.
- Sell: `Shop.sell_unit(unit)` removes from bench and credits gold equal to its base cost.

Signals
- `offers_changed(offers: Array)`: emitted on reroll and after purchases.
- `locked_changed(locked: bool)`: emitted when lock toggles or clears on reroll.
- `free_rerolls_changed(count: int)`: emitted when free rerolls change (e.g., Trader trait).
- `error(code: String, context: Dictionary)`: emitted on failed actions.

Phase Rules
- Actions enabled in all phases.
- Affordability differs by phase:
  - Planning/Post-combat: must keep at least 1 health. A purchase is allowed only if `gold - cost >= 1`.
  - Combat: you may borrow against your bet this round. A purchase is allowed if `cost <= gold + (2*bet - 1) - combat_spent`.
    - `combat_spent` is the total shop spending done during the current combat (rerolls, XP, unit buys). Selling reduces it.
    - Bet is escrowed at combat start; on win you receive `2*bet`, on loss `0`. Settlement happens before the next planning phase.
  - Failed affordability due to these rules surface as `WOULD_KILL_YOU` with a user-facing tooltip.

Error Codes
- `UNKNOWN`, `COMBAT_PHASE`, `INVALID_SLOT`, `NO_OFFERS`, `INSUFFICIENT_GOLD`, `BENCH_FULL`, `SHOP_LOCKED`, `INVALID_UNIT`, `NOT_FOUND`, `ACTION_FAILED`.

Extension Points
- Odds: edit `ODDS_BY_LEVEL` and `VALID_COSTS` in config; logic lives in `ShopOdds`.
- Catalog: place unit `.tres` in `res://data/units` (`UnitProfile`/`UnitDef`); `UnitCatalog` scans and groups by cost.
- Combining: `CombineService` promotes three-of-a-kind on bench post-purchase; adjust rules there.
- UI: `ShopPresenter` mediates Shop -> UI; buttons/labels live under `shop_buttons.gd`, cards in `shop_panel.gd` and `ShopCard.tscn`.
- Economy: `Economy` singleton provides gold and bet; all spending/credits route through it.

Developer Debug Toggles
- `DEBUG_VERBOSE` (bool): enable verbose logging in Shop internals (default: false).
- `DEBUG_SEED` (int >= 0): force shop RNG seed for deterministic rolls; when < 0, RNG is randomized (default: -1).
