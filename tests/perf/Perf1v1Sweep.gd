extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var subject_a: String = "bonko"
@export var subject_b: String = "brute"
@export var seed: int = 525600

# Sweep parameters (kept small for fast iteration)
@export var deltas: PackedFloat32Array = PackedFloat32Array([0.05, 0.25, 0.5, 1.0])
@export var adaptive_flags: PackedInt32Array = PackedInt32Array([0, 1])
@export var fast_dts: PackedFloat32Array = PackedFloat32Array([0.5, 2.0, 5.0])
@export var margin_tiles: PackedFloat32Array = PackedFloat32Array([0.5, 0.25])
@export var pos_emit_intervals: PackedFloat32Array = PackedFloat32Array([0.1, 1.0])
@export var collision_iters: PackedInt32Array = PackedInt32Array([2, 1])
@export var friendly_soft_opts: PackedInt32Array = PackedInt32Array([1, 0])
@export var avoidance_weights: PackedFloat32Array = PackedFloat32Array([0.6, 0.0])

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var baseline_sig: String = ""
    var baseline_time: int = -1
    var idx: int = 0
    for d in deltas:
        for adapt in adaptive_flags:
            for fd in fast_dts:
                for m in margin_tiles:
                    for pei in pos_emit_intervals:
                        for ci in collision_iters:
                            for fs in friendly_soft_opts:
                                for aw in avoidance_weights:
                                    idx += 1
                                    var t0: int = Time.get_ticks_msec()
                                    var job: DataModels.SimJob = _make_job(String(subject_a), String(subject_b), int(seed), float(d), 60.0, "neutral", bool(adapt), float(fd), float(m), float(pei), int(ci), bool(fs), float(aw))
                                    var pipeline := HeadlessSimPipeline.new()
                                    var collector: RefCounted = pipeline._new_combined_aggregator(false)
                                    var sim := LockstepSimulator.new()
                                    var out: Dictionary = sim.run(job, false, collector)
                                    var t1: int = Time.get_ticks_msec()
                                    var sig: String = _signature_for(out.get("aggregates", {}))
                                    var eo = out.get("engine_outcome", null)
                                    var frames: int = (int(eo.frames) if eo != null else -1)
                                    var sim_s: float = (float(eo.time_s) if eo != null else -1.0)
                                    var ms: int = max(0, t1 - t0)
                                    if baseline_sig == "":
                                        baseline_sig = sig
                                        baseline_time = ms
                                        print("[BASE] dt=", d, " adapt=", adapt, " fast=", fd, " margin=", m, " pei=", pei, " coll=", ci, " soft=", fs, " avoid=", aw, " -> ms=", ms, " frames=", frames, " sim_s=", sim_s, " sig=", sig)
                                    else:
                                        var ok: bool = (sig == baseline_sig)
                                        print(("[OK]  " if ok else "[DIFF]"),
                                            " dt=", d, " adapt=", adapt, " fast=", fd, " margin=", m,
                                            " pei=", pei, " coll=", ci, " soft=", fs, " avoid=", aw,
                                            " -> ms=", ms, " (base=", baseline_time, ") frames=", frames, " sim_s=", sim_s, " sig=", sig)
    if get_tree():
        get_tree().quit()

func _make_job(a_id: String, b_id: String, sim_seed: int, dt: float, to_s: float, scen_label: String, adapt: bool, fast_dt: float, margin_tiles: float, pos_emit_interval: float, coll_iters: int, friendly_soft: bool, avoidance_weight: float) -> DataModels.SimJob:
    var j := DataModels.SimJob.new()
    j.run_id = "perf_1v1_sweep"
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
    j.capabilities = PackedStringArray(["base"]) # base-only telemetry
    var md: Dictionary = {"scenario_label": String(scen_label)}
    if adapt:
        md["perf_adaptive"] = true
        md["perf_fast_dt"] = float(fast_dt)
        md["perf_margin_tiles"] = float(margin_tiles)
    if pos_emit_interval > 0.0:
        md["perf_pos_emit_interval"] = float(pos_emit_interval)
    md["perf_collision_iterations"] = max(1, int(coll_iters))
    md["perf_friendly_soft"] = bool(friendly_soft)
    md["perf_avoidance_weight"] = float(avoidance_weight)
    j.metadata = md
    return j

func _signature_for(val) -> String:
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
            pass

func _fmtn(x: float) -> String:
    return "%0.6f" % x
