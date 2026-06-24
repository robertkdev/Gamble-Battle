extends Node

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const APPROACH_IDS: Array[String] = [
	"access_backline",
	"burst",
	"aoe",
	"dot",
	"execute",
	"reset_mechanic",
	"on_hit_effect",
	"ramp",
	"sustain",
	"damage_reduction",
	"redirect",
	"cc_immunity",
	"untargetable",
	"reposition",
	"engage",
	"disrupt",
	"lockdown",
	"peel",
	"amp",
	"debuff",
	"long_range",
	"zone"
]

const EXPECTED_SPAN_PREFIXES: Dictionary = {
	"access_backline": "subject_first_backline_frac",
	"burst": "subject_peak_1s_",
	"aoe": "subject_targets_hit_",
	"dot": "subject_dot_tick_",
	"execute": "subject_execute_bonus_",
	"reset_mechanic": "subject_reset_event_count",
	"on_hit_effect": "subject_on_hit_proc_events",
	"ramp": "subject_ramp_state_",
	"sustain": "subject_sustain_",
	"damage_reduction": "subject_damage_reduction_",
	"redirect": "subject_redirect_",
	"cc_immunity": "subject_cc_immunity_",
	"untargetable": "subject_untargetable_frames_pct",
	"reposition": "subject_max_step_tiles_",
	"engage": "subject_early_engage_",
	"disrupt": "subject_disrupt_",
	"lockdown": "subject_lockdown_",
	"peel": "subject_peel_",
	"amp": "subject_amp_",
	"debuff": "subject_debuff_",
	"long_range": "subject_attacks_over_2_tiles_",
	"zone": "subject_zone_exposure_"
}

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var failed: bool = false
	for approach_id in APPROACH_IDS:
		var subject_id: String = _subject_id(approach_id)
		_install_probe_identity(subject_id, approach_id)
		var positive_result: Dictionary = _run_approach(approach_id, _positive_payload(approach_id, subject_id))
		var negative_result: Dictionary = _run_approach(approach_id, _negative_payload(approach_id, subject_id))
		var positive_pass: bool = bool(positive_result.get("pass", false))
		var negative_pass: bool = bool(negative_result.get("pass", false))
		var span_ok: bool = _has_span_prefix(positive_result, String(EXPECTED_SPAN_PREFIXES.get(approach_id, "")))
		print("ApproachSemanticCatalogProbe: approach=", approach_id,
			" positive=", positive_pass,
			" negative=", negative_pass,
			" span=", span_ok)
		if not positive_pass:
			printerr("ApproachSemanticCatalogProbe: FAIL positive payload did not pass for ", approach_id, " message=", String(positive_result.get("message", "")))
			failed = true
		if negative_pass:
			printerr("ApproachSemanticCatalogProbe: FAIL negative control passed for ", approach_id, " message=", String(negative_result.get("message", "")))
			failed = true
		if not span_ok:
			printerr("ApproachSemanticCatalogProbe: FAIL expected approach span prefix missing for ", approach_id)
			failed = true
	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("ApproachSemanticCatalogProbe: PASS approaches=", APPROACH_IDS.size())
	_quit(0)

func _install_probe_identity(subject_id: String, approach_id: String) -> void:
	RoleCommon._identity_cache[subject_id] = {
		"unit_id": subject_id,
		"primary_role": "probe",
		"primary_goal": "",
		"approaches": [approach_id],
		"cost": 3,
		"level": 1
	}

func _run_approach(approach_id: String, payload: Dictionary) -> Dictionary:
	var metric_path: String = "res://tests/rga_testing/metrics/approach/%s_approach_test.gd" % approach_id
	var metric_script: Script = load(metric_path) as Script
	if metric_script == null:
		return RoleCommon.fail_result([], ["missing_metric_script:%s" % metric_path])
	var metric: Variant = metric_script.new()
	var result: Dictionary = metric.call("run_metric", payload)
	metric = null
	metric_script = null
	return result

func _positive_payload(approach_id: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	var derived: Dictionary = {}
	var subject_fields: Dictionary = _subject_fields({"time_alive_s": 10.0})
	var team_damage: float = 100.0
	var extra_allies: Array[Dictionary] = []

	match approach_id:
		"access_backline":
			subject_fields = _subject_fields({"time_alive_s": 10.0, "first_cast_s": 1.0})
			_add_backline_kernel(kernels, subject_id, 1.4)
		"burst":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"peak_1s_damage_share": 0.45,
				"peak_1s_dps": 80.0,
				"overkill_rate": 0.10,
				"counterplay_window_ms": 500.0
			})
		"aoe":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"targets_hit_median": 3.0,
				"max_targets_hit": 4,
				"multi_target_groups": 2,
				"aoe_dps": 24.0
			})
		"dot":
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"dot_tick_events": 3,
				"dot_tick_damage": 36.0,
				"dot_tick_targets": 2,
				"dot_uptime_s": 3.0,
				"dot_duration_applied_s": 4.0
			})
			kernels["buff_presence"]["dot_tick_supported"] = true
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"total_damage": 100.0,
				"late_early_dps_ratio": 1.40
			})
		"execute":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"kill_count": 1,
				"low_hp_kill_count": 1,
				"low_hp_kill_share": 1.0,
				"overkill_rate": 0.20,
				"execute_bonus_events": 1,
				"execute_bonus_damage": 50.0,
				"execute_bonus_targets": 1,
				"execute_bonus_outside_threshold_events": 0,
				"execute_bonus_damage_share": 0.25
			})
		"reset_mechanic":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"reset_events": 2,
				"reset_chain_length": 3,
				"reset_targets": 2,
				"reset_time_between_min_s": 1.0,
				"reset_post_first_damage": 120.0,
				"reset_post_first_damage_share": 0.50,
				"reset_post_first_kills": 1,
				"reset_post_first_targets": 2,
				"reset_first_followup_s": 0.25
			})
			kernels["combat_patterns"]["reset_supported"] = true
		"on_hit_effect":
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"on_hit_effects": 3
			})
		"ramp":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"total_damage": 120.0,
				"ramp_state_supported": true,
				"ramp_state_events": 2,
				"ramp_stack_max": 4,
				"ramp_time_to_peak_s": 3.0,
				"ramp_peak_duration_s": 3.0,
				"ramp_window_duration_s": 3.0
			})
		"sustain":
			subject_fields = _subject_fields({
				"incoming": 100.0,
				"healing": 30.0,
				"shield": 30.0,
				"time_alive_s": 10.0
			})
		"damage_reduction":
			subject_fields = _subject_fields({
				"incoming": 60.0,
				"pre_mit_incoming": 100.0,
				"post_mit_incoming": 55.0,
				"time_alive_s": 10.0
			})
		"redirect":
			subject_fields = _subject_fields({
				"incoming": 20.0,
				"pre_mit_incoming": 20.0,
				"post_mit_incoming": 20.0,
				"time_alive_s": 10.0
			})
			extra_allies = [_ally_unit("probe_ally", 0.0, 80.0)]
			_add_subject_kernel(kernels, "redirect", subject_id, {
				"redirect_events": 1,
				"redirected_damage_prevented": 30.0,
				"ally_damage_prevented": 30.0,
				"focus_start_events": 1,
				"target_swap_to_subject_events": 1,
				"enemy_focus_time_s": 2.0,
				"taunt_events": 1,
				"taunt_duration_s": 1.0,
				"body_block_events": 1,
				"body_block_damage_prevented": 30.0,
				"explicit_threat_swap_events": 1,
				"redirect_end_risk_events": 1,
				"redirect_end_risk_s": 0.75
			})
		"cc_immunity":
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"cc_immunity": 1
			})
			_add_subject_kernel(kernels, "cooldown_pressure", subject_id, {
				"cooldowns_forced_s": 2.0,
				"cooldown_trade_efficiency": 1.20,
				"cooldown_threat_draw_casters": 1,
				"cooldown_key_threat_share": 0.75
			})
		"untargetable":
			_add_subject_kernel(kernels, "targetability", subject_id, {
				"untargetable_windows": 1,
				"untargetable_time_s": 1.2,
				"untargetable_frames_pct": 0.15,
				"key_threats_faced": 2,
				"key_threats_dodged": 1,
				"cooldown_trade_s": 2.0
			})
		"reposition":
			_add_subject_kernel(kernels, "control_mobility", subject_id, {
				"max_step_tiles": 1.5,
				"post_cast_displacement_tiles": 1.5,
				"total_path_tiles": 5.0,
				"reposition_steps": 2
			})
		"engage":
			_add_subject_kernel(kernels, "control_mobility", subject_id, {
				"early_max_displacement_tiles": 1.5,
				"first_action_s": 2.0,
				"first_cc_s": 2.5
			})
		"disrupt":
			_add_subject_kernel(kernels, "control_mobility", subject_id, {
				"cc_seconds": 1.5,
				"cc_events": 2,
				"cc_unique_targets": 2
			})
		"lockdown":
			_add_lockdown_kernel(kernels, subject_id, 2.0, 1)
			_add_subject_kernel(kernels, "counterplay_pressure", subject_id, {
				"cleanse_pressure_events": 1,
				"tenacity_tax_s": 1.0
			})
		"peel":
			derived = {"a": {"peel_saves": 1}}
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"ally_buffs_to_others": 1,
				"ally_buff_magnitude_to_others": 30.0,
				"cc_immunity": 1,
				"cleanse_applied": 1
			})
		"amp":
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"ally_buffs_to_others": 1,
				"ally_buff_magnitude_to_others": 5.0,
				"amp_output_delta": 10.0,
				"amp_output_events": 1,
				"amp_output_beneficiaries": 1
			})
		"debuff":
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"enemy_debuffs": 1,
				"debuff_magnitude": 5.0
			})
			_add_subject_kernel(kernels, "counterplay_pressure", subject_id, {
				"cleanse_pressure_events": 1,
				"cleanse_bait_rate": 0.5
			})
		"long_range":
			_add_flat_side_kernel(kernels, "per_unit_kpis", subject_id, {
				"attacks_over_2_tiles_pct": 0.80
			})
		"zone":
			_add_subject_kernel(kernels, "zone_exposure", subject_id, {
				"zone_exposure_events": 2,
				"zone_exposure_targets": 2,
				"zone_exposure_time_s": 2.5,
				"zone_exposure_damage": 24.0,
				"zone_radius_tiles_max": 2.0
			})
		_:
			pass

	return _base_payload(subject_id, subject_fields, kernels, team_damage, extra_allies, derived)

func _negative_payload(approach_id: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	var subject_fields: Dictionary = _subject_fields({
		"incoming": 100.0,
		"pre_mit_incoming": 100.0,
		"post_mit_incoming": 100.0,
		"time_alive_s": 0.0
	})
	match approach_id:
		"redirect":
			_add_subject_kernel(kernels, "redirect", subject_id, {})
		"zone":
			_add_subject_kernel(kernels, "zone_exposure", subject_id, {})
		"untargetable":
			_add_subject_kernel(kernels, "targetability", subject_id, {})
		"reset_mechanic":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {"reset_events": 0})
			kernels["combat_patterns"]["reset_supported"] = true
		_:
			pass
	return _base_payload(subject_id, subject_fields, kernels, 100.0, [], {})

func _base_payload(subject_id: String, subject_fields: Dictionary, kernels: Dictionary, team_damage: float, extra_allies: Array[Dictionary], derived: Dictionary) -> Dictionary:
	var subject_unit: Dictionary = _subject_fields(subject_fields)
	subject_unit["unit_id"] = subject_id
	var team_a_ids: Array[String] = [subject_id]
	var team_a_units: Array[Dictionary] = [subject_unit]
	for ally in extra_allies:
		team_a_units.append(ally)
		team_a_ids.append(String(ally.get("unit_id", "")))
	var sim: Dictionary = {
		"context": {
			"team_a_ids": team_a_ids,
			"team_b_ids": ["probe_enemy"]
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
			"a": team_a_units,
			"b": [
				{
					"unit_id": "probe_enemy",
					"damage": 0.0,
					"incoming": 0.0,
					"time_alive_s": 10.0
				}
			]
		},
		"outcome": {
			"time_s": 10.0,
			"winner_side": "a"
		},
		"kernels": kernels
	}
	if not derived.is_empty():
		sim["derived"] = derived
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": sim
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _subject_fields(overrides: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"damage": 0.0,
		"incoming": 0.0,
		"pre_mit_incoming": 0.0,
		"post_mit_incoming": 0.0,
		"healing": 0.0,
		"shield": 0.0,
		"time_alive_s": 0.0
	}
	for key in overrides.keys():
		out[key] = overrides.get(key)
	return out

func _ally_unit(unit_id: String, damage: float, incoming: float) -> Dictionary:
	return {
		"unit_id": unit_id,
		"damage": damage,
		"incoming": incoming,
		"pre_mit_incoming": incoming,
		"post_mit_incoming": incoming,
		"time_alive_s": 10.0
	}

func _add_subject_kernel(kernels: Dictionary, kernel_key: String, subject_id: String, rec: Dictionary, supported: bool = true) -> void:
	var side_map: Dictionary = {}
	side_map[subject_id] = rec
	var block: Dictionary = {
		"per_unit": {
			"a": side_map,
			"b": {}
		}
	}
	if supported:
		block["supported"] = true
	kernels[kernel_key] = block

func _add_flat_side_kernel(kernels: Dictionary, kernel_key: String, subject_id: String, rec: Dictionary) -> void:
	var side_map: Dictionary = {}
	side_map[subject_id] = rec
	kernels[kernel_key] = {
		"a": side_map,
		"b": {}
	}

func _add_backline_kernel(kernels: Dictionary, subject_id: String, contact_s: float) -> void:
	kernels["backline_access"] = {
		"supported": true,
		"a": {
			"entered_by_unit": {
				subject_id: contact_s
			}
		},
		"b": {}
	}

func _add_lockdown_kernel(kernels: Dictionary, subject_id: String, seconds_on_priority: float, event_count: int) -> void:
	var side_map: Dictionary = {}
	side_map[subject_id] = {
		"seconds_on_priority": seconds_on_priority,
		"events": event_count
	}
	kernels["lockdown"] = {
		"a": {
			"per_unit": side_map
		},
		"b": {
			"per_unit": {}
		}
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

func _subject_id(approach_id: String) -> String:
	return "probe_approach_%s" % approach_id

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
