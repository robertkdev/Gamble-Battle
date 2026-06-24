extends RefCounted

# Approach: aoe (per-unit subject)
# Pass condition: subject demonstrates multi-target hit groups or enough AoE DPS.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_aoe"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "aoe: subject multi-target hit groups, max targets hit, and AoE DPS."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "aoe")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var median_cfg: Dictionary = metrics_cfg.get("targets_hit_median", {})
	var max_cfg: Dictionary = metrics_cfg.get("max_targets_hit", {})
	var dps_cfg: Dictionary = metrics_cfg.get("aoe_dps", {})
	var median_req: float = RoleCommon.resolve_min_threshold(median_cfg, cost_band, scenario_label)
	var max_req: float = RoleCommon.resolve_min_threshold(max_cfg, cost_band, scenario_label)
	var dps_req: float = RoleCommon.resolve_min_threshold(dps_cfg, cost_band, scenario_label)
	if median_req <= 0.0:
		median_req = 1.5
	if max_req <= 0.0:
		max_req = 2.0
	if dps_req <= 0.0:
		dps_req = 4.0

	var median_samples: Array[float] = []
	var max_targets_seen: int = 0
	var total_multi_groups: int = 0
	var aoe_dps_samples: Array[float] = []
	for key in sims.keys():
		var rec: Dictionary = _subject_pattern(sims.get(key, {}), subject_id)
		if rec.is_empty():
			continue
		median_samples.append(float(rec.get("targets_hit_median", 0.0)))
		max_targets_seen = max(max_targets_seen, int(rec.get("max_targets_hit", 0)))
		total_multi_groups += int(rec.get("multi_target_groups", 0))
		aoe_dps_samples.append(float(rec.get("aoe_dps", 0.0)))

	var targets_median: float = RoleCommon.median(median_samples)
	var aoe_dps: float = RoleCommon.median(aoe_dps_samples)
	var median_pass: bool = median_samples.size() > 0 and targets_median >= median_req
	var max_pass: bool = max_targets_seen >= int(round(max_req))
	var dps_pass: bool = aoe_dps_samples.size() > 0 and aoe_dps >= dps_req
	var pass_flag: bool = median_pass or max_pass or dps_pass

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_samples" if median_samples.is_empty() else ""))
	extras["samples"] = median_samples.size()
	extras["multi_target_groups"] = total_multi_groups
	RoleCommon.append_span(spans, "subject_targets_hit_median", targets_median, median_req, median_pass, extras)
	RoleCommon.append_span(spans, "subject_max_targets_hit", max_targets_seen, max_req, max_pass, extras)
	RoleCommon.append_span(spans, "subject_aoe_dps_med", aoe_dps, dps_req, dps_pass, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; samples=%d; multi_groups=%d" % [scenario_label, median_samples.size(), total_multi_groups]
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
