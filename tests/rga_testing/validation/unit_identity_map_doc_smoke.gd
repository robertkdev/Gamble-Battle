extends Node

const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")

const DOC_PATH := "res://docs/unit_identity_map.md"

func _ready() -> void:
	var issues: Array[String] = _run_smoke()
	if issues.is_empty():
		print("UnitIdentityMapDocSmoke: OK")
		get_tree().quit(0)
		return
	for issue: String in issues:
		push_error(issue)
	get_tree().quit(1)

func _run_smoke() -> Array[String]:
	var issues: Array[String] = []
	var expected: Dictionary = _expected_rows()
	var actual: Dictionary = _read_doc_rows()
	if actual.is_empty():
		issues.append("UnitIdentityMapDocSmoke: no playable rows parsed from %s" % DOC_PATH)
		return issues
	for id: String in expected.keys():
		if not actual.has(id):
			issues.append("UnitIdentityMapDocSmoke: missing row for '%s'" % id)
			continue
		var expected_row: Dictionary = expected[id]
		var actual_row: Dictionary = actual[id]
		issues.append_array(_compare_row(id, expected_row, actual_row))
	for id2: String in actual.keys():
		if not expected.has(id2):
			issues.append("UnitIdentityMapDocSmoke: unexpected row for '%s'" % id2)
	return issues

func _expected_rows() -> Dictionary:
	var catalog: UnitCatalog = UnitCatalog.new()
	catalog.refresh()
	var rows: Dictionary = {}
	for cost: int in catalog.get_all_costs():
		for id: String in catalog.get_ids_by_cost(cost):
			var meta: Dictionary = catalog.get_unit_meta(id)
			var flags: Dictionary = meta.get("flags", {})
			if bool(flags.get("hidden", false)) or bool(flags.get("enemy_only", false)):
				continue
			rows[id] = {
				"name": catalog.get_name(id),
				"id": id,
				"role": catalog.get_primary_role(id),
				"goal": catalog.get_primary_goal(id),
				"approaches": _join_strings(catalog.get_approaches(id)),
				"identity_path": catalog.get_identity_path(id),
			}
	return rows

func _read_doc_rows() -> Dictionary:
	var rows: Dictionary = {}
	var file: FileAccess = FileAccess.open(DOC_PATH, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.begins_with("|"):
			continue
		if line.begins_with("| ---") or line.find("| ID |") != -1:
			continue
		var columns: PackedStringArray = line.trim_prefix("|").trim_suffix("|").split("|")
		if columns.size() < 6:
			continue
		var id: String = String(columns[1]).strip_edges()
		if id == "":
			continue
		rows[id] = {
			"name": String(columns[0]).strip_edges(),
			"id": id,
			"role": String(columns[2]).strip_edges(),
			"goal": String(columns[3]).strip_edges(),
			"approaches": String(columns[4]).strip_edges(),
			"identity_path": String(columns[5]).strip_edges(),
		}
	return rows

func _compare_row(id: String, expected_row: Dictionary, actual_row: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var fields: Array[String] = ["name", "id", "role", "goal", "approaches", "identity_path"]
	for field: String in fields:
		var expected_value: String = String(expected_row.get(field, ""))
		var actual_value: String = String(actual_row.get(field, ""))
		if actual_value != expected_value:
			issues.append("UnitIdentityMapDocSmoke: %s %s expected '%s' got '%s'" % [id, field, expected_value, actual_value])
	return issues

func _join_strings(values: Array[String]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value: String in values:
		parts.append(value)
	return ", ".join(parts)
