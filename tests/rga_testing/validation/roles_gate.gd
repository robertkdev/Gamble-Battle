extends Node

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")
const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const MetricRegistry := preload("res://tests/rga_testing/metrics/metric_registry.gd")
const RoleMetricsContextBuilder := preload("res://tests/rga_testing/metrics/_shared/context_builder.gd")
const UnitStatLint := preload("res://tests/lint/unit_stat_lint.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var success: bool = true
	var lint: Node = UnitStatLint.new()
	var lint_issues: Array[String] = lint.scan()
	if lint_issues.size() > 0:
		for issue in lint_issues:
			printerr("UnitStatLint:", issue)
		_quit(1)
		return

	var args: PackedStringArray = OS.get_cmdline_user_args()
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

	# Pipeline execution is handled below based on provided intents.

	# Build metrics context from NDJSON
	var intents_raw := String(extras.get("intents", ""))
	var intent_paths := _split_intents(intents_raw)

	# Run pipeline once per intent path to accumulate combined NDJSON
	if intent_paths.size() <= 1:
		# Guidance: suggest combined profile or explicit intents for better coverage
		print("RolesGate: hint — for multi-intent coverage, use --profile=rga_roles_mix or pass --intents=res://tests/rga_testing/config/intents/roles/tank_neutral.json,res://tests/rga_testing/config/intents/roles/tank_counter.json,res://tests/rga_testing/config/intents/roles/kite_poke.json")
		print("RolesGate: executing pipeline with", settings.to_dict())
		var pipeline := HeadlessSimPipeline.new()
		var rows_written := pipeline.run_all(settings)
		if rows_written <= 0:
			printerr("RolesGate: pipeline produced no rows")
			_quit(1)
			return
	else:
		for p in intent_paths:
			var settings2 := RGASettings.new()
			settings2.from_dict(settings.to_dict())
			settings2.metadata = {"scenario_intents": p}
			print("RolesGate: executing pipeline (intent=", p, ") with", settings2.to_dict())
			var pipeline2 := HeadlessSimPipeline.new()
			var rows_written2 := pipeline2.run_all(settings2)
			if rows_written2 <= 0:
				printerr("RolesGate: pipeline produced no rows for intent: ", p)

	# Build metrics context from all NDJSON in output directory (combined)
	var read_path := _resolve_read_path(settings.out_path, settings.run_id)
	var ctx := RoleMetricsContextBuilder.build(read_path, TelemetryCapabilities.all_caps(), "")
	if not bool(ctx.get("ok", true)):
		var missing = ctx.get("missing_caps", [])
		if missing is Array and missing.size() > 0:
			printerr("RolesGate: missing capabilities in telemetry:", ", ".join(missing))
			# Do not hard-fail here; metrics can still skip if unsupported

	# Determine available caps for metrics
	var caps_present := PackedStringArray(ctx.get("caps_present", []))
	# Filter metrics to role_* ids via registry listing
	var role_ids := _list_role_metric_ids()
	if role_ids.is_empty():
		printerr("RolesGate: no role_* metrics found to execute")
		_quit(1)
		return

	var result := MetricRegistry.run_all(caps_present, ctx, role_ids)
	_print_summary(result)
	success = bool(result.get("passed", false))
	_cleanup_runtime()
	_quit(0 if success else 1)

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
		print("RolesGate: PASS (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")
	else:
		printerr("RolesGate: FAIL (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")
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
		"rga_roles_mix":
			return "res://tests/rga_testing/config/profiles/rga_roles_mix.json"
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

func _split_intents(s: String) -> PackedStringArray:
	var src := String(s).strip_edges()
	if src == "":
		return PackedStringArray([])
	var parts: PackedStringArray = []
	for tok in src.split(","):
		var t := String(tok).strip_edges()
		if t != "":
			parts.append(t)
	return parts

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

func _quit(code: int) -> void:
	if get_tree():
		get_tree().quit(code)

func _cleanup_runtime() -> void:
	# Light cleanup to reduce noisy leak warnings in headless runs.
	# Drop references and give the engine a moment to process disconnects.
	# Note: Most collectors/kernels already implement detach() and null refs.
	# This function is a best-effort hint.
	OS.low_processor_usage_mode = false
	# Explicitly hint at processing pending deletes; avoid yields to keep CLI snappy.
	# Locals fall out of scope here, but we ensure a small idle to finish deferred frees.
	# In headless, a short delay is enough without blocking shutdown pipelines.
	OS.delay_msec(1)
