extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const MID_RUN_SMOKE_NAME: String = "MidRunProgressionSmoke"
const STARTER_ID: String = "bonko"
const MID_RUN_FIRST_FIGHT_TIMEOUT: float = 30.0
const MID_RUN_ROUND_TIMEOUT: float = 42.0
const MAX_DEPLOY_ATTEMPTS: int = 10
const ROUND_PLANS: Array[Dictionary] = [
	{
		"label": "round_2_frontline_pair",
		"offers": ["morrak", "grint", "mortem", "korath", "sari"],
		"buy": ["morrak", "grint"],
		"gold": 12,
		"min_stage_after": 3,
	},
	{
		"label": "round_3_body_width",
		"offers": ["sari", "brute", "berebell", "bo", "cashmere"],
		"buy": ["sari", "brute"],
		"gold": 12,
		"min_stage_after": 4,
	},
	{
		"label": "round_4_late_choice",
		"offers": ["berebell", "bo", "cashmere", "repo", "korath"],
		"buy": ["berebell", "bo"],
		"gold": 12,
		"min_stage_after": 5,
	},
]

var _mid_run_results: Array[Dictionary] = []
var _audit_gold_added_total: int = 0
var _resolved_battle_count: int = 0

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

	_start_main_scene()
	await _settle_frames(4)
	await _run_mid_run_progression_flow()
	_finish_mid_run_progression()

func _run_mid_run_progression_flow() -> void:
	await _ensure_unit_select()
	await _select_starter(STARTER_ID)
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "CombatView did not open for mid-run progression")
	var repositioned: bool = await _reposition_first_board_unit("mid-run opener reposition")
	_expect(repositioned, "starter did not reposition before mid-run opener")
	if not _technical_failures().is_empty():
		return

	_set_planning_timer_safe()
	_expect(_first_fight_placeholder_visible(), "forced opener placeholder missing before mid-run progression")
	await _press_continue(true, "mid-run forced opener")
	var first_result: String = await _wait_for_first_result(MID_RUN_FIRST_FIGHT_TIMEOUT)
	_expect(first_result == "shop", "mid-run opener should win into shop, got %s" % first_result)
	if first_result != "shop":
		return
	_resolved_battle_count = 1
	_expect(int(GameState.stage_in_chapter) >= 2, "mid-run opener should reach at least Stage 1 Round 2")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "mid-run first shop should have full offers")

	for raw_plan: Dictionary in ROUND_PLANS:
		var advanced: bool = await _play_planned_round(raw_plan)
		if not advanced:
			return

func _play_planned_round(plan: Dictionary) -> bool:
	var label: String = String(plan.get("label", "planned_round"))
	var offer_ids: Array[String] = _string_array(plan.get("offers", []))
	var buy_ids: Array[String] = _string_array(plan.get("buy", []))
	var target_gold: int = int(plan.get("gold", buy_ids.size()))
	var min_stage_after: int = int(plan.get("min_stage_after", 0))
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	var stage_before: int = int(GameState.stage_in_chapter)
	var board_before: Array[String] = _board_ids()
	var bench_before: Array[String] = _bench_ids()
	var result: Dictionary = {
		"label": label,
		"stage_before": stage_before,
		"board_before": board_before,
		"bench_before": bench_before,
		"target_gold": target_gold,
		"planned_buys": buy_ids,
	}

	_audit_gold_added_total += _add_gold_to_at_least(target_gold)
	await _settle_frames(2)
	var offers: Array[ShopOffer] = _offers_for_ids(offer_ids)
	_expect(offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "%s should build %d forced offers, got %d" % [label, int(SHOP_CONFIG.SLOT_COUNT), offers.size()])
	if offers.size() != int(SHOP_CONFIG.SLOT_COUNT):
		return false
	_force_shop_offers(offers, int(Economy.gold))
	await _settle_frames(4)
	result["forced_offers"] = _offer_summaries()
	result["gold_before_buys"] = int(Economy.gold)

	var bought_ids: Array[String] = []
	for unit_id: String in buy_ids:
		var bought: bool = await _buy_offer_id(unit_id)
		_expect(bought, "%s could not buy planned offer %s from %s" % [label, unit_id, JSON.stringify(_offer_summaries())])
		if not bought:
			result["bought_ids"] = bought_ids
			_record_round_result(result, failure_start, shop_error_start)
			return false
		bought_ids.append(unit_id)
		await _settle_frames(3)
	result["bought_ids"] = bought_ids
	result["bench_after_buys"] = _bench_ids()

	var deployed_count: int = await _deploy_all_bench_units()
	result["deployed_count"] = deployed_count
	result["bench_after_deploy"] = _bench_ids()
	result["board_after_deploy"] = _board_ids()
	var expected_board_min: int = board_before.size() + bought_ids.size()
	_expect(_board_ids().size() >= expected_board_min, "%s should field at least %d units, got %s" % [label, expected_board_min, JSON.stringify(_board_ids())])
	if _board_ids().size() < expected_board_min:
		_record_round_result(result, failure_start, shop_error_start)
		return false

	_set_planning_timer_safe()
	await _press_continue(false, "%s battle" % label)
	var resolved: bool = await _wait_for_preview_or_loss(MID_RUN_ROUND_TIMEOUT)
	var fight_result: String = _second_fight_result(resolved)
	var stage_after: int = int(GameState.stage_in_chapter)
	var advanced: bool = fight_result == "shop" and stage_after > stage_before
	result["resolved"] = resolved
	result["fight_result"] = fight_result
	result["stage_after"] = stage_after
	result["gold_after"] = int(Economy.gold)
	result["advanced"] = advanced
	_expect(resolved, "%s did not resolve" % label)
	_expect(fight_result == "shop", "%s should win and return to shop, got %s" % [label, fight_result])
	_expect(stage_after >= min_stage_after, "%s should reach stage >= %d, got %d" % [label, min_stage_after, stage_after])
	_record_round_result(result, failure_start, shop_error_start)
	if advanced:
		_resolved_battle_count += 1
		print("%s: %s advanced stage %d -> %d board=%s" % [
			MID_RUN_SMOKE_NAME,
			label,
			stage_before,
			stage_after,
			JSON.stringify(_board_ids()),
		])
	return advanced

func _offers_for_ids(unit_ids: Array[String]) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	for unit_id: String in unit_ids:
		if offers.size() >= int(SHOP_CONFIG.SLOT_COUNT):
			break
		if not catalog.has_id(unit_id):
			_expect(false, "mid-run forced offer id %s missing from catalog" % unit_id)
			continue
		offers.append(_offer_for_id(catalog, unit_id))
	return offers

func _buy_offer_id(unit_id: String) -> bool:
	var slot_index: int = _shop_slot_for_id(unit_id)
	if slot_index < 0:
		return false
	return await _click_shop_slot(slot_index)

func _shop_slot_for_id(unit_id: String) -> int:
	var summaries: Array[Dictionary] = _offer_summaries()
	for summary: Dictionary in summaries:
		if String(summary.get("id", "")) == unit_id:
			return int(summary.get("slot", -1))
	return -1

func _deploy_all_bench_units() -> int:
	var deployed_count: int = 0
	var attempts: int = 0
	while attempts < MAX_DEPLOY_ATTEMPTS and not _bench_ids().is_empty():
		attempts += 1
		var before_board_size: int = _board_ids().size()
		var moved: bool = await _drag_first_bench_unit_to_board()
		await _settle_frames(4)
		var after_board_size: int = _board_ids().size()
		if moved and after_board_size > before_board_size:
			deployed_count += 1
		else:
			break
	return deployed_count

func _add_gold_to_at_least(target_gold: int) -> int:
	var before_gold: int = int(Economy.gold)
	if before_gold >= target_gold:
		return 0
	var delta: int = int(target_gold) - before_gold
	Economy.add_gold(delta)
	return delta

func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		var raw_array: Array = value
		for item: Variant in raw_array:
			output.append(String(item))
	return output

func _record_round_result(result: Dictionary, failure_start: int, shop_error_start: int) -> void:
	result["technical_failures"] = _failures_since(failure_start)
	result["shop_errors"] = _shop_errors_since(shop_error_start)
	_mid_run_results.append(result.duplicate(true))

func _finish_mid_run_progression() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var final_board: Array[String] = _board_ids()
		print("%s: OK battles=%d stage=%d audit_gold_added=%d board=%s" % [
			MID_RUN_SMOKE_NAME,
			_resolved_battle_count,
			int(GameState.stage_in_chapter),
			_audit_gold_added_total,
			JSON.stringify(final_board),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [MID_RUN_SMOKE_NAME, failure])
		print("%s: results=%s" % [MID_RUN_SMOKE_NAME, JSON.stringify(_mid_run_results)])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
