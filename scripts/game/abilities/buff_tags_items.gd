extends Object
class_name BuffTagsItems

# Dedicated namespace for item-related buff tags and labels.
# Keeps core BuffTags free of item-specific constants and avoids collisions.

# Generic
const TAG_ITEM_BLEED := "item_bleed"
const TAG_ITEM_ICD_PREFIX := "item_icd_"

# Spellblade/Mindstone on-hit markers
const TAG_ITEM_SPELLBLADE := "item_spellblade"
const TAG_ITEM_MINDSTONE := "item_mindstone"

# Hyperstone ramp + gating
const TAG_ITEM_HYPERSTONE_META := "item_hyperstone_meta"              # { stacks:int, at_cap:bool }
const TAG_ITEM_HYPERSTONE_STACK_ICD := "item_hyperstone_stack_icd"
const LABEL_PREFIX_HYPERSTONE_AS := "hyperstone_as_"                  # label per-stack for AS buffs

# Shiv-style labeled sunder
const LABEL_ITEM_SHIV_SUNDER := "item_shiv_sunder"

# Mind Siphon/Turbine ICDs
const TAG_ITEM_MIND_SIPHON_ICD := "item_mind_siphon_icd"
const TAG_ITEM_TURBINE_ICD := "item_turbine_icd"

# Generic attack modifiers (optional, used by buff hooks if present)
const TAG_ITEM_DAMAGE_AMP := "item_damage_amp"                    # data: { damage_amp_pct: 0.10 }
const TAG_ITEM_IGNORE_SHIELDS_ON_CRIT := "item_ignore_shields_on_crit" # data: { ignore_shields_on_crit: true }
const TAG_ITEM_TRUE_BONUS := "item_true_bonus"                    # data: { true_bonus_pct: 0.05 }
