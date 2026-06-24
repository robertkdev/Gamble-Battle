extends "res://scripts/game/progression/rules/rule_provider.gd"
class_name EliteRule

const StageTypes = preload("res://scripts/game/progression/stage_types.gd")

func on_pre_spawn(spec: Dictionary, _ch: int, _sic: int) -> void:
	if not spec.has(StageTypes.KEY_RULES) or typeof(spec[StageTypes.KEY_RULES]) != TYPE_DICTIONARY:
		spec[StageTypes.KEY_RULES] = {}
	var rules: Dictionary = spec[StageTypes.KEY_RULES]
	rules["is_special"] = true
	rules["badge"] = "SPECIAL"
	spec[StageTypes.KEY_RULES] = rules
