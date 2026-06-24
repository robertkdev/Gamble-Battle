extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")

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
		_expect(first_slot != null and first_slot.custom_minimum_size.x >= 168.0, "Shop slots are too small", failures)
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
