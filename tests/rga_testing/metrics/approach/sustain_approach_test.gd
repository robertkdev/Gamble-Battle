extends RefCounted

# Approach: sustain (per-unit subject)
# Pass condition: subject's healing + absorbed shields show meaningful effective
# HP gain relative to incoming pressure, or enough effective HPS over fight time.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_sustain"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "sustain: subject healing plus shield absorption over incoming pressure or fight time."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "sustain")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var ehp_cfg: Dictionary = metrics_cfg.get("ehp_ratio", {})
	var hps_cfg: Dictionary = metrics_cfg.get("effective_hps", {})
	var ehp_req: float = RoleCommon.resolve_min_threshold(ehp_cfg, cost_band, scenario_label)
	var hps_req: float = RoleCommon.resolve_min_threshold(hps_cfg, cost_band, scenario_label)
	if ehp_req <= 0.0:
		ehp_req = 0.10
	if hps_req <= 0.0:
		hps_req = 2.0

	var total_incoming: float = 0.0
	var total_healing: float = 0.0
	var total_shield: float = 0.0
	var total_time_alive: float = 0.0
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		var unit_entry: Dictionary = _subject_unit(entry, side, subject_id)
		if unit_entry.is_empty():
			continue
		considered += 1
		total_incoming += float(unit_entry.get("incoming", 0.0))
		total_healing += float(unit_entry.get("healing", 0.0))
		total_shield += float(unit_entry.get("shield", 0.0))
		total_time_alive += max(0.0, float(unit_entry.get("time_alive_s", 0.0)))

	var sustain_total: float = total_healing + total_shield
	var ehp_ratio: float = sustain_total / max(1.0, total_incoming)
	var effective_hps: float = sustain_total / max(1.0, total_time_alive)
	var ehp_pass: bool = considered > 0 and total_incoming > 0.0 and ehp_ratio >= ehp_req
	var hps_pass: bool = considered > 0 and total_time_alive > 0.0 and effective_hps >= hps_req
	var pass_flag: bool = ehp_pass or hps_pass
	var reason: String = "no_samples" if considered <= 0 else ""

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["incoming_total"] = total_incoming
	extras["healing_total"] = total_healing
	extras["shield_absorbed_total"] = total_shield
	extras["time_alive_total_s"] = total_time_alive
	var ehp_extra: Dictionary = extras.duplicate()
	var ehp_ok: Variant = ehp_pass
	if pass_flag and not ehp_pass and hps_pass:
		ehp_ok = null
		ehp_extra["reason"] = "alternate_sustain_hps_evidence_satisfied"
	RoleCommon.append_span(spans, "subject_sustain_ehp_ratio", ehp_ratio, ehp_req, ehp_ok, ehp_extra)
	RoleCommon.append_span(spans, "subject_sustain_effective_hps", effective_hps, hps_req, hps_pass, extras)

	var messages: Array[String] = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("considered=%d" % considered)
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "; ".join(messages)
	}

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var context: Dictionary = entry.get("context", {})
	var team_a: Array = context.get("team_a_ids", [])
	var team_b: Array = context.get("team_b_ids", [])
	var sid: String = String(subject_id)
	for unit_id in team_a:
		if String(unit_id) == sid:
			return "a"
	for unit_id_b in team_b:
		if String(unit_id_b) == sid:
			return "b"
	return ""

func _subject_unit(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var units: Dictionary = entry.get("units", {})
	if not (units is Dictionary):
		return {}
	var arr: Array = units.get(side, [])
	if not (arr is Array):
		return {}
	for value in arr:
		if not (value is Dictionary):
			continue
		var unit_entry: Dictionary = value
		if String(unit_entry.get("unit_id", "")) == subject_id:
			return unit_entry
	return {}

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for key in sims.keys():
		var side: String = _subject_side(sims.get(key, {}), subject_id)
		if side != "":
			return side
	return ""
