extends "res://tests/visual/rapid_shop_pressure_smoke.gd"

const PRODUCTION_SMOKE_NAME: String = "ProductionRapidShopPressureSmoke"

func _smoke_name() -> String:
	return PRODUCTION_SMOKE_NAME

func _flow_time_scale() -> float:
	return 1.0

func _prepare_opener_planning() -> void:
	pass

func _prepare_rapid_shop_planning() -> void:
	pass

func _first_shop_timeout_seconds() -> float:
	return 75.0

func _post_burst_timeout_seconds() -> float:
	return 120.0
