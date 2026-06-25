extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const AoeApproachTest := preload("res://tests/rga_testing/metrics/approach/aoe_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.state = state

	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 3}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "luna"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "target_alpha"
				},
				{
					"unit_index": 1,
					"unit_id": "target_beta"
				},
				{
					"unit_index": 2,
					"unit_id": "target_gamma"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)

	kernel.call("tick", 0.20)
	engine.emit_signal("hit_applied", "player", 0, 0, 30, 30, false, 100, 70, 0.0, 0.0)
	engine.emit_signal("hit_applied", "player", 0, 1, 30, 30, false, 100, 70, 0.0, 0.0)
	engine.emit_signal("hit_applied", "player", 0, 2, 30, 30, false, 100, 70, 0.0, 0.0)
	kernel.call("tick", 0.10)
	engine.emit_signal("hit_applied", "player", 0, 0, 20, 20, false, 70, 50, 0.0, 0.0)
	engine.emit_signal("hit_applied", "player", 0, 1, 20, 20, false, 70, 50, 0.0, 0.0)
	kernel.call("finalize", 1.0)

	var result: Dictionary = kernel.call("result")
	var combat_patterns: Dictionary = result.get("combat_patterns", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("luna", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)

	var targets_median: float = float(rec.get("targets_hit_median", 0.0))
	var max_targets_hit: int = int(rec.get("max_targets_hit", 0))
	var multi_target_groups: int = int(rec.get("multi_target_groups", 0))
	var aoe_dps: float = float(rec.get("aoe_dps", 0.0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_target_span: bool = _has_passing_span(metric_result, "subject_targets_hit_median")
	var metric_max_span: bool = _has_passing_span(metric_result, "subject_max_targets_hit")
	var metric_dps_span: bool = _has_passing_span(metric_result, "subject_aoe_dps_med")

	print("AoeTargetingKernelProbe: targets_median=", targets_median,
		" max_targets=", max_targets_hit,
		" multi_groups=", multi_target_groups,
		" aoe_dps=", aoe_dps,
		" metric_pass=", metric_pass)

	var failed: bool = false
	if not combat_patterns.get("supported", false):
		printerr("AoeTargetingKernelProbe: FAIL combat pattern kernel was not supported")
		failed = true
	if not is_equal_approx(targets_median, 2.5):
		printerr("AoeTargetingKernelProbe: FAIL targets-hit median was not grouped across same-time hits")
		failed = true
	if max_targets_hit != 3 or multi_target_groups != 2:
		printerr("AoeTargetingKernelProbe: FAIL max targets or multi-target group count was not recorded")
		failed = true
	if aoe_dps < 100.0:
		printerr("AoeTargetingKernelProbe: FAIL AoE DPS was not recorded from multi-target groups")
		failed = true
	if not metric_pass:
		printerr("AoeTargetingKernelProbe: FAIL approach_aoe did not pass on direct multi-target telemetry")
		failed = true
	if not metric_target_span or not metric_max_span or not metric_dps_span:
		printerr("AoeTargetingKernelProbe: FAIL approach_aoe did not emit passing direct AoE spans")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("AoeTargetingKernelProbe: PASS")
	_quit(0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = "luna"
	attacker.max_hp = 1000
	attacker.hp = 1000
	var target_alpha: Unit = _make_target("target_alpha")
	var target_beta: Unit = _make_target("target_beta")
	var target_gamma: Unit = _make_target("target_gamma")
	var player_team: Array[Unit] = [attacker]
	var enemy_team: Array[Unit] = [target_alpha, target_beta, target_gamma]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _make_target(unit_id: String) -> Unit:
	var target: Unit = Unit.new()
	target.id = unit_id
	target.max_hp = 100
	target.hp = 100
	return target

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = AoeApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["luna"],
						"team_b_ids": ["target_alpha", "target_beta", "target_gamma"]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["luna"]
	}
	return metric.call("run_metric", payload)

func _has_passing_span(metric_result: Dictionary, label_prefix: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and bool(span.get("ok", false)):
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
