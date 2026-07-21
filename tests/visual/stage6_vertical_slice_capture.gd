extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/stage6_vertical_slice_pass"
const DESKTOP_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_SIZE: Vector2i = Vector2i(1280, 720)
const PLAYER_IDS: Array[String] = ["axiom", "berebell", "bo", "bonko", "brute", "cashmere"]
const ENEMY_IDS: Array[String] = ["korath", "brute", "berebell", "mortem", "sari", "luna"]

var _capture_records: Array[Dictionary] = []
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_configure_viewport(DESKTOP_SIZE)
	await _capture_entry_and_starter()

	var desktop_view: Control = await _create_combat_view()
	if desktop_view != null:
		await _prepare_decision_state(desktop_view)
		await _save_capture("02_planning_decision_contained.png", "planning", "decision", "desktop-1920x1080", DESKTOP_SIZE)
		if await _start_durable_boss_battle(desktop_view):
			await _wait_visual(0.08)
			_assert_stinger(desktop_view, "desktop battle intro")
			await _save_capture("03_round_stinger_t080.png", "battle_intro", "round_stinger", "desktop-1920x1080", DESKTOP_SIZE)
			await _settle(0.72)
			_assert_bar_layout(desktop_view, "desktop combat")
			await _save_capture("04_combat_cluster_readability.png", "combat", "cluster", "desktop-1920x1080", DESKTOP_SIZE)
			await _save_capture("05a_boss_phase_normal_t000.png", "boss_phase", "boss_phase", "desktop-1920x1080", DESKTOP_SIZE)
			var desktop_controller: Variant = desktop_view.get("controller")
			if desktop_controller != null:
				var revived_indices: Array[int] = [0, 1]
				var affected_player_indices: Array[int] = []
				desktop_controller.call("_on_encounter_escalated", "blood_reckoning", "BLOOD RECKONING", 0, revived_indices, affected_player_indices, 0, 3)
			await _wait_visual(0.08)
			_assert_stinger(desktop_view, "desktop boss phase")
			await _save_capture("05b_boss_phase_stinger_t080.png", "boss_phase", "boss_phase", "desktop-1920x1080", DESKTOP_SIZE)
			await _wait_visual(0.72)
			await _save_capture("05c_boss_phase_settled_t800.png", "boss_phase", "boss_phase", "desktop-1920x1080", DESKTOP_SIZE)
			if desktop_controller != null:
				desktop_controller.call("_on_victory", 4)
			await _wait_visual(0.24)
			await _save_capture("06_boss_victory_ceremony.png", "boss_victory", "consequence", "desktop-1920x1080", DESKTOP_SIZE)
			await _restore_planning_reveal(desktop_view)
			await _save_capture("07_next_planning_reveal.png", "planning_return", "handoff", "desktop-1920x1080", DESKTOP_SIZE)
		_cleanup_view(desktop_view)
		await _settle(0.12)

	_configure_viewport(COMPACT_SIZE)
	var compact_view: Control = await _create_combat_view()
	if compact_view != null:
		await _prepare_decision_state(compact_view)
		_assert_compact_containment(compact_view)
		await _save_capture("08_compact_planning_contained.png", "planning", "decision", "compact-1280x720", COMPACT_SIZE)
		if await _start_durable_boss_battle(compact_view):
			await _wait_visual(0.08)
			_assert_stinger(compact_view, "compact battle intro")
			await _save_capture("09_compact_round_stinger_t080.png", "battle_intro", "round_stinger", "compact-1280x720", COMPACT_SIZE)
			await _settle(0.72)
			_assert_bar_layout(compact_view, "compact combat")
			await _save_capture("10_compact_combat_cluster_readability.png", "combat", "cluster", "compact-1280x720", COMPACT_SIZE)
			var compact_controller: Variant = compact_view.get("controller")
			if compact_controller != null:
				compact_controller.call("_on_victory", 4)
			await _wait_visual(0.24)
			await _save_capture("11_compact_boss_victory_ceremony.png", "boss_victory", "consequence", "compact-1280x720", COMPACT_SIZE)
		_cleanup_view(compact_view)
		await _settle(0.12)

	_write_manifest()
	_finish()

func _capture_entry_and_starter() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	await _settle(0.32)
	await _save_capture("00_title_entrance.png", "title", "entry", "desktop-1920x1080", DESKTOP_SIZE)
	main.call("_on_start")
	await _settle(0.24)
	var unit_select: Control = main.get_node_or_null("UnitSelect") as Control
	var first_button: Button = unit_select.find_child("UnitButton_*", true, false) as Button if unit_select != null else null
	_expect(unit_select != null and unit_select.visible, "starter selection did not open")
	_expect(first_button != null, "starter selection button missing")
	if unit_select != null and first_button != null:
		var unit_id: String = String(first_button.get_meta("unit_id", ""))
		unit_select.call("_on_unit_button_pressed", first_button, unit_id, unit_id.capitalize())
	await _settle(0.22)
	await _save_capture("01_starter_commit.png", "starter", "commit", "desktop-1920x1080", DESKTOP_SIZE)
	var embedded_combat: Node = main.get_node_or_null("CombatView")
	if embedded_combat != null and embedded_combat.has_method("_teardown"):
		embedded_combat.call("_teardown")
	main.queue_free()
	await _settle(0.16)

func _create_combat_view() -> Control:
	GameState.set_chapter_and_stage(1, 4)
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	if view == null:
		_fail("CombatView instantiate failed")
		return null
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	await _settle(0.30)
	return view

func _prepare_decision_state(view: Control) -> void:
	GameState.set_chapter_and_stage(1, 4)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Economy.reset_run()
	Economy.add_gold(12)
	Economy.set_bet(3)
	Shop.reset_run()
	Shop.set_opening_starter_id("axiom")
	Shop.add_free_rerolls(1)
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "Stage 6 planning reroll failed")
	view.call("set_player_team_ids", ["axiom", "berebell", "bo"])
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager != null:
		manager.stage = 4
		manager.setup_stage_preview()
	var controller: Variant = view.get("controller")
	if controller != null:
		controller.call("refresh_all_views")
		controller.call("_set_continue_to_start_text")
		controller.call("_sync_bottom_combat_visibility", true)
		var economy_ui: Variant = controller.get("economy_ui")
		if economy_ui != null:
			economy_ui.call("refresh")
	view.set("planning_timer_total", 120.0)
	view.set("planning_time_left", 120.0)
	await _settle(0.32)

func _start_durable_boss_battle(view: Control) -> bool:
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager == null:
		_fail("CombatManager missing")
		return false
	GameState.set_chapter_and_stage(1, 4)
	var result: Dictionary[String, Variant] = manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, {
		"label": "Stage 6 premium vertical slice",
		"stage": 4,
	})
	if not bool(result.get("ok", false)):
		_fail("custom battle failed: %s" % String(result.get("reason", "unknown")))
		return false
	_make_team_durable(manager.player_team)
	_make_team_durable(manager.enemy_team)
	return true

func _make_team_durable(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = maxi(unit.max_hp, 9000)
		unit.hp = unit.max_hp
		unit.attack_damage = minf(unit.attack_damage, 18.0)
		unit.spell_power = minf(unit.spell_power, 18.0)

func _restore_planning_reveal(view: Control) -> void:
	var controller: Variant = view.get("controller")
	if controller != null:
		controller.call("_hide_result_banner")
		controller.call("_exit_combat_arena")
		controller.call("_sync_bottom_combat_visibility", true)
	GameState.set_chapter_and_stage(2, 1)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	await _settle(0.28)

func _assert_stinger(view: Control, context: String) -> void:
	var stinger: Control = view.get_node_or_null("BattlePhaseStinger") as Control
	_expect(stinger != null and stinger.visible, "%s stinger was not visible" % context)
	if stinger != null:
		var snapshot: Dictionary[String, Variant] = stinger.call("presentation_snapshot")
		_expect(String(snapshot.get("cue", "")) != "idle", "%s stinger cue stayed idle" % context)

func _assert_bar_layout(view: Control, context: String) -> void:
	var controller: Variant = view.get("controller")
	var arena_bridge: Variant = controller.get("arena_bridge") if controller != null else null
	var arena: Variant = arena_bridge.get("arena") if arena_bridge != null else null
	_expect(arena != null, "%s arena controller missing" % context)
	if arena == null:
		return
	arena.call("refresh_bar_layout")
	var snapshot: Array = arena.call("bar_layout_snapshot") as Array
	_expect(snapshot.size() >= 10, "%s should expose the full battle bar layout" % context)
	var rects: Array[Rect2] = []
	for entry_value: Variant in snapshot:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var rect_value: Variant = entry.get("rect", Rect2())
		if not (rect_value is Rect2):
			continue
		var rect: Rect2 = rect_value as Rect2
		for placed: Rect2 in rects:
			_expect(not rect.intersects(placed.grow(1.0)), "%s health bars overlap: %s vs %s" % [context, str(rect), str(placed)])
		rects.append(rect)

func _assert_compact_containment(view: Control) -> void:
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(COMPACT_SIZE))
	var paths: Array[String] = [
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel",
		"MarginContainer/VBoxContainer/BenchArea",
		"MarginContainer/VBoxContainer/ActionsRow",
		"MarginContainer/VBoxContainer/BottomStorageArea",
	]
	for path: String in paths:
		var control: Control = view.get_node_or_null(path) as Control
		_expect(control != null, "compact control missing: %s" % path)
		if control != null:
			_expect(viewport_rect.encloses(control.get_global_rect()), "compact control escapes viewport: %s rect=%s" % [path, str(control.get_global_rect())])
	var metric_tabs: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/MetricTabs") as Control
	if metric_tabs != null:
		for node: Node in metric_tabs.find_children("*", "Button", true, false):
			var button: Button = node as Button
			if button != null and button.visible:
				_expect(viewport_rect.encloses(button.get_global_rect()), "compact metric button is clipped: %s rect=%s" % [button.name, str(button.get_global_rect())])

func _save_capture(filename: String, state: String, event_name: String, viewport_label: String, expected_size: Vector2i) -> void:
	if _framebuffer_unavailable():
		_fail("framebuffer capture unavailable")
		return
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		_fail("viewport image unavailable for " + filename)
		return
	var actual_size: Vector2i = Vector2i(image.get_width(), image.get_height())
	if actual_size != expected_size:
		_fail("%s viewport=%s expected=%s" % [filename, str(actual_size), str(expected_size)])
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("failed to save %s error=%d" % [filename, int(error)])
		return
	_capture_records.append({
		"file": filename,
		"state": state,
		"event": event_name,
		"viewport": viewport_label,
		"actual_size": "%dx%d" % [actual_size.x, actual_size.y],
	})
	print("Stage6VerticalSliceCapture: saved %s" % ProjectSettings.globalize_path(path))

func _write_manifest() -> void:
	var path: String = "%s/runtime_manifest.json" % OUTPUT_DIR
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("runtime manifest could not be opened")
		return
	var payload: Dictionary[String, Variant] = {
		"runtime": "Godot 4.5 player-facing framebuffer",
		"scene": "res://tests/visual/Stage6VerticalSliceCapture.tscn",
		"build": "codex/019f80d9-676-task",
		"captures": _capture_records,
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _cleanup_view(view: Control) -> void:
	if view == null or not is_instance_valid(view):
		return
	if view.has_method("_teardown"):
		view.call("_teardown")
	view.queue_free()

func _configure_viewport(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	var window: Window = get_window()
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size

func _framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame

func _wait_visual(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _capture_records.size() != 14:
		_fail("expected 14 captures, got %d" % _capture_records.size())
	if _failures.is_empty():
		print("Stage6VerticalSliceCapture: OK captures=%d output=%s" % [_capture_records.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("Stage6VerticalSliceCapture: " + failure)
	get_tree().quit(1)
