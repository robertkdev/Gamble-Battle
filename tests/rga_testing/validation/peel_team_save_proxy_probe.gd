extends Node

const ApproachPeelTest := preload("res://tests/rga_testing/metrics/approach/peel_approach_test.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const SupportRoleTest := preload("res://tests/rga_testing/metrics/support/support_role_identity_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const SUBJECT_ID: String = "totem"
const CARRY_ID: String = "carry_dummy"
const ENEMY_ID: String = "enemy_dummy"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var positive_payload: Dictionary = _make_payload(1)
	var negative_payload: Dictionary = _make_payload(0)
	var positive_approach: Dictionary = _run_approach(positive_payload)
	var positive_role: Dictionary = _run_role(positive_payload)
	var positive_goal: Dictionary = _run_goal(positive_payload)
	var negative_approach: Dictionary = _run_approach(negative_payload)
	var negative_role: Dictionary = _run_role(negative_payload)
	var negative_goal: Dictionary = _run_goal(negative_payload)
	var approach_pass: bool = bool(positive_approach.get("pass", false))
	var role_pass: bool = bool(positive_role.get("pass", false))
	var goal_pass: bool = bool(positive_goal.get("pass", false))
	var approach_negative_pass: bool = bool(negative_approach.get("pass", false))
	var role_negative_pass: bool = bool(negative_role.get("pass", false))
	var goal_negative_pass: bool = bool(negative_goal.get("pass", false))
	var approach_saves: float = _span_value(positive_approach, "team_peel_saves_total")
	var role_saves: float = _span_value(positive_role, "peel_saves_med_a")
	var goal_saves: float = _span_value(positive_goal, "goal_peel_carry_peel_saves")
	var approach_span: bool = _has_passing_span(positive_approach, "team_peel_saves_total")
	var role_span: bool = _has_passing_span(positive_role, "peel_saves_med_a")
	var goal_span: bool = _has_passing_span(positive_goal, "goal_peel_carry_peel_saves")

	print("PeelTeamSaveProxyProbe: approach_pass=", approach_pass,
		" role_pass=", role_pass,
		" goal_pass=", goal_pass,
		" approach_saves=", approach_saves,
		" role_saves=", role_saves,
		" goal_saves=", goal_saves,
		" negative_approach=", approach_negative_pass,
		" negative_role=", role_negative_pass,
		" negative_goal=", goal_negative_pass)

	var failed: bool = false
	if not approach_pass or not role_pass or not goal_pass:
		printerr("PeelTeamSaveProxyProbe: FAIL team-save proxy did not pass all peel consumers")
		failed = true
	if approach_saves < 1.0 or role_saves < 1.0 or goal_saves < 1.0:
		printerr("PeelTeamSaveProxyProbe: FAIL team-save span values were below the proof threshold")
		failed = true
	if not approach_span or not role_span or not goal_span:
		printerr("PeelTeamSaveProxyProbe: FAIL expected passing team-save spans were missing")
		failed = true
	if approach_negative_pass or role_negative_pass or goal_negative_pass:
		printerr("PeelTeamSaveProxyProbe: FAIL zero-save negative payload passed a peel consumer")
		failed = true

	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("PeelTeamSaveProxyProbe: PASS")
	_quit(0)

func _run_approach(payload: Dictionary) -> Dictionary:
	var metric: Variant = ApproachPeelTest.new()
	return metric.call("run_metric", payload)

func _run_role(payload: Dictionary) -> Dictionary:
	var metric: Variant = SupportRoleTest.new()
	return metric.call("run_metric", payload)

func _run_goal(payload: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	return metric.call("run_metric", payload)

func _make_payload(peel_saves: int) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUBJECT_ID, CARRY_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"teams": {
						"a": {
							"damage": 30.0,
							"healing": 0.0,
							"shield": 0.0
						},
						"b": {
							"damage": 100.0,
							"healing": 0.0,
							"shield": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"damage": 0.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							},
							{
								"unit_id": CARRY_ID,
								"damage": 30.0,
								"incoming": 100.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": 100.0,
								"incoming": 30.0,
								"time_alive_s": 10.0
							}
						]
					},
					"derived": {
						"a": {
							"peel_saves": peel_saves
						},
						"b": {
							"peel_saves": 0
						}
					},
					"kernels": {}
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}

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
