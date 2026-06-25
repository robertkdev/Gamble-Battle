extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const BurstApproachTest := preload("res://tests/rga_testing/metrics/approach/burst_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var positive_result: Dictionary = _run_case(true)
	var negative_result: Dictionary = _run_case(false)
	var positive_rec: Dictionary = positive_result.get("rec", {})
	var positive_metric: Dictionary = positive_result.get("metric", {})
	var negative_metric: Dictionary = negative_result.get("metric", {})
	var peak_share: float = float(positive_rec.get("peak_1s_damage_share", 0.0))
	var peak_dps: float = float(positive_rec.get("peak_1s_dps", 0.0))
	var counterplay_ms: float = float(positive_rec.get("counterplay_window_ms", -1.0))
	var overkill_rate: float = float(positive_rec.get("overkill_rate", 0.0))
	var positive_pass: bool = bool(positive_metric.get("pass", false))
	var negative_pass: bool = bool(negative_metric.get("pass", false))
	var peak_share_span: bool = _has_passing_span(positive_metric, "subject_peak_1s_damage_share")
	var peak_dps_span: bool = _has_passing_span(positive_metric, "subject_peak_1s_dps")
	var overkill_span: bool = _has_passing_span(positive_metric, "subject_overkill_rate")

	print("BurstWindowKernelProbe: peak_share=", peak_share,
		" peak_dps=", peak_dps,
		" counterplay_ms=", counterplay_ms,
		" overkill_rate=", overkill_rate,
		" positive_pass=", positive_pass,
		" negative_pass=", negative_pass)

	var failed: bool = false
	if not positive_pass:
		printerr("BurstWindowKernelProbe: FAIL approach_burst did not pass on concentrated burst telemetry")
		failed = true
	if peak_share < 0.75 or peak_dps < 75.0:
		printerr("BurstWindowKernelProbe: FAIL peak-window damage share or DPS was below expected proof threshold")
		failed = true
	if not is_equal_approx(counterplay_ms, 100.0):
		printerr("BurstWindowKernelProbe: FAIL cast-to-peak counterplay window was not recorded")
		failed = true
	if overkill_rate > 0.001:
		printerr("BurstWindowKernelProbe: FAIL overkill diagnostic should remain zero in the positive case")
		failed = true
	if not peak_share_span or not peak_dps_span or not overkill_span:
		printerr("BurstWindowKernelProbe: FAIL approach_burst did not emit passing direct burst spans")
		failed = true
	if negative_pass:
		printerr("BurstWindowKernelProbe: FAIL diffuse negative case passed approach_burst")
		failed = true

	if failed:
		_quit(1)
		return
	print("BurstWindowKernelProbe: PASS")
	_quit(0)

func _run_case(concentrated: bool) -> Dictionary:
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
					"unit_id": "hexeon"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "target_dummy"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2.ZERO)
	if concentrated:
		_emit_hit(engine, kernel, 0.10, 40)
		_emit_hit(engine, kernel, 0.30, 40)
		_emit_hit(engine, kernel, 1.40, 20)
	else:
		_emit_hit(engine, kernel, 0.10, 20)
		_emit_hit(engine, kernel, 1.30, 20)
		_emit_hit(engine, kernel, 1.30, 20)
		_emit_hit(engine, kernel, 1.30, 20)
		_emit_hit(engine, kernel, 1.30, 20)
	kernel.call("finalize", 6.0)
	var result: Dictionary = kernel.call("result")
	var combat_patterns: Dictionary = result.get("combat_patterns", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("hexeon", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)
	kernel.call("detach")
	return {
		"rec": rec,
		"metric": metric_result
	}

func _emit_hit(engine: CombatEngine, kernel: Variant, delta_s: float, damage: int) -> void:
	kernel.call("tick", delta_s)
	engine.emit_signal("hit_applied", "player", 0, 0, damage, damage, false, 1000, 1000 - damage, 0.0, 0.0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = "hexeon"
	attacker.max_hp = 1000
	attacker.hp = 1000
	var target: Unit = Unit.new()
	target.id = "target_dummy"
	target.max_hp = 1000
	target.hp = 1000
	var player_team: Array[Unit] = [attacker]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = BurstApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["hexeon"],
						"team_b_ids": ["target_dummy"]
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["hexeon"]
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
