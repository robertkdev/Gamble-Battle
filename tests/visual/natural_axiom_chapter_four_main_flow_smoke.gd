extends "res://tests/visual/natural_bonko_two_stage_main_flow_smoke.gd"

const AXIOM_CHAPTER_FOUR_SMOKE_NAME: String = "NaturalAxiomChapterFourMainFlowSmoke"
const AXIOM_CHAPTER_FOUR_STARTER_ID: String = "axiom"
const AXIOM_CHAPTER_FOUR_SHOP_SEED: int = 4101
const AXIOM_CHAPTER_FOUR_TARGET_CHAPTER: int = 4
const AXIOM_CHAPTER_FOUR_TARGET_ROUND: int = 1
const AXIOM_CHAPTER_FOUR_MAX_BATTLES: int = 26
const AXIOM_CHAPTER_FOUR_ROUND_TIMEOUT: float = 190.0

func _flow_smoke_name() -> String:
	return AXIOM_CHAPTER_FOUR_SMOKE_NAME

func _flow_starter_id() -> String:
	return AXIOM_CHAPTER_FOUR_STARTER_ID

func _flow_shop_seed() -> int:
	return AXIOM_CHAPTER_FOUR_SHOP_SEED

func _flow_target_chapter() -> int:
	return AXIOM_CHAPTER_FOUR_TARGET_CHAPTER

func _flow_target_round() -> int:
	return AXIOM_CHAPTER_FOUR_TARGET_ROUND

func _flow_max_battles() -> int:
	return AXIOM_CHAPTER_FOUR_MAX_BATTLES

func _flow_round_timeout() -> float:
	return AXIOM_CHAPTER_FOUR_ROUND_TIMEOUT
