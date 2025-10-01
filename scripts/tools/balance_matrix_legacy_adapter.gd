extends Node
class_name BalanceMatrixLegacyAdapter

## Converts the identity_v2 balance matrix CSV back to the legacy identity_v1 column layout.
@export var input_path: String = "user://balance_runner/balance_matrix.csv"
@export var output_path: String = "user://balance_runner/balance_matrix_legacy.csv"
@export var expected_version: String = "identity_v2"

const LEGACY_HEADER_BASE := [
	"attacker_id",
	"defender_id",
	"attacker_roles",
	"defender_roles",
	"attacker_cost",
	"defender_cost",
	"attacker_level",
	"defender_level",
	"attacker_win_pct",
	"defender_win_pct",
	"draw_pct",
	"attacker_avg_time_to_win_s",
	"defender_avg_time_to_win_s",
	"attacker_avg_remaining_hp",
	"defender_avg_remaining_hp",
	"matches_total",
	"hit_events_total",
	"attacker_hit_events",
	"defender_hit_events",
	"attacker_avg_damage_dealt_per_match",
	"defender_avg_damage_dealt_per_match",
	"attacker_healing_total",
	"defender_healing_total",
	"attacker_shield_absorbed_total",
	"defender_shield_absorbed_total",
	"attacker_damage_mitigated_total",
	"defender_damage_mitigated_total",
	"attacker_overkill_total",
	"defender_overkill_total",
	"attacker_damage_physical_total",
	"defender_damage_physical_total",
	"attacker_damage_magic_total",
	"defender_damage_magic_total",
	"attacker_damage_true_total",
	"defender_damage_true_total",
	"attacker_time_to_first_hit_s",
	"defender_time_to_first_hit_s"
]

const LEGACY_ABILITY_COLUMNS := [
	"attacker_avg_casts_per_match",
	"defender_avg_casts_per_match",
	"attacker_first_cast_time_s",
	"defender_first_cast_time_s"
]

func _ready() -> void:
	_apply_cli_overrides()
	convert(input_path, output_path, expected_version)
	if not Engine.is_editor_hint() and get_tree():
		get_tree().quit()

static func convert(input_path: String, output_path: String, expected_version: String = "identity_v2") -> void:
	var adapter := BalanceMatrixLegacyAdapter.new()
	adapter._convert_internal(input_path, output_path, expected_version)

func _apply_cli_overrides() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--input="):
			input_path = arg.get_slice("=", 1)
		elif arg.begins_with("--output="):
			output_path = arg.get_slice("=", 1)
		elif arg.begins_with("--expected="):
			expected_version = arg.get_slice("=", 1)

func _convert_internal(input_path: String, output_path: String, expected_version: String) -> void:
	if input_path == "" or output_path == "":
		push_warning("Legacy adapter: input/output paths must be provided")
		return
	if not FileAccess.file_exists(input_path):
		push_warning("Legacy adapter: input not found at %s" % input_path)
		return
	var reader := FileAccess.open(input_path, FileAccess.READ)
	if reader == null:
		push_warning("Legacy adapter: unable to open %s" % input_path)
		return
	var header_line := reader.get_line()
	if header_line.strip_edges() == "":
		push_warning("Legacy adapter: empty matrix file")
		reader.close()
		return
	var header := header_line.split(",")
	if header.size() < 2:
		push_warning("Legacy adapter: malformed header")
		reader.close()
		return
	var index_map := {}
	for i in range(header.size()):
		index_map[header[i]] = i
	if not index_map.has("schema_version"):
		push_warning("Legacy adapter: schema_version column missing; treating file as legacy")
		reader.close()
		_copy_passthrough(input_path, output_path)
		_maybe_convert_agg(input_path, output_path)
		return
	var rows: Array = []
	while not reader.eof_reached():
		var raw := reader.get_line()
		if raw == "":
			continue
		var cols := raw.split(",")
		if cols.size() != header.size():
			push_warning("Legacy adapter: skipping malformed row (%s)" % raw)
			continue
		rows.append(cols)
	reader.close()
	if rows.is_empty():
		push_warning("Legacy adapter: no data rows found")
		return
	var version := String(rows[0][index_map["schema_version"]])
	if expected_version != "" and version != "" and version != expected_version:
		push_warning("Legacy adapter: input version %s differs from expected %s" % [version, expected_version])

	var ability_columns: Array[String] = []
	for col_name in LEGACY_ABILITY_COLUMNS:
		if index_map.has(col_name):
			ability_columns.append(col_name)

	var header_out := PackedStringArray(LEGACY_HEADER_BASE)
	for ability_col in ability_columns:
		header_out.append(String(ability_col))
	var writer := FileAccess.open(output_path, FileAccess.WRITE)
	if writer == null:
		push_warning("Legacy adapter: unable to write %s" % output_path)
		return
	writer.store_line(",".join(header_out))

	for cols in rows:
		var map: Dictionary = {}
		for key in index_map.keys():
			var idx: int = int(index_map[key])
			map[key] = (idx < cols.size()) ? cols[idx] : ""
		var attacker_roles := String(map.get("attacker_primary_role", ""))
		var defender_roles := String(map.get("defender_primary_role", ""))
		if attacker_roles == "":
			attacker_roles = String(map.get("attacker_roles", ""))
		if defender_roles == "":
			defender_roles = String(map.get("defender_roles", ""))
		var legacy_row := PackedStringArray()
		legacy_row.append(String(map.get("attacker_id", "")))
		legacy_row.append(String(map.get("defender_id", "")))
		legacy_row.append(attacker_roles)
		legacy_row.append(defender_roles)
		legacy_row.append(String(map.get("attacker_cost", "")))
		legacy_row.append(String(map.get("defender_cost", "")))
		legacy_row.append(String(map.get("attacker_level", "")))
		legacy_row.append(String(map.get("defender_level", "")))
		legacy_row.append(String(map.get("attacker_win_pct", "")))
		legacy_row.append(String(map.get("defender_win_pct", "")))
		legacy_row.append(String(map.get("draw_pct", "")))
		legacy_row.append(String(map.get("attacker_avg_time_to_win_s", "")))
		legacy_row.append(String(map.get("defender_avg_time_to_win_s", "")))
		legacy_row.append(String(map.get("attacker_avg_remaining_hp", "")))
		legacy_row.append(String(map.get("defender_avg_remaining_hp", "")))
		legacy_row.append(String(map.get("matches_total", "")))
		legacy_row.append(String(map.get("hit_events_total", "")))
		legacy_row.append(String(map.get("attacker_hit_events", "")))
		legacy_row.append(String(map.get("defender_hit_events", "")))
		legacy_row.append(String(map.get("attacker_avg_damage_dealt_per_match", "")))
		legacy_row.append(String(map.get("defender_avg_damage_dealt_per_match", "")))
		legacy_row.append(String(map.get("attacker_healing_total", "")))
		legacy_row.append(String(map.get("defender_healing_total", "")))
		legacy_row.append(String(map.get("attacker_shield_absorbed_total", "")))
		legacy_row.append(String(map.get("defender_shield_absorbed_total", "")))
		legacy_row.append(String(map.get("attacker_damage_mitigated_total", "")))
		legacy_row.append(String(map.get("defender_damage_mitigated_total", "")))
		legacy_row.append(String(map.get("attacker_overkill_total", "")))
		legacy_row.append(String(map.get("defender_overkill_total", "")))
		legacy_row.append(String(map.get("attacker_damage_physical_total", "")))
		legacy_row.append(String(map.get("defender_damage_physical_total", "")))
		legacy_row.append(String(map.get("attacker_damage_magic_total", "")))
		legacy_row.append(String(map.get("defender_damage_magic_total", "")))
		legacy_row.append(String(map.get("attacker_damage_true_total", "")))
		legacy_row.append(String(map.get("defender_damage_true_total", "")))
		legacy_row.append(String(map.get("attacker_time_to_first_hit_s", "")))
		legacy_row.append(String(map.get("defender_time_to_first_hit_s", "")))
		for ability_col in ability_columns:
			legacy_row.append(String(map.get(ability_col, "")))
		writer.store_line(",".join(legacy_row))
	writer.close()

	_maybe_convert_agg(input_path, output_path)

func _copy_passthrough(src: String, dst: String) -> void:
	var reader := FileAccess.open(src, FileAccess.READ)
	if reader == null:
		return
	var writer := FileAccess.open(dst, FileAccess.WRITE)
	if writer == null:
		reader.close()
		return
	while not reader.eof_reached():
		writer.store_line(reader.get_line())
	reader.close()
	writer.close()

func _maybe_convert_agg(input_path: String, output_path: String) -> void:
	var agg_in := input_path.get_basename() + "_agg.csv"
	if not FileAccess.file_exists(agg_in):
		return
	var reader := FileAccess.open(agg_in, FileAccess.READ)
	if reader == null:
		return
	var header_line := reader.get_line()
	if header_line.strip_edges() == "":
		reader.close()
		return
	var header := header_line.split(",")
	if header.is_empty() or header[0] != "schema_version":
		reader.seek(0)
		_copy_passthrough(agg_in, output_path.get_basename() + "_legacy_agg.csv")
		reader.close()
		return
	var agg_out_path := output_path.get_basename() + "_legacy_agg.csv"
	var agg_out := FileAccess.open(agg_out_path, FileAccess.WRITE)
	if agg_out == null:
		reader.close()
		return
	agg_out.store_line("pair,a_cluster,b_cluster,a_win_pct,b_win_pct,draw_pct,a_avg_time,b_avg_time,matches,pass")
	while not reader.eof_reached():
		var line := reader.get_line()
		if line.strip_edges() == "":
			continue
		var cols := line.split(",")
		if cols.size() < 2:
			continue
		var trimmed := cols.slice(1)
		agg_out.store_line(",".join(trimmed))
	reader.close()
	agg_out.close()
