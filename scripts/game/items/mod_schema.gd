extends Object
class_name ItemModSchema

# Normalized keys for item stat modifiers. Keep DRY and explicit.

# Percent (multiplicative or additive to percents)
const PCT_AD := "pct_ad"
const PCT_AS := "pct_as"
const PCT_CRIT_CHANCE := "pct_crit_chance"
const PCT_MANA_REGEN := "pct_mana_regen" # included for items like Orb (+15% mana regen)
const PCT_LIFESTEAL := "pct_lifesteal"
const PCT_DAMAGE_REDUCTION := "pct_damage_reduction"
const PCT_TENACITY := "pct_tenacity"

# Flat
const FLAT_SP := "flat_sp"
const FLAT_ARMOR := "flat_armor"
const FLAT_MR := "flat_mr"
const FLAT_HP := "flat_hp"
const FLAT_MANA_REGEN := "flat_mana_regen"
const FLAT_CRIT_DAMAGE := "flat_crit_damage"

# Special
const FLAT_START_MANA := "flat_start_mana"

static func pct_keys() -> PackedStringArray:
    return PackedStringArray([PCT_AD, PCT_AS, PCT_CRIT_CHANCE, PCT_MANA_REGEN, PCT_LIFESTEAL, PCT_DAMAGE_REDUCTION, PCT_TENACITY])

static func flat_keys() -> PackedStringArray:
    return PackedStringArray([FLAT_SP, FLAT_ARMOR, FLAT_MR, FLAT_HP, FLAT_MANA_REGEN, FLAT_CRIT_DAMAGE])

static func special_keys() -> PackedStringArray:
    return PackedStringArray([FLAT_START_MANA])

static func is_supported(key: String) -> bool:
    var k := String(key)
    return pct_keys().has(k) or flat_keys().has(k) or special_keys().has(k)

