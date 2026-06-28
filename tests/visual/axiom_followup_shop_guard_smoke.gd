extends "res://tests/visual/natural_axiom_chapter_four_main_flow_smoke.gd"

const AXIOM_FOLLOWUP_GUARD_SMOKE_NAME: String = "AxiomFollowupShopGuardSmoke"
const AXIOM_FOLLOWUP_TARGET_CHAPTER: int = 2
const AXIOM_FOLLOWUP_TARGET_ROUND: int = 1
const AXIOM_FOLLOWUP_MAX_BATTLES: int = 10
const AXIOM_FOLLOWUP_ROUND_TIMEOUT: float = 120.0

func _play_two_stage_round() -> Dictionary:
	var chapter_before: int = int(GameState.chapter)
	var round_before: int = int(GameState.stage_in_chapter)
	if chapter_before == 1 and round_before == 3:
		_assert_axiom_followup_guard_offers()
	var result: Dictionary = await super._play_two_stage_round()
	if chapter_before == 1 and round_before == 3:
		_expect(bool(result.get("advanced", false)), "Axiom guarded follow-up shop should clear chapter 1 round 3 without retry: %s" % JSON.stringify(result))
	return result

func _assert_axiom_followup_guard_offers() -> void:
	var offer_ids: Array[String] = []
	var blocked_seen: Array[String] = []
	var helper_seen: Array[String] = []
	var helper_ids: Array[String] = _config_string_array(SHOP_CONFIG.FIRST_SHOP_HELPERS_BY_STARTER.get(_flow_starter_id(), []) as Array)
	var blocked_ids: Array[String] = _config_string_array(SHOP_CONFIG.FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER.get(_flow_starter_id(), []) as Array)
	for summary: Dictionary in _offer_summaries():
		var unit_id: String = String(summary.get("id", ""))
		if unit_id == "":
			continue
		offer_ids.append(unit_id)
		if blocked_ids.has(unit_id):
			blocked_seen.append(unit_id)
		if helper_ids.has(unit_id):
			helper_seen.append(unit_id)
	_expect(not helper_seen.is_empty(), "Axiom follow-up shop should still include a configured helper; offers=%s" % JSON.stringify(offer_ids))
	_expect(blocked_seen.is_empty(), "Axiom follow-up shop should block early tank traps; blocked=%s offers=%s" % [JSON.stringify(blocked_seen), JSON.stringify(offer_ids)])

func _config_string_array(raw_values: Array) -> Array[String]:
	var values: Array[String] = []
	for raw_value: Variant in raw_values:
		var value: String = String(raw_value)
		if value != "":
			values.append(value)
	return values

func _flow_smoke_name() -> String:
	return AXIOM_FOLLOWUP_GUARD_SMOKE_NAME

func _flow_target_chapter() -> int:
	return AXIOM_FOLLOWUP_TARGET_CHAPTER

func _flow_target_round() -> int:
	return AXIOM_FOLLOWUP_TARGET_ROUND

func _flow_max_battles() -> int:
	return AXIOM_FOLLOWUP_MAX_BATTLES

func _flow_round_timeout() -> float:
	return AXIOM_FOLLOWUP_ROUND_TIMEOUT
