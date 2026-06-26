extends Node

const PeelApproachTest := preload("res://tests/rga_testing/metrics/approach/peel_approach_test.gd")
const SustainApproachTest := preload("res://tests/rga_testing/metrics/approach/sustain_approach_test.gd")
const SupportRoleTest := preload("res://tests/rga_testing/metrics/support/support_role_identity_test.gd")

const SUSTAIN_SUBJECT_ID: String = "berebell"
const SUPPORT_SUBJECT_ID: String = "totem"
const ENEMY_ID: String = "enemy_dummy"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var sustain_positive: Dictionary = _run_sustain(_make_sustain_payload(true))
	var sustain_negative: Dictionary = _run_sustain(_make_sustain_payload(false))
	var peel_positive: Dictionary = _run_peel(_make_support_payload(true, true))
	var peel_negative: Dictionary = _run_peel(_make_support_payload(false, true))
	var role_team_positive: Dictionary = _run_support_role(_make_support_payload(true, false))
	var role_team_negative: Dictionary = _run_support_role(_make_support_payload(false, false))
	var role_subject_positive: Dictionary = _run_support_role(_make_support_payload(true, true))
	var role_subject_negative: Dictionary = _run_support_role(_make_support_payload(false, true))
	var sustain_alternate: Dictionary = _run_sustain(_make_sustain_hps_payload())
	var peel_alternate: Dictionary = _run_peel(_make_support_alternate_payload(true))
	var role_team_alternate: Dictionary = _run_support_role(_make_support_alternate_payload(false))
	var role_subject_alternate: Dictionary = _run_support_role(_make_support_alternate_payload(true))

	var sustain_ehp: float = _span_value(sustain_positive, "subject_sustain_ehp_ratio")
	var peel_ehp: float = _span_value(peel_positive, "subject_ehp_ratio")
	var role_team_ehp: float = _span_value(role_team_positive, "ehp_ratio_a")
	var role_subject_ehp: float = _span_value(role_subject_positive, "subject_ehp_ratio")
	var sustain_pass: bool = bool(sustain_positive.get("pass", false))
	var peel_pass: bool = bool(peel_positive.get("pass", false))
	var role_team_pass: bool = bool(role_team_positive.get("pass", false))
	var role_subject_pass: bool = bool(role_subject_positive.get("pass", false))
	var sustain_negative_pass: bool = bool(sustain_negative.get("pass", false))
	var peel_negative_pass: bool = bool(peel_negative.get("pass", false))
	var role_team_negative_pass: bool = bool(role_team_negative.get("pass", false))
	var role_subject_negative_pass: bool = bool(role_subject_negative.get("pass", false))
	var sustain_span: bool = _has_passing_span(sustain_positive, "subject_sustain_ehp_ratio")
	var peel_span: bool = _has_passing_span(peel_positive, "subject_ehp_ratio")
	var role_team_span: bool = _has_passing_span(role_team_positive, "ehp_ratio_a")
	var role_subject_span: bool = _has_passing_span(role_subject_positive, "subject_ehp_ratio")
	var sustain_alternate_ok: bool = bool(sustain_alternate.get("pass", false)) and _has_diagnostic_span(sustain_alternate, "subject_sustain_ehp_ratio", "alternate_sustain_hps_evidence_satisfied") and _has_passing_span(sustain_alternate, "subject_sustain_effective_hps")
	var peel_alternate_ok: bool = bool(peel_alternate.get("pass", false)) and _has_diagnostic_span(peel_alternate, "subject_ehp_ratio", "alternate_peel_evidence_satisfied") and _has_passing_span(peel_alternate, "subject_peel_ally_protection_events")
	var role_team_alternate_ok: bool = bool(role_team_alternate.get("pass", false)) and _has_diagnostic_span(role_team_alternate, "ehp_ratio_a", "alternate_support_evidence_satisfied") and _has_passing_span(role_team_alternate, "events_per_ally_med_a")
	var role_subject_alternate_ok: bool = bool(role_subject_alternate.get("pass", false)) and _has_diagnostic_span(role_subject_alternate, "subject_ehp_ratio", "alternate_support_evidence_satisfied") and _has_passing_span(role_subject_alternate, "subject_support_events")

	print("EhpRatioPathProbe: sustain_pass=", sustain_pass,
		" sustain_ehp=", sustain_ehp,
		" peel_pass=", peel_pass,
		" peel_ehp=", peel_ehp,
		" role_team_pass=", role_team_pass,
		" role_team_ehp=", role_team_ehp,
		" role_subject_pass=", role_subject_pass,
		" role_subject_ehp=", role_subject_ehp,
		" alternates=", [sustain_alternate_ok, peel_alternate_ok, role_team_alternate_ok, role_subject_alternate_ok],
		" negatives=", [sustain_negative_pass, peel_negative_pass, role_team_negative_pass, role_subject_negative_pass])

	var failed: bool = false
	if not sustain_pass or not peel_pass or not role_team_pass or not role_subject_pass:
		printerr("EhpRatioPathProbe: FAIL at least one positive EHP path did not pass")
		failed = true
	if sustain_ehp < 0.10 or peel_ehp < 0.15 or role_team_ehp < 0.15 or role_subject_ehp < 0.15:
		printerr("EhpRatioPathProbe: FAIL EHP ratio values were below proof thresholds")
		failed = true
	if not sustain_span or not peel_span or not role_team_span or not role_subject_span:
		printerr("EhpRatioPathProbe: FAIL expected passing EHP spans were missing")
		failed = true
	if sustain_negative_pass or peel_negative_pass or role_team_negative_pass or role_subject_negative_pass:
		printerr("EhpRatioPathProbe: FAIL weak negative EHP payload passed")
		failed = true
	if not sustain_alternate_ok or not peel_alternate_ok or not role_team_alternate_ok or not role_subject_alternate_ok:
		printerr("EhpRatioPathProbe: FAIL alternate EHP fallback diagnostics did not pass")
		failed = true

	if failed:
		_quit(1)
		return
	print("EhpRatioPathProbe: PASS")
	_quit(0)

func _run_sustain(payload: Dictionary) -> Dictionary:
	var metric: Variant = SustainApproachTest.new()
	return metric.call("run_metric", payload)

func _run_peel(payload: Dictionary) -> Dictionary:
	var metric: Variant = PeelApproachTest.new()
	return metric.call("run_metric", payload)

func _run_support_role(payload: Dictionary) -> Dictionary:
	var metric: Variant = SupportRoleTest.new()
	return metric.call("run_metric", payload)

func _make_sustain_payload(strong: bool) -> Dictionary:
	var incoming: float = 100.0
	var healing: float = 12.0 if strong else 2.0
	var shield: float = 4.0 if strong else 0.0
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUSTAIN_SUBJECT_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"units": {
						"a": [
							{
								"unit_id": SUSTAIN_SUBJECT_ID,
								"incoming": incoming,
								"healing": healing,
								"shield": shield,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": incoming,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						]
					}
				}
			}
		},
		"subject_unit_ids": [SUSTAIN_SUBJECT_ID]
	}

func _make_sustain_hps_payload() -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUSTAIN_SUBJECT_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"units": {
						"a": [
							{
								"unit_id": SUSTAIN_SUBJECT_ID,
								"incoming": 1000.0,
								"healing": 30.0,
								"shield": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": 1000.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						]
					}
				}
			}
		},
		"subject_unit_ids": [SUSTAIN_SUBJECT_ID]
	}

func _make_support_payload(strong: bool, include_subject: bool) -> Dictionary:
	var incoming: float = 100.0
	var healed: float = 10.0 if strong else 2.0
	var shield_absorbed: float = 12.0 if strong else 0.0
	var team_healing: float = healed
	var team_shield: float = shield_absorbed
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUPPORT_SUBJECT_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"teams": {
						"a": {
							"damage": 10.0,
							"healing": team_healing,
							"shield": team_shield
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
								"unit_id": SUPPORT_SUBJECT_ID,
								"damage": 0.0,
								"incoming": incoming,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": incoming,
								"incoming": 10.0,
								"time_alive_s": 10.0
							}
						]
					},
					"kernels": {
						"support": {
							"healing_per_unit": {
								"a": {
									SUPPORT_SUBJECT_ID: {
										"healed": healed,
										"overheal": 0.0
									}
								},
								"b": {}
							},
							"shield_absorbed_per_unit": {
								"a": {
									SUPPORT_SUBJECT_ID: {
										"absorbed": shield_absorbed
									}
								},
								"b": {}
							}
						}
					}
				}
			}
		}
	}
	if include_subject:
		payload["subject_unit_ids"] = [SUPPORT_SUBJECT_ID]
	return payload

func _make_support_alternate_payload(include_subject: bool) -> Dictionary:
	var buff_source_rec: Dictionary = {
		"ally_buffs_to_others": 1,
		"ally_buff_magnitude_to_others": 35.0,
		"cc_immunity": 0,
		"cleanse_applied": 0
	}
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [SUPPORT_SUBJECT_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"teams": {
						"a": {
							"damage": 10.0,
							"healing": 2.0,
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
								"unit_id": SUPPORT_SUBJECT_ID,
								"damage": 0.0,
								"incoming": 100.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": 100.0,
								"incoming": 10.0,
								"time_alive_s": 10.0
							}
						]
					},
					"kernels": {
						"buff_presence": {
							"supported": true,
							"a": {
								"events_per_ally": 2.0
							},
							"b": {
								"events_per_ally": 0.0
							},
							"per_unit": {
								"a": {
									SUPPORT_SUBJECT_ID: buff_source_rec
								}
							}
						}
					}
				}
			}
		}
	}
	if include_subject:
		payload["subject_unit_ids"] = [SUPPORT_SUBJECT_ID]
	return payload

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
