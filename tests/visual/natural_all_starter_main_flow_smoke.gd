extends "res://tests/visual/all_starter_main_flow_smoke.gd"

const NATURAL_SMOKE_NAME: String = "NaturalAllStarterMainFlowSmoke"

func _smoke_name() -> String:
	return NATURAL_SMOKE_NAME

func _flow_time_scale() -> float:
	return 1.0

func _first_fight_timeout_seconds() -> float:
	return 75.0

func _second_fight_timeout_seconds() -> float:
	return 120.0

func _prepare_opener_planning(_starter_id: String) -> void:
	pass

func _prepare_first_shop_planning(_result: Dictionary) -> void:
	pass
