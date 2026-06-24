extends Node

const DerivedStatsAggregator := preload("res://tests/rga_testing/aggregators/derived_stats_aggregator.gd")
const ContextTagger := preload("res://tests/rga_testing/core/context_tagger.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var agg: DerivedStatsAggregator = _make_manual_aggregator()

	# Seed a previous target so the later retarget is a real swap.
	agg._on_target_start("enemy", 0, "player", 0)
	agg.tick(0.1)

	agg._on_cc_applied("player", 0, "enemy", 0, "stun", 1.0)
	agg.tick(0.2)
	agg._on_position_updated("enemy", 0, 96.0, 0.0)
	agg.tick(0.2)
	agg._on_position_updated("enemy", 1, 0.0, 128.0)
	agg.tick(0.2)
	agg._on_target_start("enemy", 0, "player", 1)
	agg.tick(0.2)
	agg._on_hit_applied("player", 0, 0, 20, 20, false, 20, 0, 0.0, 0.0)
	agg.tick(3.0)
	agg.finalize(agg._time_s)

	var result: Dictionary = agg.result()
	var kernels: Dictionary = result.get("kernels", {})
	var disruption: Dictionary = kernels.get("disruption", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = disruption.get("per_unit", {}) if (disruption is Dictionary) else {}
	var side_a: Dictionary = per_unit.get(DerivedStatsAggregator.SIDE_A, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("controller", {}) if (side_a is Dictionary) else {}

	var forced_events: int = int(rec.get("forced_reposition_events", 0))
	var forced_distance: float = float(rec.get("forced_reposition_distance_tiles", 0.0))
	var target_swaps: int = int(rec.get("target_swap_events", 0))
	var formation_breaks: int = int(rec.get("formation_break_events", 0))
	var spread_delta: float = float(rec.get("formation_spread_increase_tiles", 0.0))
	var follow_up_kills: int = int(rec.get("follow_up_kills", 0))

	print("DisruptionKernelProbe: forced_events=", forced_events,
		" forced_distance=", forced_distance,
		" target_swaps=", target_swaps,
		" formation_breaks=", formation_breaks,
		" spread_delta=", spread_delta,
		" follow_up_kills=", follow_up_kills)

	var failed: bool = false
	if forced_events < 1 or forced_distance < 0.75:
		printerr("DisruptionKernelProbe: FAIL forced reposition was not recorded")
		failed = true
	if target_swaps < 1:
		printerr("DisruptionKernelProbe: FAIL target swap was not recorded")
		failed = true
	if formation_breaks < 1 or spread_delta < 0.75:
		printerr("DisruptionKernelProbe: FAIL formation break was not recorded")
		failed = true
	if follow_up_kills < 1:
		printerr("DisruptionKernelProbe: FAIL follow-up kill was not recorded")
		failed = true

	if failed:
		_quit(1)
		return
	print("DisruptionKernelProbe: PASS")
	_quit(0)

func _make_manual_aggregator() -> DerivedStatsAggregator:
	var ctx: ContextTagger.ContextTags = _make_manual_context()
	var agg: DerivedStatsAggregator = DerivedStatsAggregator.new()
	agg.attach(null, null, ctx, true)
	agg._connected = true
	agg._unit_alive[DerivedStatsAggregator.SIDE_A] = [true, true]
	agg._unit_alive[DerivedStatsAggregator.SIDE_B] = [true, true]
	agg._unit_positions[DerivedStatsAggregator.SIDE_A] = [Vector2(-64.0, 0.0), Vector2(-64.0, 64.0)]
	agg._unit_positions[DerivedStatsAggregator.SIDE_B] = [Vector2(0.0, 0.0), Vector2(0.0, 64.0)]
	agg._priority_units[DerivedStatsAggregator.SIDE_A] = {0: true, 1: true}
	agg._priority_units[DerivedStatsAggregator.SIDE_B] = {0: true}
	agg._carry_units[DerivedStatsAggregator.SIDE_A] = {0: true, 1: true}
	agg._carry_units[DerivedStatsAggregator.SIDE_B] = {0: true}
	agg._threat_track[DerivedStatsAggregator.SIDE_A] = {}
	agg._threat_track[DerivedStatsAggregator.SIDE_B] = {}
	return agg

func _make_manual_context() -> ContextTagger.ContextTags:
	var ctx: ContextTagger.ContextTags = ContextTagger.ContextTags.new()
	ctx.unit_timelines = {
		DerivedStatsAggregator.SIDE_A: [
			{
				"unit_index": 0,
				"unit_id": "controller",
				"entries": [_timeline("carry")]
			},
			{
				"unit_index": 1,
				"unit_id": "ally",
				"entries": [_timeline("priority_target")]
			}
		],
		DerivedStatsAggregator.SIDE_B: [
			{
				"unit_index": 0,
				"unit_id": "controlled_target",
				"entries": [_timeline("priority_target")]
			},
			{
				"unit_index": 1,
				"unit_id": "formation_partner",
				"entries": []
			}
		]
	}
	ctx.zones = {
		DerivedStatsAggregator.SIDE_A: _zone_dict(Vector2(1.0, 0.0)),
		DerivedStatsAggregator.SIDE_B: _zone_dict(Vector2(-1.0, 0.0))
	}
	ctx.metadata = {"tile_size": 64.0}
	return ctx

func _timeline(tag: String) -> Dictionary:
	return {
		"tag": tag,
		"source": "disruption_probe",
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
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
