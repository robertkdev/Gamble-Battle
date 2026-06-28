extends "res://tests/visual/natural_bonko_multi_stage_main_flow_smoke.gd"

@export var campaign_smoke_name: String = "NaturalSingleCampaignMainFlowSmoke"
@export var campaign_starter_id: String = "bonko"
@export var campaign_shop_seed: int = 4401
@export var campaign_target_chapter: int = 6
@export var campaign_target_round: int = 1
@export var campaign_max_battles: int = 44
@export var campaign_round_timeout: float = 240.0
@export var campaign_verbose_round_logs: bool = true

func _flow_smoke_name() -> String:
	return campaign_smoke_name

func _flow_starter_id() -> String:
	return campaign_starter_id

func _flow_shop_seed() -> int:
	return campaign_shop_seed

func _flow_target_chapter() -> int:
	return campaign_target_chapter

func _flow_target_round() -> int:
	return campaign_target_round

func _flow_max_battles() -> int:
	return campaign_max_battles

func _flow_round_timeout() -> float:
	return campaign_round_timeout

func _flow_verbose_round_logs() -> bool:
	return campaign_verbose_round_logs
