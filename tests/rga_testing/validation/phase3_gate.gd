extends Node
class_name Phase3Gate

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")
const RGAScenarioBuilder := preload("res://tests/rga_testing/teams/scenario_builder.gd")
const RGAArchetypeCatalog := preload("res://tests/rga_testing/teams/archetype_catalog.gd")
const RGAProvenance := preload("res://tests/rga_testing/core/provenance.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
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

    print("Phase3Gate: pipeline settings", settings.to_dict())
    var pipeline := HeadlessSimPipeline.new()
    var rows := pipeline.run_all(settings)
    var success := true
    if rows <= 0:
        printerr("Phase3Gate: pipeline produced no rows")
        success = false

    success = _validate_scenario_jobs(settings) and success

    var run_dir := _run_dir_for(settings.out_path, settings.run_id)
    var telemetry_files := _collect_shard_files(run_dir)
    if telemetry_files.is_empty():
        printerr("Phase3Gate: no telemetry shards under", run_dir)
        success = false
    else:
        success = _validate_provenance(run_dir, telemetry_files, settings.run_id) and success
        success = _validate_shard_outputs(run_dir, telemetry_files) and success

    if get_tree():
        get_tree().quit(success ? 0 : 1)

func _validate_scenario_jobs(settings: RGASettings) -> bool:
    var builder := RGAScenarioBuilder.new()
    var catalog := RGAArchetypeCatalog.new()
    var archetypes := catalog.list_ids()
    var intents := (settings.metadata.get("scenario_intents", []) if settings.metadata != null else [])
    if intents is String:
        var parsed := JSON.parse_string(intents)
        if typeof(parsed) == TYPE_ARRAY:
            intents = parsed
        else:
            intents = []
    var jobs := builder.build(settings, intents)
    var expected_counts: Dictionary = settings.metadata.get("expected_job_counts", {}) if settings.metadata != null else {}
    if expected_counts.is_empty():
        print("Phase3Gate: no expected job counts provided; skipping archetype×map validation")
        return true
    var counts: Dictionary = {}
    for job in jobs:
        if not (job is DataModels.SimJob):
            continue
        var map_id := String(job.scenario_id)
        var arch_a := job.metadata.get("team_a_archetype", "") if job.metadata != null else ""
        var arch_b := job.metadata.get("team_b_archetype", "") if job.metadata != null else ""
        var key := "%s|%s|%s" % [map_id, arch_a, arch_b]
        counts[key] = int(counts.get(key, 0)) + 1
    var ok := true
    for key in expected_counts.keys():
        var want := int(expected_counts[key])
        var have := int(counts.get(key, 0))
        if have != want:
            printerr("Phase3Gate: scenario job count mismatch", key, "expected", want, "got", have)
            ok = false
    return ok

func _validate_provenance(run_dir: String, files: Array[String], run_id: String) -> bool:
    var ok := true
    for file in files:
        var fa := FileAccess.open(file, FileAccess.READ)
        if fa == null:
            printerr("Phase3Gate: cannot open shard", file)
            ok = false
            continue
        while not fa.eof_reached():
            var line := fa.get_line()
            if line.strip_edges() == "":
                continue
            var obj := JSON.parse_string(line)
            if typeof(obj) != TYPE_DICTIONARY:
                printerr("Phase3Gate: invalid JSON entry in", file)
                ok = false
                continue
            var aggregates := obj.get("aggregates", {})
            if aggregates == null or not aggregates.has("provenance"):
                printerr("Phase3Gate: missing provenance in", file)
                ok = false
                continue
            var prov := aggregates.get("provenance", {})
            if String(prov.get("run_id", "")) != run_id:
                printerr("Phase3Gate: provenance run_id mismatch", prov)
                ok = false
            if not prov.has("sim_index") or not prov.has("sim_seed"):
                printerr("Phase3Gate: provenance missing sim index/seed", prov)
                ok = false
        fa.close()
    return ok

func _validate_shard_outputs(run_dir: String, files: Array[String]) -> bool:
    var ok := true
    for i in range(files.size()):
        var name := files[i].get_file()
        if not name.begins_with("shard_") or not name.ends_with(".jsonl"):
            printerr("Phase3Gate: unexpected shard naming", files[i])
            ok = false
    return ok

func _collect_shard_files(run_dir: String) -> Array[String]:
    var out: Array[String] = []
    var dir := DirAccess.open(run_dir)
    if dir == null:
        return out
    dir.list_dir_begin()
    while true:
        var entry := dir.get_next()
        if entry == "":
            break
        if dir.current_is_dir():
            continue
        if entry.ends_with(".jsonl"):
            out.append("%s/%s" % [run_dir, entry])
    dir.list_dir_end()
    out.sort()
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

# --- CLI helpers (same as other gates) -----------------------------------
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
