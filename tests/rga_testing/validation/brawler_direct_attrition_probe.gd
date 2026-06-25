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
	var negative_result: Dictionary = _run_metric(_negative_payload(subject_id))
	var positive_span: Dictionary = _find_span(positive_result, "unit_direct_attrition_evidence")
	var negative_span: Dictionary = _find_span(negative_result, "unit_direct_attrition_evidence")
	var positive_pass: bool = bool(positive_result.get("pass", false))
	var negative_pass: bool = bool(negative_result.get("pass", false))
	var direct_ok: bool = bool(positive_span.get("ok", false))
	var direct_negative_ok: bool = bool(negative_span.get("ok", false))
	var frontline_share: float = float(positive_span.get("direct_attrition_frontline_share", 0.0))
	var effective_hps: float = float(positive_span.get("direct_attrition_effective_hps", 0.0))
	var aoe_dps: float = float(positive_span.get("direct_attrition_aoe_dps", 0.0))
	var max_targets_hit: float = float(positive_span.get("direct_attrition_max_targets_hit", 0.0))
	var unit_pass: bool = _has_passing_span(positive_result, "unit_pass")

	print("BrawlerDirectAttritionProbe: positive_pass=", positive_pass,
		" direct_ok=", direct_ok,
		" frontline_share=", frontline_share,
		" effective_hps=", effective_hps,
		" aoe_dps=", aoe_dps,
		" max_targets=", max_targets_hit,
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
	if aoe_dps < 4.0 or max_targets_hit < 2.0:
		printerr("BrawlerDirectAttritionProbe: FAIL pressure evidence was not recorded")
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
	_add_combat_pattern_kernel(kernels, subject_id, 6.5, 2.0)
	return _base_payload(subject_id, _subject_unit(subject_id, 120.0, 120.0, 10.0, 12.0, 14.0), kernels)

func _negative_payload(subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	_add_throughput_kernel(kernels, 5.0, 25.0, 30.0, 32.0)
	_add_focus_survival_kernel(kernels, subject_id, 9.5)
	_add_per_unit_kpi_kernel(kernels, subject_id, 0.10)
	_add_combat_pattern_kernel(kernels, subject_id, 0.5, 1.0)
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

func _add_combat_pattern_kernel(kernels: Dictionary, subject_id: String, aoe_dps: float, max_targets_hit: float) -> void:
	kernels["combat_patterns"] = {
		"per_unit": {
			"a": {
				subject_id: {
					"aoe_dps": aoe_dps,
					"max_targets_hit": max_targets_hit
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
