extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const VisionSnapshot: GDScript = preload("res://scripts/util/vision_snapshot.gd")
const OUTPUT_DIR: String = "res://outputs/vision_snapshots/smoke"
const STARTER_ID: String = "bonko"
const TIMEOUT_SECONDS: float = 45.0

var _main: Control = null
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _previous_time_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 8.0
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(6)

	await _capture("01_title", ["GAMBLE BATTLE"])
	_call_main("_on_start")
	await _settle_frames(6)
	await _capture("02_unit_select", ["NO CHAMPION CHOSEN", "START GAME"])
	_set_opening_auto_start_enabled(false)
	_call_main("_on_unit_selected", [STARTER_ID])
	var combat: Control = await MainTransitionWait.for_combat_view(self, _main)
	_expect(combat != null, "CombatView should be ready for opening capture")
	var opening_ready: bool = await _wait_for_opening_planning(20.0)
	_expect(opening_ready, "Opening planning UI should replace unit select before capture")
	await _capture("03_opening_combat", ["START OPENING FIGHT", "OPENING FIGHT"])

	_call_main("_open_system_menu")
	await _settle_frames(4)
	await _capture("04_system_menu", ["SYSTEM", "RESUME", "NEW RUN", "RETURN TO TITLE"])
	_call_main("_close_system_menu")
	await _settle_frames(4)

	_set_planning_timer_safe()
	await _press_continue()
	var shop_ready: bool = await _wait_for_shop_after_win(TIMEOUT_SECONDS)
	_expect(shop_ready, "Bonko opener should reach first shop for vision capture")
	await _settle_frames(8)
	await _capture("05_post_fight_shop", ["START BATTLE", "REROLL", "BUY XP"])

	await _show_first_unit_details()
	await _settle_frames(4)
	await _capture("06_unit_detail_stats", ["PLAYER UNIT"])
	_finish()

func _capture(label: String, required_needles: Array[String]) -> void:
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(_main, label, OUTPUT_DIR)
	_captures.append(result)
	_expect(bool(result.get("ok", false)), "%s capture should succeed" % label)
	_expect(bool(result.get("software_ok", false)), "%s software fallback PNG should be saved" % label)
	var path: String = str(result.get("path", ""))
	var software_path: String = str(result.get("software_path", ""))
	var json_path: String = str(result.get("json_path", ""))
	_expect(path != "" and FileAccess.file_exists(path), "%s final capture path missing: %s" % [label, path])
	_expect(software_path != "" and FileAccess.file_exists(software_path), "%s software capture path missing: %s" % [label, software_path])
	_expect(json_path != "" and FileAccess.file_exists(json_path), "%s JSON capture path missing: %s" % [label, json_path])
	_expect(_file_size(software_path) > 2048, "%s software capture PNG looks too small" % label)
	_expect(_json_contains_needles(json_path, required_needles), "%s JSON/text snapshot missing expected text: %s" % [label, JSON.stringify(required_needles)])

func _json_contains_needles(path: String, needles: Array[String]) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text().to_upper()
	file.close()
	for needle: String in needles:
		if not text.contains(needle.to_upper()):
			return false
	return true

func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = int(file.get_length())
	file.close()
	return size

func _call_main(method_name: String, args: Array[Variant] = []) -> void:
	if _main == null or not _main.has_method(method_name):
		_expect(false, "Main missing method %s" % method_name)
		return
	_main.callv(method_name, args)

func _set_planning_timer_safe() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 9999.0)
	combat.set("planning_time_left", 9999.0)

func _set_opening_auto_start_enabled(enabled: bool) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	if combat.has_method("set_auto_start_battle_enabled"):
		combat.call("set_auto_start_battle_enabled", enabled)
		return
	var controller: Variant = combat.get("controller")
	if controller != null and controller.has_method("set_auto_start_battle_enabled"):
		controller.call("set_auto_start_battle_enabled", enabled)

func _wait_for_opening_planning(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var unit_select: Control = _main.get_node_or_null("UnitSelect") as Control
		var button: Button = _main.find_child("ContinueButton", true, false) as Button
		var select_hidden: bool = unit_select == null or not unit_select.visible
		if select_hidden and button != null and button.visible and not button.disabled:
			if button.text == "Start Opening Fight":
				return true
	return false

func _press_continue() -> void:
	if int(GameState.phase) == int(GameState.GamePhase.COMBAT) or bool(Economy.combat_active):
		return
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	if button == null:
		_expect(false, "ContinueButton missing")
		return
	var deadline: int = Time.get_ticks_msec() + 5000
	while button.disabled and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if int(GameState.phase) == int(GameState.GamePhase.COMBAT) or bool(Economy.combat_active):
			return
	if button.disabled:
		_expect(false, "ContinueButton disabled")
		return
	button.emit_signal("pressed")

func _wait_for_shop_after_win(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			var result_banner: Control = _main.find_child("BattleResultBanner", true, false) as Control
			var banner_hidden: bool = result_banner == null or not result_banner.visible
			if banner_hidden and Shop.state != null and Shop.state.offers.size() > 0:
				return true
	return false

func _show_first_unit_details() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		_expect(false, "CombatView missing for unit detail")
		return
	var stats_panel: Control = combat.find_child("StatsPanel", true, false) as Control
	if stats_panel == null:
		_expect(false, "StatsPanel missing for unit detail")
		return
	var manager: CombatManager = combat.get("manager") as CombatManager
	if manager == null or manager.player_team.is_empty():
		_expect(false, "Player team missing for unit detail")
		return
	var unit: Unit = manager.player_team[0] as Unit
	if unit == null:
		_expect(false, "First player unit missing for unit detail")
		return
	if stats_panel.has_method("show_unit_metrics_ctx"):
		stats_panel.call("show_unit_metrics_ctx", "player", 0, unit)
	await _settle_frames(3)
	var unit_scroll: ScrollContainer = stats_panel.find_child("UnitScroll", true, false) as ScrollContainer
	if unit_scroll != null:
		var scroll_bar: VScrollBar = unit_scroll.get_v_scroll_bar()
		unit_scroll.scroll_vertical = int(scroll_bar.max_value)
		await _settle_frames(3)
	var attack_info: Label = stats_panel.find_child("AttackInfo", true, false) as Label
	var ability_info: Label = stats_panel.find_child("AbilityInfo", true, false) as Label
	_expect(attack_info != null and attack_info.text.begins_with("Attack:"), "Unit detail should expose attack copy")
	_expect(ability_info != null and ability_info.text.begins_with("Ability:"), "Unit detail should expose ability copy")

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	if _main != null and is_instance_valid(_main):
		if _main.has_method("_reset_run_state"):
			_main.call("_reset_run_state")
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	var exit_code: int = 0
	if _failures.is_empty():
		print("VisionCaptureSmoke: OK captures=%d output=%s" % [_captures.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("VisionCaptureSmoke: " + failure)
		exit_code = 1
	get_tree().quit(exit_code)
