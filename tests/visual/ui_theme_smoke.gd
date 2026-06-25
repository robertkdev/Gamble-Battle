extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")
const ShopPanelLib: Script = preload("res://scripts/ui/shop/shop_panel.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var view: Control = COMBAT_VIEW_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var failures: Array[String] = []
	_expect(view.theme != null, "CombatView theme is missing", failures)
	var stage_label: Label = view.get_node_or_null("MarginContainer/VBoxContainer/StageLabel") as Label
	_expect(stage_label != null, "StageLabel missing", failures)
	if stage_label != null:
		_expect(stage_label.get_theme_font_size("font_size") == 34, "StageLabel font size was not set to 34", failures)
	var continue_button: Button = view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null, "ContinueButton missing", failures)
	if continue_button != null:
		_expect(continue_button.custom_minimum_size.x >= 230.0, "ContinueButton is not visually prioritized", failures)
	var gold_label: Label = view.find_child("GoldLabel", true, false) as Label
	_expect(gold_label != null, "GoldLabel missing", failures)
	if gold_label != null:
		_expect(gold_label.get_theme_font_size("font_size") >= 22, "GoldLabel is too small for the command strip", failures)
		_expect(gold_label.get_parent() != null and gold_label.get_parent() is HBoxContainer, "GoldLabel was not moved into the command strip", failures)
	var shop_grid: GridContainer = view.find_child("ShopGrid", true, false) as GridContainer
	_expect(shop_grid != null, "ShopGrid missing", failures)
	if shop_grid != null and shop_grid.get_child_count() > 0:
		var first_slot: Control = shop_grid.get_child(0) as Control
		_expect(first_slot != null and first_slot.custom_minimum_size.x >= 150.0, "Shop slots are too small", failures)
		_expect(first_slot != null and first_slot.custom_minimum_size.y <= 150.0, "Shop slots are too tall for 1080p layout", failures)
		_expect(shop_grid.get_theme_constant("h_separation") >= 16, "Shop card gutters are too tight for pointer clarity", failures)
	var bottom_storage: VBoxContainer = view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	_expect(bottom_storage != null, "BottomStorageArea missing", failures)
	if bottom_storage != null:
		_expect(bottom_storage.get_theme_constant("separation") >= 14, "Command strip and shop cards are too tightly stacked", failures)
	if gold_label != null:
		var command_bar: HBoxContainer = gold_label.get_parent() as HBoxContainer
		_expect(command_bar != null, "Command bar missing", failures)
		if command_bar != null:
			_expect(command_bar.get_theme_constant("separation") >= 16, "Command controls are too tightly grouped", failures)
	await _verify_forced_first_fight_placeholder(failures)
	var player_tile: Button = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid/TileP_00") as Button
	_expect(player_tile != null, "Player tile missing", failures)
	if player_tile != null:
		_expect(player_tile.has_theme_stylebox_override("disabled"), "Player tile disabled style missing", failures)
	var stats_plate: Panel = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/GothicStatsAreaPlate") as Panel
	_expect(stats_plate != null, "Stats backplate missing", failures)
	var scoreboard_row: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	add_child(scoreboard_row)
	await get_tree().process_frame
	_expect(scoreboard_row.get_node_or_null("HBox/Content/Name") != null, "Scoreboard row name label missing", failures)
	_expect(scoreboard_row.custom_minimum_size.y >= 48.0, "Scoreboard row is too compressed", failures)
	scoreboard_row.queue_free()
	if failures.size() > 0:
		for failure: String in failures:
			push_error("UIThemeSmoke: " + failure)
		get_tree().quit(1)
		return
	print("UIThemeSmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _verify_forced_first_fight_placeholder(failures: Array[String]) -> void:
	var host: VBoxContainer = VBoxContainer.new()
	add_child(host)
	var grid: GridContainer = GridContainer.new()
	host.add_child(grid)
	var panel: ShopPanel = ShopPanelLib.new()
	panel.configure(grid, 5)
	panel.set_empty_state("FIRST FIGHT", "Win to open shop", true)
	panel.set_offers([])
	await get_tree().process_frame
	_expect(grid.columns == 1, "First fight placeholder should occupy one wide shop panel", failures)
	_expect(grid.get_child_count() == 1, "First fight placeholder should be a single panel", failures)
	var placeholder: PanelContainer = null
	if grid.get_child_count() > 0:
		placeholder = grid.get_child(0) as PanelContainer
	_expect(placeholder != null, "First fight placeholder panel missing", failures)
	if placeholder != null:
		_expect(placeholder.custom_minimum_size.x >= 790.0, "First fight placeholder should span the shop strip", failures)
		var panel_style: StyleBoxFlat = placeholder.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(panel_style != null, "First fight placeholder style missing", failures)
		if panel_style != null:
			_expect(panel_style.border_width_top >= 2, "First fight placeholder border is too subtle", failures)
			_expect(panel_style.border_color.r >= 0.70 and panel_style.border_color.g >= 0.40, "First fight placeholder border is not prominent enough", failures)
	var label: Label = _find_label_with_text(host, "FIRST FIGHT")
	_expect(label != null, "FIRST FIGHT label missing", failures)
	if label != null:
		_expect(label.get_theme_font_size("font_size") >= 16, "FIRST FIGHT label is too small", failures)
		var label_color: Color = label.get_theme_color("font_color")
		_expect(label_color.r >= 0.90 and label_color.g >= 0.65, "FIRST FIGHT label is too muted", failures)
	var hint: Label = _find_label_with_text(host, "Win to open shop")
	_expect(hint != null, "First fight hint missing", failures)
	if hint != null:
		_expect(hint.get_theme_font_size("font_size") >= 13, "First fight hint is too small", failures)
	panel.clear()
	remove_child(host)
	host.free()

func _find_label_with_text(root: Node, text: String) -> Label:
	if root is Label and String((root as Label).text) == text:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null
