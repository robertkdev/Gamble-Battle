extends Object
class_name BuffTags

# Centralized buff tag names to keep DRY and consistent across engine and UI.

const TAG_NYXA := "nyxa_cv_active"
const TAG_KORATH := "korath_absorb_active"
const TAG_CC_IMMUNE := "cc_immune"
const TAG_KYTHERA := "kythera_siphon_active"
const TAG_BONKO := "bonko_buddy_active"
const TAG_BEREBELL := "berebell_unstable_active"

# Generic ability-damage amplifier tag; data may include { ability_damage_amp: 0.40 }
const TAG_ABILITY_AMP := "ability_amp"

# One-time marker that Arcanist double-cast has been consumed for this unit
const TAG_ARCANIST_DBL_USED := "arcanist_double_used"

# Executioner specials
const TAG_EXEC_T8 := "executioner_t8"
const TAG_EXEC_BLEED := "executioner_bleed"

# Generic damage amplifier for attacks; data includes { damage_amp_pct: 0.10 }
const TAG_DAMAGE_AMP := "damage_amp"

# Catalyst stub metadata tag (for future item progression)
const TAG_CATALYST_META := "catalyst_meta"

# Healing/shield modulation (used by traits like Blessed)
const TAG_HEALING_MODS := "healing_mods"

# Exile upgrades (exact-count tiers). Data includes { level: 1|2|3 }
const TAG_EXILE_UPGRADE := "exile_upgrade"
