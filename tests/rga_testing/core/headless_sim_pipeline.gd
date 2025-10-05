extends RefCounted
class_name HeadlessSimPipeline

const RGASettings = preload("res://tests/rga_testing/settings.gd")
const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const TeamBuilderScript = preload("res://tests/rga_testing/teams/team_builder.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector = preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const TelemetryCapabilities = preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const TelemetryWriter = preload("res://tests/rga_testing/io/telemetry_writer.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")

# Orchestrates: settings -> team_builder -> scenario+simulator -> base aggregator -> telemetry_writer

func run_all(settings: RGASettings) -> int:
	if settings == null:
		push_warning("Pipeline: settings missing")
		return 0
	_ensure_run_defaults(settings)

	# Build jobs (Phase 1: 1v1 only)
	if settings.team_sizes.size() > 0 and not settings.team_sizes.has(1):
		push_warning("Pipeline: team_sizes does not include 1 -- defaulting to 1v1 for Phase 1")
	var builder = TeamBuilderScript.new()
	var base_jobs: Array = builder.build_1v1(settings)
	var repeats: int = max(1, int(settings.repeats))
	var include_swapped := bool(settings.include_swapped)
	var orientations := (2 if include_swapped else 1)
	var total := base_jobs.size() * repeats * orientations
	if total == 0:
		push_warning("Pipeline: no jobs to run (filters too strict or no units)")
		return 0

	# Writer
	_reset_output_file(settings.out_path)
	var writer: TelemetryWriter = TelemetryWriter.new(settings.out_path, false)
	var written := 0

	var sim_idx: int = 0
	var sim_counter: int = 0
	var total_pairs: int = base_jobs.size()
	var pair_idx: int = 0
	for base in base_jobs:
		# Pair anchor ids (canonical order from builder)
		var attacker_id := String(base.team_a_ids[0])
		var defender_id := String(base.team_b_ids[0])
		pair_idx += 1
		print("RGA Pipeline: matchup ", pair_idx, "/", total_pairs, " ", attacker_id, " vs ", defender_id, " repeats=", repeats, " orientations=", (2 if include_swapped else 1))
		var stats := _new_pair_stats()
		var first_ctx = null
		for r in range(repeats):
			# Orientation 1: attacker=A vs defender=B
			var j1: DataModels.SimJob = _clone_job(base, settings, sim_idx)
			sim_idx += 1
			# per-iteration print suppressed to reduce spam; we log once per matchup
			sim_counter += 1
			var sim1 := LockstepSimulator.new()
			var col1 := CombatStatsCollector.new()
			var out1: Dictionary = sim1.run(j1, false, col1)
			if first_ctx == null:
				first_ctx = out1.get("context", null)
			if not bool(settings.aggregates_only):
				written += _write_sim_row(writer, out1)
			_accumulate_pair(stats, out1, true)

			# Orientation 2: swapped (attacker=B vs defender=A)
			if include_swapped:
				var j2: DataModels.SimJob = _clone_job_swapped(base, settings, sim_idx)
				sim_idx += 1
				# per-iteration print suppressed to reduce spam; we log once per matchup
				sim_counter += 1
				var sim2 := LockstepSimulator.new()
				var col2 := CombatStatsCollector.new()
				var out2: Dictionary = sim2.run(j2, false, col2)
				if not bool(settings.aggregates_only):
					written += _write_sim_row(writer, out2)
				_accumulate_pair(stats, out2, false)

		# After repeats for this pair, write one aggregated set row if requested
		var summary := _summarize_pair(stats)
		summary["a"] = attacker_id
		summary["b"] = defender_id
		if bool(settings.aggregates_only):
			var agg_row := DataModels.TelemetryRow.new()
			agg_row.schema_version = "telemetry_v1"
			if first_ctx != null:
				agg_row.context = first_ctx
			agg_row.aggregates = {"pair_set": summary}
			agg_row.events.clear()
			TelemetryCapabilities.attach_to_row(agg_row, [TelemetryCapabilities.CAP_BASE])
			if bool(writer.call("append_row", agg_row, false)):
				written += 1

	print("RGA Pipeline: wrote ", written, " rows to ", settings.out_path)
	_clear_unit_factory_cache()
	return written

func _clone_job(base, settings: RGASettings, sim_index: int) -> DataModels.SimJob:
	var j := DataModels.SimJob.new()
	j.run_id = String(settings.run_id)
	j.sim_index = sim_index
	j.seed = int(settings.sim_seed_start) + sim_index
	j.team_a_ids = base.team_a_ids.duplicate()
	j.team_b_ids = base.team_b_ids.duplicate()
	j.team_size = int(base.team_size)
	j.scenario_id = String(base.scenario_id)
	j.map_params = base.map_params.duplicate()
	j.deterministic = bool(settings.deterministic)
	j.delta_s = float(base.delta_s)
	j.timeout_s = float(settings.timeout_s)
	j.abilities = bool(settings.abilities)
	j.ability_metrics = bool(settings.ability_metrics)
	j.alternate_order = bool(base.alternate_order)
	j.bridge_projectile_to_hit = bool(base.bridge_projectile_to_hit)
	j.capabilities = base.capabilities.duplicate()
	return j

func _clone_job_swapped(base, settings: RGASettings, sim_index: int) -> DataModels.SimJob:
	var j: DataModels.SimJob = _clone_job(base, settings, sim_index)
	var a: Array = base.team_a_ids.duplicate()
	var b: Array = base.team_b_ids.duplicate()
	j.team_a_ids = b
	j.team_b_ids = a
	return j

func _write_sim_row(writer: TelemetryWriter, sim_out: Dictionary) -> int:
	var row := DataModels.TelemetryRow.new()
	row.schema_version = "telemetry_v1"
	var ctx = sim_out.get("context", null)
	if ctx != null:
		row.context = ctx
	var outcome = sim_out.get("engine_outcome", null)
	if outcome != null:
		row.engine_outcome = outcome
	var aggregates = sim_out.get("aggregates", null)
	if aggregates != null:
		row.aggregates = aggregates
	row.events.clear()
	TelemetryCapabilities.attach_to_row(row, [TelemetryCapabilities.CAP_BASE])
	return (1 if bool(writer.call("append_row", row, false)) else 0)

func _new_pair_stats() -> Dictionary:
	return {
		"matches_total": 0,
		"a_wins": 0, "b_wins": 0, "draws": 0,
		"a_time_sum": 0.0, "b_time_sum": 0.0,
		"a_damage_sum": 0.0, "b_damage_sum": 0.0
	}

func _accumulate_pair(acc: Dictionary, sim_out: Dictionary, attacker_is_team_a: bool) -> void:
	var outcome = sim_out.get("engine_outcome", null)
	var aggregates: Dictionary = sim_out.get("aggregates", {})
	var teams: Dictionary = aggregates.get("teams", {})
	var a: Dictionary = (teams.get("a", {}) as Dictionary)
	var b: Dictionary = (teams.get("b", {}) as Dictionary)
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
	# Damage per match (sum both sides separately, aligned to attacker/defender)
	var dmg_a := int(a.get("damage", 0))
	var dmg_b := int(b.get("damage", 0))
	if attacker_is_team_a:
		acc.a_damage_sum += dmg_a
		acc.b_damage_sum += dmg_b
	else:
		acc.a_damage_sum += dmg_b
		acc.b_damage_sum += dmg_a

func _summarize_pair(acc: Dictionary) -> Dictionary:
	var total: int = max(1, int(acc.matches_total))
	var a_wins: int = int(acc.a_wins)
	var b_wins: int = int(acc.b_wins)
	return {
		"matches_total": total,
		"a_win_pct": float(a_wins) / float(total),
		"b_win_pct": float(b_wins) / float(total),
		"draw_pct": float(int(acc.draws)) / float(total),
		"a_avg_time_to_win_s": (float(acc.a_time_sum) / max(1.0, float(a_wins))),
		"b_avg_time_to_win_s": (float(acc.b_time_sum) / max(1.0, float(b_wins))),
		"a_avg_damage_dealt_per_match": (float(acc.a_damage_sum) / float(total)),
		"b_avg_damage_dealt_per_match": (float(acc.b_damage_sum) / float(total))
	}

func _clear_unit_factory_cache() -> void:
	if UnitFactory == null:
		return
	UnitFactory.clear_cache()

func _ensure_run_defaults(settings: RGASettings) -> void:
	# Provide a default run_id/seed if not specified.
	if String(settings.run_id).strip_edges() == "":
		var ts := 0
		# Godot 4 Time API (fallback to OS if unavailable)
		ts = int(Time.get_unix_time_from_system())
		settings.run_id = "run_%d" % ts
	# Keep sim_seed_start as provided; zero is allowed but not recommended.

func _reset_output_file(path: String) -> void:
	if String(path).strip_edges() == "":
		return
	var dir_path: String = path
	var slash: int = max(dir_path.rfind("/"), dir_path.rfind("\\"))
	if slash >= 0:
		dir_path = dir_path.substr(0, slash)
	if dir_path != "" and not dir_path.ends_with("://") and dir_path != "user:/" and dir_path != "user:":
		DirAccess.make_dir_recursive_absolute(dir_path)
	# Remove any existing file or directory at 'path' to guarantee a clean run.
	if DirAccess.dir_exists_absolute(path):
		_remove_dir_recursive(path)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	# Create an empty file at path if we are in single-file mode; harmless otherwise
	var fa: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if fa != null:
		fa.close()

func _remove_dir_recursive(dir_abs_path: String) -> void:
	var d := DirAccess.open(dir_abs_path)
	if d == null:
		# Try remove directly in case it's an empty dir
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
