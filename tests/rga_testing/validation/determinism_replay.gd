extends Node
class_name DeterminismReplay

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector = preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")

# Determinism replay gate: reruns a completed sim job and ensures aggregates match bit-for-bit.

func run(job: DataModels.SimJob, aggregates_reference: Dictionary) -> void:
    if job == null:
        push_error("DeterminismReplay: job null")
        assert(false)
        return
    var sim: LockstepSimulator = LockstepSimulator.new()
    var collector: CombatStatsCollector = CombatStatsCollector.new()
    var out: Dictionary = sim.run(job, false, collector)
    var aggregates_candidate: Dictionary = out.get("aggregates", {})
    var ref_bytes: PackedByteArray = _dict_to_bytes(aggregates_reference)
    var cand_bytes: PackedByteArray = _dict_to_bytes(aggregates_candidate)
    if ref_bytes != cand_bytes:
        push_error("DeterminismReplay: aggregates mismatch")
        _log_diff(aggregates_reference, aggregates_candidate)
        assert(false)

func _dict_to_bytes(data: Dictionary) -> PackedByteArray:
    return Marshalls.variant_to_base64(data, true).to_utf8_buffer()

func _log_diff(expected: Dictionary, actual: Dictionary) -> void:
    var expected_json: String = JSON.stringify(expected, "  ")
    var actual_json: String = JSON.stringify(actual, "  ")
    print("DeterminismReplay expected:\n" + expected_json)
    print("DeterminismReplay actual:\n" + actual_json)
