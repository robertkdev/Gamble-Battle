extends RefCounted

# Approach: disrupt (per-unit subject)
# Pass condition: subject applies enough control pressure across enemy targets.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_disrupt"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["cc"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "disrupt: subject CC seconds, events, and unique controlled targets."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "disrupt")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var seconds_cfg: Dictionary = metrics_cfg.get("cc_seconds", {})
	var events_cfg: Dictionary = metrics_cfg.get("cc_events", {})
	var targets_cfg: Dictionary = metrics_cfg.get("cc_unique_targets", {})
	var seconds_req: float = RoleCommon.resolve_min_threshold(seconds_cfg, cost_band, scenario_label)
	var events_req: float = RoleCommon.resolve_min_threshold(events_cfg, cost_band, scenario_label)
	var targets_req: float = RoleCommon.resolve_min_threshold(targets_cfg, cost_band, scenario_label)
	if seconds_req <= 0.0:
		seconds_req = 1.0
	if events_req <= 0.0:
		events_req = 1.0
	if targets_req <= 0.0:
		targets_req = 1.0

	var total_seconds: float = 0.0
	var total_events: int = 0
	var max_unique_targets: int = 0
	var considered: int = 0
	var kernel_missing: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var rec: Dictionary = _subject_control(entry, subject_id)
		if rec.is_empty():
			var side: String = _subject_side(entry, subject_id)
			if side != "":
				considered += 1
				kernel_missing += 1
			continue
		considered += 1
		total_seconds += float(rec.get("cc_seconds", 0.0))
		total_events += int(rec.get("cc_events", 0))
		max_unique_targets = max(max_unique_targets, int(rec.get("cc_unique_targets", 0)))

	var seconds_pass: bool = considered > 0 and total_seconds >= seconds_req
	var events_pass: bool = considered > 0 and float(total_events) >= events_req
	var targets_pass: bool = considered > 0 and float(max_unique_targets) >= targets_req
	var pass_flag: bool = seconds_pass or events_pass or targets_pass
	var reason: String = ""
	if considered <= 0:
		reason = "no_samples"
	elif kernel_missing >= considered:
		reason = "kernel_unsupported"

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["kernel_missing"] = kernel_missing
	RoleCommon.append_span(spans, "subject_disrupt_cc_seconds", total_seconds, seconds_req, seconds_pass, extras)
	RoleCommon.append_span(spans, "subject_disrupt_cc_events", total_events, events_req, events_pass, extras)
	RoleCommon.append_span(spans, "subject_disrupt_unique_targets", max_unique_targets, targets_req, targets_pass, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; events=%d" % [scenario_label, considered, total_events]
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
