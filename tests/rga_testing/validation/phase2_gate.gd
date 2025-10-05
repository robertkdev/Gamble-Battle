extends Node
class_name Phase2Gate

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")
const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const RGAInvariants := preload("res://tests/rga_testing/core/invariants.gd")
const MetricRegistry := preload("res://tests/rga_testing/metrics/metric_registry.gd")
const GoldenScenarios := preload("res://tests/rga_testing/validation/golden_scenarios.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var success := true
    var args := OS.get_cmdline_user_args()
    var extras := _parse_kv(args)

    var profile_path := _resolve_profile_path(String(extras.get("profile", "")))
    var base_path := String(extras.get("config", ""))
    var cli_cfg := _cli_to_settings_dict(extras)

    var merged := RGAConfigLoader.merge_all(
        RGAConfigLoader.load_config(base_path),
        RGAConfigLoader.load_config(profile_path),
        cli_cfg
    )
    var settings := RGASettings.new()
    settings.from_dict(merged)

    print("Phase2Gate: executing pipeline with settings", settings.to_dict())
    var pipeline := HeadlessSimPipeline.new()
    var rows_written := pipeline.run_all(settings)
    if rows_written <= 0:
        printerr("Phase2Gate: pipeline produced no rows")
        success = false

    var run_dir := _run_dir_for(settings.out_path, settings.run_id)
    var rows := _load_telemetry_rows(run_dir)
    if rows.size() == 0:
        printerr("Phase2Gate: no telemetry rows found under", run_dir)
        success = false
    else:
        success = _verify_event_families(rows) and success
        success = _run_invariants(rows) and success

    success = _run_golden_scenarios() and success
    success = _run_metric_tests() and success

    if get_tree():
        get_tree().quit(success ? 0 : 1)

# --- Event verification --------------------------------------------------
func _verify_event_families(rows: Array[DataModels.TelemetryRow]) -> bool:
    var required_caps := [TelemetryCapabilities.CAP_CC, TelemetryCapabilities.CAP_TARGETS, TelemetryCapabilities.CAP_MOBILITY]
    var required_kinds := {
        "cc": ["cc_applied", "cc_refresh", "cc_expired"],
        "targets": ["target_start", "target_end"],
        "positions": ["position_updated"],
        "casts": ["ability_cast", "spell_cast"]
    }
    var present_caps: Dictionary = {}
    var present_kinds: Dictionary = {}
    var any_events := false
    for row in rows:
        if row.context != null:
            for cap in row.context.capabilities:
                present_caps[String(cap)] = true
        if row.events != null and row.events.size() > 0:
            any_events = true
            for evt in row.events:
                if evt is Dictionary:
                    var kind := String(evt.get("kind", ""))
                    if kind != "":
                        present_kinds[kind] = true
    var ok := true
    if not any_events:
        printerr("Phase2Gate: telemetry rows contained no events")
        ok = false
    for cap in required_caps:
        if not present_caps.has(cap):
            printerr("Phase2Gate: missing capability in telemetry context", cap)
            ok = false
    for family in required_kinds.keys():
        var list: Array = required_kinds[family]
        var satisfied := false
        for kind in list:
            if present_kinds.has(kind):
                satisfied = true
                break
        if not satisfied:
            printerr("Phase2Gate: missing event family", family, " expected kinds=", list)
            ok = false
    return ok

# --- Invariants ----------------------------------------------------------
func _run_invariants(rows: Array[DataModels.TelemetryRow]) -> bool:
    var ok := true
    for row in rows:
        var issues := RGAInvariants.validate(row)
        if issues.size() > 0:
            ok = false
            printerr("Phase2Gate: invariants failed for sim", (row.context.sim_index if row.context else -1))
            for issue in issues:
                printerr("  ", issue)
    return ok

# --- Golden scenarios ----------------------------------------------------
func _run_golden_scenarios() -> bool:
    var script := GoldenScenarios.new()
    var ok := true
    if script.has_method("_test_stun_vs_tenacity"):
        ok = script._test_stun_vs_tenacity() and ok
    if script.has_method("_test_peel_displacement_timing"):
        ok = script._test_peel_displacement_timing() and ok
    if ok:
        print("Phase2Gate: golden scenarios PASS")
    else:
        printerr("Phase2Gate: golden scenarios FAILED")
    return ok

# --- Metrics -------------------------------------------------------------
func _run_metric_tests() -> bool:
    var caps := TelemetryCapabilities.all_caps()
    var result := MetricRegistry.run_all(caps, {}, [])
    if not bool(result.get("passed", false)):
        printerr("Phase2Gate: metric tests failed")
        var metrics := result.get("metrics", [])
        for m in metrics:
            if m.get("status", "pass") != "pass":
                printerr("  metric", m.get("id"), "status", m.get("status"), "message", m.get("message"))
        return false
    print("Phase2Gate: metric registry PASS")
    return true

# --- Telemetry loading helpers ------------------------------------------
func _load_telemetry_rows(run_dir: String) -> Array[DataModels.TelemetryRow]:
    var rows: Array[DataModels.TelemetryRow] = []
    var dir := DirAccess.open(run_dir)
    if dir == null:
        return rows
    dir.list_dir_begin()
    while true:
        var name := dir.get_next()
        if name == "":
            break
        if dir.current_is_dir():
            continue
        if not name.ends_with(".jsonl"):
            continue
        var path := "%s/%s" % [run_dir, name]
        var fa := FileAccess.open(path, FileAccess.READ)
        if fa == null:
            continue
        while not fa.eof_reached():
            var line := fa.get_line()
            if line.strip_edges() == "":
                continue
            var parsed := JSON.parse_string(line)
            if typeof(parsed) == TYPE_DICTIONARY:
                rows.append(_dict_to_row(parsed))
        fa.close()
    dir.list_dir_end()
    return rows

func _dict_to_row(data: Dictionary) -> DataModels.TelemetryRow:
    var row := DataModels.TelemetryRow.new()
    row.schema_version = String(data.get("schema_version", ""))
    row.context = _dict_to_context(data.get("context", {}))
    row.engine_outcome = _dict_to_outcome(data.get("engine_outcome", {}))
    row.aggregates = data.get("aggregates", {})
    var events = data.get("events", [])
    row.events = (events if events is Array else [])
    return row

func _dict_to_context(d: Dictionary) -> DataModels.MatchContext:
    var ctx := DataModels.MatchContext.new()
    if d == null:
        return ctx
    ctx.run_id = String(d.get("run_id", ""))
    ctx.sim_index = int(d.get("sim_index", 0))
    ctx.sim_seed = int(d.get("sim_seed", 0))
    ctx.engine_version = String(d.get("engine_version", ""))
    ctx.asset_hash = String(d.get("asset_hash", ""))
    ctx.scenario_id = String(d.get("scenario_id", ""))
    ctx.map_id = String(d.get("map_id", ""))
    ctx.map_params = d.get("map_params", {})
    ctx.team_a_ids = _string_array(d.get("team_a_ids", []))
    ctx.team_b_ids = _string_array(d.get("team_b_ids", []))
    ctx.team_size = int(d.get("team_size", 1))
    ctx.tile_size = float(d.get("tile_size", 1.0))
    ctx.arena_bounds = _dict_to_rect(d.get("arena_bounds", {}))
    ctx.spawn_a = _array_to_vec2(d.get("spawn_a", []))
    ctx.spawn_b = _array_to_vec2(d.get("spawn_b", []))
    ctx.capabilities = PackedStringArray(_string_array(d.get("capabilities", [])))
    return ctx

func _dict_to_outcome(d: Dictionary) -> DataModels.EngineOutcome:
    var o := DataModels.EngineOutcome.new()
    if d == null:
        return o
    o.result = String(d.get("result", ""))
    o.reason = String(d.get("reason", ""))
    o.time_s = float(d.get("time_s", 0.0))
    o.frames = int(d.get("frames", 0))
    o.team_a_alive = int(d.get("team_a_alive", 0))
    o.team_b_alive = int(d.get("team_b_alive", 0))
    return o

func _string_array(value) -> Array[String]:
    var out: Array[String] = []
    if value is Array:
        for v in value:
            out.append(String(v))
    elif value is PackedStringArray:
        for v in value:
            out.append(String(v))
    elif value != null:
        out.append(String(value))
    return out

func _dict_to_rect(d: Dictionary) -> Rect2:
    if d == null:
        return Rect2()
    return Rect2(Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0))), Vector2(float(d.get("w", 0.0)), float(d.get("h", 0.0))))

func _array_to_vec2(list) -> Array[Vector2]:
    var out: Array[Vector2] = []
    if list == null:
        return out
    if list is Array:
        for v in list:
            if v is Array and v.size() >= 2:
                out.append(Vector2(float(v[0]), float(v[1])))
    return out

func _run_dir_for(base: String, run_id: String) -> String:
    var root := String(base)
    while root.ends_with("/") or root.ends_with("\\"):
        root = root.substr(0, root.length() - 1)
    if root == "":
        root = "user://rga_out"
    var rid := String(run_id)
    if rid.strip_edges() == "":
        rid = "default"
    var dir := "%s/run_%s" % [root, rid]
    _check_dir(dir)
    return dir

# --- CLI helpers ---------------------------------------------------------
func _cli_to_settings_dict(kv: Dictionary) -> Dictionary:
    var d := {}
    for key in ["run_id", "sim_seed_start", "deterministic", "team_sizes", "repeats", "timeout", "abilities", "ability_metrics", "out", "aggregates_only", "include_swapped"]:
        if kv.has(key):
            d[_map_key(key)] = kv[key]
    if kv.has("role"):
        d["role_filter"] = kv["role"]
    if kv.has("goal"):
        d["goal_filter"] = kv["goal"]
    if kv.has("approach"):
        d["approach_filter"] = kv["approach"]
    if kv.has("cost"):
        d["cost_filter"] = kv["cost"]
    if kv.has("ids"):
        d["ids"] = kv["ids"]
    return d

func _map_key(k: String) -> String:
    match k:
        "timeout":
            return "timeout_s"
        "out":
            return "out_path"
        _:
            return k

func _resolve_profile_path(name: String) -> String:
    var n := String(name).strip_edges().to_lower()
    if n == "" or n == "none":
        return ""
    if n.ends_with(".json") or n.ends_with(".tres") or n.find("//") >= 0 or n.find("/") >= 0 or n.find("\\") >= 0:
        return n
    match n:
        "designer_quick":
            return "res://tests/rga_testing/config/profiles/designer_quick.json"
        "ci_full":
            return "res://tests/rga_testing/config/profiles/ci_full.json"
        _:
            return ""

func _parse_kv(argv: PackedStringArray) -> Dictionary:
    var out := {}
    var seen_sep := false
    for a in argv:
        if a == "--":
            seen_sep = true
            continue
        var s := String(a)
        if (not seen_sep) and (not s.contains("=")):
            continue
        var parts := s.split("=", false, 2)
        if parts.size() == 2:
            out[parts[0].lstrip("-")] = parts[1]
    return out

func _check_dir(path: String) -> bool:
    var trimmed := String(path).strip_edges()
    if trimmed == "":
        return false
    var err := DirAccess.make_dir_recursive_absolute(trimmed)
    if err == OK:
        return true
    return DirAccess.dir_exists_absolute(trimmed)
