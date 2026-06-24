extends RefCounted

# Approach: burst (per-unit subject)
# Pass condition: subject has a concentrated 1s damage window while keeping
# overkill within the configured diagnostic cap.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_burst"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "burst: subject peak 1s damage share/DPS and overkill diagnostics."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "burst")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var share_cfg: Dictionary = metrics_cfg.get("peak_1s_damage_share", {})
	var dps_cfg: Dictionary = metrics_cfg.get("peak_1s_dps", {})
	var overkill_cfg: Dictionary = metrics_cfg.get("overkill_rate", {})
	var share_req: float = RoleCommon.resolve_min_threshold(share_cfg, cost_band, scenario_label)
	var dps_req: float = RoleCommon.resolve_min_threshold(dps_cfg, cost_band, scenario_label)
	var overkill_max: float = RoleCommon.resolve_max_threshold(overkill_cfg, cost_band, scenario_label)
	if share_req <= 0.0:
		share_req = 0.25
	if dps_req <= 0.0:
		dps_req = 25.0
	if overkill_max <= 0.0:
		overkill_max = 0.45

	var share_samples: Array[float] = []
	var dps_samples: Array[float] = []
	var overkill_samples: Array[float] = []
	var counterplay_samples: Array[float] = []
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var rec: Dictionary = _subject_pattern(entry, subject_id)
		if rec.is_empty():
			continue
		share_samples.append(float(rec.get("peak_1s_damage_share", 0.0)))
		dps_samples.append(float(rec.get("peak_1s_dps", 0.0)))
		overkill_samples.append(float(rec.get("overkill_rate", 0.0)))
		var counterplay_ms: float = float(rec.get("counterplay_window_ms", -1.0))
		if counterplay_ms >= 0.0:
			counterplay_samples.append(counterplay_ms)

	var share_value: float = RoleCommon.median(share_samples)
	var dps_value: float = RoleCommon.median(dps_samples)
	var overkill_value: float = RoleCommon.median(overkill_samples)
	var counterplay_value: float = RoleCommon.median(counterplay_samples)
	var share_pass: bool = share_samples.size() > 0 and share_value >= share_req
	var dps_pass: bool = dps_samples.size() > 0 and dps_value >= dps_req
	var overkill_ok: bool = overkill_samples.size() <= 0 or overkill_value <= overkill_max
	var pass_flag: bool = (share_pass or dps_pass) and overkill_ok

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_samples" if share_samples.is_empty() else ""))
	extras["samples"] = share_samples.size()
	RoleCommon.append_span(spans, "subject_peak_1s_damage_share_med", share_value, share_req, share_pass, extras)
	RoleCommon.append_span(spans, "subject_peak_1s_dps_med", dps_value, dps_req, dps_pass, extras)
	RoleCommon.append_span(spans, "subject_overkill_rate_med", overkill_value, overkill_max, overkill_ok, extras)
	RoleCommon.append_span(spans, "subject_counterplay_window_ms_med", counterplay_value, null, true, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; samples=%d" % [scenario_label, share_samples.size()]
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
