extends Node

const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const SUBJECT_ID: String = "probe_mage_sustain"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_install_probe_identity()
	var positive_result: Dictionary = _run_goal(_positive_payload())
	var negative_result: Dictionary = _run_goal(_negative_aoe_only_payload())
	RoleCommon.clear_identity_cache()

	var positive_pass: bool = bool(positive_result.get("pass", false))
	var negative_pass: bool = bool(negative_result.get("pass", false))
	var dot_span: bool = _has_span_prefix(positive_result, "goal_mage_sustained_dps_dot_tick_events")
	var zone_span: bool = _has_span_prefix(positive_result, "goal_mage_sustained_dps_zone_exposure_events")
	var ramp_span: bool = _has_span_prefix(positive_result, "goal_mage_sustained_dps_ramp_state_events")
	var diagnostic_span: bool = _has_span_prefix(negative_result, "goal_mage_sustained_dps_aoe_dps_diagnostic")

	print("MageSustainedDpsGoalProbe: positive_pass=", positive_pass,
		" negative_pass=", negative_pass,
		" dot_span=", dot_span,
		" zone_span=", zone_span,
		" ramp_span=", ramp_span,
		" diagnostic_span=", diagnostic_span)

	var failed: bool = false
	if not positive_pass:
		printerr("MageSustainedDpsGoalProbe: FAIL direct sustained magic evidence did not pass")
		failed = true
	if negative_pass:
		printerr("MageSustainedDpsGoalProbe: FAIL AoE-only damage case passed without direct sustained mechanism")
		failed = true
	if not dot_span or not zone_span or not ramp_span:
		printerr("MageSustainedDpsGoalProbe: FAIL direct DoT/zone/ramp spans were not emitted")
		failed = true
	if not diagnostic_span:
		printerr("MageSustainedDpsGoalProbe: FAIL AoE DPS diagnostic span was not emitted")
		failed = true

	if failed:
		_quit(1)
		return
	print("MageSustainedDpsGoalProbe: PASS")
	_quit(0)

func _install_probe_identity() -> void:
	RoleCommon.clear_identity_cache()
	RoleCommon._identity_cache[SUBJECT_ID] = {
		"unit_id": SUBJECT_ID,
		"primary_role": "mage",
		"primary_goal": "mage.sustained_dps",
		"approaches": ["dot", "zone", "ramp"],
		"cost": 0,
		"level": 1
	}

func _run_goal(payload: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	return metric.call("run_metric", payload)

func _positive_payload() -> Dictionary:
	return _base_payload({
		"combat_patterns": {
			"per_unit": {
				"a": {
					SUBJECT_ID: {
						"aoe_dps": 8.0,
						"ramp_state_supported": true,
						"ramp_state_events": 2,
						"ramp_stack_max": 3,
						"ramp_time_to_peak_s": 3.0,
						"ramp_peak_duration_s": 2.0,
						"ramp_window_duration_s": 2.0
					}
				}
			}
		},
		"buff_presence": {
			"supported": true,
			"dot_tick_supported": true,
			"per_unit": {
				"a": {
					SUBJECT_ID: {
						"dot_tick_events": 3,
						"dot_tick_damage": 45.0,
						"dot_tick_targets": 1,
						"dot_duration_applied_s": 3.0,
						"dot_uptime_s": 2.0
					}
				},
				"b": {}
			},
			"target_unit": {
				"a": {},
				"b": {
					"brute": {
						"dot_ticks_received": 3,
						"dot_damage_received": 45.0,
						"dot_uptime_received_s": 2.0
					}
				}
			}
		},
		"zone_exposure": {
			"supported": true,
			"per_unit": {
				"a": {
					SUBJECT_ID: {
						"zone_exposure_events": 2,
						"zone_exposure_targets": 2,
						"zone_exposure_time_s": 2.25,
						"zone_exposure_damage": 36.0,
						"zone_radius_tiles_max": 2.0
					}
				},
				"b": {}
			}
		}
	}, 90.0, 180.0)

func _negative_aoe_only_payload() -> Dictionary:
	return _base_payload({
		"combat_patterns": {
			"per_unit": {
				"a": {
					SUBJECT_ID: {
						"aoe_dps": 25.0,
						"max_targets_hit": 4,
						"multi_target_groups": 2
					}
				}
			}
		}
	}, 120.0, 180.0)

func _base_payload(kernels: Dictionary, subject_damage: float, team_damage: float) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUBJECT_ID],
						"team_b_ids": ["brute"]
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
					"kernels": kernels
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}

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
