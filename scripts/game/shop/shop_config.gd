extends Object
class_name ShopConfig

# Single source of truth for shop-related constants.
# Keep data-only and minimal; no logic here.

# Slots and general behavior
const SLOT_COUNT := 5                              # Number of offers shown per shop refresh
const ALLOW_DUPLICATES := true                    # PVE: duplicates allowed in a single shop
const REPLACE_PURCHASE_WITH_EMPTY := true         # Purchased slots become SOLD/EMPTY placeholders

# Reroll and XP costs
const REROLL_COST := 2                            # Gold per reroll
const BUY_XP_COST := 4                            # Gold per XP purchase
const XP_PER_BUY := 4                             # XP granted per purchase

# Player level band
const STARTING_LEVEL := 1
const MIN_LEVEL := 1
const MAX_LEVEL := 6                              # Minimal range for initial content

# XP required to go from (level-1) -> level. Keys are target level.
# Example: reaching level 3 requires XP_TO_REACH_LEVEL[3] total XP from level 2.
const XP_TO_REACH_LEVEL := {
    2: 2,
    3: 6,
    4: 10,
    5: 16,
    6: 24,
}

# Lock rules
const LOCK_PERSISTS_ACROSS_INTERMISSION := true   # Locked shop persists across PREVIEW/POST_COMBAT
const CLEAR_LOCK_ON_REROLL := true                # Any manual reroll clears lock
const CLEAR_LOCK_ON_NEW_RUN := true               # Starting a new run clears lock

# Minimal roll odds by player level. Probabilities per cost tier sum to 1.0.
# Current content mostly has 1-cost units with some 3-cost; extend as new costs are added.
const VALID_COSTS := [1, 3]
const ODDS_BY_LEVEL := {
    1: {1: 1.00},
    2: {1: 0.95, 3: 0.05},
    3: {1: 0.90, 3: 0.10},
    4: {1: 0.85, 3: 0.15},
    5: {1: 0.80, 3: 0.20},
    6: {1: 0.75, 3: 0.25},
}

# Fallback behavior for undefined levels (e.g., clamp to last defined)
const DEFAULT_ROLL_LEVEL := STARTING_LEVEL

# Debug toggles (off by default)
const DEBUG_VERBOSE := false
const DEBUG_SEED := -1     # Set to >=0 to fix RNG seed
