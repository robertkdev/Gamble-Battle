extends RefCounted

# Approach: ramp (per-unit subject)
# Pass condition: subject's damage output rises late or reaches peak after an
# appreciable setup window.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_ramp"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "ramp: subject late/early DPS ratio, time to peak, and post-peak falloff."
	}

func run_metric(payload: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = payload.get("context", {})
	var sims: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	if sims.is_empty():
		return RoleCommon.fail_result([], ["no_sims_in_context"])
	var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)
	if subject_set.is_empty():
		return RoleCommon.fail_result([], ["no_subject_specified"])
	var subject_id: String = String(subject_set.keys()[0])
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var cost_band: int = int(ident.get("cost", 3))
	var scenario_label: String = String(ctx.get("scenario", "neutral"))
	var thresholds_all: Dictionary = RoleCommon.load_thresholds()
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "ramp")
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 2, "n": 3})
	var direct_kcfg: Dictionary = cfg.get("direct_k_of_n", {"k": 2, "n": 4})
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var ratio_cfg: Dictionary = metrics_cfg.get("late_early_dps_ratio", {})
	var peak_cfg: Dictionary = metrics_cfg.get("time_to_peak_s", {})
	var falloff_cfg: Dictionary = metrics_cfg.get("falloff_after_peak", {})
	var state_events_cfg: Dictionary = metrics_cfg.get("ramp_state_events", {})
	var stack_max_cfg: Dictionary = metrics_cfg.get("ramp_stack_max", {})
	var peak_duration_cfg: Dictionary = metrics_cfg.get("ramp_peak_duration_s", {})
	var window_duration_cfg: Dictionary = metrics_cfg.get("ramp_window_duration_s", {})
	var ratio_req: float = RoleCommon.resolve_min_threshold(ratio_cfg, cost_band, scenario_label)
	var peak_req: float = RoleCommon.resolve_min_threshold(peak_cfg, cost_band, scenario_label)
	var falloff_req: float = RoleCommon.resolve_min_threshold(falloff_cfg, cost_band, scenario_label)
	var state_events_req: float = RoleCommon.resolve_min_threshold(state_events_cfg, cost_band, scenario_label)
	var stack_max_req: float = RoleCommon.resolve_min_threshold(stack_max_cfg, cost_band, scenario_label)
	var peak_duration_req: float = RoleCommon.resolve_min_threshold(peak_duration_cfg, cost_band, scenario_label)
	var window_duration_req: float = RoleCommon.resolve_min_threshold(window_duration_cfg, cost_band, scenario_label)
	if ratio_req <= 0.0:
		ratio_req = 1.15
	if peak_req <= 0.0:
		peak_req = 5.0
	if falloff_req <= 0.0:
		falloff_req = 0.25
	if state_events_req <= 0.0:
		state_events_req = 1.0
	if stack_max_req <= 0.0:
		stack_max_req = 2.0
	if peak_duration_req <= 0.0:
		peak_duration_req = 1.0
	if window_duration_req <= 0.0:
		window_duration_req = 1.0

	var ratio_samples: Array[float] = []
	var peak_samples: Array[float] = []
	var falloff_samples: Array[float] = []
	var state_event_samples: Array[float] = []
	var stack_max_samples: Array[float] = []
	var peak_duration_samples: Array[float] = []
	var window_duration_samples: Array[float] = []
	var direct_time_to_peak_samples: Array[float] = []
	var direct_supported: bool = false
	for key in sims.keys():
		var rec: Dictionary = _subject_pattern(sims.get(key, {}), subject_id)
		if rec.is_empty() or float(rec.get("total_damage", 0.0)) <= 0.0:
			if rec.is_empty():
				continue
		if bool(rec.get("ramp_state_supported", false)):
			direct_supported = true
			state_event_samples.append(float(rec.get("ramp_state_events", 0.0)))
			stack_max_samples.append(float(rec.get("ramp_stack_max", 0.0)))
			peak_duration_samples.append(float(rec.get("ramp_peak_duration_s", 0.0)))
			window_duration_samples.append(float(rec.get("ramp_window_duration_s", 0.0)))
			direct_time_to_peak_samples.append(float(rec.get("ramp_time_to_peak_s", 0.0)))
		elif float(rec.get("total_damage", 0.0)) > 0.0:
			ratio_samples.append(float(rec.get("late_early_dps_ratio", 0.0)))
			peak_samples.append(float(rec.get("time_to_peak_s", 0.0)))
			falloff_samples.append(float(rec.get("falloff_after_peak", 0.0)))

	if direct_supported:
		return _direct_ramp_result(
			subject_id,
			sims,
			scenario_label,
			state_event_samples,
			stack_max_samples,
			peak_duration_samples,
			window_duration_samples,
			direct_time_to_peak_samples,
			state_events_req,
			stack_max_req,
			peak_duration_req,
			window_duration_req,
			int(direct_kcfg.get("k", 2)),
			int(direct_kcfg.get("n", 4))
		)

	var ratio_value: float = RoleCommon.median(ratio_samples)
	var peak_value: float = RoleCommon.median(peak_samples)
	var falloff_value: float = RoleCommon.median(falloff_samples)
	var ratio_pass: bool = ratio_samples.size() > 0 and ratio_value >= ratio_req
	var peak_pass: bool = peak_samples.size() > 0 and peak_value >= peak_req
	var falloff_pass: bool = falloff_samples.size() > 0 and falloff_value >= falloff_req
	var eval: Dictionary = RoleCommon.k_of_n([ratio_pass, peak_pass, falloff_pass], int(kcfg.get("k", 2)), int(kcfg.get("n", 3)))
	var pass_flag: bool = bool(eval.get("pass", false))

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_samples" if ratio_samples.is_empty() else ""))
	extras["samples"] = ratio_samples.size()
	RoleCommon.append_span(spans, "subject_late_early_dps_ratio_med", ratio_value, ratio_req, ratio_pass, extras)
	RoleCommon.append_span(spans, "subject_time_to_peak_s_med", peak_value, peak_req, peak_pass, extras)
	RoleCommon.append_span(spans, "subject_falloff_after_peak_med", falloff_value, falloff_req, falloff_pass, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; samples=%d" % [scenario_label, ratio_samples.size()]
	}

func _direct_ramp_result(subject_id: String, sims: Dictionary, scenario_label: String, state_event_samples: Array[float], stack_max_samples: Array[float], peak_duration_samples: Array[float], window_duration_samples: Array[float], direct_time_to_peak_samples: Array[float], state_events_req: float, stack_max_req: float, peak_duration_req: float, window_duration_req: float, k_required: int, n_total: int) -> Dictionary:
	var state_events_value: float = RoleCommon.median(state_event_samples)
	var stack_max_value: float = RoleCommon.median(stack_max_samples)
	var peak_duration_value: float = RoleCommon.median(peak_duration_samples)
	var window_duration_value: float = RoleCommon.median(window_duration_samples)
	var time_to_peak_value: float = RoleCommon.median(direct_time_to_peak_samples)
	var state_events_pass: bool = state_event_samples.size() > 0 and state_events_value >= state_events_req
	var stack_max_pass: bool = stack_max_samples.size() > 0 and stack_max_value >= stack_max_req
	var peak_duration_pass: bool = peak_duration_samples.size() > 0 and peak_duration_value >= peak_duration_req
	var window_duration_pass: bool = window_duration_samples.size() > 0 and window_duration_value >= window_duration_req
	var eval: Dictionary = RoleCommon.k_of_n([state_events_pass, stack_max_pass, peak_duration_pass, window_duration_pass], k_required, n_total)
	var pass_flag: bool = bool(eval.get("pass", false))
	var stack_span_ok: Variant = stack_max_pass
	if pass_flag and state_events_pass and (peak_duration_pass or window_duration_pass) and not stack_max_pass:
		stack_span_ok = null

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_direct_ramp_events" if state_event_samples.is_empty() else "direct_ramp_state"))
	extras["samples"] = state_event_samples.size()
	extras["direct_ramp_state"] = true
	RoleCommon.append_span(spans, "subject_ramp_state_events", state_events_value, state_events_req, state_events_pass, extras)
	RoleCommon.append_span(spans, "subject_ramp_stack_max", stack_max_value, stack_max_req, stack_span_ok, _extras_for_span(extras, stack_span_ok, "alternate_ramp_state_evidence_satisfied"))
	RoleCommon.append_span(spans, "subject_ramp_peak_duration_s", peak_duration_value, peak_duration_req, peak_duration_pass, extras)
	RoleCommon.append_span(spans, "subject_ramp_window_duration_s", window_duration_value, window_duration_req, window_duration_pass, extras)
	RoleCommon.append_span(spans, "subject_ramp_time_to_peak_s", time_to_peak_value, null, true, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; direct_ramp_samples=%d" % [scenario_label, state_event_samples.size()]
	}

func _subject_pattern(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var patterns: Dictionary = kernels.get("combat_patterns", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = patterns.get("per_unit", {}) if (patterns is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _extras_for_span(base_extras: Dictionary, span_ok: Variant, diagnostic_reason: String) -> Dictionary:
	if span_ok != null:
		return base_extras
	var diagnostic_extras: Dictionary = base_extras.duplicate(true)
	diagnostic_extras["reason"] = diagnostic_reason
	return diagnostic_extras

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var context: Dictionary = entry.get("context", {})
	var team_a: Array = context.get("team_a_ids", [])
	var team_b: Array = context.get("team_b_ids", [])
	for unit_id in team_a:
		if String(unit_id) == subject_id:
			return "a"
	for unit_id_b in team_b:
		if String(unit_id_b) == subject_id:
			return "b"
	return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for key in sims.keys():
		var side: String = _subject_side(sims.get(key, {}), subject_id)
		if side != "":
			return side
	return ""
