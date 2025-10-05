extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector = preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")

# Determinism replay gate: reruns a completed sim job and ensures aggregates match bit-for-bit.
class_name DeterminismReplay

func run(job: DataModels.SimJob, aggregates_reference: Dictionary) -> void:
    if job == null:
        push_error("DeterminismReplay: job null")
        assert(false)
        return
    var sim := LockstepSimulator.new()
    var collector := CombatStatsCollector.new()
    var out := sim.run(job, false, collector)
    var aggregates_candidate: Dictionary = out.get("aggregates", {})
    var ref_bytes := _dict_to_bytes(aggregates_reference)
    var cand_bytes := _dict_to_bytes(aggregates_candidate)
    if ref_bytes != cand_bytes:
        push_error("DeterminismReplay: aggregates mismatch")
        _log_diff(aggregates_reference, aggregates_candidate)
        assert(false)

func _dict_to_bytes(data: Dictionary) -> PackedByteArray:
    return Marshalls.variant_to_bytes(data, true)

func _log_diff(expected: Dictionary, actual: Dictionary) -> void:
    var expected_json := JSON.stringify(expected, "  ")
    var actual_json := JSON.stringify(actual, "  ")
    print("DeterminismReplay expected:\n" + expected_json)
    print("DeterminismReplay actual:\n" + actual_json)
