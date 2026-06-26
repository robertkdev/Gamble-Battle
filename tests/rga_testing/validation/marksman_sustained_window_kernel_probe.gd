extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

const SUBJECT_ID: String = "teller"
const ALLY_ID: String = "marksman_window_ally"
const TARGET_ID: String = "marksman_window_target"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var strong_kernel: Dictionary = _window_kernel_result(10.0, [30.0, 40.0], [250.0], [70.0])
	var weak_kernel: Dictionary = _window_kernel_result(50.0, [10.0], [150.0], [90.0])
	var strong_rec: Dictionary = _subject_pattern_rec(strong_kernel)
	var weak_rec: Dictionary = _subject_pattern_rec(weak_kernel)
	var strong_goal: Dictionary = _run_goal("windowed_sustained_pass", strong_kernel, 80.0, 400.0)
	var weak_goal: Dictionary = _run_goal("windowed_sustained_fail", weak_kernel, 60.0, 300.0)

	var early_damage: float = float(strong_rec.get("early_0_3s_damage", 0.0))
	var sustained_damage: float = float(strong_rec.get("sustained_3_10s_damage", 0.0))
	var sustained_rate: float = float(strong_rec.get("sustained_3_10s_rate", 0.0))
	var sustained_team_share: float = float(strong_rec.get("sustained_3_10s_team_share", 0.0))
	var strong_goal_pass: bool = bool(strong_goal.get("pass", false))
	var weak_goal_pass: bool = bool(weak_goal.get("pass", false))
	var strong_team_share_diagnostic: bool = _has_diagnostic_span(strong_goal, "goal_marksman_sustained_dps_team_damage_share", "alternate_sustained_window_evidence_satisfied")
	var strong_window_share_pass: bool = _has_span(strong_goal, "goal_marksman_sustained_dps_sustained_3_10s_team_share", true)
	var strong_window_rate_pass: bool = _has_span(strong_goal, "goal_marksman_sustained_dps_sustained_3_10s_rate", true)
	var weak_window_share_failed: bool = _has_span(weak_goal, "goal_marksman_sustained_dps_sustained_3_10s_team_share", false)
	var weak_window_rate_failed: bool = _has_span(weak_goal, "goal_marksman_sustained_dps_sustained_3_10s_rate", false)

	print("MarksmanSustainedWindowKernelProbe: early=", early_damage,
		" sustained=", sustained_damage,
		" rate=", sustained_rate,
		" sustained_team_share=", sustained_team_share,
		" strong_goal_pass=", strong_goal_pass,
		" strong_team_share_diagnostic=", strong_team_share_diagnostic,
		" weak_goal_pass=", weak_goal_pass,
		" weak_window_share_failed=", weak_window_share_failed,
		" weak_window_rate_failed=", weak_window_rate_failed)

	var failed: bool = false
	if not is_equal_approx(early_damage, 10.0) or not is_equal_approx(sustained_damage, 70.0):
		printerr("MarksmanSustainedWindowKernelProbe: FAIL window damage buckets were not recorded")
		failed = true
	if sustained_rate < 9.99 or sustained_team_share < 0.49:
		printerr("MarksmanSustainedWindowKernelProbe: FAIL sustained 3-10s rate or team share was below proof thresholds")
		failed = true
	if not strong_goal_pass or not strong_team_share_diagnostic or not strong_window_share_pass or not strong_window_rate_pass:
		printerr("MarksmanSustainedWindowKernelProbe: FAIL strong windowed sustained proof did not pass through goal evidence")
		failed = true
	if not weak_goal_pass or not weak_window_share_failed or not weak_window_rate_failed:
		printerr("MarksmanSustainedWindowKernelProbe: FAIL weak windowed sustained control did not preserve failed direct spans")
		failed = true

	if failed:
		_quit(1)
		return
	print("MarksmanSustainedWindowKernelProbe: PASS")
	_quit(0)

func _window_kernel_result(subject_early: float, subject_sustained: Array[float], ally_early: Array[float], ally_sustained: Array[float]) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.state = state
	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 2, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				},
				{
					"unit_index": 1,
					"unit_id": ALLY_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": TARGET_ID
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	kernel.call("tick", 1.0)
	engine._resolver_emit_hit("player", 0, 0, int(subject_early), int(subject_early), false, 1000, 1000 - int(subject_early), 0.0, 0.0)
	for ally_early_damage in ally_early:
		engine._resolver_emit_hit("player", 1, 0, int(ally_early_damage), int(ally_early_damage), false, 1000, 1000 - int(ally_early_damage), 0.0, 0.0)
	kernel.call("tick", 3.0)
	for subject_damage in subject_sustained:
		engine._resolver_emit_hit("player", 0, 0, int(subject_damage), int(subject_damage), false, 1000, 1000 - int(subject_damage), 0.0, 0.0)
	kernel.call("tick", 3.0)
	for ally_sustained_damage in ally_sustained:
		engine._resolver_emit_hit("player", 1, 0, int(ally_sustained_damage), int(ally_sustained_damage), false, 1000, 1000 - int(ally_sustained_damage), 0.0, 0.0)
	kernel.call("finalize", 10.0)
	var result: Dictionary = kernel.call("result")
	kernel.call("detach")
	return result

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var subject: Unit = Unit.new()
	subject.id = SUBJECT_ID
	subject.max_hp = 1000
	subject.hp = 1000
	var ally: Unit = Unit.new()
	ally.id = ALLY_ID
	ally.max_hp = 1000
	ally.hp = 1000
	var target: Unit = Unit.new()
	target.id = TARGET_ID
	target.max_hp = 1000
	target.hp = 1000
	var player_team: Array[Unit] = [subject, ally]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _subject_pattern_rec(kernels: Dictionary) -> Dictionary:
	var patterns: Dictionary = kernels.get("combat_patterns", {})
	var per_unit: Dictionary = patterns.get("per_unit", {}) if (patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(SUBJECT_ID, {}) if (side_a is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _run_goal(case_id: String, kernels: Dictionary, subject_damage: float, team_damage: float) -> Dictionary:
	var ally_damage: float = max(0.0, team_damage - subject_damage)
	var metric: Variant = GoalPrimaryTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "sustained",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [SUBJECT_ID, ALLY_ID],
						"team_b_ids": [TARGET_ID]
					},
					"teams": {
						"a": {
							"damage": team_damage
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"damage": subject_damage,
								"incoming": 0.0,
								"time_alive_s": 10.0
							},
							{
								"unit_id": ALLY_ID,
								"damage": ally_damage,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": TARGET_ID,
								"damage": 0.0
							}
						]
					},
					"outcome": {
						"time_s": 10.0,
						"winner_side": "a"
					},
					"kernels": _with_positioning(kernels)
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}
	return metric.call("run_metric", payload)

func _with_positioning(kernels: Dictionary) -> Dictionary:
	var out: Dictionary = kernels.duplicate(true)
	out["per_unit_kpis"] = {
		"supported": true,
		"a": {
			SUBJECT_ID: {
				"time_on_target_pct": 0.70,
				"attacks_over_2_tiles_pct": 0.80,
				"attack_distance_median_tiles": 4.0
			}
		},
		"b": {}
	}
	return out

func _has_span(metric_result: Dictionary, label_prefix: String, required_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and span.has("ok") and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _has_diagnostic_span(metric_result: Dictionary, label_prefix: String, expected_reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value
		var label: String = String(span.get("label", ""))
		var reason: String = String(span.get("reason", ""))
		if label.begins_with(label_prefix) and not span.has("ok") and reason == expected_reason:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
