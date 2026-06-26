extends "res://tests/visual/all_starter_main_flow_smoke.gd"

const INPUT_SMOKE_NAME: String = "NaturalInputMainFlowSmoke"
const INPUT_STARTER_ID: String = "sari"

func _smoke_name() -> String:
	return INPUT_SMOKE_NAME

func _starter_ids_for_run(_catalog: UnitCatalog) -> Array[String]:
	return [INPUT_STARTER_ID]

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

func _require_opener_board_reposition() -> bool:
	return false

func _use_synthetic_input() -> bool:
	return true

func _allow_button_signal_fallback() -> bool:
	return false

func _allow_drag_lifecycle_fallback() -> bool:
	return false
