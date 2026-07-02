extends Object
class_name ShopConfig

# Single source of truth for shop-related constants.
# Keep data-only and minimal; no logic here.

# Slots and general behavior
const SLOT_COUNT := 5                              # Number of offers shown per shop refresh
const ALLOW_DUPLICATES := true                    # PVE: duplicates allowed in a single shop
const REPLACE_PURCHASE_WITH_EMPTY := true         # Purchased slots become SOLD/EMPTY placeholders
const FIRST_SHOP_HELPERS_BY_STARTER: Dictionary = {
    "axiom": ["sari"],
    "bo": ["berebell", "grint"],
    "bonko": ["morrak", "grint", "mortem", "korath"],
    "cashmere": ["brute", "bonko"],
    "korath": ["bonko", "sari", "morrak", "berebell"],
    "knoll": ["sari", "brute", "grint", "bonko", "morrak"],
    "morrak": ["berebell", "sari", "bonko"],
    "mortem": ["morrak", "bonko", "sari", "berebell"],
    "pilfer": ["brute", "bonko", "grint", "morrak", "sari"],
    "repo": ["berebell", "bonko", "sari"],
    "sari": ["bonko", "grint", "brute", "berebell", "morrak"],
}
const FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER: Dictionary = {
    "axiom": ["axiom", "repo", "grint", "korath", "brute", "bo", "bonko", "morrak", "berebell", "mortem", "cashmere"],
    "bo": ["cashmere", "brute", "axiom"],
    "bonko": ["axiom"],
    "cashmere": ["korath", "repo", "axiom"],
    "korath": ["brute", "axiom"],
    "knoll": ["axiom", "knoll", "pilfer"],
    "morrak": ["repo", "brute", "korath", "grint"],
    "mortem": ["brute", "axiom"],
    "pilfer": ["axiom", "knoll", "pilfer"],
    "repo": ["axiom", "mortem", "korath", "brute", "cashmere", "grint", "repo"],
    "sari": ["axiom"],
}

# Reroll and XP costs
const REROLL_COST := 2                            # Gold per reroll
const BUY_XP_COST := 4                            # Gold per XP purchase
const XP_PER_BUY := 4                             # XP granted per purchase
const OPENING_HELPER_GUARDED_SHOPS := 2           # Starter support should get viable helpers through the first follow-up shop

# Player level band
const STARTING_LEVEL := 1
const MIN_LEVEL := 1
const MAX_LEVEL := 6                              # Minimal range for initial content
const POST_OPENING_MIN_TEAM_SIZE := 2             # First shop should support buying and deploying a helper
const POST_OPENING_TEAM_SIZE_BONUS := 1           # Level 2 should unlock a third board slot after the opener
const EARLY_RUN_CAP_FLOOR_STAGE := 3              # By the second shop, bought bench units should be deployable
const EARLY_RUN_CAP_FLOOR_TEAM_SIZE := 3
const EARLY_LEVEL_TWO_CAP_FLOOR_STAGE := 3        # By the second shop, Buy XP should create a real board-slot payoff
const EARLY_LEVEL_TWO_CAP_FLOOR_TEAM_SIZE := 4
const CHAPTER_TWO_CAP_FLOOR_STAGE := 8            # Chapter 2 round 2 should let roster depth break retry loops
const CHAPTER_TWO_CAP_FLOOR_TEAM_SIZE := 6
const CHAPTER_THREE_CAP_FLOOR_STAGE := 14         # Chapter 3 should let accumulated bench depth matter before normal fights
const CHAPTER_THREE_CAP_FLOOR_TEAM_SIZE := 7
const CHAPTER_FOUR_CAP_FLOOR_STAGE := 20          # Late chapters should not strand a full bench at the same board cap
const CHAPTER_FOUR_CAP_FLOOR_TEAM_SIZE := 8
const CHAPTER_FIVE_CAP_FLOOR_STAGE := 26
const CHAPTER_FIVE_CAP_FLOOR_TEAM_SIZE := 9

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
# Current content spans 1-cost foundations, 2-cost premium kits, and 3-cost capstones.
const VALID_COSTS := [1, 2, 3]
const ODDS_BY_LEVEL := {
    1: {1: 1.00},
    2: {1: 0.80, 2: 0.20},
    3: {1: 0.65, 2: 0.30, 3: 0.05},
    4: {1: 0.50, 2: 0.40, 3: 0.10},
    5: {1: 0.40, 2: 0.45, 3: 0.15},
    6: {1: 0.30, 2: 0.50, 3: 0.20},
}

# Fallback behavior for undefined levels (e.g., clamp to last defined)
const DEFAULT_ROLL_LEVEL := STARTING_LEVEL

# Debug toggles (off by default)
const DEBUG_VERBOSE := false
const DEBUG_SEED := -1     # Set to >=0 to fix RNG seed
