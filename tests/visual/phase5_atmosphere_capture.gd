extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/phase5_atmosphere_pass"
const DESKTOP_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_SIZE: Vector2i = Vector2i(1280, 720)
const PLAYER_IDS: Array[String] = ["axiom", "berebell", "bo", "bonko", "brute", "cashmere"]
const ENEMY_IDS: Array[String] = ["korath", "brute", "berebell", "mortem", "sari", "luna"]

var _captures: Array[Dictionary] = []
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_configure_viewport(DESKTOP_SIZE)
	var view: Control = await _create_view()
	if view == null:
		_finish()
		return
	await _save_capture("00_planning_authored_light.png", "planning", "planning", "desktop-1920x1080", DESKTOP_SIZE)
	var started: bool = await _start_durable_battle(view)
	if not started:
		view.queue_free()
		_finish()
		return
	# Boss phases occur after sustained combat; let the authored combat grade
	# fully converge so the pulse filmstrip measures escalation, not arena entry.
	await _settle(0.80)
	await _save_capture("01_combat_authored_light.png", "combat", "combat_open", "desktop-1920x1080", DESKTOP_SIZE)
	var controller: Variant = view.get("controller")
	var arena_atmosphere: Variant = controller.get("_arena_atmosphere") if controller != null else null
	# The trigger instant uses the settled combat grade; subsequent frames show
	# the authored rise rather than capture latency masquerading as onset.
	await _save_capture("02a_boss_escalation_t000.png", "escalation", "boss_escalation", "desktop-1920x1080", DESKTOP_SIZE)
	if arena_atmosphere != null:
		arena_atmosphere.call("pulse_escalation", 3)
	await _wait_visual(0.06)
	await _save_capture("02b_boss_escalation_t120.png", "escalation", "boss_escalation", "desktop-1920x1080", DESKTOP_SIZE)
	await _wait_visual(0.38)
	await _save_capture("02c_boss_escalation_t520.png", "escalation", "boss_escalation", "desktop-1920x1080", DESKTOP_SIZE)
	if controller != null:
		controller.call("_on_victory", 4)
	await _settle(0.16)
	await _save_capture("03_victory_color_consequence.png", "victory", "victory", "desktop-1920x1080", DESKTOP_SIZE)
	view.queue_free()
	await _settle(0.16)

	var defeat_view: Control = await _create_view()
	var defeat_started: bool = false
	if defeat_view != null:
		defeat_started = await _start_durable_battle(defeat_view)
	if defeat_started:
		var defeat_controller: Variant = defeat_view.get("controller")
		if defeat_controller != null:
			defeat_controller.call("_on_defeat", 4)
		await _settle(0.16)
		await _save_capture("04_defeat_color_consequence.png", "defeat", "defeat", "desktop-1920x1080", DESKTOP_SIZE)
		defeat_view.queue_free()
		await _settle(0.16)

	_configure_viewport(COMPACT_SIZE)
	var compact_view: Control = await _create_view()
	if compact_view != null:
		await _prepare_planning_state(compact_view)
		await _save_capture("05_compact_planning_authored_light.png", "planning", "planning", "compact-1280x720", COMPACT_SIZE)
	var compact_started: bool = false
	if compact_view != null:
		compact_started = await _start_durable_battle(compact_view)
	if compact_started:
		await _settle(0.80)
		await _save_capture("06_compact_combat_authored_light.png", "combat", "combat_open", "compact-1280x720", COMPACT_SIZE)
		var compact_controller: Variant = compact_view.get("controller")
		var compact_atmosphere: Variant = compact_controller.get("_arena_atmosphere") if compact_controller != null else null
		await _save_capture("07a_compact_boss_escalation_t000.png", "escalation", "boss_escalation", "compact-1280x720", COMPACT_SIZE)
		if compact_atmosphere != null:
			compact_atmosphere.call("pulse_escalation", 3)
		await _wait_visual(0.06)
		await _save_capture("07b_compact_boss_escalation_t120.png", "escalation", "boss_escalation", "compact-1280x720", COMPACT_SIZE)
		await _wait_visual(0.38)
		await _save_capture("07c_compact_boss_escalation_t520.png", "escalation", "boss_escalation", "compact-1280x720", COMPACT_SIZE)
		if compact_controller != null:
			compact_controller.call("_on_victory", 4)
		await _settle(0.16)
		await _save_capture("08_compact_victory_color_consequence.png", "victory", "victory", "compact-1280x720", COMPACT_SIZE)
		compact_view.queue_free()
		await _settle(0.10)
	var compact_defeat_view: Control = await _create_view()
	var compact_defeat_started: bool = false
	if compact_defeat_view != null:
		compact_defeat_started = await _start_durable_battle(compact_defeat_view)
	if compact_defeat_started:
		var compact_defeat_controller: Variant = compact_defeat_view.get("controller")
		if compact_defeat_controller != null:
			compact_defeat_controller.call("_on_defeat", 4)
		await _settle(0.16)
		await _save_capture("09_compact_defeat_color_consequence.png", "defeat", "defeat", "compact-1280x720", COMPACT_SIZE)
		compact_defeat_view.queue_free()
		await _settle(0.10)
	_write_manifest()
	_finish()

func _prepare_planning_state(view: Control) -> void:
	if Engine.has_singleton("GameState") or view.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.PREVIEW)
	var controller: Variant = view.get("controller")
	if controller != null:
		controller.call("_sync_bottom_combat_visibility", true)
	await _settle(0.28)

func _create_view() -> Control:
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	if view == null:
		_fail("CombatView instantiate failed")
		return null
	add_child(view)
	await _settle(0.28)
	return view

func _start_durable_battle(view: Control) -> bool:
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager == null:
		_fail("CombatManager missing")
		return false
	var result: Dictionary[String, Variant] = manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, {
		"label": "Phase 5 atmosphere capture",
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

func _configure_viewport(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	var window: Window = get_window()
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size

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
	_captures.append({
		"file": filename,
		"state": state,
		"event": event_name,
		"viewport": viewport_label,
		"actual_size": "%dx%d" % [actual_size.x, actual_size.y],
	})
	print("Phase5AtmosphereCapture: saved %s" % ProjectSettings.globalize_path(path))

func _write_manifest() -> void:
	var path: String = "%s/runtime_manifest.json" % OUTPUT_DIR
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("runtime manifest could not be opened")
		return
	var payload: Dictionary[String, Variant] = {
		"runtime": "Godot 4.5 player-facing framebuffer",
		"scene": "res://tests/visual/Phase5AtmosphereCapture.tscn",
		"build": "codex/019f80d9-676-task",
		"captures": _captures,
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

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

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty() and _captures.size() == 14:
		print("Phase5AtmosphereCapture: OK captures=%d output=%s" % [_captures.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
		get_tree().quit(0)
		return
	if _captures.size() != 14:
		_fail("expected 14 captures, got %d" % _captures.size())
	for failure: String in _failures:
		push_error("Phase5AtmosphereCapture: " + failure)
	get_tree().quit(1)
