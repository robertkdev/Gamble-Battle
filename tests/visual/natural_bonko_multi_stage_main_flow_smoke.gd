extends "res://tests/visual/natural_bonko_two_stage_main_flow_smoke.gd"

const MULTI_STAGE_SMOKE_NAME: String = "NaturalBonkoMultiStageMainFlowSmoke"
const MULTI_STAGE_TARGET_CHAPTER: int = 3
const MULTI_STAGE_TARGET_ROUND: int = 1
const MULTI_STAGE_MAX_BATTLES: int = 14
const MULTI_STAGE_ROUND_TIMEOUT: float = 140.0

func _flow_smoke_name() -> String:
	return MULTI_STAGE_SMOKE_NAME

func _flow_target_chapter() -> int:
	return MULTI_STAGE_TARGET_CHAPTER

func _flow_target_round() -> int:
	return MULTI_STAGE_TARGET_ROUND

func _flow_max_battles() -> int:
	return MULTI_STAGE_MAX_BATTLES

func _flow_round_timeout() -> float:
	return MULTI_STAGE_ROUND_TIMEOUT
