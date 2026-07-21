extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/attack_visuals_pass"
const DESKTOP_VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_VIEWPORT_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1366, 768)]
const ENEMY_IDS: Array[String] = ["korath", "brute", "berebell", "mortem", "sari", "luna"]
const GROUPS: Array[Dictionary] = [
	{
		"name": "opening_frontline",
		"units": ["axiom", "berebell", "bo", "bonko", "brute", "cashmere"],
		"source_index": 1,
	},
	{
		"name": "engage_arcane",
		"units": ["grint", "hexeon", "korath", "kythera", "luna", "morrak"],
		"source_index": 3,
	},
	{
		"name": "blood_precision",
		"units": ["mortem", "nyxa", "paisley", "repo", "sari", "teller"],
		"source_index": 1,
	},
	{
		"name": "support_voltage",
		"units": ["totem", "veyra", "volt", "vykos"],
		"source_index": 1,
	},
]

var _captures_saved: int = 0
var _capture_skipped: bool = false
var _capture_contract_failed: bool = false
var _manifest_events: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_configure_viewport(DESKTOP_VIEWPORT_SIZE)
	for group: Dictionary in GROUPS:
		var ok: bool = await _run_group(group, "", DESKTOP_VIEWPORT_SIZE)
		if not ok:
			get_tree().quit(1)
			return
	var compact_group: Dictionary = GROUPS[1]
	for viewport_size: Vector2i in COMPACT_VIEWPORT_SIZES:
		_configure_viewport(viewport_size)
		var size_suffix: String = "_%dx%d" % [viewport_size.x, viewport_size.y]
		var compact_ok: bool = await _run_group(compact_group, size_suffix, viewport_size)
		if not compact_ok:
			get_tree().quit(1)
			return
	if _captures_saved <= 0 and not _capture_skipped:
		push_error("AttackVisualSignatureCapture: no screenshots were saved")
		get_tree().quit(1)
		return
	_write_temporal_manifest()
	if _capture_contract_failed:
		get_tree().quit(1)
		return
	print("AttackVisualSignatureCapture: OK groups=%d compact_sizes=%d captures=%d output=%s" % [GROUPS.size(), COMPACT_VIEWPORT_SIZES.size(), _captures_saved, ProjectSettings.globalize_path(OUTPUT_DIR)])
	get_tree().quit(0)

func _run_group(group: Dictionary, filename_suffix: String, expected_viewport: Vector2i) -> bool:
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	if view == null:
		push_error("AttackVisualSignatureCapture: CombatView instantiate failed")
		return false
	add_child(view)
	await _settle(0.20)
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager == null:
		push_error("AttackVisualSignatureCapture: manager missing")
		view.queue_free()
		return false
	var units: Array[String] = _string_array(group.get("units", []))
	var label: String = String(group.get("name", "attack_visuals"))
	var result: Dictionary[String, Variant] = manager.start_custom_battle(units, ENEMY_IDS, {
		"label": "Attack visuals " + label,
		"stage": 1,
	})
	if not bool(result.get("ok", false)):
		push_error("AttackVisualSignatureCapture: custom battle failed %s reason=%s" % [label, String(result.get("reason", ""))])
		view.queue_free()
		return false
	_make_team_durable(manager.player_team)
	_make_team_durable(manager.enemy_team)
	await _settle(0.12)
	var source_index: int = clampi(int(group.get("source_index", 1)), 0, manager.player_team.size() - 1)
	var target_index: int = mini(1, manager.enemy_team.size() - 1)
	var controller: Variant = view.get("controller")
	var bridge: Variant = controller.get("projectile_bridge") if controller != null else null
	var projectile_manager: ProjectileManager = bridge.get("projectile_manager") as ProjectileManager if bridge != null else null
	if projectile_manager == null:
		push_error("AttackVisualSignatureCapture: projectile manager missing for %s" % label)
		view.queue_free()
		return false
	var arrival_state: Dictionary[String, Variant] = {"arrived": false}
	projectile_manager.projectile_visual_arrived.connect(func(_team: String, _source: int, _target: int, _crit: bool, _style: Dictionary) -> void:
		arrival_state["arrived"] = true
	, CONNECT_ONE_SHOT)
	var capture_started_ms: int = Time.get_ticks_msec()
	manager.emit_signal("projectile_fired", "player", source_index, target_index, 1, false)
	await _settle(0.04)
	_save_capture("%s%s_01_anticipation_t040.png" % [label, filename_suffix], label, "anticipation", Time.get_ticks_msec() - capture_started_ms, expected_viewport)
	await _settle(0.08)
	_save_capture("%s%s_02_release_t120.png" % [label, filename_suffix], label, "release", Time.get_ticks_msec() - capture_started_ms, expected_viewport)
	var arrival_deadline_ms: int = Time.get_ticks_msec() + 1600
	while not bool(arrival_state.get("arrived", false)) and Time.get_ticks_msec() < arrival_deadline_ms:
		await get_tree().process_frame
	if not bool(arrival_state.get("arrived", false)):
		push_error("AttackVisualSignatureCapture: projectile arrival timeout for %s" % label)
		view.queue_free()
		return false
	if not _is_framebuffer_unavailable():
		await RenderingServer.frame_post_draw
	_save_capture("%s%s_03_impact_arrival.png" % [label, filename_suffix], label, "impact", Time.get_ticks_msec() - capture_started_ms, expected_viewport)
	await _settle(0.28)
	_save_capture("%s%s_04_recovery.png" % [label, filename_suffix], label, "recovery", Time.get_ticks_msec() - capture_started_ms, expected_viewport)
	view.queue_free()
	await _settle(0.12)
	return true

func _configure_viewport(viewport_size: Vector2i) -> void:
	DisplayServer.window_set_size(viewport_size)
	var window: Window = get_window()
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size

func _make_team_durable(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = max(unit.max_hp, 5000)
		unit.hp = unit.max_hp
		unit.attack_damage = min(unit.attack_damage, 45.0)
		unit.spell_power = min(unit.spell_power, 45.0)

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in (value as Array):
			result.append(String(entry))
	return result

func _save_capture(filename: String, group_label: String, event_name: String, offset_ms: int, expected_viewport: Vector2i) -> void:
	if _is_framebuffer_unavailable():
		_capture_skipped = true
		print("AttackVisualSignatureCapture: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_warning("AttackVisualSignatureCapture: skipped %s; viewport texture unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("AttackVisualSignatureCapture: skipped %s; viewport image unavailable" % filename)
		return
	var actual_viewport: Vector2i = Vector2i(image.get_width(), image.get_height())
	if actual_viewport != expected_viewport:
		_capture_contract_failed = true
		push_error("AttackVisualSignatureCapture: %s viewport=%s expected=%s" % [filename, str(actual_viewport), str(expected_viewport)])
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("AttackVisualSignatureCapture: failed to save %s error=%s" % [ProjectSettings.globalize_path(path), str(int(err))])
		return
	_captures_saved += 1
	_manifest_events.append({
		"group": group_label,
		"event": event_name,
		"offset_ms": offset_ms,
		"file": filename,
		"requested_viewport": "%dx%d" % [expected_viewport.x, expected_viewport.y],
		"viewport": "%dx%d" % [actual_viewport.x, actual_viewport.y],
	})
	print("AttackVisualSignatureCapture: saved %s" % ProjectSettings.globalize_path(path))

func _write_temporal_manifest() -> void:
	var path: String = "%s/temporal_manifest.json" % OUTPUT_DIR
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("AttackVisualSignatureCapture: failed to open temporal manifest")
		return
	var manifest: Dictionary[String, Variant] = {
		"runtime": "Godot player-facing framebuffer",
		"scene": "res://tests/visual/AttackVisualSignatureCapture.tscn",
		"capture_contract": "event-synchronized anticipation / release / projectile arrival impact / recovery",
		"events": _manifest_events,
	}
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("AttackVisualSignatureCapture: manifest %s" % ProjectSettings.globalize_path(path))

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame
