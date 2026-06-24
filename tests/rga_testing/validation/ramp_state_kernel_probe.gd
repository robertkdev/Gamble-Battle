extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const RampApproachTest := preload("res://tests/rga_testing/metrics/approach/ramp_approach_test.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.state = state

	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "nyxa"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "brute"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)

	kernel.call("tick", 1.0)
	engine._resolver_emit_ramp_state_changed("player", 0, "stack_window", 1, 1.0, 4, 2.0, "probe_ramp_setup")
	kernel.call("tick", 2.0)
	engine._resolver_emit_ramp_state_changed("player", 0, "stack_window", 4, 4.0, 4, 3.0, "probe_ramp_peak")
	kernel.call("finalize", 6.0)

	var result: Dictionary = kernel.call("result")
	var combat_patterns: Dictionary = result.get("combat_patterns", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("nyxa", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)
	var goal_result: Dictionary = _run_goal_result(result)

	var supported: bool = bool(combat_patterns.get("ramp_state_supported", false))
	var ramp_events: int = int(rec.get("ramp_state_events", 0))
	var stack_max: int = int(rec.get("ramp_stack_max", 0))
	var time_to_peak: float = float(rec.get("ramp_time_to_peak_s", 0.0))
	var peak_duration: float = float(rec.get("ramp_peak_duration_s", 0.0))
	var window_duration: float = float(rec.get("ramp_window_duration_s", 0.0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_direct_span: bool = _has_span_prefix(metric_result, "subject_ramp_state_events")
	var goal_direct_span: bool = _has_span_prefix(goal_result, "goal_backline_siege_ramp_state_events")
	var goal_pass: bool = bool(goal_result.get("pass", false))

	print("RampStateKernelProbe: supported=", supported,
		" events=", ramp_events,
		" stack_max=", stack_max,
		" time_to_peak=", time_to_peak,
		" peak_duration=", peak_duration,
		" window_duration=", window_duration,
		" metric_pass=", metric_pass,
		" goal_pass=", goal_pass)

	var failed: bool = false
	if not supported:
		printerr("RampStateKernelProbe: FAIL ramp_state_changed signal was not connected")
		failed = true
	if ramp_events != 2 or stack_max != 4:
		printerr("RampStateKernelProbe: FAIL ramp event count or max stack was not recorded")
		failed = true
	if not is_equal_approx(time_to_peak, 3.0):
		printerr("RampStateKernelProbe: FAIL time to peak was not recorded")
		failed = true
	if not is_equal_approx(peak_duration, 3.0) or not is_equal_approx(window_duration, 3.0):
		printerr("RampStateKernelProbe: FAIL peak/window duration was not recorded")
		failed = true
	if not metric_pass:
		printerr("RampStateKernelProbe: FAIL approach_ramp did not pass on direct ramp telemetry")
		failed = true
	if not metric_direct_span:
		printerr("RampStateKernelProbe: FAIL approach_ramp did not emit direct ramp-state span")
		failed = true
	if not goal_direct_span:
		printerr("RampStateKernelProbe: FAIL goal_primary did not emit direct ramp-state span")
		failed = true
	if not goal_pass:
		printerr("RampStateKernelProbe: FAIL goal_primary did not pass with direct ramp plus siege support evidence")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("RampStateKernelProbe: PASS")
	_quit(0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = "nyxa"
	attacker.max_hp = 1000
	attacker.hp = 1000
	var target: Unit = Unit.new()
	target.id = "brute"
	target.max_hp = 1000
	target.hp = 1000
	var player_team: Array[Unit] = [attacker]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = RampApproachTest.new()
	return metric.call("run_metric", _payload(kernel_result))

func _run_goal_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	return metric.call("run_metric", _payload(kernel_result))

func _payload(kernel_result: Dictionary) -> Dictionary:
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["nyxa"],
						"team_b_ids": ["brute"]
					},
					"teams": {
						"a": {
							"damage": 300.0
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": "nyxa",
								"damage": 120.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": "brute",
								"damage": 0.0
							}
						]
					},
					"outcome": {
						"time_s": 10.0
					},
					"kernels": _with_siege_kpis(kernel_result)
				}
			}
		},
		"subject_unit_ids": ["nyxa"]
	}
	return payload

func _with_siege_kpis(kernel_result: Dictionary) -> Dictionary:
	var copy: Dictionary = kernel_result.duplicate(true)
	copy["per_unit_kpis"] = {
		"supported": true,
		"a": {
			"nyxa": {
				"attacks_over_2_tiles_pct": 0.80,
				"time_on_target_pct": 0.70,
				"damage_to_frontline_pct": 0.20
			}
		},
		"b": {}
	}
	return copy

func _has_span_prefix(metric_result: Dictionary, prefix: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var label: String = String((span_value as Dictionary).get("label", ""))
		if label.begins_with(prefix):
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
