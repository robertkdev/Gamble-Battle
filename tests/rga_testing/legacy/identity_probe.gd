# DEPRECATED: superseded by RoleMatrixProbe (tests/rga_testing/validation/RoleMatrixProbe.tscn)
extends Node

# Identity Probe Gate
# Runs a targeted matrix for a single unit across multiple scenario labels and seeds,
# writes telemetry rows, then executes all role_* metrics with subject filtering so
# results are per-unit and facets aggregate across runs.

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const TelemetryWriter := preload("res://tests/rga_testing/io/telemetry_writer.gd")
const RoleMetricsContextBuilder := preload("res://tests/rga_testing/metrics/_shared/context_builder.gd")
const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const MetricRegistry := preload("res://tests/rga_testing/metrics/metric_registry.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")
const UnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
var _report_compiler_script: Script = null
const RGAConfigLoader := preload("res://tests/rga_testing/config/config_loader.gd")

@export var default_unit_id: String = ""        # used when no CLI arg provided
@export var default_repeats: int = 6
@export var default_out_path: String = "user://rga_out.jsonl"
@export var write_report: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var kv := _parse_kv(args)
	var subject_id := String(kv.get("unit_id", "")).strip_edges()
	if subject_id == "" and String(default_unit_id) != "":
		subject_id = String(default_unit_id)
	if subject_id == "":
		printerr("IdentityProbe: --unit_id=<id> is required")
		_quit(1)
		return

	# Merge optional profile/config overrides
	var repeats: int = int(default_repeats)
	if kv.has("repeats"):
		repeats = int(String(kv.get("repeats", "0")))
	var dump_json: bool = false
	if kv.has("dump_json"):
		dump_json = bool(kv.get("dump_json"))
	var include_swapped := false
	var sim_seed_start: int = int(String(kv.get("sim_seed_start", "0")))
	var out_root := String(kv.get("out", default_out_path)).strip_edges()
	var prof := String(kv.get("profile", "")).strip_edges()
	var base_cfg_path := String(kv.get("config", "")).strip_edges()
	if prof != "" or base_cfg_path != "":
		var prof_path := _resolve_profile_path(prof)
		var merged := RGAConfigLoader.load_and_merge(base_cfg_path, prof_path, {})
		if merged.has("repeats"): repeats = int(merged.get("repeats", repeats))
		if merged.has("include_swapped"): include_swapped = bool(merged.get("include_swapped", include_swapped))
		if merged.has("sim_seed_start"): sim_seed_start = int(merged.get("sim_seed_start", sim_seed_start))
		if merged.has("out_path"): out_root = String(merged.get("out_path", out_root))
	var run_id := "probe_%s" % subject_id

	# If rows directory/file provided, skip simulation and just read
	var rows_input := String(kv.get("rows", String(kv.get("rows_dir", String(kv.get("rows_path", "")))))).strip_edges()
	var read_path := ""
	if rows_input != "":
		read_path = rows_input
	else:
		# Opponents: select a few units from catalog, excluding the subject
		var opp_limit := 1
		var opponents := _select_opponents(subject_id, max(1, opp_limit))
		if opponents.is_empty():
			printerr("IdentityProbe: no opponents available after excluding subject")
			_quit(1)
			return
		# Prepare writer
		var settings := RGASettings.new()
		settings.run_id = run_id
		settings.out_path = out_root
		var pipeline := HeadlessSimPipeline.new()
		_reset_output_dir(pipeline, out_root, run_id)
		var writer: TelemetryWriter = TelemetryWriter.new(out_root, false)
		# Scenarios: default or map from --intents
		var intents_raw := String(kv.get("intents", "")).strip_edges()
		var scenarios: Array = []
		if intents_raw != "":
			scenarios = _scenarios_from_intents(intents_raw)
		else:
			scenarios = [{"label": "neutral", "map_params": {}}]
		# Subject header with identity snapshot and opponents
		var ident: Dictionary = RoleCommon.get_identity(subject_id)
		var role := String(ident.get("primary_role", ""))
		var goal := String(ident.get("primary_goal", ""))
		var approaches: Array = ident.get("approaches", [])
		var cost: int = int(ident.get("cost", 0))
		var level: int = int(ident.get("level", 0))
		print("subject=", subject_id, " role=", role, " goal=", goal, " approaches=", approaches, " cost=", cost, " level=", level, " vs ", opponents)
		var scenario_labels: Array[String] = []
		for sc in scenarios:
			var lb := String((sc as Dictionary).get("label", ""))
			if lb != "": scenario_labels.append(lb)
		print("scenarios=", scenario_labels)
		# Run matrix
		var sim_idx := 0
		for scen in scenarios:
			var scen_label := String((scen as Dictionary).get("label", "neutral"))
			var mp: Dictionary = (scen as Dictionary).get("map_params", {})
			for opp in opponents:
				for r in range(max(1, repeats)):
					var j1 := _make_job(settings, subject_id, String(opp), sim_idx, sim_seed_start + sim_idx, scen_label, mp)
					sim_idx += 1
					_run_one(writer, pipeline, j1)
					if include_swapped:
						var j2 := _make_job(settings, String(opp), subject_id, sim_idx, sim_seed_start + sim_idx, scen_label, mp)
						sim_idx += 1
						_run_one(writer, pipeline, j2)
		# Build read path from run_id
		read_path = _resolve_read_path(out_root, run_id)
		print("sims=", sim_idx)

	# Build metrics context from rows (point to the first shard file for user:// compatibility)
	var shard0 := "%s/shard_%03d.jsonl" % [read_path, 0]
	var ctx := RoleMetricsContextBuilder.build(shard0, TelemetryCapabilities.all_caps(), "")
	var caps_present := PackedStringArray(ctx.get("caps_present", []))
	print("caps=", caps_present)
	print("rows=", shard0)
	# Gather role_* metric ids (keep narrow for speed; include brawler for debugging)
	var ids: Array = [
		"tank_role_identity",
		"role_brawler_identity"
	]
	# Run metrics with subject filter
	var result := MetricRegistry.run_all(caps_present, ctx, ids, [subject_id])
	_print_summary(subject_id, result)
	if dump_json:
		print(JSON.stringify(result))
	# Emit a richer per-metric summary (with reasons and key details)
	var metrics_out: Array = result.get("metrics", [])
	for m in metrics_out:
		if not (m is Dictionary):
			continue
		var mid := String(m.get("id", ""))
		var st := String(m.get("status", ""))
		var msg := String(m.get("message", ""))
		print("  ", mid, " -> ", st, " :: ", msg)
		# Subject spans, if present
		var spans: Array = m.get("spans", [])
		for s in spans:
			if not (s is Dictionary):
				continue
			var sd: Dictionary = s
			var uid := String(sd.get("unit_id", ""))
			if uid != "" and uid != subject_id:
				continue
			var label := String(sd.get("label", ""))
			var ok := bool(sd.get("ok", false)) if sd.has("ok") else false
			var v = sd.get("value", null)
			var w = sd.get("want", null)
			var reason := String(sd.get("reason", ""))
			var side := String(sd.get("subject_side", String(sd.get("side", ""))))
			var parts: Array[String] = []
			if sd.has("sustained_mult_vs_median"): parts.append("mult=" + _fmt_num(sd.get("sustained_mult_vs_median"), 2))
			if sd.has("sustained_z"): parts.append("z=" + _fmt_num(sd.get("sustained_z"), 2))
			if sd.has("focus_survival_avg_s"): parts.append("focus_s=" + _fmt_num(sd.get("focus_survival_avg_s"), 2))
			if sd.has("time_alive_avg_s"): parts.append("ta_s=" + _fmt_num(sd.get("time_alive_avg_s"), 2))
			if sd.has("soak_index"): parts.append("soak=" + _fmt_num(sd.get("soak_index"), 2))
			var extras := (" [" + ", ".join(parts) + "]" if parts.size() > 0 else "")
			var want_str := (" vs " + _fmt_num(w, 2) if w != null else "")
			var side_str := (" side=" + side if side.strip_edges() != "" else "")
			var reason_str := (" reason=" + reason if reason.strip_edges() != "" else "")
			print("    ", label, ": ", _fmt_num(v, 2), want_str, " -> ", ("OK" if ok else "FAIL"), side_str, reason_str, extras)
			# If thresholds are provided in extras, print readable criteria lines
			var crit: Array[String] = []
			if sd.has("sustained_ok"):
				crit.append("      sustained: " + ("OK" if bool(sd.get("sustained_ok")) else "FAIL"))
			if sd.has("survivability_ok"):
				crit.append("      survivability: " + ("OK" if bool(sd.get("survivability_ok")) else "FAIL"))
			if sd.has("sustained_mult_vs_median") and sd.has("req_mult"):
				crit.append("      sustained.mult: " + _fmt_num(sd.get("sustained_mult_vs_median"), 2) + " >= " + _fmt_num(sd.get("req_mult"), 2))
			if sd.has("sustained_z") and sd.has("req_z"):
				crit.append("      sustained.z: " + _fmt_num(sd.get("sustained_z"), 2) + " >= " + _fmt_num(sd.get("req_z"), 2))
			if sd.has("focus_survival_avg_s") and sd.has("req_focus_s") and sd.get("focus_survival_avg_s") != null:
				crit.append("      focus_survival_s: " + _fmt_num(sd.get("focus_survival_avg_s"), 2) + " >= " + _fmt_num(sd.get("req_focus_s"), 2))
			elif sd.has("time_alive_avg_s") and sd.has("req_time_alive_s"):
				crit.append("      time_alive_s: " + _fmt_num(sd.get("time_alive_avg_s"), 2) + " >= " + _fmt_num(sd.get("req_time_alive_s"), 2))
			if sd.has("soak_index") and (sd.has("req_soak_min") or (sd.has("req_soak_min") and sd.has("req_soak_max"))):
				var smin: Variant = (sd.get("req_soak_min") if sd.has("req_soak_min") else null)
				var smax: Variant = (sd.get("req_soak_max") if sd.has("req_soak_max") else null)
				if smin != null and smax == null:
					crit.append("      soak_index: " + _fmt_num(sd.get("soak_index"), 2) + " >= " + _fmt_num(smin, 2))
				else:
					var rng: String = ("[" + (_fmt_num(smin, 2) if smin != null else "") + ", " + (_fmt_num(smax, 2) if smax != null else "") + "]")
					crit.append("      soak_index: " + _fmt_num(sd.get("soak_index"), 2) + " in " + rng)
			for cl in crit:
				print(cl)

	# Compile and write report (best-effort; disabled unless write_report is true)
	if write_report and _report_compiler_script == null:
		_report_compiler_script = load("res://tests/rga_testing/validation/probe_report_compiler.gd")
	if write_report and _report_compiler_script != null:
		var report: Dictionary = _report_compiler_script.compile(subject_id, ctx, result, {"run_id": run_id, "rows_path": read_path})
		var report_path: String = _report_compiler_script.write(report)
		if report_path != "":
			print("IdentityProbe: report written to ", report_path)
			print(report_path)
		else:
			push_warning("IdentityProbe: failed to write report")
	elif write_report:
		push_warning("IdentityProbe: report compiler unavailable; skipping report write")

	_quit(0 if bool(result.get("passed", false)) else 1)

func _run_one(writer: TelemetryWriter, pipeline: HeadlessSimPipeline, job: DataModels.SimJob) -> void:
	# Create a roles-derived aggregator and run the sim
	var sim := LockstepSimulator.new()
	var collector = pipeline._new_combined_aggregator(true)
	var out: Dictionary = sim.run(job, false, collector)
	# Append telemetry row
	_pipeline_write_row(pipeline, writer, out)

func _make_job(settings: RGASettings, a_id: String, b_id: String, sim_index: int, seed: int, scenario_label: String, mp: Dictionary) -> DataModels.SimJob:
	var j := DataModels.SimJob.new()
	j.run_id = String(settings.run_id)
	j.sim_index = sim_index
	j.seed = seed
	j.team_a_ids = [String(a_id)]
	j.team_b_ids = [String(b_id)]
	j.team_size = 1
	j.scenario_id = "open_field"
	j.map_params = (mp.duplicate(true) if (mp is Dictionary) else {})
	j.deterministic = true
	j.delta_s = 0.05
	j.timeout_s = 120.0
	j.abilities = true
	j.ability_metrics = true
	j.alternate_order = false
	j.bridge_projectile_to_hit = true
	# Ensure roles-derived aggregator is appropriate for this job
	j.capabilities = PackedStringArray(["base", "cc", "targets", "mobility", "zones"])
	# Tag scenario label so relaxations apply
	j.metadata = {"scenario_label": String(scenario_label)}
	return j

func _select_opponents(subject_id: String, limit: int) -> Array:
	var cat := UnitCatalog.new()
	var cfg := RGASettings.new()
	cfg.role_filter = []
	cfg.goal_filter = []
	cfg.approach_filter = []
	cfg.cost_filter = PackedInt32Array([])
	var entries: Array = cat.list(cfg)
	var out: Array = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var uid := String((e as Dictionary).get("id", ""))
		if uid == "" or uid == subject_id:
			continue
		out.append(uid)
		if out.size() >= max(1, int(limit)):
			break
	return out

func _list_role_metrics() -> Array:
	var descs := MetricRegistry.list_metrics([])
	var out: Array = []
	for d in descs:
		var id := String(d.get("id", ""))
		if id.begins_with("role_"):
			out.append(id)
	return out

func _pipeline_write_row(pipeline: HeadlessSimPipeline, writer: TelemetryWriter, sim_out: Dictionary) -> void:
	# Reuse pipeline’s row serialization helper to keep schema consistent
	if pipeline != null and pipeline.has_method("_write_sim_row"):
		pipeline._write_sim_row(writer, sim_out)

func _reset_output_dir(pipeline: HeadlessSimPipeline, out_path: String, run_id: String) -> void:
	if pipeline != null and pipeline.has_method("_reset_output_file"):
		pipeline._reset_output_file(out_path, run_id)

func _resolve_read_path(base: String, run_id: String) -> String:
	var root := String(base)
	if root.strip_edges() == "":
		root = "user://rga_out"
	var s := root.to_lower()
	if s.ends_with(".jsonl") or s.ends_with(".ndjson"):
		return root
	var rid := String(run_id)
	if rid.strip_edges() == "":
		rid = "default"
	return "%s/run_%s" % [root.rstrip("/\\"), rid]

func _resolve_profile_path(name_or_path: String) -> String:
	var s := String(name_or_path).strip_edges()
	if s == "":
		return ""
	if s.find("://") >= 0 or s.ends_with(".json") or s.ends_with(".tres") or s.ends_with(".res"):
		return s
	# Assume shorthand profile id under standard profiles directory
	return "res://tests/rga_testing/config/profiles/%s.json" % s

func _scenarios_from_intents(csv: String) -> Array:
	var labels_set := {}
	for tok in String(csv).split(","):
		var t := String(tok).strip_edges().to_lower()
		if t == "": continue
		if t.find("peel") >= 0:
			labels_set["peel"] = true
		elif t.find("burst") >= 0 or t.find("antiheal") >= 0:
			labels_set["burst"] = true
		elif t.find("counter") >= 0:
			labels_set["counter"] = true
		elif t.find("kite") >= 0 or t.find("poke") >= 0:
			labels_set["kite"] = true
		else:
			labels_set["neutral"] = true
	var out: Array = []
	for k in labels_set.keys():
		match String(k):
			"kite":
				out.append({"label": "kite", "map_params": {"artillery_range": 10.0, "openness": 0.8}})
			_:
				out.append({"label": String(k), "map_params": {}})
	return out

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

func _print_summary(subject_id: String, result: Dictionary) -> void:
	var passed_all: bool = bool(result.get("passed", false))
	var failed: int = int(result.get("failed_count", 0))
	var skipped: int = int(result.get("skipped_count", 0))
	var errors: int = int(result.get("error_count", 0))
	var hdr := "IdentityProbe(%s): " % subject_id
	if passed_all:
		print(hdr, "PASS (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")
	else:
		print(hdr, "FAIL (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")
	# Keep summary concise; per-metric details are printed separately

func _quit(code: int) -> void:
	if get_tree():
		get_tree().quit(code)

# Simple numeric formatter for readable output
func _fmt_num(v: Variant, decimals: int = 2) -> String:
	if v == null:
		return "<null>"
	var t := typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		var fmt := "%0." + str(decimals) + "f"
		return fmt % float(v)
	return String(v)
