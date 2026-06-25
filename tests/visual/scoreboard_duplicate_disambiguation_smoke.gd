extends Node

const ScoreboardModelLib: GDScript = preload("res://scripts/ui/combat/stats/scoreboard_model.gd")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")

var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	await _verify_duplicate_rows()
	_verify_unique_rows()
	_finish()

func _verify_duplicate_rows() -> void:
	var model: ScoreboardModel = ScoreboardModelLib.new()
	var duplicate_rows: Array = [
		_make_source_row("player", 0, "Berebell", 1200.0),
		_make_source_row("player", 1, "Berebell", 900.0),
	]
	var decorated_rows: Array = model._decorate_and_sort_rows(duplicate_rows, 2100.0, 0.0, ScoreboardModel.NormMode.TEAM_SHARE)
	_expect(_has_display_name(decorated_rows, "Berebell #1"), "duplicate rows missing Berebell #1")
	_expect(_has_display_name(decorated_rows, "Berebell #2"), "duplicate rows missing Berebell #2")
	_expect(_display_names_are_unique(decorated_rows), "duplicate rows still render ambiguous display names")
	for row: Dictionary in decorated_rows:
		await _verify_rendered_label(row)

func _verify_unique_rows() -> void:
	var model: ScoreboardModel = ScoreboardModelLib.new()
	var unique_rows: Array = [
		_make_source_row("player", 0, "Berebell", 1200.0),
		_make_source_row("player", 1, "Bonko", 900.0),
	]
	var decorated_rows: Array = model._decorate_and_sort_rows(unique_rows, 2100.0, 0.0, ScoreboardModel.NormMode.TEAM_SHARE)
	_expect(_has_display_name(decorated_rows, "Berebell"), "unique Berebell row should not get a copy suffix")
	_expect(_has_display_name(decorated_rows, "Bonko"), "unique Bonko row should not get a copy suffix")
	_expect(not _has_display_name(decorated_rows, "Berebell #1"), "unique Berebell row got an unnecessary suffix")
	_expect(not _has_display_name(decorated_rows, "Bonko #1"), "unique Bonko row got an unnecessary suffix")

func _verify_rendered_label(row: Dictionary) -> void:
	var row_node: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	add_child(row_node)
	row_node.set_row_data(row)
	await get_tree().process_frame
	var name_label: Label = row_node.get_node_or_null("HBox/Content/Name") as Label
	var expected: String = String(row.get("display_name", ""))
	var actual: String = name_label.text if name_label != null else ""
	_expect(actual == expected, "rendered label expected %s got %s" % [expected, actual])
	remove_child(row_node)
	row_node.free()

func _make_source_row(team: String, index: int, unit_name: String, value: float) -> Dictionary:
	var unit: Unit = Unit.new()
	unit.id = unit_name.to_lower()
	unit.name = unit_name
	return {
		"team": team,
		"index": index,
		"unit": unit,
		"value": value,
	}

func _has_display_name(rows: Array, expected: String) -> bool:
	for row: Dictionary in rows:
		if String(row.get("display_name", "")) == expected:
			return true
	return false

func _display_names_are_unique(rows: Array) -> bool:
	var seen: Dictionary = {}
	for row: Dictionary in rows:
		var display_name: String = String(row.get("display_name", ""))
		if seen.has(display_name):
			return false
		seen[display_name] = true
	return true

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("ScoreboardDuplicateDisambiguationSmoke: OK")
	else:
		for failure: String in _failures:
			push_error("ScoreboardDuplicateDisambiguationSmoke: " + failure)
		exit_code = 1
	get_tree().quit(exit_code)
