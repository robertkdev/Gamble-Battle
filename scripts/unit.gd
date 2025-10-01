extends RefCounted
class_name Unit
const Health := preload("res://scripts/game/stats/health.gd")
const Mana := preload("res://scripts/game/stats/mana.gd")
const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")

# Identity
var id: String = ""
var name: String = ""
var sprite_path: String = ""
var ability_id: String = ""
var traits: Array[String] = []
var roles: Array[String] = [] # Legacy multi-role data; prefer primary_role/goal
var cost: int = 1
var level: int = 1
var primary_role: String = ""
var primary_goal: String = ""
var approaches: Array[String] = []
var alt_goals: Array[String] = []
var identity: UnitIdentity = null

# Health
var max_hp: int = 1
var hp: int = 1
var hp_regen: float = 0.0

# Offense
var attack_damage: float = 0.0 # AD
var spell_power: float = 0.0   # SP
var attack_speed: float = 1.0 # AS attacks/second (rate of fire)
var crit_chance: float = 0.05 # 0..1
var crit_damage: float = 2.0  # 1.0 = no bonus, 2.0 = double
var true_damage: float = 0.0  # flat true damage
var lifesteal: float = 0.0    # 0..1
var attack_range: int = 1
var move_speed: float = 120.0 #120

# Defense
var armor: float = 0.0
var magic_resist: float = 0.0
var block_chance: float = 0.0     # 0..1
var damage_reduction: float = 0.0 # 0..1 (reserved)
var armor_pen_flat: float = 0.0
var armor_pen_pct: float = 0.0
var mr_pen_flat: float = 0.0
var mr_pen_pct: float = 0.0

# Global flat damage reduction (applies after armor/MR and percent DR, before shields)
var damage_reduction_flat: float = 0.0

# CC resistance (0..0.95). Reduces incoming crowd-control durations.
var tenacity: float = 0.0

# Mana
var mana: int = 0
var mana_max: int = 0      # ability cost
var mana_start: int = 0
var mana_regen: float = 0.0
var cast_speed: float = 1.0
var mana_gain_per_attack: int = 30

# UI helper: total active shield amount (for rendering). Updated by BuffSystem.
var ui_shield: int = 0

func _init() -> void:
	pass

func is_alive() -> bool:
	return hp > 0

func heal_to_full() -> void:
	Health.heal_full(self)

func take_damage(amount: int) -> int:
	# Armor/damage_reduction could reduce damage earlier in pipeline.
	var res := Health.apply_damage(self, amount)
	return int(res.get("dealt", int(max(0, amount))))

func attack_roll(rng: RandomNumberGenerator) -> Dictionary:
	# returns { damage:int, crit:bool }
	var crit := rng.randf() < crit_chance
	var dmg_f := float(attack_damage) * (crit_damage if crit else 1.0) + true_damage
	return { "damage": int(round(dmg_f)), "crit": crit }

func end_of_turn() -> void:
	# Delegate to centralized systems for regen
	Health.regen_tick(self, 1.0)
	Mana.regen_tick(self, 1.0)

func summary() -> String:
	return "HP %d/%d  AD %d  CRIT %d%%  LS %d%%  BLOCK %d%%  REGEN %d" % [
		hp, max_hp, attack_damage, int(crit_chance * 100.0), int(lifesteal * 100.0),
		int(block_chance * 100.0), hp_regen
	]

func set_identity_data(primary_role_value: String, primary_goal_value: String, approaches_value: Array[String], alt_goals_value: Array[String] = [], identity_resource: UnitIdentity = null) -> void:
	primary_role = String(primary_role_value)
	primary_goal = String(primary_goal_value)
	approaches = _to_string_array(approaches_value)
	alt_goals = _to_string_array(alt_goals_value)
	identity = identity_resource

func get_primary_role() -> String:
	return primary_role

func get_primary_goal() -> String:
	return primary_goal

func is_primary_role(role_id: String) -> bool:
	if role_id == null:
		return false
	var current := String(primary_role).strip_edges()
	if current == "":
		return false
	return current.to_lower() == String(role_id).strip_edges().to_lower()

func get_approaches() -> Array[String]:
	return approaches.duplicate()

func get_alt_goals() -> Array[String]:
	return alt_goals.duplicate()

func has_approach(approach_id: String) -> bool:
	var key := String(approach_id)
	for a in approaches:
		if String(a) == key:
			return true
	return false

func _to_string_array(values) -> Array[String]:
	var out: Array[String] = []
	if values is Array:
		for v in values:
			out.append(String(v))
	elif values is PackedStringArray:
		for v in values:
			out.append(String(v))
	elif typeof(values) == TYPE_STRING:
		out.append(String(values))
	return out
