extends Node

const DerivedStatsAggregator := preload("res://tests/rga_testing/aggregators/derived_stats_aggregator.gd")
const ContextTagger := preload("res://tests/rga_testing/core/context_tagger.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var ok := true
    ok = _test_stun_vs_tenacity() and ok
    ok = _test_peel_displacement_timing() and ok
    if ok:
        print("Golden Scenarios: PASS")
    else:
        printerr("Golden Scenarios: FAILED")
    _quit(ok ? 0 : 1)

# --- Tests ---------------------------------------------------------------

func _test_stun_vs_tenacity() -> bool:
    print("Golden: stun_vs_tenacity")
    var base_lockdown := _simulate_lockdown_seconds(2.0)
    var reduced_lockdown := _simulate_lockdown_seconds(1.0)
    var pass := base_lockdown > 0.0 and reduced_lockdown > 0.0 and reduced_lockdown < base_lockdown and reduced_lockdown <= base_lockdown * 0.75
    if not pass:
        printerr("  Expected reduced lockdown < baseline (and at least 25% shorter). baseline=", base_lockdown, " reduced=", reduced_lockdown)
    return pass

func _test_peel_displacement_timing() -> bool:
    print("Golden: peel_displacement_timing")
    var saves_fast := _simulate_peel_saves(1.0)
    var saves_slow := _simulate_peel_saves(2.6)
    var pass := saves_fast >= 1 and saves_slow == 0
    if not pass:
        printerr("  Expected peel_saves fast>=1 slow=0. fast=", saves_fast, " slow=", saves_slow)
    return pass

# --- Simulation kernels --------------------------------------------------

func _simulate_lockdown_seconds(duration_s: float) -> float:
    var agg := _make_manual_aggregator()
    agg.tick(0.5)
    agg._on_target_start("player", 0, "enemy", 0)
    agg.tick(0.1)
    agg._on_cc_applied("player", 0, "enemy", 0, "stun", duration_s)
    agg.tick(0.5)
    agg.finalize(agg._time_s)
    var derived := agg.result().get("derived", {})
    var side_a: Dictionary = derived.get(DerivedStatsAggregator.SIDE_A, {})
    return float(side_a.get("lockdown_seconds_on_priority", 0.0))

func _simulate_peel_saves(delay_s: float) -> int:
    var agg := _make_manual_aggregator()
    agg._on_target_start("player", 0, "enemy", 0)
    agg.tick(delay_s)
    agg._on_cc_applied("enemy", 0, "player", 0, "stun", 0.4)
    agg.tick(0.2)
    agg.finalize(agg._time_s)
    var derived := agg.result().get("derived", {})
    var side_b: Dictionary = derived.get(DerivedStatsAggregator.SIDE_B, {})
    return int(side_b.get("peel_saves", 0))

# --- Aggregator harness --------------------------------------------------

func _make_manual_aggregator() -> DerivedStatsAggregator:
    var ctx := _make_manual_context()
    var agg := DerivedStatsAggregator.new()
    agg.attach(null, null, ctx, true)
    agg._context_tags = ctx
    agg._connected = true
    agg._unit_alive[DerivedStatsAggregator.SIDE_A] = [true]
    agg._unit_alive[DerivedStatsAggregator.SIDE_B] = [true]
    agg._unit_positions[DerivedStatsAggregator.SIDE_A] = [Vector2.ZERO]
    agg._unit_positions[DerivedStatsAggregator.SIDE_B] = [Vector2.ZERO]
    agg._carry_units[DerivedStatsAggregator.SIDE_A] = {0: true}
    agg._carry_units[DerivedStatsAggregator.SIDE_B] = {}
    agg._priority_units[DerivedStatsAggregator.SIDE_A] = {}
    agg._priority_units[DerivedStatsAggregator.SIDE_B] = {0: true}
    agg._threat_track[DerivedStatsAggregator.SIDE_A] = {}
    agg._threat_track[DerivedStatsAggregator.SIDE_B] = {}
    return agg

func _make_manual_context() -> ContextTagger.ContextTags:
    var ctx := ContextTagger.ContextTags.new()
    ctx.unit_timelines = {
        DerivedStatsAggregator.SIDE_A: [
            {
                "unit_index": 0,
                "unit_id": "attacker",
                "entries": [_timeline("carry")]
            }
        ],
        DerivedStatsAggregator.SIDE_B: [
            {
                "unit_index": 0,
                "unit_id": "defender",
                "entries": [_timeline("priority_target")]
            }
        ]
    }
    ctx.zones = {
        DerivedStatsAggregator.SIDE_A: _zone_dict(Vector2(1, 0)),
        DerivedStatsAggregator.SIDE_B: _zone_dict(Vector2(-1, 0))
    }
    ctx.metadata = {}
    return ctx

func _timeline(tag: String) -> Dictionary:
    return {
        "tag": tag,
        "source": "golden",
        "segments": [
            {
                "start_us": 0,
                "end_us": -1,
                "confidence": 100
            }
        ]
    }

func _zone_dict(forward: Vector2) -> Dictionary:
    return {
        "forward": {"x": forward.x, "y": forward.y},
        "frontline": {
            "center": {"x": 0.0, "y": 0.0},
            "half_length": 2.0,
            "half_width": 2.0
        }
    }

func _quit(code: int) -> void:
    if get_tree():
        get_tree().quit(code)
