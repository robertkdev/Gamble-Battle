extends Node

const ApproachPeelTest := preload("res://tests/rga_testing/metrics/approach/peel_approach_test.gd")
const CcImmunityApproachTest := preload("res://tests/rga_testing/metrics/approach/cc_immunity_approach_test.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")
const SupportRoleTest := preload("res://tests/rga_testing/metrics/support/support_role_identity_test.gd")

const SUBJECT_ID: String = "totem"
const CARRY_ID: String = "nyxa"
const ENEMY_ID: String = "repo"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var full_result: Dictionary = _run_all(_make_payload("full", 1, 100.0, 30.0, 1, 35.0, 1, 1, 1, 2.0, 2.0, 2, 1.0, 1))
	var low_result: Dictionary = _run_all(_make_payload("low_aggregate", 0, 100.0, 0.0, 1, 35.0, 1, 1, 0, 1.0, 0.82, 1, 1.0, 0))
	var weak_result: Dictionary = _run_all(_make_payload("weak", 0, 100.0, 0.0, 0, 0.0, 0, 0, 0, 0.0, 0.0, 0, 0.0, 0))

	var full_peel: Dictionary = full_result.get("approach_peel", {})
	var full_cc: Dictionary = full_result.get("approach_cc_immunity", {})
	var full_role: Dictionary = full_result.get("role_support", {})
	var full_goal: Dictionary = full_result.get("goal_primary", {})
	var low_peel: Dictionary = low_result.get("approach_peel", {})
	var low_cc: Dictionary = low_result.get("approach_cc_immunity", {})
	var low_role: Dictionary = low_result.get("role_support", {})
	var low_goal: Dictionary = low_result.get("goal_primary", {})

	var full_pass: bool = _all_metric_pass(full_result)
	var low_pass: bool = _all_metric_pass(low_result)
	var weak_pass: bool = _any_metric_pass(weak_result)
	var low_team_save_diagnostic: bool = _has_diagnostic_span(low_peel, "team_peel_saves_total", "alternate_peel_evidence_satisfied") and _has_diagnostic_span(low_role, "peel_saves_med_a", "alternate_support_evidence_satisfied") and _has_span(low_goal, "goal_peel_carry_peel_saves", false)
	var low_ehp_diagnostic: bool = _has_diagnostic_span(low_peel, "subject_ehp_ratio", "alternate_peel_evidence_satisfied") and _has_diagnostic_span(low_role, "subject_ehp_ratio", "alternate_support_evidence_satisfied")
	var low_cc_prevented_failed: bool = _has_span(low_cc, "subject_cc_prevented_as_target", false)
	var low_cooldown_efficiency_failed: bool = _has_span(low_cc, "subject_cc_immunity_cooldown_trade_efficiency", false) and _has_span(low_goal, "goal_peel_carry_cooldown_trade_efficiency", false)
	var low_interrupt_failed: bool = _has_span(low_goal, "goal_peel_carry_interrupt_events", false)
	var low_direct_protection_passed: bool = _has_span(low_peel, "subject_peel_ally_protection_events", true) and _has_span(low_role, "subject_support_events", true) and _has_span(low_goal, "goal_peel_carry_ally_protection_events", true)

	print("TotemPeelCarryAcceptedMissProbe: full_pass=", full_pass,
		" low_pass=", low_pass,
		" weak_pass=", weak_pass,
		" low_team_save_diagnostic=", low_team_save_diagnostic,
		" low_ehp_diagnostic=", low_ehp_diagnostic,
		" low_cc_prevented_failed=", low_cc_prevented_failed,
		" low_cooldown_efficiency_failed=", low_cooldown_efficiency_failed,
		" low_interrupt_failed=", low_interrupt_failed)

	var failed: bool = false
	if not full_pass:
		printerr("TotemPeelCarryAcceptedMissProbe: FAIL full Totem support/peel proof did not pass all consumers")
		failed = true
	if not _has_span(full_peel, "team_peel_saves_total", true) or not _has_span(full_cc, "subject_cc_prevented_as_target", true) or not _has_span(full_goal, "goal_peel_carry_interrupt_events", true):
		printerr("TotemPeelCarryAcceptedMissProbe: FAIL full proof did not emit expected passing lower-level spans")
		failed = true
	if not low_pass:
		printerr("TotemPeelCarryAcceptedMissProbe: FAIL aggregate direct-protection control did not pass all consumers")
		failed = true
	if not low_team_save_diagnostic or not low_ehp_diagnostic or not low_cc_prevented_failed or not low_cooldown_efficiency_failed or not low_interrupt_failed:
		printerr("TotemPeelCarryAcceptedMissProbe: FAIL aggregate control did not preserve expected diagnostic/failed lower-level spans")
		failed = true
	if not low_direct_protection_passed:
		printerr("TotemPeelCarryAcceptedMissProbe: FAIL aggregate control did not pass through direct protection evidence")
		failed = true
	if weak_pass:
		printerr("TotemPeelCarryAcceptedMissProbe: FAIL weak support/peel payload passed at least one consumer")
		failed = true

	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("TotemPeelCarryAcceptedMissProbe: PASS")
	_quit(0)

func _run_all(payload: Dictionary) -> Dictionary:
	var approach_peel: Variant = ApproachPeelTest.new()
	var approach_cc: Variant = CcImmunityApproachTest.new()
	var support_role: Variant = SupportRoleTest.new()
	var goal_primary: Variant = GoalPrimaryTest.new()
	return {
		"approach_peel": approach_peel.call("run_metric", payload),
		"approach_cc_immunity": approach_cc.call("run_metric", payload),
		"role_support": support_role.call("run_metric", payload),
		"goal_primary": goal_primary.call("run_metric", payload)
	}

func _make_payload(case_id: String, team_peel_saves: int, incoming: float, support_shield: float, ally_events: int, ally_magnitude: float, cc_immunity: int, cleanse_applied: int, cc_prevented: int, cooldown_s: float, cooldown_efficiency: float, cooldown_casters: int, key_threat_share: float, cc_events: int) -> Dictionary:
	var buff_source_rec: Dictionary = {
		"ally_buffs_to_others": ally_events,
		"ally_buff_magnitude_to_others": ally_magnitude,
		"cc_immunity": cc_immunity,
		"cleanse_applied": cleanse_applied
	}
	var buff_target_rec: Dictionary = {
		"cc_prevented": cc_prevented,
		"cc_immunity_received": 0
	}
	var cooldown_rec: Dictionary = {
		"cooldowns_forced": 1 if cooldown_s > 0.0 else 0,
		"key_cooldowns_forced": 1 if cooldown_s > 0.0 else 0,
		"cooldowns_forced_s": cooldown_s,
		"cooldown_trade_efficiency": cooldown_efficiency,
		"cooldown_threat_draw_casters": cooldown_casters,
		"cooldown_threat_draw_abilities": cooldown_casters,
		"cooldown_key_threat_share": key_threat_share
	}
	var control_rec: Dictionary = {
		"cc_events": cc_events,
		"cc_seconds": float(cc_events)
	}
	var support_rec: Dictionary = {
		"absorbed": support_shield
	}
	var buff_per_unit_a: Dictionary = {}
	var buff_target_a: Dictionary = {}
	var cooldown_per_unit_a: Dictionary = {}
	var control_per_unit_a: Dictionary = {}
	var shield_per_unit_a: Dictionary = {}
	buff_per_unit_a[SUBJECT_ID] = buff_source_rec
	buff_target_a[SUBJECT_ID] = buff_target_rec
	cooldown_per_unit_a[SUBJECT_ID] = cooldown_rec
	control_per_unit_a[SUBJECT_ID] = control_rec
	shield_per_unit_a[SUBJECT_ID] = support_rec
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [SUBJECT_ID, CARRY_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"teams": {
						"a": {
							"damage": 20.0,
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
								"unit_id": SUBJECT_ID,
								"damage": 0.0,
								"incoming": incoming,
								"time_alive_s": 10.0
							},
							{
								"unit_id": CARRY_ID,
								"damage": 20.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": incoming,
								"incoming": 20.0,
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
							},
							"target_unit": {
								"a": buff_target_a
							}
						},
						"control_mobility": {
							"per_unit": {
								"a": control_per_unit_a
							}
						},
						"cooldown_pressure": {
							"per_unit": {
								"a": cooldown_per_unit_a
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
		"subject_unit_ids": [SUBJECT_ID]
	}

func _all_metric_pass(results: Dictionary) -> bool:
	return _metric_pass(results, "approach_peel") and _metric_pass(results, "approach_cc_immunity") and _metric_pass(results, "role_support") and _metric_pass(results, "goal_primary")

func _any_metric_pass(results: Dictionary) -> bool:
	return _metric_pass(results, "approach_peel") or _metric_pass(results, "approach_cc_immunity") or _metric_pass(results, "role_support") or _metric_pass(results, "goal_primary")

func _metric_pass(results: Dictionary, metric_key: String) -> bool:
	var result: Dictionary = results.get(metric_key, {}) if (results is Dictionary) else {}
	return bool(result.get("pass", false))

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

func _has_diagnostic_span(metric_result: Dictionary, label_prefix: String, reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and not span.has("ok") and String(span.get("reason", "")) == reason:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
