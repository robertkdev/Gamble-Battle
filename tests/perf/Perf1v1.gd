extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var subject_a: String = "bonko"
@export var subject_b: String = "brute"
@export var seed: int = 525600
@export var delta_s_override: float = 0.05
@export var timeout_s: float = 60.0
@export var use_roles_aggregator: bool = false
@export var scenario_label: String = "neutral"
@export var adaptive_step: bool = false
@export var fast_dt: float = 0.5
@export var margin_tiles: float = 0.75
@export var pos_emit_interval: float = 0.1
@export var collision_iterations: int = 2
@export var friendly_soft: bool = true
@export var avoidance_weight: float = 0.6

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	var job: DataModels.SimJob = _make_job(subject_a, subject_b, seed, delta_s_override, timeout_s, scenario_label)
	var pipeline := HeadlessSimPipeline.new()
	var collector: RefCounted = pipeline._new_combined_aggregator(use_roles_aggregator)
	var sim := LockstepSimulator.new()
	var out: Dictionary = sim.run(job, false, collector)
	var t1: int = Time.get_ticks_msec()
	var agg: Dictionary = out.get("aggregates", {})
	var sig: String = _signature_for(agg)
	var frames: int = 0
	var eo = out.get("engine_outcome", null)
	if eo != null:
		frames = int(eo.frames)
	print("Perf1v1: time_ms=", (t1 - t0), " frames=", frames, " sig=", sig)
	if get_tree():
		get_tree().quit()

func _make_job(a_id: String, b_id: String, sim_seed: int, dt: float, to_s: float, scen_label: String) -> DataModels.SimJob:
	var j := DataModels.SimJob.new()
	j.run_id = "perf_1v1"
	j.sim_index = 0
	j.seed = int(sim_seed)
	j.team_a_ids = [String(a_id)]
	j.team_b_ids = [String(b_id)]
	j.team_size = 1
	j.scenario_id = "open_field"
	j.map_params = {}
	j.deterministic = true
	j.delta_s = max(0.001, float(dt))
	j.timeout_s = max(1.0, float(to_s))
	j.abilities = true
	j.ability_metrics = true
	j.alternate_order = false
	j.bridge_projectile_to_hit = true
	# Aggregator gate via capabilities — roles kernels only when explicitly enabled
	if use_roles_aggregator:
		j.capabilities = PackedStringArray(["base", "cc", "targets", "mobility", "zones"]) # triggers CombinedAggregator
	else:
		j.capabilities = PackedStringArray(["base"]) # base collector only
	var md: Dictionary = {"scenario_label": String(scen_label)}
	# Perf/adaptive stepping controls carried in metadata to avoid core DTO changes
	if bool(adaptive_step):
		md["perf_adaptive"] = true
		md["perf_fast_dt"] = float(fast_dt)
		md["perf_margin_tiles"] = float(margin_tiles)
	# Reduce position update emissions to lighten per-second work (base aggregator is invariant to this)
	md["perf_pos_emit_interval"] = float(pos_emit_interval)
	md["perf_collision_iterations"] = max(1, int(collision_iterations))
	md["perf_friendly_soft"] = bool(friendly_soft)
	md["perf_avoidance_weight"] = float(avoidance_weight)
	j.metadata = md
	return j

func _signature_for(val) -> String:
	# Build a deterministic summary to compare derived data equivalence.
	var parts: Array[String] = []
	_collect_sig(parts, val, "root")
	parts.sort()
	var acc: int = 5381
	for p in parts:
		for c in String(p).to_utf8_buffer():
			acc = ((acc << 5) + acc) + int(c)
	return str(acc) + ":" + str(parts.size())

func _collect_sig(out: Array[String], v, k: String) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys()
			keys.sort()
			for kk in keys:
				_collect_sig(out, d.get(kk), String(k) + "." + String(kk))
		TYPE_ARRAY:
			var idx: int = 0
			for item in (v as Array):
				_collect_sig(out, item, String(k) + "[" + str(idx) + "]")
				idx += 1
		TYPE_FLOAT, TYPE_INT:
			out.append(String(k) + "=" + _fmtn(float(v)))
		TYPE_BOOL:
			out.append(String(k) + "=" + ("1" if bool(v) else "0"))
		_:
			# ignore strings/null for signature to focus on numeric derived content
			pass

func _fmtn(x: float) -> String:
	# normalize to stable 1e-6 rounding to avoid tiny jitter
	return "%0.6f" % x
