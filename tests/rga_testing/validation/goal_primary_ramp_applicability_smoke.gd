extends Node

const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const SUBJECT_ID := "probe_attrition_ramp_applicability"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var ok: bool = true
	ok = _assert_non_ramp_goal_skips_ramp_spans() and ok
	ok = _assert_ramp_goal_keeps_ramp_spans() and ok
	RoleCommon.clear_identity_cache()
	if ok:
		print("GoalPrimaryRampApplicabilitySmoke: OK")
		get_tree().quit(0)
	else:
		printerr("GoalPrimaryRampApplicabilitySmoke: FAIL")
		get_tree().quit(1)

func _assert_non_ramp_goal_skips_ramp_spans() -> bool:
	_install_identity(["sustain", "burst"])
	var result: Dictionary = _run_goal()
	if not bool(result.get("pass", false)):
		printerr("Smoke: non-ramp attrition goal should still pass on frontline/sustain/survival evidence")
		return false
	if _has_span_prefix(result, "goal_attrition_dps_ramp_"):
		printerr("Smoke: non-ramp attrition goal emitted ramp diagnostic spans")
		return false
	return true

func _assert_ramp_goal_keeps_ramp_spans() -> bool:
	_install_identity(["sustain", "ramp"])
	var result: Dictionary = _run_goal()
	if not bool(result.get("pass", false)):
		printerr("Smoke: ramp-tagged attrition goal should pass on direct ramp evidence")
		return false
	if not _has_span_prefix(result, "goal_attrition_dps_ramp_state_events"):
		printerr("Smoke: ramp-tagged attrition goal did not emit direct ramp spans")
		return false
	return true

func _install_identity(approaches: Array[String]) -> void:
	RoleCommon.clear_identity_cache()
	RoleCommon._identity_cache[SUBJECT_ID] = {
		"unit_id": SUBJECT_ID,
		"primary_role": "brawler",
		"primary_goal": "brawler.attrition_dps",
		"approaches": approaches.duplicate(),
		"cost": 1,
		"level": 1
	}

func _run_goal() -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	return metric.call("run_metric", _payload())

func _payload() -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUBJECT_ID],
						"team_b_ids": ["probe_enemy"]
					},
					"teams": {
						"a": {"damage": 200.0},
						"b": {"damage": 0.0}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"damage": 120.0,
								"incoming": 50.0,
								"pre_mit_incoming": 50.0,
								"post_mit_incoming": 20.0,
								"healing": 20.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": "probe_enemy",
								"damage": 0.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						]
					},
					"outcome": {"time_s": 10.0},
					"kernels": {
						"per_unit_kpis": {
							"supported": true,
							"per_unit": {
								"a": {
									SUBJECT_ID: {"damage_to_frontline_pct": 0.60}
								},
								"b": {}
							}
						},
						"combat_patterns": {
							"supported": true,
							"per_unit": {
								"a": {
									SUBJECT_ID: {
										"ramp_state_supported": true,
										"ramp_state_events": 2,
										"ramp_stack_max": 3,
										"ramp_peak_duration_s": 2.0,
										"ramp_window_duration_s": 2.0,
										"ramp_time_to_peak_s": 3.0
									}
								},
								"b": {}
							}
						}
					}
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}

func _has_span_prefix(metric_result: Dictionary, prefix: String) -> bool:
	var raw_spans: Variant = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	if not (raw_spans is Array):
		return false
	for span_value: Variant in raw_spans:
		if not (span_value is Dictionary):
			continue
		var label: String = String((span_value as Dictionary).get("label", ""))
		if label.begins_with(prefix):
			return true
	return false
