extends Object
class_name UnitDefaults

const BASELINE_STATS := {
	"max_hp": 360,
	"hp_regen": 0.0,
	"attack_damage": 45.0,
	"spell_power": 0.0,
	"attack_speed": 0.7,
	"crit_chance": 0.0,
	"crit_damage": 1.5,
	"true_damage": 0.0,
	"lifesteal": 0.0,
	"attack_range": 1,
	"armor": 12.0,
	"magic_resist": 10.0,
	"armor_pen_flat": 0.0,
	"armor_pen_pct": 0.0,
	"mr_pen_flat": 0.0,
	"mr_pen_pct": 0.0,
	"mana_max": 0,
	"mana_regen": 0.0,
	"mana_start": 0,
	"cast_speed": 1.0,
	"mana_gain_per_attack": 60,
}

const BANNED_UNIT_RESOURCE_KEYS := [
	"max_hp",
	"hp_regen",
	"attack_damage",
	"spell_power",
	"attack_speed",
	"crit_chance",
	"crit_damage",
	"true_damage",
	"lifesteal",
	"attack_range",
	"armor",
	"magic_resist",
	"armor_pen_flat",
	"armor_pen_pct",
	"mr_pen_flat",
	"mr_pen_pct",
	"mana",
	"mana_max",
	"mana_regen",
	"mana_start",
	"cast_speed",
	"mana_gain_per_attack",
	"damage_type",
	"power_level",
]

static func baseline_stats() -> Dictionary:
	return BASELINE_STATS.duplicate(true)

static func banned_keys() -> PackedStringArray:
	var out := PackedStringArray()
	for key in BANNED_UNIT_RESOURCE_KEYS:
		out.append(String(key))
	return out
