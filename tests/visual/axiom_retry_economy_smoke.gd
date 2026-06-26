extends "res://tests/visual/actual_run_loop_smoke.gd"

const SMOKE_NAME: String = "AxiomRetryEconomySmoke"
const RETRY_TIMEOUT_SECONDS: float = 30.0
const RETRY_FIGHT_TIMEOUT_SECONDS: float = 35.0

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
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(4)

	await _ensure_unit_select()
	if _finish_if_failed():
		return
	await _select_starter("axiom")
	if _finish_if_failed():
		return
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "combat view did not open for Axiom")
	var repositioned: bool = await _reposition_first_board_unit("Axiom retry board reposition")
	_expect(repositioned, "Axiom board unit did not reposition through mouse drag")
	if _finish_if_failed():
		return

	_set_planning_timer_safe()
	await _press_continue(true, "Axiom forced first fight")
	var retry_ready: bool = await _wait_for_retry_shop(RETRY_TIMEOUT_SECONDS)
	_expect(retry_ready, "Axiom did not reach retry shop after forced opener defeat")
	if _finish_if_failed():
		return

	_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "nonlethal Axiom retry should not show loss overlay")
	_expect(int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) == 1, "Axiom retry should stay on Chapter 1 Stage 1")
	_expect(int(Economy.gold) == 2, "Axiom retry should recover to exactly 2 gold, got %d" % int(Economy.gold))
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "Axiom retry shop did not have full offers")
	_expect(_first_retry_offer_is_configured_helper(), "Axiom retry shop should start with a configured helper, got %s" % JSON.stringify(_retry_offer_summaries()))
	_expect(_affordable_shop_card_count() >= 1, "Axiom retry shop should contain at least one affordable helper")
	if _finish_if_failed():
		return

	var bought: bool = await _press_affordable_shop_card()
	_expect(bought, "Axiom retry could not buy an affordable helper")
	await _settle_frames(4)
	_expect(int(Economy.gold) == 1, "Axiom retry purchase should preserve 1 health, got %d gold" % int(Economy.gold))
	_expect(Roster.compact().size() >= 1, "Axiom retry purchase did not place a unit on bench")
	_expect(_deploy_prompt_visible(), "Axiom retry purchase did not show deploy guidance")
	_expect(_first_deploy_bench_highlight_visible(), "Axiom retry helper did not get first-deploy bench highlight")
	if _finish_if_failed():
		return

	var moved_to_board: bool = await _drag_first_bench_unit_to_board()
	_expect(moved_to_board, "Axiom retry helper did not move from bench to board")
	await _settle_frames(4)
	_expect(_player_team_size() >= 2, "Axiom retry board did not widen after helper deployment")
	_expect(not _first_deploy_bench_highlight_visible(), "Axiom retry bench highlight did not clear after deployment")
	if _finish_if_failed():
		return

	await _press_continue(false, "Axiom retry fight")
	var retry_fight_resolved: bool = await _wait_for_preview_or_loss(RETRY_FIGHT_TIMEOUT_SECONDS)
	_expect(retry_fight_resolved, "Axiom retry fight did not resolve")
	_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "Axiom retry fight should not end in a loss overlay")
	_expect(int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) >= 2, "Axiom retry fight should progress to Chapter 1 Stage 2")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "Axiom retry fight should return to a full planning shop")
	_finish()

func _wait_for_retry_shop(timeout_seconds: float) -> bool:
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

func _affordable_shop_card_count() -> int:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		return 0
	var count: int = 0
	for child: Node in grid.get_children():
		var card: ShopCard = child as ShopCard
		if card != null and not card.disabled:
			count += 1
	return count

func _player_team_size() -> int:
	var controller: Variant = _combat_controller()
	if controller == null:
		return 0
	var manager: Variant = controller.get("manager")
	if manager == null:
		return 0
	return int(manager.player_team.size())

func _first_retry_offer_is_configured_helper() -> bool:
	if Shop == null or Shop.state == null or Shop.state.offers == null or Shop.state.offers.is_empty():
		return false
	var raw_helpers: Array = SHOP_CONFIG.FIRST_SHOP_HELPERS_BY_STARTER.get("axiom", []) as Array
	var helper_ids: Array[String] = []
	for raw_helper: Variant in raw_helpers:
		helper_ids.append(String(raw_helper))
	var first_offer: ShopOffer = Shop.state.offers[0] as ShopOffer
	return first_offer != null and helper_ids.has(String(first_offer.id))

func _retry_offer_summaries() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if Shop == null or Shop.state == null or Shop.state.offers == null:
		return output
	for index: int in range(Shop.state.offers.size()):
		var offer: ShopOffer = Shop.state.offers[index] as ShopOffer
		if offer == null:
			output.append({"slot": index, "id": "", "cost": 0})
		else:
			output.append({"slot": index, "id": String(offer.id), "cost": int(offer.cost)})
	return output

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
	else:
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
