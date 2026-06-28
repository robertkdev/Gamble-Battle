extends "res://tests/visual/natural_representative_multi_stage_main_flow_smoke.gd"

const REPRESENTATIVE_CAMPAIGN_SMOKE_NAME: String = "NaturalRepresentativeCampaignMainFlowSmoke"
const REPRESENTATIVE_CAMPAIGN_TARGET_CHAPTER: int = 6
const REPRESENTATIVE_CAMPAIGN_TARGET_ROUND: int = 1
const REPRESENTATIVE_CAMPAIGN_MAX_BATTLES: int = 44
const REPRESENTATIVE_CAMPAIGN_ROUND_TIMEOUT: float = 240.0

func _finish_representative_flow() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var representative_starters: Array[String] = _representative_starters()
		var reached_count: int = 0
		for sample_result: Dictionary in _representative_results:
			if bool(sample_result.get("reached_target", false)):
				reached_count += 1
		_expect(reached_count == representative_starters.size(), "%s should reach target for every representative starter, reached=%d/%d results=%s" % [
			_representative_smoke_name(),
			reached_count,
			representative_starters.size(),
			JSON.stringify(_representative_result_summary()),
		])
	if _technical_failures().is_empty():
		print("%s: OK samples=%d reached=%d starters=%s target_chapter=%d target_round=%d summary=%s" % [
			_representative_smoke_name(),
			_representative_results.size(),
			_reached_representative_count(),
			JSON.stringify(_representative_starters()),
			_flow_target_chapter(),
			_flow_target_round(),
			JSON.stringify(_representative_result_summary()),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [_representative_smoke_name(), failure])
		print("%s: summary=%s" % [_representative_smoke_name(), JSON.stringify(_representative_result_summary())])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _flow_smoke_name() -> String:
	if _current_representative_starter == "":
		return _representative_smoke_name()
	return "%s[%s]" % [_representative_smoke_name(), _current_representative_starter]

func _flow_target_chapter() -> int:
	return REPRESENTATIVE_CAMPAIGN_TARGET_CHAPTER

func _flow_target_round() -> int:
	return REPRESENTATIVE_CAMPAIGN_TARGET_ROUND

func _flow_max_battles() -> int:
	return REPRESENTATIVE_CAMPAIGN_MAX_BATTLES

func _flow_round_timeout() -> float:
	return REPRESENTATIVE_CAMPAIGN_ROUND_TIMEOUT

func _representative_smoke_name() -> String:
	return REPRESENTATIVE_CAMPAIGN_SMOKE_NAME
