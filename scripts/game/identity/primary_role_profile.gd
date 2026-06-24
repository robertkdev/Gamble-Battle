extends Resource
class_name PrimaryRoleProfile
const Unit := preload("res://scripts/unit.gd")
const UnitDefaults := preload("res://scripts/game/units/unit_defaults.gd")

@export var role_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var base_stats: Dictionary = {}
@export var validation_rules: Array[Dictionary] = []
@export var default_goals: Array[String] = []
@export var default_approaches: Array[String] = []

func base_stat_value(stat: String) -> float:
	return float(base_stats.get(stat, UnitDefaults.BASELINE_STATS.get(stat, 0)))

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
		if rule.has("min") or rule.has("min_by_cost"):
			var min_v: float = _resolve_rule_bound(rule, "min", unit, -INF)
			if value < min_v:
				var msg := String(rule.get("message", "%s: %.2f < %.2f"))
				issues.append(msg % [label, value, min_v])
				continue
		if rule.has("max") or rule.has("max_by_cost"):
			var max_v: float = _resolve_rule_bound(rule, "max", unit, INF)
			if value > max_v:
				var msg2 := String(rule.get("message", "%s: %.2f > %.2f"))
				issues.append(msg2 % [label, value, max_v])
	return issues

func _resolve_rule_bound(rule: Dictionary, bound_key: String, unit: Unit, default_value: float) -> float:
	var by_cost_key: String = "%s_by_cost" % bound_key
	if rule.has(by_cost_key):
		var raw_by_cost: Variant = rule.get(by_cost_key)
		if raw_by_cost is Dictionary:
			var by_cost: Dictionary = raw_by_cost
			var cost_key: String = str(max(1, int(unit.cost)))
			if by_cost.has(cost_key):
				return float(by_cost.get(cost_key))
			if by_cost.has("*"):
				return float(by_cost.get("*"))
	if rule.has(bound_key):
		return float(rule[bound_key])
	return default_value

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
