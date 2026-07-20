extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const LOSS_SCENE: PackedScene = preload("res://scenes/ui/LossScreen.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/sprint3"
const PLAYER_IDS: Array[String] = ["saffron", "bonko", "paisley", "volt"]
const ENEMY_IDS: Array[String] = ["brute", "korath", "mortem", "luna"]

var _main: Control = null
var _failures: Array[String] = []
var _captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle_seconds(0.55)
	_save_capture("01_title_brand_1280x720.png")
	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	if enter_button == null:
		_fail("title-page entry button missing")
	else:
		enter_button.emit_signal("pressed")
	await _settle_seconds(0.55)
	_save_capture("02_main_menu_brand_1280x720.png")

	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	var title_page: Control = _main.get_node_or_null("TitlePage") as Control
	var combat_view: Control = _main.get_node_or_null("CombatView") as Control
	if title_menu != null:
		title_menu.visible = false
	if title_page != null:
		title_page.visible = false
	if combat_view == null:
		_fail("CombatView missing")
		_finish()
		return
	combat_view.visible = true
	combat_view.set_process(true)
	combat_view.call("set_player_team_ids", PLAYER_IDS)
	combat_view.call("_init_game")
	await _settle_frames(10)
	var manager: CombatManager = combat_view.get("manager") as CombatManager
	if manager == null:
		_fail("CombatManager missing")
		_finish()
		return
	var result: Dictionary[String, Variant] = manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, {
		"label": "Sprint3VisualCapture",
		"stage": 2,
		"seed": 319,
		"deterministic_rolls": true,
		"abilities_enabled": true,
	})
	if not bool(result.get("ok", false)):
		_fail("custom combat failed: %s" % String(result.get("reason", "unknown")))
		_finish()
		return
	_make_team_durable(manager.player_team)
	_make_team_durable(manager.enemy_team)
	await _settle_frames(10)
	var bridge: CombatVfxBridge = combat_view.find_child("CombatVfxBridge", true, false) as CombatVfxBridge
	if bridge == null:
		_fail("CombatVfxBridge missing")
	else:
		bridge.call("_on_heal_applied", "player", 0, "player", 0, 85, 0, 300, 385)
		bridge.call("_on_buff_applied", "player", 0, "player", 0, "shield", {}, 120.0, 6.0)
		bridge.call("_on_cc_applied", "player", 0, "enemy", 0, "stun", 1.5)
		bridge.call("_on_hit_applied", "player", 0, 0, 180, 180, true, 360, 180, 0.0, 0.0)
	await _settle_seconds(0.08)
	_save_capture("03a_combat_vfx_anticipation_1280x720.png")
	await _settle_seconds(0.16)
	_save_capture("03b_combat_vfx_impact_1280x720.png")
	await _settle_seconds(0.24)
	_save_capture("03c_combat_vfx_recovery_1280x720.png")

	var controller: Variant = combat_view.get("controller")
	if controller == null:
		_fail("CombatController missing")
	else:
		controller.call("_show_result_banner", "VICTORY", "Round secured. Preparing your next decision.", Color(0.58, 0.72, 0.38, 1.0), Color(0.86, 0.94, 0.74, 1.0))
	await _settle_seconds(0.34)
	_save_capture("04_victory_feedback_1280x720.png")

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Sprint3LossLayer"
	layer.layer = 300
	add_child(layer)
	var loss_screen: LossScreen = LOSS_SCENE.instantiate() as LossScreen
	layer.add_child(loss_screen)
	loss_screen.configure(_make_populated_tracker())
	await _settle_seconds(0.38)
	_save_capture("05_defeat_feedback_1280x720.png")
	_finish()

func _make_team_durable(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = max(unit.max_hp, 10000)
		unit.hp = unit.max_hp
		unit.attack_damage = min(unit.attack_damage, 25.0)
		unit.spell_power = min(unit.spell_power, 25.0)

func _make_populated_tracker() -> StatsTracker:
	var tracker_manager: CombatManager = CombatManager.new()
	add_child(tracker_manager)
	tracker_manager.player_team = manager_team_copy("player")
	tracker_manager.enemy_team = manager_team_copy("enemy")
	var tracker: StatsTracker = StatsTracker.new()
	add_child(tracker)
	tracker.configure(tracker_manager)
	var enemy_unit: Unit = tracker_manager.enemy_team[0] if not tracker_manager.enemy_team.is_empty() else null
	tracker._on_battle_started(1, enemy_unit)
	tracker._on_hit_applied("player", 0, 0, 438, 438, true, 1000, 562, 0.0, 0.0)
	tracker._on_hit_applied("player", 1, 0, 281, 281, false, 562, 281, 0.0, 0.0)
	tracker._on_battle_end(1)
	return tracker

func manager_team_copy(team: String) -> Array[Unit]:
	var combat_view: Control = _main.get_node_or_null("CombatView") as Control
	var manager: CombatManager = combat_view.get("manager") as CombatManager if combat_view != null else null
	if manager == null:
		return []
	return manager.player_team.duplicate() if team == "player" else manager.enemy_team.duplicate()

func _save_capture(filename: String) -> void:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_fail("viewport texture unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_fail("viewport image unavailable for %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_fail("failed to save %s error=%d" % [path, int(save_error)])
		return
	_captures += 1
	print("Sprint3VisualCapture: saved " + ProjectSettings.globalize_path(path))

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _settle_seconds(seconds: float) -> void:
	await _settle_frames(3)
	await get_tree().create_timer(seconds).timeout
	await _settle_frames(3)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("Sprint3VisualCapture: OK captures=%d output=%s" % [_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		exit_code = 1
		for failure: String in _failures:
			push_error("Sprint3VisualCapture: " + failure)
	get_tree().quit(exit_code)
