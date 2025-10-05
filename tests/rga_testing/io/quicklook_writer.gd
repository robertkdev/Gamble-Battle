extends RefCounted
class_name QuicklookWriter

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")

var output_dir: String = "user://rga_quicklook"
var write_csv: bool = true
var write_parquet: bool = false # Placeholder; Parquet emission is not yet implemented.
var shard_name_prefix: String = "shard"

var _csv_headers_written: Dictionary = {}
var _parquet_warning_emitted: bool = false

const _COLUMNS := [
    "run_id",
    "sim_index",
    "shard_index",
    "scenario_id",
    "map_id",
    "team_size",
    "team_a_ids",
    "team_b_ids",
    "result",
    "time_s",
    "frames",
    "team_a_alive",
    "team_b_alive",
    "team_a_damage",
    "team_a_healing",
    "team_a_shield",
    "team_a_mitigated",
    "team_a_overkill",
    "team_a_kills",
    "team_a_deaths",
    "team_a_casts",
    "team_a_first_hit_s",
    "team_a_first_cast_s",
    "team_b_damage",
    "team_b_healing",
    "team_b_shield",
    "team_b_mitigated",
    "team_b_overkill",
    "team_b_kills",
    "team_b_deaths",
    "team_b_casts",
    "team_b_first_hit_s",
    "team_b_first_cast_s"
]

func _init(dir_path: String = "user://rga_quicklook", enable_csv: bool = true, enable_parquet: bool = false) -> void:
    output_dir = dir_path
    write_csv = enable_csv
    write_parquet = enable_parquet

func append(row: DataModels.TelemetryRow, shard_index: int = 0) -> bool:
    if row == null:
        push_warning("QuicklookWriter: row is null; ignored")
        return false
    var aggregates: Dictionary = row.aggregates if row.aggregates != null else {}
    var teams: Dictionary = aggregates.get("teams", {})
    if teams.is_empty():
        push_warning("QuicklookWriter: aggregates missing team data; ignored")
        return false
    var record := _build_record(row, teams, shard_index)
    if record.is_empty():
        return false
    var ok := true
    if write_csv:
        ok = ok and _write_csv_row(shard_index, record)
    if write_parquet:
        _write_parquet_row(shard_index, record)
    return ok

func _build_record(row: DataModels.TelemetryRow, teams: Dictionary, shard_index: int) -> Dictionary:
    var ctx: DataModels.MatchContext = row.context
    var outcome: DataModels.EngineOutcome = row.engine_outcome
    if ctx == null or outcome == null:
        push_warning("QuicklookWriter: row missing context/outcome; ignored")
        return {}
    var team_a: Dictionary = teams.get("a", {})
    var team_b: Dictionary = teams.get("b", {})
    return {
        "run_id": String(ctx.run_id),
        "sim_index": int(ctx.sim_index),
        "shard_index": int(shard_index),
        "scenario_id": String(ctx.scenario_id),
        "map_id": String(ctx.map_id),
        "team_size": int(ctx.team_size),
        "team_a_ids": _join_ids(ctx.team_a_ids),
        "team_b_ids": _join_ids(ctx.team_b_ids),
        "result": String(outcome.result),
        "time_s": float(outcome.time_s),
        "frames": int(outcome.frames),
        "team_a_alive": int(outcome.team_a_alive),
        "team_b_alive": int(outcome.team_b_alive),
        "team_a_damage": _int_from(team_a, "damage"),
        "team_a_healing": _int_from(team_a, "healing"),
        "team_a_shield": _int_from(team_a, "shield"),
        "team_a_mitigated": _int_from(team_a, "mitigated"),
        "team_a_overkill": _int_from(team_a, "overkill"),
        "team_a_kills": _int_from(team_a, "kills"),
        "team_a_deaths": _int_from(team_a, "deaths"),
        "team_a_casts": _int_from(team_a, "casts"),
        "team_a_first_hit_s": _float_from(team_a, "first_hit_s", -1.0),
        "team_a_first_cast_s": _float_from(team_a, "first_cast_s", -1.0),
        "team_b_damage": _int_from(team_b, "damage"),
        "team_b_healing": _int_from(team_b, "healing"),
        "team_b_shield": _int_from(team_b, "shield"),
        "team_b_mitigated": _int_from(team_b, "mitigated"),
        "team_b_overkill": _int_from(team_b, "overkill"),
        "team_b_kills": _int_from(team_b, "kills"),
        "team_b_deaths": _int_from(team_b, "deaths"),
        "team_b_casts": _int_from(team_b, "casts"),
        "team_b_first_hit_s": _float_from(team_b, "first_hit_s", -1.0),
        "team_b_first_cast_s": _float_from(team_b, "first_cast_s", -1.0)
    }

func _write_csv_row(shard_index: int, record: Dictionary) -> bool:
    if not _ensure_dir(output_dir):
        push_warning("QuicklookWriter: unable to create output dir %s" % output_dir)
        return false
    var path := _csv_path_for(shard_index)
    var fa: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
    if fa == null:
        var creator := FileAccess.open(path, FileAccess.WRITE)
        if creator == null:
            push_warning("QuicklookWriter: cannot create %s" % path)
            return false
        creator.close()
        fa = FileAccess.open(path, FileAccess.READ_WRITE)
        if fa == null:
            push_warning("QuicklookWriter: cannot reopen %s" % path)
            return false
    var write_header := false
    if fa.get_length() == 0 or not _csv_headers_written.get(path, false):
        write_header = true
    fa.seek_end()
    if write_header:
        fa.store_line(_csv_format_header())
        _csv_headers_written[path] = true
    fa.store_line(_csv_format_row(record))
    fa.close()
    return true

func _csv_format_header() -> String:
    var parts: Array[String] = []
    for col in _COLUMNS:
        parts.append(_csv_escape(String(col)))
    return ",".join(parts)

func _csv_format_row(record: Dictionary) -> String:
    var parts: Array[String] = []
    for col in _COLUMNS:
        var value = record.get(col, "")
        parts.append(_csv_escape(str(value)))
    return ",".join(parts)

func _csv_escape(value: String) -> String:
    if value.find(",") == -1 and value.find("\"") == -1 and value.find("\n") == -1 and value.find("\r") == -1:
        return value
    return "\"%s\"" % value.replace("\"", "\"\"")

func _csv_path_for(shard_index: int) -> String:
    var base := String(output_dir)
    while base.length() > 0 and (base.ends_with("/") or base.ends_with("\\")):
        base = base.substr(0, base.length() - 1)
    if base == "":
        base = String(output_dir)
    return "%s/%s_%03d.csv" % [base, shard_name_prefix, int(shard_index)]

func _write_parquet_row(_shard_index: int, _record: Dictionary) -> void:
    if _parquet_warning_emitted:
        return
    push_warning("QuicklookWriter: Parquet output not yet implemented; CSV rollup written")
    _parquet_warning_emitted = true

func _join_ids(arr) -> String:
    if arr == null:
        return ""
    if arr is PackedStringArray:
        return ";".join(arr as PackedStringArray)
    if arr is Array:
        var parts: Array[String] = []
        for val in arr:
            parts.append(String(val))
        return ";".join(parts)
    return String(arr)

func _ensure_dir(path: String) -> bool:
    var trimmed := String(path).strip_edges()
    if trimmed == "":
        return false
    var err := DirAccess.make_dir_recursive_absolute(trimmed)
    if err == OK:
        return true
    return DirAccess.dir_exists_absolute(trimmed)

func _int_from(src: Dictionary, key: String, default_value: int = 0) -> int:
    if src == null or not src.has(key):
        return default_value
    var v = src[key]
    if v is int:
        return v
    if v is float:
        return int(round(v))
    var s := str(v)
    if s.is_valid_int():
        return int(s)
    if s.is_valid_float():
        return int(round(float(s)))
    return default_value

func _float_from(src: Dictionary, key: String, default_value: float) -> float:
    if src == null or not src.has(key):
        return default_value
    var v = src[key]
    if v is float:
        return v
    if v is int:
        return float(v)
    var s := str(v)
    if s.is_valid_float():
        return float(s)
    if s.is_valid_int():
        return float(int(s))
    return default_value

func reset_state() -> void:
    _csv_headers_written.clear()
    _parquet_warning_emitted = false
