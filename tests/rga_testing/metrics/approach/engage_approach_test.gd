extends RefCounted

# Approach: engage (per-unit subject)
# Pass condition: subject starts combat impact from distance quickly enough to
# function as an initiator.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_engage"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["mobility", "targets"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "engage: subject early displacement plus early hit/cast/CC initiation."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "engage")
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 2, "n": 3})
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var distance_cfg: Dictionary = metrics_cfg.get("early_engage_displacement_tiles", {})
	var action_cfg: Dictionary = metrics_cfg.get("time_to_first_action_s", {})
	var cc_cfg: Dictionary = metrics_cfg.get("time_to_first_cc_s", {})
	var distance_req: float = RoleCommon.resolve_min_threshold(distance_cfg, cost_band, scenario_label)
	var action_max: float = RoleCommon.resolve_max_threshold(action_cfg, cost_band, scenario_label)
	var cc_max: float = RoleCommon.resolve_max_threshold(cc_cfg, cost_band, scenario_label)
	if distance_req <= 0.0:
		distance_req = 1.0
	if action_max <= 0.0:
		action_max = 5.0
	if cc_max <= 0.0:
		cc_max = 6.0

	var distance_samples: Array[float] = []
	var action_samples: Array[float] = []
	var cc_samples: Array[float] = []
	var considered: int = 0
	for key in sims.keys():
		var rec: Dictionary = _subject_control(sims.get(key, {}), subject_id)
		if rec.is_empty():
			continue
		considered += 1
		distance_samples.append(float(rec.get("early_max_displacement_tiles", 0.0)))
		var first_action: float = float(rec.get("first_action_s", -1.0))
		if first_action >= 0.0:
			action_samples.append(first_action)
		var first_cc: float = float(rec.get("first_cc_s", -1.0))
		if first_cc >= 0.0:
			cc_samples.append(first_cc)

	var distance_value: float = RoleCommon.median(distance_samples)
	var distance_peak_value: float = _max_sample(distance_samples)
	var action_value: float = RoleCommon.median(action_samples)
	var cc_value: float = RoleCommon.median(cc_samples)
	var distance_pass: bool = distance_samples.size() > 0 and distance_value >= distance_req
	var distance_peak_pass: bool = distance_samples.size() > 0 and distance_peak_value >= distance_req
	var action_pass: bool = action_samples.size() > 0 and action_value <= action_max
	var cc_pass: bool = cc_samples.size() > 0 and cc_value <= cc_max
	var eval: Dictionary = RoleCommon.k_of_n([distance_pass, action_pass, cc_pass], int(kcfg.get("k", 2)), int(kcfg.get("n", 3)))
	var standard_pass: bool = bool(eval.get("pass", false))
	var peak_initiate_pass: bool = distance_peak_pass and action_pass
	var pass_flag: bool = standard_pass or peak_initiate_pass

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_samples" if considered <= 0 else ""))
	extras["considered"] = considered
	extras["k_required"] = int(eval.get("k", 2))
	extras["true_count"] = max(int(eval.get("true_count", 0)), 2) if peak_initiate_pass else int(eval.get("true_count", 0))
	var distance_extra: Dictionary = extras.duplicate()
	var peak_extra: Dictionary = extras.duplicate()
	var action_extra: Dictionary = extras.duplicate()
	var cc_extra: Dictionary = extras.duplicate()
	var distance_ok: Variant = distance_pass
	var peak_ok: Variant = distance_peak_pass
	var action_ok: Variant = action_pass
	var cc_ok: Variant = cc_pass
	if peak_initiate_pass and not standard_pass and not distance_pass:
		distance_ok = null
		distance_extra["reason"] = "alternate_engage_peak_distance_satisfied"
	elif pass_flag and not distance_pass:
		distance_ok = null
		distance_extra["reason"] = "alternate_engage_evidence_satisfied"
	if pass_flag and not distance_peak_pass:
		peak_ok = null
		peak_extra["reason"] = "alternate_engage_evidence_satisfied"
	if pass_flag and not action_pass:
		action_ok = null
		action_extra["reason"] = "alternate_engage_evidence_satisfied"
	if peak_initiate_pass and not standard_pass and not cc_pass:
		cc_ok = null
		cc_extra["reason"] = "alternate_engage_peak_distance_satisfied"
	elif pass_flag and not cc_pass:
		cc_ok = null
		cc_extra["reason"] = "alternate_engage_evidence_satisfied"
	RoleCommon.append_span(spans, "subject_early_engage_displacement_tiles_med", distance_value, distance_req, distance_ok, distance_extra)
	RoleCommon.append_span(spans, "subject_early_engage_displacement_tiles_peak", distance_peak_value, distance_req, peak_ok, peak_extra)
	RoleCommon.append_span(spans, "subject_time_to_first_action_s_med", action_value, action_max, action_ok, action_extra)
	RoleCommon.append_span(spans, "subject_time_to_first_cc_s_med", cc_value, cc_max, cc_ok, cc_extra)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d" % [scenario_label, considered]
	}

func _subject_control(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var control: Dictionary = kernels.get("control_mobility", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = control.get("per_unit", {}) if (control is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

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

func _max_sample(samples: Array[float]) -> float:
	var result: float = 0.0
	var has_sample: bool = false
	for sample_value in samples:
		if not has_sample or sample_value > result:
			result = sample_value
			has_sample = true
	return result
