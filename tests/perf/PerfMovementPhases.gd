extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline = preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var seed: int = 525600
@export var delta_s_override: float = 0.05
@export var timeout_s: float = 75.0

const TEAM_A_POOL: Array[String] = [
	"bonko", "korath", "sari", "pilfer", "cashmere", "axiom",
	"brute", "repo", "hexeon", "luna", "nyxa", "morrak"
]

const TEAM_B_POOL: Array[String] = [
	"repo", "bo", "sari", "pilfer", "cashmere", "knoll",
	"korath", "brute", "hexeon", "luna", "nyxa", "morrak"
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_defs: Array[Dictionary] = [
		{"label": "6v6_neutral", "team_size": 6, "map_params": _map_params_6v6("perf_phase_6v6_neutral")},
		{"label": "12v12_large", "team_size": 12, "map_params": _map_params_large(12)}
	]
	var failures: int = 0
	print("PerfMovementPhases: cases=", case_defs.size())
	for case_def in case_defs:
		var result: Dictionary = _run_case(case_def)
		if not bool(result.get("ok", false)):
			failures += 1
	if get_tree() != null:
		get_tree().quit(1 if failures > 0 else 0)

func _run_case(case_def: Dictionary) -> Dictionary:
	var label: String = String(case_def.get("label", "unknown"))
	var team_size: int = max(1, int(case_def.get("team_size", 1)))
	var raw_map_params: Variant = case_def.get("map_params", {})
	var map_params: Dictionary = raw_map_params.duplicate(true) if raw_map_params is Dictionary else {}
	var start_ms: int = Time.get_ticks_msec()
	var job: DataModels.SimJob = _make_job(label, team_size, map_params)
	var pipeline: HeadlessSimPipeline = HeadlessSimPipeline.new()
	var collector: RefCounted = pipeline._new_combined_aggregator(false)
	var sim: LockstepSimulator = LockstepSimulator.new()
	var out: Dictionary = sim.run(job, false, collector)
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	var outcome: Variant = out.get("engine_outcome", null)
	var frames: int = -1
	var sim_s: float = -1.0
	var result: String = ""
	var team_a_alive: int = -1
	var team_b_alive: int = -1
	if outcome != null:
		frames = int(outcome.frames)
		sim_s = float(outcome.time_s)
		result = String(outcome.result)
		team_a_alive = int(outcome.team_a_alive)
		team_b_alive = int(outcome.team_b_alive)
	var payload: Dictionary = {
		"aggregates": out.get("aggregates", {}),
		"outcome": {
			"result": result,
			"time_s": sim_s,
			"frames": frames,
			"team_a_alive": team_a_alive,
			"team_b_alive": team_b_alive
		}
	}
	var signature: String = _signature_for(payload)
	var diagnostics: Dictionary = out.get("movement_diagnostics", {}) if out.get("movement_diagnostics", {}) is Dictionary else {}
	var movement_frames: int = int(diagnostics.get("frames", 0))
	var total_usec: int = int(diagnostics.get("total_usec", 0))
	var target_calls: int = int(diagnostics.get("target_calls", 0))
	var target_skips: int = int(diagnostics.get("target_skips", 0))
	var phase_summary: String = _phase_summary(diagnostics)
	var ok: bool = movement_frames > 0 and total_usec > 0
	if not ok:
		push_error("PerfMovementPhases: missing movement diagnostics for " + label)
	print("PerfMovementPhases case=", label,
		" elapsed_ms=", elapsed_ms,
		" frames=", frames,
		" movement_frames=", movement_frames,
		" sim_s=", _fmtn(sim_s),
		" result=", result,
		" alive=", team_a_alive, ":", team_b_alive,
		" sig=", signature,
		" target_calls=", target_calls,
		" target_skips=", target_skips,
		" movement_usec=", total_usec,
		" phases=", phase_summary)
	return {"ok": ok, "signature": signature}

func _make_job(label: String, team_size: int, map_params: Dictionary) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "perf_movement_phases_%s" % String(label)
	job.sim_index = 0
	job.seed = int(seed)
	job.team_a_ids = _pick_ids(TEAM_A_POOL, team_size)
	job.team_b_ids = _pick_ids(TEAM_B_POOL, team_size)
	job.team_size = int(team_size)
	job.scenario_id = "open_field"
	job.map_params = map_params.duplicate(true)
	job.deterministic = true
	job.delta_s = max(0.001, float(delta_s_override))
	job.timeout_s = max(1.0, float(timeout_s))
	job.abilities = true
	job.ability_metrics = true
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base"])
	job.metadata = {
		"scenario_label": String(label),
		"profile": "perf_movement_phases",
		"perf_collision_iterations": 2,
		"perf_friendly_soft": true,
		"perf_avoidance_weight": 0.6,
		"perf_movement_diagnostics": true
	}
	return job

func _pick_ids(pool: Array[String], count: int) -> Array[String]:
	var out: Array[String] = []
	for index in range(max(0, count)):
		out.append(String(pool[index % pool.size()]))
	return out

func _map_params_6v6(map_id: String) -> Dictionary:
	return {
		"tile_size": 96.0,
		"formation": "role_based",
		"depth_gap": 1.5,
		"map_id": String(map_id),
		"openness": 0.7,
		"choke_count": 0,
		"obstacle_density": 0.25,
		"artillery_range": 8.0
	}

func _map_params_large(team_size: int) -> Dictionary:
	return {
		"tile_size": 96.0,
		"formation": "role_based",
		"depth_gap": 1.5,
		"map_id": "perf_phase_large_%d" % int(team_size),
		"openness": 0.8,
		"choke_count": 1,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
		"half_width_tiles": 9.0,
		"half_height_tiles": max(6.0, float(team_size) * 0.55),
		"row_spacing_tiles": 1.0
	}

func _phase_summary(diagnostics: Dictionary) -> String:
	var phases_value: Variant = diagnostics.get("phases_usec", {})
	if not (phases_value is Dictionary):
		return ""
	var phases: Dictionary = phases_value
	var total_usec: float = max(1.0, float(diagnostics.get("total_usec", 0)))
	var rows: Array[Dictionary] = []
	for phase_key in phases.keys():
		var usec: int = int(phases.get(phase_key, 0))
		rows.append({
			"name": String(phase_key),
			"usec": usec,
			"pct": (float(usec) / total_usec) * 100.0
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("usec", 0)) > int(b.get("usec", 0)))
	var parts: Array[String] = []
	var max_rows: int = min(6, rows.size())
	for index in range(max_rows):
		var row: Dictionary = rows[index]
		parts.append("%s:%dus:%0.1f%%" % [String(row.get("name", "")), int(row.get("usec", 0)), float(row.get("pct", 0.0))])
	return ",".join(parts)

func _signature_for(val: Variant) -> String:
	var parts: Array[String] = []
	_collect_sig(parts, val, "root")
	parts.sort()
	var acc: int = 5381
	for part in parts:
		for character in String(part).to_utf8_buffer():
			acc = ((acc << 5) + acc) + int(character)
	return str(acc) + ":" + str(parts.size())

func _collect_sig(out: Array[String], value: Variant, key: String) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict_value: Dictionary = value
			var keys: Array = dict_value.keys()
			keys.sort()
			for dict_key in keys:
				_collect_sig(out, dict_value.get(dict_key), String(key) + "." + String(dict_key))
		TYPE_ARRAY:
			var index: int = 0
			for item in (value as Array):
				_collect_sig(out, item, String(key) + "[" + str(index) + "]")
				index += 1
		TYPE_FLOAT, TYPE_INT:
			out.append(String(key) + "=" + _fmtn(float(value)))
		TYPE_BOOL:
			out.append(String(key) + "=" + ("1" if bool(value) else "0"))
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(String(key) + "=" + String(value))
		_:
			pass

func _fmtn(value: float) -> String:
	return "%0.6f" % value
