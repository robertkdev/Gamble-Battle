extends Resource
class_name PrimaryRoleProfile
const Unit := preload("res://scripts/unit.gd")
const DEFAULT_BASE_STATS := {
	"max_hp": 500,
	"attack_damage": 50,
	"spell_power": 0,
	"attack_range": 1,
	"armor": 20,
	"magic_resist": 0,
}

@export var role_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var base_stats: Dictionary = {}
@export var validation_rules: Array[Dictionary] = []
@export var default_goals: Array[String] = []
@export var default_approaches: Array[String] = []

func base_stat_value(stat: String) -> float:
	return float(base_stats.get(stat, DEFAULT_BASE_STATS.get(stat, 0)))

func modifier() -> Dictionary:
	var delta: Dictionary = {}
	for key in DEFAULT_BASE_STATS.keys():
		if not base_stats.has(key):
			continue
		var desired := float(base_stats[key])
		var baseline := float(DEFAULT_BASE_STATS.get(key, 0))
		delta[key] = desired - baseline
	return delta

func validate_unit(unit: Unit) -> Array[String]:
	if unit == null:
		return []
	var issues: Array[String] = []
	for rule in validation_rules:
		var metric := String(rule.get("metric", ""))
		if metric == "":
			continue
		var value := _metric_value(unit, metric)
		var label := String(rule.get("label", metric))
		if rule.has("min"):
			var min_v := float(rule["min"])
			if value < min_v:
				var msg := String(rule.get("message", "%s: %.2f < %.2f"))
				issues.append(msg % [label, value, min_v])
				continue
		if rule.has("max"):
			var max_v := float(rule["max"])
			if value > max_v:
				var msg2 := String(rule.get("message", "%s: %.2f > %.2f"))
				issues.append(msg2 % [label, value, max_v])
	return issues

func _metric_value(unit: Unit, metric: String) -> float:
	match metric:
		"max_hp":
			return float(unit.max_hp)
		"attack_range":
			return float(unit.attack_range)
		"attack_damage":
			return float(unit.attack_damage)
		"spell_power":
			return float(unit.spell_power)
		"armor":
			return float(unit.armor)
		"magic_resist":
			return float(unit.magic_resist)
		"armor_plus_mr":
			return float(unit.armor + unit.magic_resist)
		"burst_proxy":
			return float(unit.attack_damage + 0.5 * unit.spell_power)
		"hp_regen":
			return float(unit.hp_regen)
		_:
			if unit.has_method("get"):
				return float(unit.get(metric))
			return 0.0
