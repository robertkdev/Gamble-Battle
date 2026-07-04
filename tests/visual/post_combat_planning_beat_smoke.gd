extends "res://tests/visual/actual_run_loop_smoke.gd"

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const SMOKE_NAME: String = "PostCombatPlanningBeatSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/post_combat_planning_beat_pass"
const MIN_RESTORED_PLANNING_SECONDS: float = 55.0

var _saved_captures: int = 0

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
	var opener_started: bool = await _wait_for_combat_active(5.0)
	_expect(opener_started, "opening fight did not start immediately after starter select")
	_expect(not _bottom_planning_visible(), "bottom planning/shop area stayed visible during the opening fight")
	if _finish_if_failed():
		return

	var intermission_seen: bool = await _wait_for_intermission_bar(24.0)
	_expect(intermission_seen, "post-combat intermission bar did not appear before planning returned")
	if _finish_if_failed():
		return
	_save_capture("01_post_win_intermission_bar.png")

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
	_normalize_restored_planning_capture_timer()
	await get_tree().process_frame
	_save_capture("02_post_win_planning_restored.png")
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

func _bottom_planning_visible() -> bool:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return false
	var bench: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as Control
	var bottom: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	return (bench != null and bench.visible) or (bottom != null and bottom.visible)

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

func _normalize_restored_planning_capture_timer() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 60.0)
	combat.set("planning_time_left", 60.0)
	var timer_label: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if timer_label != null:
		timer_label.text = "Planning: 1:00"

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_save_vision_capture(filename)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: skipped %s; viewport texture unavailable" % [SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: skipped %s; viewport image unavailable" % [SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s: failed to save %s error=%s" % [SMOKE_NAME, ProjectSettings.globalize_path(path), str(int(error))])
		return
	_saved_captures += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _save_vision_capture(filename: String) -> void:
	var root_node: Node = self
	if _main != null:
		root_node = _main
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(root_node, filename.get_basename(), OUTPUT_DIR)
	if not bool(result.get("ok", false)):
		push_error("%s: vision fallback failed for %s reason=%s" % [SMOKE_NAME, filename, str(result.get("reason", ""))])
		return
	_saved_captures += 1
	print("%s: saved %s via %s" % [SMOKE_NAME, ProjectSettings.globalize_path(str(result.get("path", ""))), str(result.get("kind", ""))])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
