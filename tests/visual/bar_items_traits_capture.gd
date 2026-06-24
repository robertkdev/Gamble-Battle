extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/bar_items_traits_pass"

var _main: Control = null
var _view: Control = null
var _planning_visible_bars: int = 0
var _combat_visible_bars: int = 0
var _filled_item_cards: int = 0
var _visible_trait_icons: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle(0.25)
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle(0.20)
	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	await _settle(0.30)
	_view = _main.get_node_or_null("CombatView") as Control
	if _view == null:
		push_error("BarItemsTraitsCapture: CombatView missing")
		get_tree().quit(1)
		return
	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", ["mortem", "berebell"])
	if _view.has_method("_init_game"):
		_view.call("_init_game")
	await _settle(0.45)
	_force_item_and_trait_state()
	await _settle(0.35)

	_filled_item_cards = _count_filled_item_cards()
	_visible_trait_icons = _count_visible_trait_icons()
	_planning_visible_bars = _visible_progressbars(_player_grid()) + _visible_progressbars(_enemy_grid())
	_save_capture("01_planning_grid_bars_hidden_items_traits.png")
	_show_item_tooltip()
	_show_trait_tooltip()
	await _settle(0.35)
	_save_capture("02_trait_tooltip_and_item_cards.png")
	_clear_tooltips()
	var hover_mechanics_ok: bool = await _exercise_hover_mechanics()
	if not hover_mechanics_ok:
		push_error("BarItemsTraitsCapture: item/trait hover mechanics did not show and clear tooltips")
		get_tree().quit(1)
		return
	var edge_cases_ok: bool = await _exercise_tooltip_edge_cases()
	if not edge_cases_ok:
		push_error("BarItemsTraitsCapture: item/trait tooltip edge cases failed")
		get_tree().quit(1)
		return

	if _view.has_method("_on_continue_pressed"):
		_view.call("_on_continue_pressed")
	await _settle(0.28)
	_combat_visible_bars = _visible_progressbars(_arena_units())
	_save_capture("03_combat_bars_visible.png")

	if _planning_visible_bars > 0:
		push_error("BarItemsTraitsCapture: planning grid still has visible bars: %d" % _planning_visible_bars)
		get_tree().quit(1)
		return
	if _combat_visible_bars <= 0:
		push_error("BarItemsTraitsCapture: combat actors did not show bars")
		get_tree().quit(1)
		return
	if _filled_item_cards <= 0:
		push_error("BarItemsTraitsCapture: item cards did not render filled inventory items")
		get_tree().quit(1)
		return
	if _visible_trait_icons <= 0:
		push_error("BarItemsTraitsCapture: trait icons did not render")
		get_tree().quit(1)
		return
	print("BarItemsTraitsCapture: OK planning_visible_bars=%d combat_visible_bars=%d filled_item_cards=%d visible_trait_icons=%d output=%s" % [_planning_visible_bars, _combat_visible_bars, _filled_item_cards, _visible_trait_icons, ProjectSettings.globalize_path(OUTPUT_DIR)])
	get_tree().quit(0)

func _force_item_and_trait_state() -> void:
	var manager: CombatManager = _view.get("manager") as CombatManager
	if manager == null or manager.player_team.is_empty():
		return
	Items.force_set_equipped(manager.player_team[0], ["hammer", "crystal", "veil"])
	if manager.player_team.size() > 1:
		Items.force_set_equipped(manager.player_team[1], ["plate", "orb"])
	var inventory_ids: Array[String] = ["hammer", "crystal", "wand", "core", "plate", "veil", "orb", "spike"]
	for item_id: String in inventory_ids:
		Items.add_to_inventory(item_id, 1)
	var controller: Variant = _view.get("controller")
	if controller == null:
		return
	var items_presenter: Variant = controller.get("items_presenter")
	if items_presenter != null and items_presenter.has_method("rebuild"):
		items_presenter.rebuild()
	var traits_presenter: Variant = controller.get("traits_presenter")
	if traits_presenter != null and traits_presenter.has_method("rebuild"):
		traits_presenter.rebuild()

func _count_filled_item_cards() -> int:
	var item_grid: GridContainer = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	if item_grid == null:
		return 0
	var filled_cards: int = 0
	for card_node: Node in item_grid.get_children():
		var script_ref: Script = card_node.get_script() as Script
		if script_ref == null or script_ref.resource_path != "res://scripts/ui/items/item_card.gd":
			continue
		if String(card_node.get("item_id")).strip_edges() != "":
			filled_cards += 1
	return filled_cards

func _count_visible_trait_icons() -> int:
	var traits_vbox: VBoxContainer = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/TraitsPanel/TraitsScroll/TraitsVBox") as VBoxContainer
	if traits_vbox == null:
		return 0
	var total: int = 0
	for icon_node: Node in traits_vbox.get_children():
		var control: Control = icon_node as Control
		if control != null and control.visible and control.is_visible_in_tree():
			total += 1
	return total

func _show_trait_tooltip() -> void:
	var traits_vbox: VBoxContainer = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/TraitsPanel/TraitsScroll/TraitsVBox") as VBoxContainer
	if traits_vbox == null or traits_vbox.get_child_count() == 0:
		return
	var icon: Control = traits_vbox.get_child(0) as Control
	var trait_id: String = "Sanguine"
	if icon != null:
		trait_id = String(icon.get("trait_id"))
	var tooltip: Control = load("res://scenes/ui/traits/TraitTooltip.tscn").instantiate() as Control
	if tooltip == null:
		return
	tooltip.name = "CaptureTraitTooltip"
	get_tree().root.add_child(tooltip)
	if tooltip.has_method("set_trait"):
		tooltip.call("set_trait", trait_id)
	if tooltip.has_method("set_context"):
		var active: bool = bool(icon.get("_active")) if icon != null else true
		var count: int = int(icon.get("_count")) if icon != null else 2
		var tier: int = int(icon.get("_tier")) if icon != null else 0
		tooltip.call("set_context", active, count, tier)
	var tooltip_position: Vector2 = Vector2(88.0, 360.0)
	if icon != null:
		tooltip_position = icon.get_global_rect().position + Vector2(62.0, 28.0)
	if tooltip.has_method("show_at"):
		tooltip.call("show_at", tooltip_position)

func _show_item_tooltip() -> void:
	var card: Control = _first_filled_item_card()
	if card != null:
		var tooltip: Control = load("res://scenes/ui/items/ItemTooltip.tscn").instantiate() as Control
		if tooltip == null:
			return
		tooltip.name = "CaptureItemTooltip"
		get_tree().root.add_child(tooltip)
		if tooltip.has_method("set_item_id"):
			tooltip.call("set_item_id", String(card.get("item_id")))
		var tooltip_position: Vector2 = card.get_global_rect().position + Vector2(58.0, 18.0)
		if tooltip.has_method("show_at"):
			tooltip.call("show_at", tooltip_position)

func _clear_tooltips() -> void:
	for node: Node in get_tree().root.get_children():
		if node.name == "CaptureTraitTooltip" or node.name == "CaptureItemTooltip":
			node.queue_free()
	_clear_script_tooltips()

func _exercise_hover_mechanics() -> bool:
	var item_ok: bool = await _exercise_item_hover()
	var trait_ok: bool = await _exercise_trait_hover()
	return item_ok and trait_ok

func _exercise_tooltip_edge_cases() -> bool:
	var item_ok: bool = await _exercise_item_tooltip_edges()
	var trait_ok: bool = await _exercise_trait_tooltip_edges()
	_clear_tooltips()
	return item_ok and trait_ok

func _exercise_item_tooltip_edges() -> bool:
	var item_tooltip: Control = load("res://scenes/ui/items/ItemTooltip.tscn").instantiate() as Control
	if item_tooltip == null:
		return false
	item_tooltip.name = "CaptureItemTooltip"
	get_tree().root.add_child(item_tooltip)
	if item_tooltip.has_method("set_item_id"):
		item_tooltip.call("set_item_id", "")
	if item_tooltip.has_method("show_at"):
		item_tooltip.call("show_at", _bottom_right_probe_position())
	await _settle(0.08)
	var empty_inside: bool = _control_inside_viewport(item_tooltip)
	if item_tooltip.has_method("set_item_id"):
		item_tooltip.call("set_item_id", "__missing_item__")
	if item_tooltip.has_method("move_to"):
		item_tooltip.call("move_to", _bottom_right_probe_position())
	await _settle(0.04)
	var missing_inside: bool = _control_inside_viewport(item_tooltip)
	return empty_inside and missing_inside

func _exercise_trait_tooltip_edges() -> bool:
	var trait_tooltip: Control = load("res://scenes/ui/traits/TraitTooltip.tscn").instantiate() as Control
	if trait_tooltip == null:
		return false
	trait_tooltip.name = "CaptureTraitTooltip"
	get_tree().root.add_child(trait_tooltip)
	if trait_tooltip.has_method("set_trait"):
		trait_tooltip.call("set_trait", "__MissingTrait__")
	if trait_tooltip.has_method("set_context"):
		trait_tooltip.call("set_context", false, 1, -1)
	if trait_tooltip.has_method("show_at"):
		trait_tooltip.call("show_at", _bottom_right_probe_position())
	await _settle(0.08)
	return _control_inside_viewport(trait_tooltip)

func _exercise_item_hover() -> bool:
	var card: Control = _first_filled_item_card()
	if card == null:
		return false
	Input.warp_mouse(card.get_global_rect().get_center())
	card.call("_on_mouse_entered")
	await _settle(0.18)
	var shown: bool = _count_script_instances(get_tree().root, "res://scripts/ui/items/item_tooltip.gd") > 0
	card.call("_on_mouse_exited")
	await _settle(0.06)
	var cleared: bool = _count_script_instances(get_tree().root, "res://scripts/ui/items/item_tooltip.gd") == 0
	return shown and cleared

func _exercise_trait_hover() -> bool:
	var icon: Control = _first_trait_icon()
	if icon == null:
		return false
	Input.warp_mouse(icon.get_global_rect().get_center())
	icon.call("_on_mouse_entered")
	await _settle(0.14)
	var shown: bool = _count_script_instances(get_tree().root, "res://scripts/ui/traits/trait_tooltip.gd") > 0
	icon.call("_on_mouse_exited")
	await _settle(0.06)
	var cleared: bool = _count_script_instances(get_tree().root, "res://scripts/ui/traits/trait_tooltip.gd") == 0
	return shown and cleared

func _first_filled_item_card() -> Control:
	var item_grid: GridContainer = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	if item_grid == null:
		return null
	for card_node: Node in item_grid.get_children():
		var card: Control = card_node as Control
		if card == null:
			continue
		if String(card.get("item_id")).strip_edges() != "":
			return card
	return null

func _first_trait_icon() -> Control:
	var traits_vbox: VBoxContainer = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/TraitsPanel/TraitsScroll/TraitsVBox") as VBoxContainer
	if traits_vbox == null or traits_vbox.get_child_count() == 0:
		return null
	return traits_vbox.get_child(0) as Control

func _clear_script_tooltips() -> void:
	_clear_script_tooltips_recursive(get_tree().root)

func _clear_script_tooltips_recursive(root: Node) -> void:
	for child: Node in root.get_children():
		var script_ref: Script = child.get_script() as Script
		if script_ref != null and (script_ref.resource_path == "res://scripts/ui/items/item_tooltip.gd" or script_ref.resource_path == "res://scripts/ui/traits/trait_tooltip.gd"):
			child.queue_free()
		else:
			_clear_script_tooltips_recursive(child)

func _count_script_instances(root: Node, script_path: String) -> int:
	var total: int = 0
	var script_ref: Script = root.get_script() as Script
	if script_ref != null and script_ref.resource_path == script_path:
		total += 1
	for child: Node in root.get_children():
		total += _count_script_instances(child, script_path)
	return total

func _bottom_right_probe_position() -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2(1900.0, 1060.0)
	return viewport.get_visible_rect().size - Vector2(2.0, 2.0)

func _control_inside_viewport(control: Control) -> bool:
	if control == null:
		return false
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var rect: Rect2 = control.get_global_rect()
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= viewport_size.x + 0.5 and rect.end.y <= viewport_size.y + 0.5

func _player_grid() -> Node:
	return _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid") if _view != null else null

func _enemy_grid() -> Node:
	return _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid") if _view != null else null

func _arena_units() -> Node:
	return _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits") if _view != null else null

func _visible_progressbars(root: Node) -> int:
	if root == null:
		return 0
	var total: int = 0
	if root is ProgressBar and (root as ProgressBar).visible and (root as ProgressBar).is_visible_in_tree():
		total += 1
	for child: Node in root.get_children():
		total += _visible_progressbars(child)
	return total

func _save_capture(filename: String) -> void:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_warning("BarItemsTraitsCapture: skipped %s; viewport texture unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("BarItemsTraitsCapture: skipped %s; viewport image unavailable" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("BarItemsTraitsCapture: failed to save %s error=%s" % [ProjectSettings.globalize_path(path), str(int(err))])
		return
	print("BarItemsTraitsCapture: saved %s" % ProjectSettings.globalize_path(path))

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame
