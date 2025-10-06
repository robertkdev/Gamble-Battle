extends "res://scripts/game/progression/rules/rule_provider.gd"
class_name BossRule

const LogSchema := preload("res://scripts/util/log_schema.gd")

func on_pre_spawn(spec: Dictionary, _ch: int, _sic: int) -> void:
    if spec == null:
        return
    if not spec.has("rules") or typeof(spec["rules"]) != TYPE_DICTIONARY:
        spec["rules"] = {}
    # Placeholder: tag boss for UI/rewards
    spec["rules"]["is_boss"] = true
    spec["rules"]["badge"] = LogSchema.format_boss_badge()

