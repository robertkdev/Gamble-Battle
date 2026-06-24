extends RefCounted

# Approach: amp (per-unit subject)
# Pass condition: subject applies buffs/utility to other allies.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_amp"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["buffs"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "amp: subject applies ally-directed buffs, shields, or utility such as mana grants."
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
	var scenario_label: String = String(ctx.get("scenario", "neutral"))
	var thresholds_all: Dictionary = RoleCommon.load_thresholds()
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "amp")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var ally_cfg: Dictionary = metrics_cfg.get("ally_buffs_to_others", {})
	var magnitude_cfg: Dictionary = metrics_cfg.get("ally_buff_magnitude_to_others", {})
	var output_cfg: Dictionary = metrics_cfg.get("amp_output_delta", {})
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var cost_band: int = int(ident.get("cost", 3))
	var ally_req: float = RoleCommon.resolve_min_threshold(ally_cfg, cost_band, scenario_label)
	var magnitude_req: float = RoleCommon.resolve_min_threshold(magnitude_cfg, cost_band, scenario_label)
	var output_req: float = RoleCommon.resolve_min_threshold(output_cfg, cost_band, scenario_label)
	if ally_req <= 0.0:
		ally_req = 1.0
	if magnitude_req <= 0.0:
		magnitude_req = 1.0
	if output_req <= 0.0:
		output_req = 1.0

	var ally_buffs: int = 0
	var buff_magnitude: float = 0.0
	var amp_output_delta: float = 0.0
	var amp_output_events: int = 0
	var amp_output_beneficiaries: int = 0
	var considered: int = 0
	for key in sims.keys():
		var rec: Dictionary = _subject_buff_source(sims.get(key, {}), subject_id)
		if rec.is_empty():
			if _subject_side(sims.get(key, {}), subject_id) != "":
				considered += 1
			continue
		considered += 1
		ally_buffs += int(rec.get("ally_buffs_to_others", 0))
		buff_magnitude += float(rec.get("ally_buff_magnitude_to_others", 0.0))
		amp_output_delta += float(rec.get("amp_output_delta", 0.0))
		amp_output_events += int(rec.get("amp_output_events", 0))
		amp_output_beneficiaries = max(amp_output_beneficiaries, int(rec.get("amp_output_beneficiaries", 0)))

	var ally_pass: bool = considered > 0 and float(ally_buffs) >= ally_req
	var magnitude_pass: bool = considered > 0 and buff_magnitude >= magnitude_req
	var output_pass: bool = considered > 0 and amp_output_delta >= output_req
	var pass_flag: bool = ally_pass or magnitude_pass or output_pass
	var reason: String = "no_samples" if considered <= 0 else ""
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	RoleCommon.append_span(spans, "subject_amp_ally_buffs_to_others", ally_buffs, ally_req, ally_pass, extras)
	RoleCommon.append_span(spans, "subject_amp_ally_buff_magnitude_to_others", buff_magnitude, magnitude_req, magnitude_pass, extras)
	RoleCommon.append_span(spans, "subject_amp_output_delta", amp_output_delta, output_req, output_pass, extras)
	RoleCommon.append_span(spans, "subject_amp_output_events", amp_output_events, 1.0, amp_output_events >= 1, extras)
	RoleCommon.append_span(spans, "subject_amp_output_beneficiaries", amp_output_beneficiaries, 1.0, amp_output_beneficiaries >= 1, extras)
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; ally_buffs=%d; amp_output_delta=%.1f" % [scenario_label, considered, ally_buffs, amp_output_delta]
	}

func _subject_buff_source(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var buffs: Dictionary = kernels.get("buff_presence", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = buffs.get("per_unit", {}) if (buffs is Dictionary) else {}
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
