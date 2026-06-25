extends "res://tests/visual/actual_run_loop_smoke.gd"

const SMOKE_NAME: String = "PostCombatPlanningBeatSmoke"
const MIN_RESTORED_PLANNING_SECONDS: float = 55.0

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
	await _select_starter("bonko")
	if _finish_if_failed():
		return
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "combat view did not open for Bonko")
	var repositioned: bool = await _reposition_first_board_unit("post-combat beat board reposition")
	_expect(repositioned, "Bonko board unit did not reposition through mouse drag")
	if _finish_if_failed():
		return

	_set_planning_timer_safe()
	await _press_continue(true, "Bonko forced first fight")
	var intermission_seen: bool = await _wait_for_intermission_bar(24.0)
	_expect(intermission_seen, "post-combat intermission bar did not appear before planning returned")
	if _finish_if_failed():
		return

	var restored: bool = await _wait_for_post_win_planning(8.0)
	_expect(restored, "post-win planning did not restore after intermission")
	if _finish_if_failed():
		return

	_expect(int(GameState.stage_in_chapter) >= 2, "post-win planning did not advance to the next stage")
	_expect(not Economy.combat_active, "economy still marked combat active after post-win planning restored")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "post-win planning did not restore a full shop")
	_expect(_continue_button_text() == "Start Battle", "post-win planning did not restore Start Battle, got %s" % _continue_button_text())
	_expect(not _continue_button_disabled(), "post-win Start Battle button stayed disabled")
	_expect(_planning_time_left() >= MIN_RESTORED_PLANNING_SECONDS, "post-win planning timer was not reset; got %.2f" % _planning_time_left())
	await _settle_frames(12)
	_expect(GameState.phase == GameState.GamePhase.PREVIEW, "post-win planning did not remain in PREVIEW for the first beat")
	_expect(_continue_button_text() == "Start Battle", "post-win planning button changed during the first beat")
	_finish()

func _wait_for_intermission_bar(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if _intermission_bar_visible():
			_expect(GameState.phase != GameState.GamePhase.PREVIEW, "planning returned before the intermission beat was visible")
			return true
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			return false
	return false

func _wait_for_post_win_planning(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			return true
	return false

func _intermission_bar_visible() -> bool:
	var bar: ProgressBar = _main.find_child("GothicIntermissionBar", true, false) as ProgressBar
	return bar != null and bar.visible

func _continue_button_text() -> String:
	var button: Button = _continue_button()
	return String(button.text) if button != null else "<missing>"

func _continue_button_disabled() -> bool:
	var button: Button = _continue_button()
	return true if button == null else bool(button.disabled)

func _continue_button() -> Button:
	if _main == null or not is_instance_valid(_main):
		return null
	return _main.find_child("ContinueButton", true, false) as Button

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
