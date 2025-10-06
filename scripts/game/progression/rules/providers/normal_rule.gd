extends "res://scripts/game/progression/rules/rule_provider.gd"
class_name NormalRule

func on_pre_spawn(spec: Dictionary, _ch: int, _sic: int) -> void:
    if spec == null:
        return
    if not spec.has("rules") or typeof(spec["rules"]) != TYPE_DICTIONARY:
        spec["rules"] = {}

