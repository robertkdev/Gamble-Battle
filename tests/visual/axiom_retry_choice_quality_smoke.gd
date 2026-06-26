extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const AXIOM_SMOKE_NAME: String = "AxiomRetryChoiceQualitySmoke"
const AXIOM_ID: String = "axiom"
const AXIOM_RETRY_TIMEOUT: float = 30.0
const AXIOM_RETRY_FIGHT_TIMEOUT: float = 35.0

var _axiom_retry_results: Array[Dictionary] = []

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 8.0
	if Shop != null and not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)

	var result: Dictionary = await _run_axiom_retry_choice_sweep()
	_axiom_retry_results.append(result)
	_assert_all_axiom_retry_helpers_advance(result)
	_finish_axiom_retry_choice()

func _run_axiom_retry_choice_sweep() -> Dictionary:
	var snapshot: Dictionary = await _capture_axiom_retry_snapshot()
	var result: Dictionary = {
		"id": AXIOM_ID,
		"snapshot": snapshot.get("summary", {}),
		"trials": [],
	}
	if not bool(snapshot.get("ok", false)):
		result["error"] = String(snapshot.get("error", "snapshot_failed"))
		return result
	var offers: Array[ShopOffer] = _axiom_retry_offers()
	var offer_summaries: Array[Dictionary] = _offer_summaries_for_offers(offers)
	_expect(offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "Axiom retry helper set should have %d offers, got %d" % [int(SHOP_CONFIG.SLOT_COUNT), offers.size()])
	var gold_before_buy: int = int(snapshot.get("gold", 0))
	for slot_index: int in range(offers.size()):
		var offer: ShopOffer = offers[slot_index]
		if offer == null or String(offer.id) == "":
			continue
		var offer_summary: Dictionary = offer_summaries[slot_index] if slot_index < offer_summaries.size() else _offer_summary_from_offer(slot_index, offer)
		var trial: Dictionary = await _run_axiom_retry_slot_trial(offers, gold_before_buy, slot_index, offer_summary)
		var trials: Array = result.get("trials", []) as Array
		trials.append(trial)
		result["trials"] = trials
	return result

func _capture_axiom_retry_snapshot() -> Dictionary:
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	_start_main_scene()
	await _settle_frames(4)
	await _ensure_unit_select()
	await _select_starter(AXIOM_ID)
	await _settle_frames(4)
	var combat_opened: bool = _node_visible("CombatView")
	var board_repositioned: bool = await _reposition_first_board_unit("Axiom retry snapshot board reposition") if combat_opened else false
	_set_planning_timer_safe()
	await _press_continue(true, "Axiom retry snapshot forced first fight")
	var retry_ready: bool = await _wait_for_axiom_retry_shop(AXIOM_RETRY_TIMEOUT)
	var output: Dictionary = {
		"ok": retry_ready,
		"summary": {
			"first_fight_result": "retry" if retry_ready else "not_ready",
			"stage_after_first": int(GameState.stage_in_chapter),
			"gold_after_first": int(Economy.gold),
			"offers_after_first": _offer_summaries(),
			"board_after_first": _board_ids(),
			"combat_opened": combat_opened,
			"board_repositioned": board_repositioned,
			"shop_errors": _shop_errors_since(shop_error_start),
			"technical_failures": _failures_since(failure_start),
		},
		"gold": int(Economy.gold),
	}
	if not retry_ready:
		output["error"] = "retry_shop_not_ready"
	await _cleanup_between_starters()
	return output

func _run_axiom_retry_slot_trial(offers: Array[ShopOffer], gold_before_buy: int, slot_index: int, offer_summary: Dictionary) -> Dictionary:
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	_start_main_scene()
	await _settle_frames(4)
	await _ensure_unit_select()
	await _select_starter(AXIOM_ID)
	await _settle_frames(4)
	var combat_opened: bool = _node_visible("CombatView")
	var board_repositioned: bool = await _reposition_first_board_unit("Axiom retry trial slot %d board reposition" % slot_index) if combat_opened else false
	_set_planning_timer_safe()
	await _press_continue(true, "Axiom retry trial slot %d forced first fight" % slot_index)
	var retry_ready: bool = await _wait_for_axiom_retry_shop(AXIOM_RETRY_TIMEOUT)
	var result: Dictionary = {
		"slot": slot_index,
		"offer": offer_summary,
		"first_fight_result": "retry" if retry_ready else "not_ready",
		"combat_opened": combat_opened,
		"board_repositioned": board_repositioned,
		"stage_after_first": int(GameState.stage_in_chapter),
		"gold_after_first_actual": int(Economy.gold),
	}
	if not retry_ready:
		result["error"] = "retry_shop_not_ready"
		result["technical_failures"] = _failures_since(failure_start)
		result["shop_errors"] = _shop_errors_since(shop_error_start)
		await _cleanup_between_starters()
		return result
	_force_shop_offers(offers, gold_before_buy)
	await _settle_frames(4)
	result["gold_before_buy_forced"] = int(Economy.gold)
	result["forced_offers"] = _offer_summaries()
	result["shop_buy_clicked"] = await _click_shop_slot(slot_index)
	await _settle_frames(4)
	result["bench_after_buy"] = _bench_ids()
	result["deploy_prompt_visible"] = _deploy_prompt_visible()
	var moved_to_board: bool = false
	if not _bench_ids().is_empty():
		moved_to_board = await _drag_first_bench_unit_to_board()
		await _settle_frames(4)
	result["moved_to_board"] = moved_to_board
	result["bench_after_deploy"] = _bench_ids()
	result["board_after_deploy"] = _board_ids()
	if moved_to_board:
		await _press_continue(false, "Axiom retry trial slot %d retry fight" % slot_index)
		var retry_fight_resolved: bool = await _wait_for_preview_or_loss(AXIOM_RETRY_FIGHT_TIMEOUT)
		result["retry_fight_resolved"] = retry_fight_resolved
		result["retry_fight_result"] = _second_fight_result(retry_fight_resolved)
		result["stage_after_retry"] = int(GameState.stage_in_chapter)
		result["gold_after_retry"] = int(Economy.gold)
		result["advanced_after_retry"] = int(result["stage_after_retry"]) > int(result["stage_after_first"])
	else:
		result["retry_fight_resolved"] = false
		result["retry_fight_result"] = "not_started"
		result["advanced_after_retry"] = false
	result["technical_failures"] = _failures_since(failure_start)
	result["shop_errors"] = _shop_errors_since(shop_error_start)
	await _cleanup_between_starters()
	print("%s: trial slot=%d offer=%s advanced=%s stage=%d" % [
		AXIOM_SMOKE_NAME,
		slot_index,
		String(offer_summary.get("id", "")),
		str(bool(result.get("advanced_after_retry", false))),
		int(result.get("stage_after_retry", -1)),
	])
	return result

func _wait_for_axiom_retry_shop(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if GameState.phase == GameState.GamePhase.PREVIEW and not Economy.combat_active:
			var same_opening_stage: bool = int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) == 1
			var shop_ready: bool = Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT)
			if same_opening_stage and shop_ready:
				return true
	return false

func _axiom_retry_offers() -> Array[ShopOffer]:
	var output: Array[ShopOffer] = []
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	for helper_id: String in _axiom_retry_helper_ids():
		if not catalog.has_id(helper_id):
			_expect(false, "Axiom retry helper id %s missing from catalog" % helper_id)
			continue
		output.append(_offer_for_id(catalog, helper_id))
	return output

func _axiom_retry_helper_ids() -> Array[String]:
	var output: Array[String] = []
	var raw: Array = SHOP_CONFIG.FIRST_SHOP_HELPERS_BY_STARTER.get(AXIOM_ID, []) as Array
	for value: Variant in raw:
		output.append(String(value))
	return output

func _assert_all_axiom_retry_helpers_advance(result: Dictionary) -> void:
	var trials: Array = result.get("trials", []) as Array
	_expect(trials.size() == int(SHOP_CONFIG.SLOT_COUNT), "Axiom retry should test all configured helpers")
	for raw_trial: Variant in trials:
		var trial: Dictionary = raw_trial as Dictionary
		var offer: Dictionary = trial.get("offer", {}) as Dictionary
		var helper_id: String = String(offer.get("id", ""))
		_expect(bool(trial.get("advanced_after_retry", false)), "Axiom retry helper %s did not advance beyond Stage 1" % helper_id)

func _finish_axiom_retry_choice() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var summary: Dictionary = _axiom_retry_summary()
		print("%s: PASS trials=%d advanced=%d" % [
			AXIOM_SMOKE_NAME,
			int(summary.get("trial_count", 0)),
			int(summary.get("advanced_count", 0)),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [AXIOM_SMOKE_NAME, failure])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _axiom_retry_summary() -> Dictionary:
	var trial_count: int = 0
	var advanced_count: int = 0
	for starter: Dictionary in _axiom_retry_results:
		var trials: Array = starter.get("trials", []) as Array
		for raw_trial: Variant in trials:
			var trial: Dictionary = raw_trial as Dictionary
			trial_count += 1
			if bool(trial.get("advanced_after_retry", false)):
				advanced_count += 1
	return {
		"trial_count": trial_count,
		"advanced_count": advanced_count,
	}
