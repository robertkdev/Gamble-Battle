extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const OUTPUT_DIR: String = "res://outputs/visual_iter/sprint1"
const PLAYER_IDS: Array[String] = ["saffron", "bonko", "paisley", "volt"]
const ENEMY_IDS: Array[String] = ["brute", "korath", "mortem", "luna"]

var _view: Control = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	await _settle_frames(8)
	_view.call("set_player_team_ids", PLAYER_IDS)
	_view.call("_init_game")
	await _settle_frames(10)
	_log_opening_placeholder_rect()
	_save_capture("01_compact_planning_1280x720.png")
	print("Sprint1VisualCapture: planning ready")
	await get_tree().create_timer(5.0).timeout
	var manager: CombatManager = _view.get("manager") as CombatManager
	var result: Dictionary[String, Variant] = manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, {
		"label": "Sprint 1 visual capture",
		"stage": 1,
		"seed": 91,
		"deterministic_rolls": true,
		"abilities_enabled": true,
	})
	if not bool(result.get("ok", false)):
		push_error("Sprint1VisualCapture: custom battle failed reason=%s" % String(result.get("reason", "unknown")))
		return
	_make_team_durable(manager.player_team)
	_make_team_durable(manager.enemy_team)
	await _settle_frames(12)
	var bridge: CombatVfxBridge = _view.find_child("CombatVfxBridge", true, false) as CombatVfxBridge
	if bridge != null:
		bridge.call("_on_arena_pressure_changed", 0.72, 2)
	var controller: Variant = _view.get("controller")
	var arena_bridge: ArenaBridge = null
	if controller != null:
		arena_bridge = controller.get("arena_bridge") as ArenaBridge
	if arena_bridge != null:
		var selected_actor: UnitActor = arena_bridge.get_player_actor(0)
		var target_actor: UnitActor = arena_bridge.get_enemy_actor(0)
		if selected_actor != null:
			selected_actor.set_selected(true)
		if target_actor != null:
			target_actor.set_targeted_count(2)
	await _settle_frames(3)
	_save_capture("02_compact_combat_1280x720.png")
	print("Sprint1VisualCapture: combat ready")

func _make_team_durable(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = max(unit.max_hp, 10000)
		unit.hp = unit.max_hp
		unit.attack_damage = min(unit.attack_damage, 25.0)
		unit.spell_power = min(unit.spell_power, 25.0)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Sprint1VisualCapture: framebuffer unavailable for %s" % filename)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Sprint1VisualCapture: failed to save %s error=%d" % [path, int(error)])
		return
	print("Sprint1VisualCapture: saved %s" % ProjectSettings.globalize_path(path))

func _log_opening_placeholder_rect() -> void:
	for node: Node in _view.find_children("*", "PanelContainer", true, false):
		var panel: PanelContainer = node as PanelContainer
		if panel != null and bool(panel.get_meta("opening_fight_placeholder", false)):
			var panel_rect: Rect2 = panel.get_global_rect()
			var viewport_rect: Rect2 = get_viewport().get_visible_rect()
			print("Sprint1VisualCapture: opening rect=%s viewport=%s" % [str(panel_rect), str(viewport_rect)])
			if panel_rect.end.y > viewport_rect.end.y + 0.5:
				push_error("Sprint1VisualCapture: opening panel extends below viewport")
			return
