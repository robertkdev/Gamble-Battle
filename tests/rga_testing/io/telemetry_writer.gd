extends RefCounted
class_name TelemetryWriter

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const DEFAULT_ROOT := "user://rga_out"
const MAX_ROWS_PER_SHARD := 1000

var output_root: String = DEFAULT_ROOT
var include_events_by_default: bool = false
var rows_per_shard: int = MAX_ROWS_PER_SHARD
var _file_mode: bool = false # when true, write all rows to a single file (output_root)

var _current_run_id: String = ""
var _current_shard_index: int = 0
var _current_row_count: int = 0
var _written_keys: Dictionary = {}

func _init(out_root: String = DEFAULT_ROOT, include_events: bool = false, shard_size: int = MAX_ROWS_PER_SHARD) -> void:
    output_root = out_root
    include_events_by_default = include_events
    rows_per_shard = max(1, shard_size)
    _file_mode = _detect_file_mode(output_root)

func append_row(row: DataModels.TelemetryRow, with_events: Variant = null) -> bool:
    if row == null:
        return false
    var ctx: DataModels.MatchContext = row.context
    var run_id: String = String(ctx.run_id if ctx != null else "default")
    if run_id.strip_edges() == "":
        run_id = "default"
    _ensure_run_state(run_id)

    var key: String = _key_for(ctx)
    if key != "" and _written_keys.has(key):
        return true # idempotent: already written

    if (not _file_mode) and _current_row_count >= rows_per_shard:
        _rotate_shard()

    var include_events: bool = (include_events_by_default if with_events == null else bool(with_events))
    var line_obj: Dictionary = _row_to_dict(row, include_events)
    var line: String = JSON.stringify(line_obj)
    var path: String = _shard_path()
    if not _append_line_atomic(path, line):
        return false

    _current_row_count += 1
    if key != "":
        _written_keys[key] = true
    return true

func append_rows(rows: Array, with_events: Variant = null) -> int:
    var count: int = 0
    for r in rows:
        if r is DataModels.TelemetryRow:
            if append_row(r, with_events):
                count += 1
    return count

func reset_state() -> void:
    _current_run_id = ""
    _current_shard_index = 0
    _current_row_count = 0
    _written_keys.clear()

func _ensure_run_state(run_id: String) -> void:
    if run_id != _current_run_id:
        _current_run_id = run_id
        _current_shard_index = 0
        _current_row_count = 0
        _written_keys.clear()
        if _file_mode:
            _check_dir(_path_dir(output_root))
        else:
            _check_dir(_run_dir())

func _rotate_shard() -> void:
    _current_shard_index += 1
    _current_row_count = 0

func _shard_path() -> String:
    if _file_mode:
        return String(output_root)
    var dir: String = _run_dir()
    var shard_name: String = "shard_%03d.jsonl" % _current_shard_index
    return "%s/%s" % [dir, shard_name]

func _run_dir() -> String:
    return "%s/run_%s" % [String(output_root).rstrip("/\\"), _current_run_id]

func _key_for(ctx: DataModels.MatchContext) -> String:
    if ctx == null:
        return ""
    return "%s|%d" % [String(ctx.run_id), int(ctx.sim_index)]

func _row_to_dict(row: DataModels.TelemetryRow, include_events: bool) -> Dictionary:
    return {
        "schema_version": String(row.schema_version),
        "context": _ctx_to_dict(row.context),
        "engine_outcome": _outcome_to_dict(row.engine_outcome),
        "aggregates": (row.aggregates if row.aggregates != null else {}),
        "events": (row.events if (include_events and row.events != null and row.events.size() > 0) else null)
    }

# -- Helpers for converting DTOs --
func _ctx_to_dict(ctx: DataModels.MatchContext) -> Dictionary:
    if ctx == null:
        return {}
    return {
        "run_id": String(ctx.run_id),
        "sim_index": int(ctx.sim_index),
        "sim_seed": int(ctx.sim_seed),
        "engine_version": String(ctx.engine_version),
        "asset_hash": String(ctx.asset_hash),
        "scenario_id": String(ctx.scenario_id),
        "map_id": String(ctx.map_id),
        "map_params": (ctx.map_params if ctx.map_params != null else {}),
        "team_a_ids": ctx.team_a_ids.duplicate(),
        "team_b_ids": ctx.team_b_ids.duplicate(),
        "team_size": int(ctx.team_size),
        "tile_size": float(ctx.tile_size),
        "arena_bounds": _rect_to_obj(ctx.arena_bounds),
        "spawn_a": _vec2_array(ctx.spawn_a),
        "spawn_b": _vec2_array(ctx.spawn_b),
        "capabilities": (ctx.capabilities if ctx.capabilities != null else [])
    }

func _outcome_to_dict(o: DataModels.EngineOutcome) -> Dictionary:
    if o == null:
        return {}
    return {
        "result": String(o.result),
        "reason": String(o.reason),
        "time_s": float(o.time_s),
        "frames": int(o.frames),
        "team_a_alive": int(o.team_a_alive),
        "team_b_alive": int(o.team_b_alive)
    }

func _vec2_array(arr) -> Array:
    var out: Array = []
    if arr == null:
        return out
    for v in arr:
        if typeof(v) == TYPE_VECTOR2:
            out.append([v.x, v.y])
    return out

func _rect_to_obj(r: Rect2) -> Dictionary:
    return {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y}

# -- File system helpers --
func _append_line_atomic(path: String, line: String) -> bool:
    if path == "":
        push_warning("TelemetryWriter: invalid shard path")
        return false
    if not _check_dir(_path_dir(path)):
        push_warning("TelemetryWriter: cannot create directory for %s" % path)
        return false
    # In single-file mode, append directly to the file (simple and deterministic)
    if _file_mode:
        var existing := FileAccess.file_exists(path)
        var mode := FileAccess.READ_WRITE if existing else FileAccess.WRITE
        var f: FileAccess = FileAccess.open(path, mode)
        if f == null:
            # Handle legacy directory-at-path collisions by removing the directory once
            if DirAccess.dir_exists_absolute(path):
                _remove_dir_recursive(path)
            # Fallback: try WRITE always
            f = FileAccess.open(path, FileAccess.WRITE)
            if f == null:
                push_warning("TelemetryWriter: cannot open file %s" % path)
                return false
        f.seek_end()
        f.store_line(line)
        f.close()
        return true
    var tmp_path: String = "%s.tmp" % path
    var fa: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
    if fa == null:
        push_warning("TelemetryWriter: cannot open temp file %s" % tmp_path)
        return false
    fa.store_line(line)
    fa.close()
    if FileAccess.file_exists(path):
        var target: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
        if target == null:
            push_warning("TelemetryWriter: cannot open existing shard %s" % path)
            DirAccess.remove_absolute(tmp_path)
            return false
        target.seek_end()
        var append_source: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
        if append_source == null:
            target.close()
            DirAccess.remove_absolute(tmp_path)
            push_warning("TelemetryWriter: cannot reopen temp %s" % tmp_path)
            return false
        while not append_source.eof_reached():
            target.store_line(append_source.get_line())
        append_source.close()
        target.close()
        DirAccess.remove_absolute(tmp_path)
        return true
    # No existing file: move temp to final path for atomic create
    var rename_err: int = DirAccess.rename_absolute(tmp_path, path)
    if rename_err != OK:
        push_warning("TelemetryWriter: rename failed %s -> %s" % [tmp_path, path])
        DirAccess.remove_absolute(tmp_path)
        return false
    return true

func _check_dir(path: String) -> bool:
    var trimmed: String = String(path).strip_edges()
    if trimmed == "":
        return false
    var err: int = DirAccess.make_dir_recursive_absolute(trimmed)
    if err == OK:
        return true
    return DirAccess.dir_exists_absolute(trimmed)

func _path_dir(path: String) -> String:
    var idx: int = max(path.rfind("/"), path.rfind("\\"))
    if idx < 0:
        return ""
    var parent := path.substr(0, idx)
    # Normalize Godot resource scheme parents like user:// and res://
    if parent == "user:/":
        return "user://"
    if parent == "res:/":
        return "res://"
    return parent

func _detect_file_mode(path: String) -> bool:
    var s := String(path).strip_edges().to_lower()
    if s == "":
        return false
    # Treat .jsonl or .ndjson paths as single-file destinations
    if s.ends_with(".jsonl") or s.ends_with(".ndjson"):
        return true
    return false

func _remove_dir_recursive(dir_abs_path: String) -> void:
    var d := DirAccess.open(dir_abs_path)
    if d == null:
        DirAccess.remove_absolute(dir_abs_path)
        return
    d.list_dir_begin()
    while true:
        var name := d.get_next()
        if name == "":
            break
        if name == "." or name == "..":
            continue
        var child := dir_abs_path.rstrip("/\\") + "/" + name
        if d.current_is_dir():
            _remove_dir_recursive(child)
        else:
            DirAccess.remove_absolute(child)
    d.list_dir_end()
    DirAccess.remove_absolute(dir_abs_path)
