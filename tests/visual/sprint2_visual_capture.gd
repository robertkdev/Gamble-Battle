extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const ITEM_TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/items/ItemTooltip.tscn")
const TRAIT_TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/traits/TraitTooltip.tscn")
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const OUTPUT_DIR: String = "res://outputs/visual_iter/sprint2"
const CAPTURE_NAME: String = "Sprint2VisualCapture"

var _main: Control = null
var _failures: Array[String] = []
var _capture_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(8)
	_build_post_shop_state()
	await _settle_frames(16)
	_validate_planning_hierarchy()
	_save_capture("01_planning_shop_1280x720.png")
	await _capture_shop_tooltip()
	await _capture_item_tooltip()
	await _capture_trait_tooltip()
	await _finish()

func _build_post_shop_state() -> void:
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
	_expect(bool(reroll_result.get("ok", false)), "post-shop reroll failed")
	var manager: Variant = combat.get("manager")
	if manager != null:
		manager.set("stage", 2)
		manager.call("setup_stage_preview")
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

func _validate_planning_hierarchy() -> void:
	var combat: Control = _combat()
	if combat == null:
		return
	var bottom_storage: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	_expect_inside_viewport(bottom_storage, "bottom shop area")
	var continue_button: Button = combat.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null, "Start Battle button missing")
	if continue_button != null:
		_expect(continue_button.size.x >= 170.0, "Start Battle is not visually primary: width=%.1f" % continue_button.size.x)
		_expect(continue_button.get_theme_font_size("font_size") >= 17, "Start Battle label is too small")
	var shop_grid: Control = combat.find_child("ShopGrid", true, false) as Control
	if shop_grid != null:
		for child: Node in shop_grid.get_children():
			var card: Control = child as Control
			if card == null or bool(card.get_meta("opening_fight_placeholder", false)):
				continue
			_expect_inside_viewport(card, "shop card")
			var name_label: Label = card.get_node_or_null("Name") as Label
			var price_label: Label = card.get_node_or_null("Price") as Label
			if name_label != null and price_label != null:
				_expect(name_label.get_global_rect().end.x <= price_label.get_global_rect().position.x + 1.0, "shop name and price overlap")
	var tier_expectations: Dictionary[String, int] = {
		"GothicBattlePlate": 1,
		"GothicShopPlate": 2,
		"GothicItemsPlate": 3,
		"GothicTraitsPlate": 3,
	}
	for plate_name: String in tier_expectations.keys():
		var plate: Control = combat.find_child(plate_name, true, false) as Control
		_expect(plate != null, "%s missing" % plate_name)
		if plate != null:
			_expect(int(plate.get_meta("surface_tier", 0)) == tier_expectations[plate_name], "%s has wrong surface tier" % plate_name)

func _capture_shop_tooltip() -> void:
	var combat: Control = _combat()
	var card: Control = combat.find_child("ShopCard", true, false) as Control if combat != null else null
	_expect(card != null, "shop card missing for tooltip capture")
	if card == null:
		return
	Input.warp_mouse(card.get_global_rect().get_center())
	card.call("_on_hover_entered")
	await _settle_frames(6)
	var tooltip: Control = card.get("_tooltip") as Control
	_expect(tooltip != null, "shop tooltip did not open")
	_expect_inside_viewport(tooltip, "shop tooltip")
	_expect(_has_label_text(tooltip, "TEAM FIT"), "shop tooltip lacks TEAM FIT section")
	_expect(_has_label_text(tooltip, "COMBAT PROFILE"), "shop tooltip lacks COMBAT PROFILE section")
	_save_capture("02_shop_tooltip_1280x720.png")
	card.call("_on_hover_exited")
	await _settle_frames(3)

func _capture_item_tooltip() -> void:
	var tooltip: Control = ITEM_TOOLTIP_SCENE.instantiate() as Control
	tooltip.name = "Sprint2ItemTooltip"
	get_tree().root.add_child(tooltip)
	tooltip.call("set_item_id", "windwall")
	tooltip.call("show_at", Vector2(80.0, 180.0))
	await _settle_frames(6)
	_expect_inside_viewport(tooltip, "item tooltip")
	_expect(_has_label_prefix(tooltip, "STAT CHANGES"), "item tooltip lacks stat section")
	_expect(_has_label_prefix(tooltip, "HOW TO USE"), "item tooltip lacks use section")
	_save_capture("03_item_tooltip_1280x720.png")
	tooltip.queue_free()
	await _settle_frames(3)

func _capture_trait_tooltip() -> void:
	var tooltip: Control = TRAIT_TOOLTIP_SCENE.instantiate() as Control
	tooltip.name = "Sprint2TraitTooltip"
	get_tree().root.add_child(tooltip)
	tooltip.call("set_trait", "Chronomancer")
	tooltip.call("set_context", true, 2, 0)
	tooltip.call("show_at", Vector2(80.0, 340.0))
	await _settle_frames(6)
	_expect_inside_viewport(tooltip, "trait tooltip")
	_expect(_has_label_prefix(tooltip, "EFFECT"), "trait tooltip lacks effect section")
	_expect(_has_label_prefix(tooltip, "ACTIVE BONUS"), "trait tooltip lacks active bonus section")
	_save_capture("04_trait_tooltip_1280x720.png")
	tooltip.queue_free()
	await _settle_frames(3)

func _combat() -> Control:
	return _main.get_node_or_null("CombatView") as Control if _main != null else null

func _has_label_text(root: Node, expected: String) -> bool:
	if root == null:
		return false
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.text == expected:
			return true
	return false

func _has_label_prefix(root: Node, expected: String) -> bool:
	if root == null:
		return false
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and label.text.begins_with(expected):
			return true
	return false

func _expect_inside_viewport(control: Control, label: String) -> void:
	_expect(control != null, "%s missing" % label)
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	_expect(rect.position.x >= viewport_rect.position.x - 1.0, "%s left edge out of bounds: %s" % [label, str(rect)])
	_expect(rect.position.y >= viewport_rect.position.y - 1.0, "%s top edge out of bounds: %s" % [label, str(rect)])
	_expect(rect.end.x <= viewport_rect.end.x + 1.0, "%s right edge out of bounds: %s" % [label, str(rect)])
	_expect(rect.end.y <= viewport_rect.end.y + 1.0, "%s bottom edge out of bounds: %s" % [label, str(rect)])

func _save_capture(filename: String) -> void:
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("framebuffer unavailable for %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_failures.append("failed to save %s error=%d" % [path, int(error)])
		return
	_capture_count += 1
	print("%s: saved %s" % [CAPTURE_NAME, ProjectSettings.globalize_path(path)])

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d" % [CAPTURE_NAME, _capture_count])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [CAPTURE_NAME, failure])
		exit_code = 1
	if _main != null and is_instance_valid(_main):
		var combat: Node = _main.get_node_or_null("CombatView")
		if combat != null and combat.has_method("_teardown"):
			combat.call("_teardown")
		_main.queue_free()
	await _settle_frames(4)
	get_tree().quit(exit_code)
