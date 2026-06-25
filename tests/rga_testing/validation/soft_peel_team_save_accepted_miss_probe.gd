extends Node

const ApproachPeelTest := preload("res://tests/rga_testing/metrics/approach/peel_approach_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")
const SupportRoleTest := preload("res://tests/rga_testing/metrics/support/support_role_identity_test.gd")

const AXIOM_ID: String = "axiom"
const PAISLEY_ID: String = "paisley"
const CARRY_ID: String = "nyxa"
const ENEMY_ID: String = "repo"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var failures: Array[String] = []
	var axiom_full: Dictionary = _run_soft_peel_case(AXIOM_ID, _make_payload(AXIOM_ID, "axiom_full_team_save", 1, 0, 0.0, 0.0, 100.0))
	var axiom_aggregate: Dictionary = _run_soft_peel_case(AXIOM_ID, _make_payload(AXIOM_ID, "axiom_aggregate_ally_protection", 0, 1, 35.0, 0.0, 100.0))
	var axiom_weak: Dictionary = _run_soft_peel_case(AXIOM_ID, _make_payload(AXIOM_ID, "axiom_weak", 0, 0, 0.0, 0.0, 100.0))
	var paisley_full: Dictionary = _run_soft_peel_case(PAISLEY_ID, _make_payload(PAISLEY_ID, "paisley_full_team_save", 1, 0, 0.0, 0.0, 100.0))
	var paisley_aggregate: Dictionary = _run_soft_peel_case(PAISLEY_ID, _make_payload(PAISLEY_ID, "paisley_aggregate_ally_protection", 0, 1, 35.0, 0.0, 100.0))
	var paisley_weak: Dictionary = _run_soft_peel_case(PAISLEY_ID, _make_payload(PAISLEY_ID, "paisley_weak", 0, 0, 0.0, 0.0, 100.0))

	_check_approach_full(AXIOM_ID, axiom_full.get("approach_peel", {}), failures)
	_check_approach_aggregate(AXIOM_ID, axiom_aggregate.get("approach_peel", {}), failures)
	_check_approach_weak(AXIOM_ID, axiom_weak.get("approach_peel", {}), failures)
	_check_support_full(axiom_full.get("role_support", {}), failures)
	_check_support_aggregate(axiom_aggregate.get("role_support", {}), failures)
	_check_support_weak(axiom_weak.get("role_support", {}), failures)
	_check_approach_full(PAISLEY_ID, paisley_full.get("approach_peel", {}), failures)
	_check_approach_aggregate(PAISLEY_ID, paisley_aggregate.get("approach_peel", {}), failures)
	_check_approach_weak(PAISLEY_ID, paisley_weak.get("approach_peel", {}), failures)

	print("SoftPeelTeamSaveAcceptedMissProbe: axiom_full=", bool((axiom_full.get("approach_peel", {}) as Dictionary).get("pass", false)),
		" axiom_aggregate=", bool((axiom_aggregate.get("approach_peel", {}) as Dictionary).get("pass", false)),
		" paisley_full=", bool((paisley_full.get("approach_peel", {}) as Dictionary).get("pass", false)),
		" paisley_aggregate=", bool((paisley_aggregate.get("approach_peel", {}) as Dictionary).get("pass", false)))

	RoleCommon.clear_identity_cache()
	if not failures.is_empty():
		for failure in failures:
			printerr(failure)
		_quit(1)
		return
	print("SoftPeelTeamSaveAcceptedMissProbe: PASS")
	_quit(0)

func _run_soft_peel_case(subject_id: String, payload: Dictionary) -> Dictionary:
	var approach_peel: Variant = ApproachPeelTest.new()
	var results: Dictionary = {
		"approach_peel": approach_peel.call("run_metric", payload)
	}
	if subject_id == AXIOM_ID:
		var support_role: Variant = SupportRoleTest.new()
		results["role_support"] = support_role.call("run_metric", payload)
	return results

func _check_approach_full(subject_id: String, metric_result: Dictionary, failures: Array[String]) -> void:
	var pass_flag: bool = bool(metric_result.get("pass", false))
	var team_save_span: bool = _has_span(metric_result, "team_peel_saves_total", true)
	var ally_span: bool = _has_span(metric_result, "subject_peel_ally_protection_events", true)
	if not pass_flag or not team_save_span or ally_span:
		failures.append("SoftPeelTeamSaveAcceptedMissProbe: FAIL %s team-save approach proof pass=%s team_save_span=%s ally_span=%s" % [subject_id, str(pass_flag), str(team_save_span), str(ally_span)])

func _check_approach_aggregate(subject_id: String, metric_result: Dictionary, failures: Array[String]) -> void:
	var pass_flag: bool = bool(metric_result.get("pass", false))
	var team_save_fail_span: bool = _has_span(metric_result, "team_peel_saves_total", false)
	var ally_span: bool = _has_span(metric_result, "subject_peel_ally_protection_events", true)
	var ally_magnitude_span: bool = _has_span(metric_result, "subject_peel_ally_protection_magnitude", true)
	if not pass_flag or not team_save_fail_span or not ally_span or not ally_magnitude_span:
		failures.append("SoftPeelTeamSaveAcceptedMissProbe: FAIL %s aggregate approach control pass=%s team_save_fail=%s ally_span=%s ally_magnitude_span=%s" % [subject_id, str(pass_flag), str(team_save_fail_span), str(ally_span), str(ally_magnitude_span)])

func _check_approach_weak(subject_id: String, metric_result: Dictionary, failures: Array[String]) -> void:
	if bool(metric_result.get("pass", false)):
		failures.append("SoftPeelTeamSaveAcceptedMissProbe: FAIL %s weak approach control passed" % subject_id)

func _check_support_full(metric_result: Dictionary, failures: Array[String]) -> void:
	var pass_flag: bool = bool(metric_result.get("pass", false))
	var team_save_span: bool = _has_span(metric_result, "peel_saves_med_a", true)
	if not pass_flag or not team_save_span:
		failures.append("SoftPeelTeamSaveAcceptedMissProbe: FAIL Axiom support-role team-save proof pass=%s team_save_span=%s" % [str(pass_flag), str(team_save_span)])

func _check_support_aggregate(metric_result: Dictionary, failures: Array[String]) -> void:
	var pass_flag: bool = bool(metric_result.get("pass", false))
	var team_save_fail_span: bool = _has_span(metric_result, "peel_saves_med_a", false)
	var subject_support_span: bool = _has_span(metric_result, "subject_support_events", true)
	var subject_magnitude_span: bool = _has_span(metric_result, "subject_support_ally_buff_magnitude", true)
	if not pass_flag or not team_save_fail_span or not subject_support_span or not subject_magnitude_span:
		failures.append("SoftPeelTeamSaveAcceptedMissProbe: FAIL Axiom support-role aggregate control pass=%s team_save_fail=%s subject_support=%s subject_magnitude=%s" % [str(pass_flag), str(team_save_fail_span), str(subject_support_span), str(subject_magnitude_span)])

func _check_support_weak(metric_result: Dictionary, failures: Array[String]) -> void:
	if bool(metric_result.get("pass", false)):
		failures.append("SoftPeelTeamSaveAcceptedMissProbe: FAIL Axiom weak support-role control passed")

func _make_payload(subject_id: String, case_id: String, team_peel_saves: int, ally_events: int, ally_magnitude: float, support_shield: float, incoming: float) -> Dictionary:
	var buff_source_rec: Dictionary = {
		"ally_buffs_to_others": ally_events,
		"ally_buff_magnitude_to_others": ally_magnitude,
		"cc_immunity": 0,
		"cleanse_applied": 0
	}
	var support_rec: Dictionary = {
		"absorbed": support_shield
	}
	var buff_per_unit_a: Dictionary = {}
	var shield_per_unit_a: Dictionary = {}
	buff_per_unit_a[subject_id] = buff_source_rec
	shield_per_unit_a[subject_id] = support_rec
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [subject_id, CARRY_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"teams": {
						"a": {
							"damage": 30.0,
							"healing": 0.0,
							"shield": support_shield
						},
						"b": {
							"damage": incoming,
							"healing": 0.0,
							"shield": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": subject_id,
								"damage": 0.0,
								"incoming": incoming,
								"time_alive_s": 10.0
							},
							{
								"unit_id": CARRY_ID,
								"damage": 30.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": incoming,
								"incoming": 30.0,
								"time_alive_s": 10.0
							}
						]
					},
					"derived": {
						"a": {
							"peel_saves": team_peel_saves
						},
						"b": {
							"peel_saves": 0
						}
					},
					"kernels": {
						"buff_presence": {
							"supported": true,
							"per_unit": {
								"a": buff_per_unit_a
							}
						},
						"support": {
							"shield_absorbed_per_unit": {
								"a": shield_per_unit_a
							}
						}
					}
				}
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _has_span(metric_result: Dictionary, label_prefix: String, required_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
