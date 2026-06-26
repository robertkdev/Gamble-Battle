extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

const SARI_ID: String = "sari"
const TELLER_ID: String = "teller"
const ALLY_ID: String = "marksman_goal_ally"
const TARGET_ID: String = "marksman_goal_target"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var sari_full_result: Dictionary = _run_case("sari_full_goal", SARI_ID, 90.0, 300.0, 0.72, 0.82, true, 4)
	var sari_low_damage_result: Dictionary = _run_case("sari_low_damage", SARI_ID, 60.0, 300.0, 0.72, 0.82, true, 4)
	var sari_low_ramp_result: Dictionary = _run_case("sari_low_ramp", SARI_ID, 90.0, 300.0, 0.72, 0.82, true, 1)
	var teller_full_result: Dictionary = _run_case("teller_full_goal", TELLER_ID, 90.0, 300.0, 0.70, 0.80, false, 0)
	var teller_low_damage_result: Dictionary = _run_case("teller_low_damage", TELLER_ID, 60.0, 300.0, 0.70, 0.80, false, 0)
	var weak_result: Dictionary = _run_case("weak_marksman_goal", SARI_ID, 30.0, 300.0, 0.10, 0.10, false, 0, 2.0)

	var sari_full_goal: Dictionary = sari_full_result.get("goal", {})
	var sari_low_damage_goal: Dictionary = sari_low_damage_result.get("goal", {})
	var sari_low_ramp_goal: Dictionary = sari_low_ramp_result.get("goal", {})
	var teller_full_goal: Dictionary = teller_full_result.get("goal", {})
	var teller_low_damage_goal: Dictionary = teller_low_damage_result.get("goal", {})
	var weak_goal: Dictionary = weak_result.get("goal", {})

	var sari_full_pass: bool = bool(sari_full_goal.get("pass", false))
	var sari_low_damage_pass: bool = bool(sari_low_damage_goal.get("pass", false))
	var sari_low_ramp_pass: bool = bool(sari_low_ramp_goal.get("pass", false))
	var teller_full_pass: bool = bool(teller_full_goal.get("pass", false))
	var teller_low_damage_pass: bool = bool(teller_low_damage_goal.get("pass", false))
	var weak_pass: bool = bool(weak_goal.get("pass", false))
	var sari_damage_share: float = _span_value(sari_full_goal, "goal_marksman_sustained_dps_team_damage_share")
	var teller_damage_share: float = _span_value(teller_full_goal, "goal_marksman_sustained_dps_team_damage_share")
	var sari_ramp_stack: float = _span_value(sari_full_goal, "goal_marksman_sustained_dps_ramp_stack_max")
	var sari_damage_span: bool = _has_span(sari_full_goal, "goal_marksman_sustained_dps_team_damage_share", true)
	var teller_damage_span: bool = _has_span(teller_full_goal, "goal_marksman_sustained_dps_team_damage_share", true)
	var sari_ramp_stack_span: bool = _has_span(sari_full_goal, "goal_marksman_sustained_dps_ramp_stack_max", true)
	var sari_low_damage_fail_span: bool = _has_span(sari_low_damage_goal, "goal_marksman_sustained_dps_team_damage_share", false)
	var teller_low_damage_fail_span: bool = _has_span(teller_low_damage_goal, "goal_marksman_sustained_dps_team_damage_share", false)
	var sari_low_ramp_stack: float = _span_value(sari_low_ramp_goal, "goal_marksman_sustained_dps_ramp_stack_max")
	var sari_low_ramp_diagnostic: bool = _has_diagnostic_span(sari_low_ramp_goal, "goal_marksman_sustained_dps_ramp_stack_max", "alternate_ramp_state_evidence_satisfied")
	var weak_damage_span: bool = _has_span(weak_goal, "goal_marksman_sustained_dps_team_damage_share", true)
	var weak_range_span: bool = _has_span(weak_goal, "goal_marksman_sustained_dps_attacks_over_2_tiles", true)

	print("MarksmanSustainedDpsGoalProbe: sari_full_pass=", sari_full_pass,
		" sari_damage_share=", sari_damage_share,
		" sari_ramp_stack=", sari_ramp_stack,
		" sari_low_damage_pass=", sari_low_damage_pass,
		" sari_low_damage_fail_span=", sari_low_damage_fail_span,
		" sari_low_ramp_pass=", sari_low_ramp_pass,
		" sari_low_ramp_stack=", sari_low_ramp_stack,
		" sari_low_ramp_diagnostic=", sari_low_ramp_diagnostic,
		" teller_full_pass=", teller_full_pass,
		" teller_damage_share=", teller_damage_share,
		" teller_low_damage_pass=", teller_low_damage_pass,
		" teller_low_damage_fail_span=", teller_low_damage_fail_span,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not sari_full_pass or not sari_damage_span or not sari_ramp_stack_span:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL Sari full sustained-DPS proof did not pass direct damage and ramp spans")
		failed = true
	if sari_damage_share < 0.29 or sari_ramp_stack < 4.0:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL Sari direct damage share or ramp stack proof was below target")
		failed = true
	if not teller_full_pass or not teller_damage_span:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL Teller full sustained-DPS proof did not pass direct damage share")
		failed = true
	if teller_damage_share < 0.29:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL Teller direct damage share proof was below target")
		failed = true
	if not sari_low_damage_pass or not sari_low_damage_fail_span:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL Sari low-damage aggregate path did not preserve a failed damage-share span")
		failed = true
	if not teller_low_damage_pass or not teller_low_damage_fail_span:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL Teller low-damage aggregate path did not preserve a failed damage-share span")
		failed = true
	if not sari_low_ramp_pass or not sari_low_ramp_diagnostic or sari_low_ramp_stack >= 2.0:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL Sari low-ramp aggregate path did not keep ramp-stack span diagnostic")
		failed = true
	if weak_pass or weak_damage_span or weak_range_span:
		printerr("MarksmanSustainedDpsGoalProbe: FAIL weak marksman sustained-DPS control passed")
		failed = true

	if failed:
		_quit(1)
		return
	print("MarksmanSustainedDpsGoalProbe: PASS")
	_quit(0)

func _run_case(case_id: String, subject_id: String, subject_damage: float, team_damage: float, time_on_target: float, ranged_share: float, include_ramp: bool, ramp_stack_max: int, time_alive_s: float = 10.0) -> Dictionary:
	var kernels: Dictionary = {
		"per_unit_kpis": {
			"supported": true,
			"a": {
				subject_id: {
					"time_on_target_pct": time_on_target,
					"attacks_over_2_tiles_pct": ranged_share,
					"attack_distance_median_tiles": 4.0 if ranged_share >= 0.50 else 1.0
				}
			},
			"b": {}
		}
	}
	if include_ramp:
		var ramp_result: Dictionary = _ramp_kernel_result(subject_id, ramp_stack_max)
		for key in ramp_result.keys():
			kernels[key] = ramp_result.get(key)
	var goal_result: Dictionary = _run_goal(case_id, subject_id, kernels, subject_damage, team_damage, time_alive_s)
	return {
		"goal": goal_result
	}

func _ramp_kernel_result(subject_id: String, ramp_stack_max: int) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state(subject_id)
	engine.state = state
	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": subject_id
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
	var peak_stack: int = max(1, ramp_stack_max)
	kernel.call("attach", engine, team_sizes, context_tags, true)
	kernel.call("tick", 1.0)
	engine._resolver_emit_ramp_state_changed("player", 0, "stack_window", 1, 1.0, peak_stack, 2.0, "marksman_goal_ramp_setup")
	kernel.call("tick", 2.0)
	engine._resolver_emit_ramp_state_changed("player", 0, "stack_window", peak_stack, float(peak_stack), peak_stack, 3.0, "marksman_goal_ramp_peak")
	kernel.call("finalize", 6.0)
	var result: Dictionary = kernel.call("result")
	kernel.call("detach")
	return result

func _make_state(subject_id: String) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var subject: Unit = Unit.new()
	subject.id = subject_id
	subject.max_hp = 1000
	subject.hp = 1000
	var target: Unit = Unit.new()
	target.id = TARGET_ID
	target.max_hp = 1000
	target.hp = 1000
	var player_team: Array[Unit] = [subject]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_goal(case_id: String, subject_id: String, kernels: Dictionary, subject_damage: float, team_damage: float, time_alive_s: float) -> Dictionary:
	var ally_damage: float = max(0.0, team_damage - subject_damage)
	var metric: Variant = GoalPrimaryTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [subject_id, ALLY_ID],
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
								"unit_id": subject_id,
								"damage": subject_damage,
								"incoming": 0.0,
								"time_alive_s": time_alive_s
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
					"kernels": kernels
				}
			}
		},
		"subject_unit_ids": [subject_id]
	}
	return metric.call("run_metric", payload)

func _has_span(metric_result: Dictionary, label_prefix: String, required_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and span.has("ok") and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _has_diagnostic_span(metric_result: Dictionary, label_prefix: String, expected_reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		var reason: String = String(span.get("reason", ""))
		if label.begins_with(label_prefix) and not span.has("ok") and reason == expected_reason:
			return true
	return false

func _span_value(metric_result: Dictionary, label_prefix: String) -> float:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return float(span.get("value", 0.0))
	return 0.0

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
