extends Node

const CAPTURE_NAME: String = "Sprint4VisualAcceptanceCapture"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const ITEM_TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/items/ItemTooltip.tscn")
const TRAIT_TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/traits/TraitTooltip.tscn")
const LOSS_SCENE: PackedScene = preload("res://scenes/ui/LossScreen.tscn")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/sprint4"
const VIEWPORTS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const PLAYER_IDS: Array[String] = ["saffron", "bonko", "paisley", "volt", "axiom", "grint"]
const ENEMY_IDS: Array[String] = ["bastionne", "korath", "mortem", "luna", "brute", "morrak"]

var _main: Control = null
var _unit_select: UnitSelect = null
var _failures: Array[String] = []
var _temporary_nodes: Array[Node] = []
var _captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for viewport: Vector2i in VIEWPORTS:
		await _capture_viewport(viewport)
	await _cleanup_runtime()
	_finish()

func _capture_viewport(viewport: Vector2i) -> void:
	_configure_viewport(viewport)
	var suffix: String = "%dx%d" % [viewport.x, viewport.y]
	await _capture_title_menu_states(suffix)
	await _capture_character_states(suffix)
	await _capture_run_states(suffix)

func _configure_viewport(viewport: Vector2i) -> void:
	DisplayServer.window_set_size(viewport)
	var window: Window = get_window()
	if window != null:
		window.size = viewport
		window.content_scale_size = viewport

func _capture_title_menu_states(suffix: String) -> void:
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_seconds(0.48)
	_save_capture("01_title_%s.png" % suffix)
	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	_expect(enter_button != null, "title entry button missing at %s" % suffix)
	if enter_button != null:
		enter_button.emit_signal("pressed")
	await _settle_seconds(0.52)
	_save_capture("02_main_menu_%s.png" % suffix)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	_expect(title_menu != null, "title menu missing at %s" % suffix)
	if title_menu != null:
		title_menu.call("_select_section", "settings")
	await _settle_frames(8)
	_save_capture("03_settings_%s.png" % suffix)
	if title_menu != null:
		title_menu.call("_select_section", "units")
		var search: LineEdit = title_menu.find_child("SearchField", true, false) as LineEdit
		if search != null:
			search.text = "saffron"
			title_menu.call("_render_active_section")
	await _settle_frames(8)
	_save_capture("04_vertical_roster_portrait_%s.png" % suffix)
	await _free_main()

func _capture_character_states(suffix: String) -> void:
	_unit_select = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	_unit_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_unit_select)
	await _settle_frames(10)
	var button: Button = _first_unit_button()
	_expect(button != null, "unit-select button missing at %s" % suffix)
	if button != null:
		button.emit_signal("mouse_entered")
	await _settle_frames(8)
	_save_capture("05_character_hover_%s.png" % suffix)
	if button != null:
		button.button_pressed = true
		button.emit_signal("pressed")
	await _settle_frames(8)
	_save_capture("06_character_selected_%s.png" % suffix)
	if _unit_select != null and is_instance_valid(_unit_select):
		_unit_select.queue_free()
	_unit_select = null
	await _settle_frames(5)

func _capture_run_states(suffix: String) -> void:
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(10)
	_build_planning_state()
	await _settle_frames(16)
	_save_capture("07_planning_%s.png" % suffix)
	await _capture_shop_tooltip("08_shop_tooltip_%s.png" % suffix)
	await _capture_item_tooltip("09_item_tooltip_%s.png" % suffix)
	await _capture_trait_tooltip("10_trait_tooltip_%s.png" % suffix)
	_main.call("_open_system_menu")
	await _settle_frames(6)
	_save_capture("11_system_menu_%s.png" % suffix)
	_main.call("_close_system_menu")
	await _settle_frames(4)
	await _capture_dense_combat(suffix)
	await _capture_outcomes(suffix)
	await _free_main()

func _build_planning_state() -> void:
	for path: String in ["TitlePage", "TitleMenu", "UnitSelect"]:
		var page: Control = _main.get_node_or_null(path) as Control
		if page != null:
			page.visible = false
	var combat: Control = _combat()
	_expect(combat != null, "CombatView missing")
	if combat == null:
		return
	combat.visible = true
	combat.set_process(true)
	combat.call("set_player_team_ids", ["bonko", "berebell"])
	combat.call("_init_game")
	GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Economy.reset_run()
	Economy.add_gold(6)
	Economy.set_bet(1)
	Shop.reset_run()
	Shop.set_opening_starter_id("bonko")
	Shop.add_free_rerolls(1)
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "planning shop reroll failed")
	var manager: CombatManager = combat.get("manager") as CombatManager
	if manager != null:
		manager.stage = 2
		manager.setup_stage_preview()
	var controller: Variant = combat.get("controller")
	if controller != null:
		controller.call("refresh_all_views")
		controller.call("_set_continue_to_start_text")
		controller.call("_sync_bottom_combat_visibility", true)
		var economy_ui: Variant = controller.get("economy_ui")
		if economy_ui != null:
			economy_ui.call("refresh")
	combat.set("planning_timer_total", 120.0)
	combat.set("planning_time_left", 120.0)

func _capture_shop_tooltip(filename: String) -> void:
	var combat: Control = _combat()
	var card: Control = combat.find_child("ShopCard*", true, false) as Control if combat != null else null
	var injected: bool = false
	if card == null:
		card = SHOP_CARD_SCENE.instantiate() as Control
		get_tree().root.add_child(card)
		card.position = Vector2(get_viewport().get_visible_rect().size.x * 0.42, get_viewport().get_visible_rect().size.y - 160.0)
		card.call("set_data", {
			"id": "saffron",
			"name": "Saffron",
			"price": 4,
			"sprite_path": "res://assets/units/saffron.png",
			"primary_role": "support",
			"primary_goal": "protect allies",
			"approaches": ["sustain", "peel"],
			"traits": ["Blessed", "Scholar"],
		})
		injected = true
	_expect(card != null, "shop card missing for tooltip")
	if card == null:
		return
	Input.warp_mouse(card.get_global_rect().get_center())
	card.call("_on_hover_entered")
	await _settle_frames(7)
	_save_capture(filename)
	card.call("_on_hover_exited")
	if injected:
		card.queue_free()
	await _settle_frames(3)

func _capture_item_tooltip(filename: String) -> void:
	var tooltip: Control = ITEM_TOOLTIP_SCENE.instantiate() as Control
	get_tree().root.add_child(tooltip)
	tooltip.call("set_item_id", "windwall")
	tooltip.call("show_at", Vector2(80.0, 180.0))
	await _settle_frames(6)
	_save_capture(filename)
	tooltip.queue_free()
	await _settle_frames(3)

func _capture_trait_tooltip(filename: String) -> void:
	var tooltip: Control = TRAIT_TOOLTIP_SCENE.instantiate() as Control
	get_tree().root.add_child(tooltip)
	tooltip.call("set_trait", "Chronomancer")
	tooltip.call("set_context", true, 2, 0)
	tooltip.call("show_at", Vector2(80.0, 340.0))
	await _settle_frames(6)
	_save_capture(filename)
	tooltip.queue_free()
	await _settle_frames(3)

func _capture_dense_combat(suffix: String) -> void:
	var combat: Control = _combat()
	if combat == null:
		return
	var manager: CombatManager = combat.get("manager") as CombatManager
	_expect(manager != null, "CombatManager missing")
	if manager == null:
		return
	var result: Dictionary[String, Variant] = manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, {
		"label": "Sprint4VisualAcceptanceCapture",
		"stage": 4,
		"seed": 407,
		"deterministic_rolls": true,
		"abilities_enabled": true,
	})
	_expect(bool(result.get("ok", false)), "dense combat failed: %s" % String(result.get("reason", "unknown")))
	if not bool(result.get("ok", false)):
		return
	_make_team_durable(manager.player_team)
	_make_team_durable(manager.enemy_team)
	await _settle_frames(10)
	var bridge: CombatVfxBridge = combat.find_child("CombatVfxBridge", true, false) as CombatVfxBridge
	_expect(bridge != null, "CombatVfxBridge missing")
	if bridge != null:
		bridge.call("_on_heal_applied", "player", 0, "player", 0, 85, 0, 300, 385)
		bridge.call("_on_buff_applied", "player", 1, "player", 1, "shield", {}, 120.0, 6.0)
		bridge.call("_on_cc_applied", "player", 2, "enemy", 1, "stun", 1.5)
		bridge.call("_on_hit_applied", "player", 0, 0, 180, 180, true, 360, 180, 0.0, 0.0)
		bridge.call("_on_hit_applied", "enemy", 2, 3, 92, 92, false, 340, 248, 0.0, 0.0)
	await _settle_seconds(0.06)
	_save_capture("12a_dense_combat_anticipation_%s.png" % suffix)
	await _settle_seconds(0.10)
	_save_capture("12b_dense_combat_impact_%s.png" % suffix)
	await _settle_seconds(0.12)
	_save_capture("12c_dense_combat_peak_%s.png" % suffix)
	await _settle_seconds(0.18)
	_save_capture("12d_dense_combat_recovery_%s.png" % suffix)

func _capture_outcomes(suffix: String) -> void:
	var combat: Control = _combat()
	var controller: Variant = combat.get("controller") if combat != null else null
	if controller != null:
		controller.call("_show_result_banner", "VICTORY", "Round secured. Preparing your next decision.", Color(0.58, 0.72, 0.38, 1.0), Color(0.86, 0.94, 0.74, 1.0))
	await _settle_seconds(0.30)
	_save_capture("13_victory_%s.png" % suffix)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 300
	add_child(layer)
	_temporary_nodes.append(layer)
	var loss_screen: LossScreen = LOSS_SCENE.instantiate() as LossScreen
	layer.add_child(loss_screen)
	loss_screen.configure(_make_populated_tracker())
	await _settle_seconds(0.34)
	_save_capture("14_defeat_%s.png" % suffix)
	layer.queue_free()
	_temporary_nodes.erase(layer)
	await _settle_frames(4)

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
	_temporary_nodes.append(tracker_manager)
	tracker_manager.player_team = _manager_team_copy("player")
	tracker_manager.enemy_team = _manager_team_copy("enemy")
	var tracker: StatsTracker = StatsTracker.new()
	add_child(tracker)
	_temporary_nodes.append(tracker)
	tracker.configure(tracker_manager)
	var enemy_unit: Unit = tracker_manager.enemy_team[0] if not tracker_manager.enemy_team.is_empty() else null
	tracker._on_battle_started(1, enemy_unit)
	tracker._on_hit_applied("player", 0, 0, 438, 438, true, 1000, 562, 0.0, 0.0)
	tracker._on_hit_applied("player", 1, 0, 281, 281, false, 562, 281, 0.0, 0.0)
	tracker._on_battle_end(1)
	return tracker

func _manager_team_copy(team: String) -> Array[Unit]:
	var combat: Control = _combat()
	var manager: CombatManager = combat.get("manager") as CombatManager if combat != null else null
	if manager == null:
		return []
	return manager.player_team.duplicate() if team == "player" else manager.enemy_team.duplicate()

func _first_unit_button() -> Button:
	if _unit_select == null:
		return null
	return _unit_select.find_child("UnitButton_*", true, false) as Button

func _combat() -> Control:
	return _main.get_node_or_null("CombatView") as Control if _main != null else null

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
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("failed to save %s error=%d" % [path, int(error)])
		return
	_captures += 1
	print("%s: saved %s" % [CAPTURE_NAME, ProjectSettings.globalize_path(path)])

func _free_main() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	var combat: Node = _main.get_node_or_null("CombatView")
	if combat != null and combat.has_method("_teardown"):
		combat.call("_teardown")
	_main.queue_free()
	_main = null
	await _cleanup_temporary_nodes()
	await _settle_frames(6)

func _cleanup_temporary_nodes() -> void:
	for node: Node in _temporary_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_temporary_nodes.clear()
	await _settle_frames(3)

func _cleanup_runtime() -> void:
	await _cleanup_temporary_nodes()
	if _unit_select != null and is_instance_valid(_unit_select):
		_unit_select.queue_free()
	_unit_select = null
	await _free_main()

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _settle_seconds(seconds: float) -> void:
	await _settle_frames(3)
	await get_tree().create_timer(seconds).timeout
	await _settle_frames(3)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [CAPTURE_NAME, _captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("%s: %s" % [CAPTURE_NAME, failure])
	get_tree().quit(1)
