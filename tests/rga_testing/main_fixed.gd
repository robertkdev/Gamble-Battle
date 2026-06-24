extends Node

# RGA Testing - Main scene script
# Purpose: parse settings, run the headless pipeline, and exit.

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")
const ProfileSettings := preload("res://tests/rga_testing/config/profile_settings.gd")
const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const RoleMetricsContextBuilder := preload("res://tests/rga_testing/metrics/_shared/context_builder.gd")
const MetricRegistry := preload("res://tests/rga_testing/metrics/metric_registry.gd")
const RolesThresholdsChecker := preload("res://tests/rga_testing/metrics/roles/thresholds_checker.gd")

@export var use_editor_params: bool = true
@export var profile_settings: ProfileSettings

var settings: RGASettings = RGASettings.new()

func _ready() -> void:
	# Defer to ensure OS args are available and scene is fully loaded
	call_deferred("_run")

func _run() -> void:
	# Use only user-provided args (after "--") so editor defaults apply
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var extras: Dictionary
	var use_editor := (args.size() == 0 and bool(use_editor_params))
	if use_editor:
		extras = _build_editor_extras()
	else:
		extras = _parse_kv(args)

	var profile_name := String(extras.get("profile", "")).strip_edges().to_lower()
	var base_path := String(extras.get("config", "")).strip_edges()
	var cli_cfg := _cli_to_settings_dict(extras)
	var profile_path := _resolve_profile_path(profile_name)

	var merged := RGAConfigLoader.merge_all(
		RGAConfigLoader.load_config(base_path),
		RGAConfigLoader.load_config(profile_path),
		cli_cfg
	)
	settings.from_dict(merged)

	print("RGATesting: starting pipeline with settings: ", settings.to_dict())
	# Early thresholds sanity: warn if required keys are missing
	if RolesThresholdsChecker != null:
		RolesThresholdsChecker.check_and_warn()
	var pipeline := HeadlessSimPipeline.new()
	var rows := pipeline.run_all(settings)
	print("RGATesting: completed. rows=", rows, " out=", settings.out_path)

	# Optional: run role_* metrics (e.g., Tank identity) after pipeline if enabled in editor.
	if profile_settings != null and bool(profile_settings.run_roles_metrics):
		_run_roles_metrics(extras)
	if get_tree():
		get_tree().quit()

func _build_editor_extras() -> Dictionary:
	var out := {}
	if profile_settings != null:
		if String(profile_settings.profile) != "":
			out["profile"] = String(profile_settings.profile)
		var overrides: Dictionary = profile_settings.to_cli_dict()
		for k in overrides.keys():
			out[k] = overrides[k]
	return out

func _run_roles_metrics(extras: Dictionary) -> void:
	# Determine scenario hint from intents path (editor override if present)
	var intents_path := String(extras.get("intents", ""))
	var scenario_hint := _scenario_hint_from_path(intents_path)
	# Build metrics context from telemetry output
	var read_path := _resolve_read_path(settings.out_path, settings.run_id)
	var ctx := RoleMetricsContextBuilder.build(read_path, TelemetryCapabilities.all_caps(), scenario_hint)
	var caps_present := PackedStringArray(ctx.get("caps_present", []))
	# Decide which metrics to run: explicit IDs, else all role_*
	var ids: Array = []
	var raw_ids := String(profile_settings.role_metric_ids).strip_edges()
	if raw_ids != "":
		for part in raw_ids.split(",", false):
			var id := String(part).strip_edges()
			if id != "":
				ids.append(id)
	else:
		ids = _list_role_metric_ids()
	var result := MetricRegistry.run_all(caps_present, ctx, ids)
	_print_summary(result)

func _list_role_metric_ids() -> Array:
	var descs := MetricRegistry.list_metrics([])
	var out: Array = []
	for d in descs:
		var id := String(d.get("id", ""))
		if id.begins_with("role_"):
			out.append(id)
	return out

func _print_summary(result: Dictionary) -> void:
	var passed_all: bool = bool(result.get("passed", false))
	var failed: int = int(result.get("failed_count", 0))
	var skipped: int = int(result.get("skipped_count", 0))
	var errors: int = int(result.get("error_count", 0))
	var metrics: Array = result.get("metrics", [])
	if passed_all:
		print("RolesMetrics: PASS (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")
	else:
		printerr("RolesMetrics: FAIL (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")
		for m in metrics:
			var status := String(m.get("status", "pass"))
			if status != "pass":
				printerr("  ", m.get("id"), " -> ", status, " :: ", String(m.get("message", "")))

func _resolve_read_path(base: String, run_id: String) -> String:
	var root := String(base)
	if root.strip_edges() == "":
		root = "user://rga_out"
	var s := root.to_lower()
	# If explicit file (jsonl/ndjson), return it; else compute run directory
	if s.ends_with(".jsonl") or s.ends_with(".ndjson"):
		return root
	var rid := String(run_id)
	if rid.strip_edges() == "":
		rid = "default"
	var dir := "%s/run_%s" % [root.rstrip("/\\"), rid]
	_check_dir(dir)
	return dir

func _check_dir(path: String) -> bool:
	var trimmed := String(path).strip_edges()
	if trimmed == "":
		return false
	var err := DirAccess.make_dir_recursive_absolute(trimmed)
	if err == OK:
		return true
	return DirAccess.dir_exists_absolute(trimmed)

func _scenario_hint_from_path(p: String) -> String:
	var s := String(p).strip_edges().to_lower()
	if s == "":
		return ""
	if s.find("neutral") >= 0:
		return "neutral"
	if s.find("counter") >= 0:
		return "counter"
	return ""

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
		"rga_roles_base":
			return "res://tests/rga_testing/config/profiles/rga_roles_base.json"
		"rga_roles_derived":
			return "res://tests/rga_testing/config/profiles/rga_roles_derived.json"
		_:
			return ""

func _cli_to_settings_dict(kv: Dictionary) -> Dictionary:
	var d := {}
	var keys := ["run_id", "sim_seed_start", "deterministic", "team_sizes", "repeats", "timeout", "abilities", "ability_metrics", "out", "aggregates_only", "include_swapped"]
	for key in keys:
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
	if kv.has("intents"):
		d["metadata"] = {"scenario_intents": kv["intents"]}
	return d

func _map_key(k: String) -> String:
	match k:
		"timeout":
			return "timeout_s"
		"out":
			return "out_path"
		_:
			return k

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
