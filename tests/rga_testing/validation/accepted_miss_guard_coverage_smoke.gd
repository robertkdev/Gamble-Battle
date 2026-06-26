extends Node

const SUMMARY_PATH: String = "res://outputs/audit_playtest/rga_accepted_misses_2026_06_25/accepted_gap_kind_summary.csv"
const RESIDUAL_AUDIT_PATH: String = "res://docs/rga/accepted_miss_residual_audit_2026-06-26.md"
const EXPECTED_GAP_KIND_COUNT: int = 4
const EXPECTED_ACCEPTED_SPAN_COUNT: int = 4

const GUARDS_BY_GAP_KIND: Dictionary = {
	"assassin_opening_presence_below_target": ["res://tests/rga_testing/validation/AssassinOpeningRoleProbe.tscn", "res://tests/rga_testing/validation/AssassinOpeningScenarioPackSmoke.tscn"],
	"peel_carry_goal_save_proxy_absent": ["res://tests/rga_testing/validation/TotemPeelCarryAcceptedMissProbe.tscn", "res://tests/rga_testing/validation/SupportCarryThreatScenarioPackSmoke.tscn"],
	"peel_interrupt_context_absent": ["res://tests/rga_testing/validation/TotemPeelCarryAcceptedMissProbe.tscn", "res://tests/rga_testing/validation/SupportCarryThreatScenarioPackSmoke.tscn"],
	"team_fortification_buff_uptime_absent": ["res://tests/rga_testing/validation/TeamFortificationBuffGoalProbe.tscn", "res://tests/rga_testing/validation/TeamFortificationScenarioPackSmoke.tscn"]
}

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var rows: Array[Dictionary] = _load_summary_rows(failures)
	var seen_gap_kinds: Dictionary = {}
	var accepted_span_count: int = 0

	for row in rows:
		var gap_kind: String = String(row.get("audit_gap_kind", ""))
		var count: int = int(row.get("count", 0))
		seen_gap_kinds[gap_kind] = true
		accepted_span_count += count
		if gap_kind == "":
			failures.append("AcceptedMissGuardCoverageSmoke: row has empty audit_gap_kind")
			continue
		if not GUARDS_BY_GAP_KIND.has(gap_kind):
			failures.append("AcceptedMissGuardCoverageSmoke: unmapped gap kind %s" % gap_kind)
			continue
		_validate_guard_paths(gap_kind, GUARDS_BY_GAP_KIND.get(gap_kind, []), failures)

	for gap_kind_value in GUARDS_BY_GAP_KIND.keys():
		var mapped_gap_kind: String = String(gap_kind_value)
		if not seen_gap_kinds.has(mapped_gap_kind):
			failures.append("AcceptedMissGuardCoverageSmoke: stale mapping not present in export %s" % mapped_gap_kind)

	if rows.size() != EXPECTED_GAP_KIND_COUNT:
		failures.append("AcceptedMissGuardCoverageSmoke: expected %d gap kinds, found %d" % [EXPECTED_GAP_KIND_COUNT, rows.size()])
	if accepted_span_count != EXPECTED_ACCEPTED_SPAN_COUNT:
		failures.append("AcceptedMissGuardCoverageSmoke: expected %d accepted spans, found %d" % [EXPECTED_ACCEPTED_SPAN_COUNT, accepted_span_count])
	_validate_residual_audit_doc(rows, failures)

	print("AcceptedMissGuardCoverageSmoke: gap_kinds=", rows.size(),
		" accepted_spans=", accepted_span_count,
		" mapped_gap_kinds=", GUARDS_BY_GAP_KIND.size())

	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		_quit(1)
		return
	print("AcceptedMissGuardCoverageSmoke: PASS")
	_quit(0)

func _load_summary_rows(failures: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not FileAccess.file_exists(SUMMARY_PATH):
		failures.append("AcceptedMissGuardCoverageSmoke: missing summary CSV at %s; regenerate with tests/rga_testing/tools/Export-AcceptedMisses.ps1" % SUMMARY_PATH)
		return rows
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.READ)
	if file == null:
		failures.append("AcceptedMissGuardCoverageSmoke: could not open summary CSV at %s" % SUMMARY_PATH)
		return rows
	if file.eof_reached():
		failures.append("AcceptedMissGuardCoverageSmoke: summary CSV is empty")
		return rows
	var headers: PackedStringArray = _parse_csv_line(file.get_line())
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.strip_edges() == "":
			continue
		var values: PackedStringArray = _parse_csv_line(line)
		var row: Dictionary = {}
		for index: int in range(headers.size()):
			var key: String = String(headers[index])
			var value: String = values[index] if index < values.size() else ""
			row[key] = value
		rows.append(row)
	return rows

func _parse_csv_line(line: String) -> PackedStringArray:
	var fields: PackedStringArray = PackedStringArray()
	var current: String = ""
	var inside_quotes: bool = false
	var index: int = 0
	while index < line.length():
		var character: String = line.substr(index, 1)
		if character == "\"":
			var next_character: String = line.substr(index + 1, 1) if index + 1 < line.length() else ""
			if inside_quotes and next_character == "\"":
				current += "\""
				index += 2
				continue
			inside_quotes = not inside_quotes
		elif character == "," and not inside_quotes:
			fields.append(current)
			current = ""
		else:
			current += character
		index += 1
	fields.append(current)
	return fields

func _validate_guard_paths(gap_kind: String, raw_guards: Variant, failures: Array[String]) -> void:
	if not (raw_guards is Array):
		failures.append("AcceptedMissGuardCoverageSmoke: guard mapping for %s is not an array" % gap_kind)
		return
	var guard_paths: Array = raw_guards as Array
	if guard_paths.is_empty():
		failures.append("AcceptedMissGuardCoverageSmoke: guard mapping for %s is empty" % gap_kind)
		return
	for guard_path_value in guard_paths:
		var guard_path: String = String(guard_path_value)
		if guard_path == "":
			failures.append("AcceptedMissGuardCoverageSmoke: guard mapping for %s contains an empty path" % gap_kind)
			continue
		if not ResourceLoader.exists(guard_path):
			failures.append("AcceptedMissGuardCoverageSmoke: guard scene for %s missing at %s" % [gap_kind, guard_path])

func _validate_residual_audit_doc(rows: Array[Dictionary], failures: Array[String]) -> void:
	if not FileAccess.file_exists(RESIDUAL_AUDIT_PATH):
		failures.append("AcceptedMissGuardCoverageSmoke: missing residual audit doc at %s" % RESIDUAL_AUDIT_PATH)
		return
	var file: FileAccess = FileAccess.open(RESIDUAL_AUDIT_PATH, FileAccess.READ)
	if file == null:
		failures.append("AcceptedMissGuardCoverageSmoke: could not open residual audit doc at %s" % RESIDUAL_AUDIT_PATH)
		return
	var doc_text: String = file.get_as_text()
	if doc_text.strip_edges() == "":
		failures.append("AcceptedMissGuardCoverageSmoke: residual audit doc is empty")
		return
	var lower_doc_text: String = doc_text.to_lower()
	for row in rows:
		var gap_kind: String = String(row.get("audit_gap_kind", ""))
		if gap_kind != "" and not doc_text.contains(gap_kind):
			failures.append("AcceptedMissGuardCoverageSmoke: residual audit doc missing gap kind %s" % gap_kind)
		for unit in _split_csv_cell(String(row.get("units", ""))):
			if unit != "" and not lower_doc_text.contains(unit.to_lower()):
				failures.append("AcceptedMissGuardCoverageSmoke: residual audit doc missing unit %s for %s" % [unit, gap_kind])
		for label in _split_csv_cell(String(row.get("labels", ""))):
			if label != "" and not doc_text.contains(label):
				failures.append("AcceptedMissGuardCoverageSmoke: residual audit doc missing label %s for %s" % [label, gap_kind])

func _split_csv_cell(value: String) -> Array[String]:
	var parts: Array[String] = []
	for raw_part: String in value.split(","):
		var part: String = raw_part.strip_edges()
		if part != "":
			parts.append(part)
	return parts

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
