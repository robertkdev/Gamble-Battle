extends "res://tests/visual/natural_axiom_chapter_four_main_flow_smoke.gd"

const AXIOM_CAMPAIGN_SMOKE_NAME: String = "NaturalAxiomCampaignMainFlowSmoke"
const AXIOM_CAMPAIGN_TARGET_CHAPTER: int = 6
const AXIOM_CAMPAIGN_TARGET_ROUND: int = 1
const AXIOM_CAMPAIGN_MAX_BATTLES: int = 44
const AXIOM_CAMPAIGN_ROUND_TIMEOUT: float = 240.0

func _flow_smoke_name() -> String:
	return AXIOM_CAMPAIGN_SMOKE_NAME

func _flow_target_chapter() -> int:
	return AXIOM_CAMPAIGN_TARGET_CHAPTER

func _flow_target_round() -> int:
	return AXIOM_CAMPAIGN_TARGET_ROUND

func _flow_max_battles() -> int:
	return AXIOM_CAMPAIGN_MAX_BATTLES

func _flow_round_timeout() -> float:
	return AXIOM_CAMPAIGN_ROUND_TIMEOUT
