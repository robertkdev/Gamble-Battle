extends Node

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")
const BrawlerRoleTest := preload("res://tests/rga_testing/metrics/brawler/brawler_role_identity_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var subject_id: String = "probe_brawler_direct_attrition"
	RoleCommon._identity_cache[subject_id] = {
		"unit_id": subject_id,
		"primary_role": "brawler",
		"primary_goal": "brawler.attrition_dps",
		"approaches": ["sustain", "aoe", "damage_reduction"],
		"cost": 2,
		"level": 1
	}

	var positive_result: Dictionary = _run_metric(_positive_payload(subject_id))
	var prevention_result: Dictionary = _run_metric(_prevention_sustain_payload(subject_id))
	var support_result: Dictionary = _run_metric(_support_sustain_payload(subject_id))
	var burst_result: Dictionary = _run_metric(_burst_payload(subject_id))
	var negative_result: Dictionary = _run_metric(_negative_payload(subject_id))
	var positive_span: Dictionary = _find_span(positive_result, "unit_direct_attrition_evidence")
	var prevention_span: Dictionary = _find_span(prevention_result, "unit_direct_attrition_evidence")
	var support_span: Dictionary = _find_span(support_result, "unit_direct_attrition_evidence")
	var burst_span: Dictionary = _find_span(burst_result, "unit_direct_attrition_evidence")
	var negative_span: Dictionary = _find_span(negative_result, "unit_direct_attrition_evidence")
	var positive_pass: bool = bool(positive_result.get("pass", false))
	var prevention_pass: bool = bool(prevention_result.get("pass", false))
	var support_pass: bool = bool(support_result.get("pass", false))
	var burst_pass: bool = bool(burst_result.get("pass", false))
	var negative_pass: bool = bool(negative_result.get("pass", false))
	var direct_ok: bool = bool(positive_span.get("ok", false))
	var prevention_direct_ok: bool = bool(prevention_span.get("ok", false))
	var support_direct_ok: bool = bool(support_span.get("ok", false))
	var burst_direct_ok: bool = bool(burst_span.get("ok", false))
	var direct_negative_ok: bool = bool(negative_span.get("ok", false))
	var frontline_share: float = float(positive_span.get("direct_attrition_frontline_share", 0.0))
	var effective_hps: float = float(positive_span.get("direct_attrition_effective_hps", 0.0))
	var prevention_effective_hps: float = float(prevention_span.get("direct_attrition_effective_hps", 0.0))
	var prevented_damage_total: float = float(prevention_span.get("direct_attrition_prevented_damage", 0.0))
	var support_effective_hps: float = float(support_span.get("direct_attrition_effective_hps", 0.0))
	var support_healing_total: float = float(support_span.get("direct_attrition_support_healing", 0.0))
	var support_shield_total: float = float(support_span.get("direct_attrition_support_shield", 0.0))
	var aoe_dps: float = float(positive_span.get("direct_attrition_aoe_dps", 0.0))
	var max_targets_hit: float = float(positive_span.get("direct_attrition_max_targets_hit", 0.0))
	var burst_peak_dps: float = float(burst_span.get("direct_attrition_burst_peak_dps", 0.0))
	var burst_peak_share: float = float(burst_span.get("direct_attrition_burst_peak_share", 0.0))
	var burst_pressure_ok: bool = bool(burst_span.get("direct_attrition_burst_ok", false))
	var unit_pass: bool = _has_passing_span(positive_result, "unit_pass")
	var prevention_unit_pass: bool = _has_passing_span(prevention_result, "unit_pass")
	var support_unit_pass: bool = _has_passing_span(support_result, "unit_pass")
	var burst_unit_pass: bool = _has_passing_span(burst_result, "unit_pass")

	print("BrawlerDirectAttritionProbe: positive_pass=", positive_pass,
		" direct_ok=", direct_ok,
		" frontline_share=", frontline_share,
		" effective_hps=", effective_hps,
		" aoe_dps=", aoe_dps,
		" max_targets=", max_targets_hit,
		" prevention_pass=", prevention_pass,
		" prevention_direct_ok=", prevention_direct_ok,
		" prevention_effective_hps=", prevention_effective_hps,
		" prevented_damage=", prevented_damage_total,
		" support_pass=", support_pass,
		" support_direct_ok=", support_direct_ok,
		" support_effective_hps=", support_effective_hps,
		" support_healing=", support_healing_total,
		" support_shield=", support_shield_total,
		" burst_pass=", burst_pass,
		" burst_direct_ok=", burst_direct_ok,
		" burst_peak_dps=", burst_peak_dps,
		" burst_peak_share=", burst_peak_share,
		" burst_pressure_ok=", burst_pressure_ok,
		" negative_pass=", negative_pass,
		" negative_direct_ok=", direct_negative_ok)

	var failed: bool = false
	if not positive_pass or not unit_pass:
		printerr("BrawlerDirectAttritionProbe: FAIL positive payload did not pass the brawler role")
		failed = true
	if not direct_ok:
		printerr("BrawlerDirectAttritionProbe: FAIL direct attrition span did not pass")
		failed = true
	if frontline_share < 0.40 or effective_hps < 2.0:
		printerr("BrawlerDirectAttritionProbe: FAIL frontline or sustain direct attrition evidence was below threshold")
		failed = true
	if not prevention_pass or not prevention_unit_pass or not prevention_direct_ok:
		printerr("BrawlerDirectAttritionProbe: FAIL prevented-damage sustain payload did not pass direct attrition")
		failed = true
	if prevention_effective_hps < 2.0 or prevented_damage_total <= 0.0:
		printerr("BrawlerDirectAttritionProbe: FAIL prevented-damage sustain evidence was not recorded")
		failed = true
	if not support_pass or not support_unit_pass or not support_direct_ok:
		printerr("BrawlerDirectAttritionProbe: FAIL support-kernel sustain payload did not pass direct attrition")
		failed = true
	if support_effective_hps < 2.0 or support_healing_total + support_shield_total <= 0.0:
		printerr("BrawlerDirectAttritionProbe: FAIL support-kernel sustain evidence was not recorded")
		failed = true
	if aoe_dps < 4.0 or max_targets_hit < 2.0:
		printerr("BrawlerDirectAttritionProbe: FAIL pressure evidence was not recorded")
		failed = true
	if not burst_pass or not burst_unit_pass or not burst_direct_ok:
		printerr("BrawlerDirectAttritionProbe: FAIL burst-pressure payload did not pass direct attrition")
		failed = true
	if burst_peak_dps < 25.0 or not burst_pressure_ok:
		printerr("BrawlerDirectAttritionProbe: FAIL burst pressure evidence was not recorded")
		failed = true
	if negative_pass or direct_negative_ok:
		printerr("BrawlerDirectAttritionProbe: FAIL negative payload passed")
		failed = true

	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("BrawlerDirectAttritionProbe: PASS")
	_quit(0)

func _run_metric(payload: Dictionary) -> Dictionary:
	var metric: Variant = BrawlerRoleTest.new()
	return metric.call("run_metric", payload)

func _positive_payload(subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	_add_throughput_kernel(kernels, 38.0, 10.0, 12.0, 14.0)
	_add_focus_survival_kernel(kernels, subject_id, 9.5)
	_add_per_unit_kpi_kernel(kernels, subject_id, 0.55)
	_add_combat_pattern_kernel(kernels, subject_id, 6.5, 2.0, 20.0, 0.10)
	return _base_payload(subject_id, _subject_unit(subject_id, 120.0, 120.0, 10.0, 12.0, 14.0), kernels)

func _prevention_sustain_payload(subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	_add_throughput_kernel(kernels, 38.0, 10.0, 12.0, 14.0)
	_add_focus_survival_kernel(kernels, subject_id, 9.5)
	_add_per_unit_kpi_kernel(kernels, subject_id, 0.55)
	_add_combat_pattern_kernel(kernels, subject_id, 6.5, 2.0, 20.0, 0.10)
	return _base_payload(subject_id, _subject_unit_with_prevention(subject_id, 120.0, 120.0, 10.0, 26.0), kernels)

func _support_sustain_payload(subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	_add_throughput_kernel(kernels, 38.0, 10.0, 12.0, 14.0)
	_add_focus_survival_kernel(kernels, subject_id, 9.5)
	_add_per_unit_kpi_kernel(kernels, subject_id, 0.55)
	_add_combat_pattern_kernel(kernels, subject_id, 6.5, 2.0, 20.0, 0.10)
	_add_support_kernel(kernels, subject_id, 16.0, 10.0)
	return _base_payload(subject_id, _subject_unit(subject_id, 120.0, 120.0, 10.0, 0.0, 0.0), kernels)

func _burst_payload(subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	_add_throughput_kernel(kernels, 38.0, 10.0, 12.0, 14.0)
	_add_focus_survival_kernel(kernels, subject_id, 9.5)
	_add_per_unit_kpi_kernel(kernels, subject_id, 0.55)
	_add_combat_pattern_kernel(kernels, subject_id, 0.0, 1.0, 80.0, 0.18)
	return _base_payload(subject_id, _subject_unit(subject_id, 120.0, 120.0, 10.0, 12.0, 14.0), kernels)

func _negative_payload(subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	_add_throughput_kernel(kernels, 5.0, 25.0, 30.0, 32.0)
	_add_focus_survival_kernel(kernels, subject_id, 9.5)
	_add_per_unit_kpi_kernel(kernels, subject_id, 0.10)
	_add_combat_pattern_kernel(kernels, subject_id, 0.5, 1.0, 5.0, 0.02)
	return _base_payload(subject_id, _subject_unit(subject_id, 20.0, 120.0, 10.0, 0.0, 0.0), kernels)

func _base_payload(subject_id: String, subject_unit: Dictionary, kernels: Dictionary) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [subject_id, "probe_brawler_ally"],
						"team_b_ids": ["probe_enemy_0", "probe_enemy_1"]
					},
					"teams": {
						"a": {
							"damage": 140.0
						},
						"b": {
							"damage": 60.0
						}
					},
					"units": {
						"a": [
							subject_unit,
							_subject_unit("probe_brawler_ally", 30.0, 20.0, 10.0, 0.0, 0.0)
						],
						"b": [
							_subject_unit("probe_enemy_0", 25.0, 0.0, 10.0, 0.0, 0.0),
							_subject_unit("probe_enemy_1", 35.0, 0.0, 10.0, 0.0, 0.0)
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

func _subject_unit(unit_id: String, damage: float, incoming: float, time_alive_s: float, healing: float, shield: float) -> Dictionary:
	return {
		"unit_id": unit_id,
		"damage": damage,
		"incoming": incoming,
		"mitigated": 0.0,
		"pre_mit_incoming": incoming,
		"post_mit_incoming": incoming,
		"healing": healing,
		"shield": shield,
		"time_alive_s": time_alive_s
	}

func _subject_unit_with_prevention(unit_id: String, damage: float, incoming: float, time_alive_s: float, prevented_damage: float) -> Dictionary:
	var unit: Dictionary = _subject_unit(unit_id, damage, incoming, time_alive_s, 0.0, 0.0)
	unit["mitigated"] = prevented_damage
	unit["pre_mit_incoming"] = incoming + prevented_damage
	unit["post_mit_incoming"] = incoming
	return unit

func _add_throughput_kernel(kernels: Dictionary, subject_rate: float, ally_rate: float, enemy_rate_a: float, enemy_rate_b: float) -> void:
	kernels["throughput"] = {
		"peers": {
			"all": [subject_rate, ally_rate, enemy_rate_a, enemy_rate_b],
			"a": [subject_rate, ally_rate],
			"b": [enemy_rate_a, enemy_rate_b]
		},
		"peers_by_index": {
			"a": {
				"0": subject_rate,
				"1": ally_rate
			},
			"b": {
				"0": enemy_rate_a,
				"1": enemy_rate_b
			}
		}
	}

func _add_focus_survival_kernel(kernels: Dictionary, subject_id: String, focus_survival_s: float) -> void:
	kernels["focus_survival"] = {
		"supported": true,
		"focus_survival_per_unit": {
			"a": {
				subject_id: {
					"avg_s": focus_survival_s,
					"samples": 1
				}
			},
			"b": {}
		}
	}

func _add_per_unit_kpi_kernel(kernels: Dictionary, subject_id: String, damage_to_frontline_pct: float) -> void:
	kernels["per_unit_kpis"] = {
		"a": {
			subject_id: {
				"damage_to_frontline_pct": damage_to_frontline_pct
			}
		},
		"b": {}
	}

func _add_combat_pattern_kernel(kernels: Dictionary, subject_id: String, aoe_dps: float, max_targets_hit: float, peak_1s_dps: float, peak_1s_damage_share: float) -> void:
	kernels["combat_patterns"] = {
		"per_unit": {
			"a": {
				subject_id: {
					"aoe_dps": aoe_dps,
					"max_targets_hit": max_targets_hit,
					"peak_1s_dps": peak_1s_dps,
					"peak_1s_damage_share": peak_1s_damage_share
				}
			},
			"b": {}
		}
	}

func _add_support_kernel(kernels: Dictionary, subject_id: String, healed: float, shield_absorbed: float) -> void:
	kernels["support"] = {
		"healing_per_unit": {
			"a": {
				subject_id: {
					"healed": healed,
					"overheal": 0.0,
					"samples": 1
				}
			},
			"b": {}
		},
		"shield_absorbed_per_unit": {
			"a": {
				subject_id: {
					"absorbed": shield_absorbed,
					"samples": 1
				}
			},
			"b": {}
		}
	}

func _find_span(metric_result: Dictionary, label_prefix: String) -> Dictionary:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return span
	return {}

func _has_passing_span(metric_result: Dictionary, label_prefix: String) -> bool:
	var span: Dictionary = _find_span(metric_result, label_prefix)
	return bool(span.get("ok", false))

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
