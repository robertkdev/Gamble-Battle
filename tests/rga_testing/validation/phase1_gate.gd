extends Node
class_name Phase1Gate

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")
const RGAInvariants := preload("res://tests/rga_testing/core/invariants.gd")
const BalanceRunnerReader := preload("res://tests/rga_testing/io/br_csv_reader.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var exit_code := 0
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

    print("Phase1Gate: running pipeline with settings", settings.to_dict())
    var pipeline := HeadlessSimPipeline.new()
    var rows_written := pipeline.run_all(settings)
    if rows_written <= 0:
        printerr("Phase1Gate: pipeline produced no rows")
        success = false

    var run_dir := _run_dir_for(settings.out_path, settings.run_id)
    var telemetry_rows := _load_telemetry_rows(run_dir)
    if telemetry_rows.size() == 0:
        printerr("Phase1Gate: no telemetry rows found under", run_dir)
        success = false
    else:
        print("Phase1Gate: telemetry rows=", telemetry_rows.size())

    success = _run_invariants(telemetry_rows) and success

    var br_csv := String(extras.get("br_csv", "")).strip_edges()
    if br_csv == "":
        printerr("Phase1Gate: --br_csv=<path> required for parity gate")
        success = false
    else:
        var parity_ok := _run_balance_runner_parity(settings, br_csv, extras)
        success = parity_ok and success

    exit_code = (0 if success else 1)
    if get_tree():
        get_tree().quit(exit_code)

func _run_invariants(rows: Array[DataModels.TelemetryRow]) -> bool:
    var all_ok := true
    for row in rows:
        var issues := RGAInvariants.validate(row)
        if issues.size() > 0:
            all_ok = false
            printerr("Phase1Gate: invariants failed for sim", row.context.sim_index if row.context else -1)
            for issue in issues:
                printerr("  ", issue)
    return all_ok

func _run_balance_runner_parity(settings: RGASettings, br_csv: String, extras: Dictionary) -> bool:
    var rows := BalanceRunnerReader.read_rows(br_csv)
    if rows.is_empty():
        printerr("Phase1Gate: BalanceRunner CSV empty", br_csv)
        return false
    if settings.ids.is_empty():
        settings.ids = [{"a":"sari","b":"paisley"}, {"a":"nyxa","b":"volt"}]
    var repeats := max(1, int(settings.repeats))
    var timeout_s := float(settings.timeout_s)
    var abilities := bool(settings.abilities)
    var seed_start := int(settings.sim_seed_start)
    var tol_win := float(extras.get("tol_win_pct", 0.02))
    var tol_time := float(extras.get("tol_time_s", 0.10))
    var tol_dmg_rel := float(extras.get("tol_damage_rel", 0.03))
    var all_ok := true
    for pair in settings.ids:
        if not (pair is Dictionary):
            continue
        var a_id := String(pair.get("a", ""))
        var b_id := String(pair.get("b", ""))
        if a_id == "" or b_id == "":
            continue
        var ours := _run_pair(a_id, b_id, repeats, timeout_s, abilities, seed_start)
        var br := _find_br_row(rows, a_id, b_id)
        if br.is_empty():
            printerr("Phase1Gate: missing BalanceRunner row for", a_id, "vs", b_id)
            all_ok = false
            continue
        var ok := _compare_metrics(a_id, b_id, ours, br, tol_win, tol_time, tol_dmg_rel)
        all_ok = all_ok and ok
    return all_ok

func _run_pair(a_id: String, b_id: String, repeats: int, timeout_s: float, abilities: bool, seed0: int) -> Dictionary:
    var stats := {
        "matches_total": 0,
        "a_wins": 0, "b_wins": 0, "draws": 0,
        "a_time_sum": 0.0, "b_time_sum": 0.0,
        "a_damage_sum": 0.0, "b_damage_sum": 0.0
    }
    var idx := 0
    for r in range(repeats):
        var job1 := _make_job(a_id, b_id, timeout_s, abilities, seed0 + idx); idx += 1
        var out1 := _run_sim(job1)
        _accumulate(stats, out1, true)

        var job2 := _make_job(b_id, a_id, timeout_s, abilities, seed0 + idx); idx += 1
        var out2 := _run_sim(job2)
        _accumulate(stats, out2, false)
    return _summarize(stats)

func _make_job(a_id: String, b_id: String, timeout_s: float, abilities: bool, seed: int) -> DataModels.SimJob:
    var job := DataModels.SimJob.new()
    job.run_id = "phase1_gate"
    job.sim_index = seed
    job.seed = seed
    job.team_a_ids = [a_id]
    job.team_b_ids = [b_id]
    job.team_size = 1
    job.timeout_s = timeout_s
    job.abilities = abilities
    job.deterministic = true
    job.delta_s = 0.05
    job.bridge_projectile_to_hit = true
    job.capabilities = PackedStringArray(["base"])
    return job

func _run_sim(job: DataModels.SimJob) -> Dictionary:
    var sim := LockstepSimulator.new()
    var collector := CombatStatsCollector.new()
    return sim.run(job, false, collector)

func _accumulate(acc: Dictionary, sim_out: Dictionary, attacker_is_team_a: bool) -> void:
    var outcome = sim_out.get("engine_outcome", null)
    var aggregates: Dictionary = sim_out.get("aggregates", {})
    var teams: Dictionary = aggregates.get("teams", {})
    var a: Dictionary = teams.get("a", {})
    var b: Dictionary = teams.get("b", {})
    acc.matches_total += 1
    var win_side := ""
    if outcome != null:
        win_side = String(outcome.result)
    if win_side == "team_a":
        if attacker_is_team_a:
            acc.a_wins += 1
            acc.a_time_sum += float(outcome.time_s)
        else:
            acc.b_wins += 1
            acc.b_time_sum += float(outcome.time_s)
    elif win_side == "team_b":
        if attacker_is_team_a:
            acc.b_wins += 1
            acc.b_time_sum += float(outcome.time_s)
        else:
            acc.a_wins += 1
            acc.a_time_sum += float(outcome.time_s)
    else:
        acc.draws += 1
    var dmg_a := int(a.get("damage", 0))
    var dmg_b := int(b.get("damage", 0))
    if attacker_is_team_a:
        acc.a_damage_sum += dmg_a
        acc.b_damage_sum += dmg_b
    else:
        acc.a_damage_sum += dmg_b
        acc.b_damage_sum += dmg_a

func _summarize(acc: Dictionary) -> Dictionary:
    var total := max(1, int(acc.matches_total))
    var a_wins := int(acc.a_wins)
    var b_wins := int(acc.b_wins)
    return {
        "attacker_win_pct": float(a_wins) / float(total),
        "defender_win_pct": float(b_wins) / float(total),
        "draw_pct": float(int(acc.draws)) / float(total),
        "attacker_avg_time_to_win_s": float(acc.a_time_sum) / max(1.0, float(a_wins)),
        "defender_avg_time_to_win_s": float(acc.b_time_sum) / max(1.0, float(b_wins)),
        "attacker_avg_damage_dealt_per_match": float(acc.a_damage_sum) / float(total),
        "defender_avg_damage_dealt_per_match": float(acc.b_damage_sum) / float(total)
    }

func _find_br_row(rows: Array[Dictionary], attacker: String, defender: String) -> Dictionary:
    for r in rows:
        if String(r.get("attacker_id", "")) == attacker and String(r.get("defender_id", "")) == defender:
            return r
    return {}

func _compare_metrics(attacker: String, defender: String, ours: Dictionary, br: Dictionary, tol_win_abs: float, tol_time_abs: float, tol_dmg_rel: float) -> bool:
    var ok := true
    print("Phase1Gate parity:", attacker, "vs", defender)
    ok = _cmp_scalar("attacker_win_pct", ours, br, tol_win_abs, 0.0) and ok
    ok = _cmp_scalar("defender_win_pct", ours, br, tol_win_abs, 0.0) and ok
    ok = _cmp_scalar("attacker_avg_time_to_win_s", ours, br, tol_time_abs, 0.0) and ok
    ok = _cmp_scalar("defender_avg_time_to_win_s", ours, br, tol_time_abs, 0.0) and ok
    ok = _cmp_scalar("attacker_avg_damage_dealt_per_match", ours, br, INF, tol_dmg_rel) and ok
    ok = _cmp_scalar("defender_avg_damage_dealt_per_match", ours, br, INF, tol_dmg_rel) and ok
    return ok

func _cmp_scalar(key: String, ours: Dictionary, br: Dictionary, tol_abs: float, tol_rel: float) -> bool:
    var a := float(ours.get(key, 0.0))
    var b := float(br.get(key, 0.0))
    var diff := abs(a - b)
    var rel := diff / max(1e-6, abs(b))
    var pass := (diff <= tol_abs) or (rel <= tol_rel)
    if not pass:
        printerr("  ", key, ": ours=", a, " br=", b, " diff=", diff, " rel=", rel)
    else:
        print("  ", key, ": ours=", a, " br=", b)
    return pass

# --- Telemetry loading helpers ---
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

# --- CLI helpers ---
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
