extends RefCounted

# Approach: damage_reduction (per-unit subject)
# Pass condition: subject prevents enough pre-mitigation incoming damage before
# shields/HP caps are applied.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_damage_reduction"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "damage_reduction: subject pre-mitigation to post-mitigation prevention ratio."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "damage_reduction")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var ratio_cfg: Dictionary = metrics_cfg.get("mitigation_ratio", {})
	var prevented_cfg: Dictionary = metrics_cfg.get("prevented_damage", {})
	var ratio_req: float = RoleCommon.resolve_min_threshold(ratio_cfg, cost_band, scenario_label)
	var prevented_req: float = RoleCommon.resolve_min_threshold(prevented_cfg, cost_band, scenario_label)
	if ratio_req <= 0.0:
		ratio_req = 0.08
	if prevented_req <= 0.0:
		prevented_req = 25.0

	var total_pre_mit: float = 0.0
	var total_post_mit: float = 0.0
	var total_incoming: float = 0.0
	var total_shield: float = 0.0
	var considered: int = 0
	var missing_post_mit: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		var unit_entry: Dictionary = _subject_unit(entry, side, subject_id)
		if unit_entry.is_empty():
			continue
		if not unit_entry.has("post_mit_incoming"):
			missing_post_mit += 1
			continue
		var pre_mit: float = float(unit_entry.get("pre_mit_incoming", 0.0))
		if pre_mit <= 0.0:
			continue
		considered += 1
		total_pre_mit += pre_mit
		total_post_mit += max(0.0, float(unit_entry.get("post_mit_incoming", 0.0)))
		total_incoming += float(unit_entry.get("incoming", 0.0))
		total_shield += float(unit_entry.get("shield", 0.0))

	var prevented_damage: float = max(0.0, total_pre_mit - total_post_mit)
	var mitigation_ratio: float = prevented_damage / max(1.0, total_pre_mit)
	var ratio_pass: bool = considered > 0 and mitigation_ratio >= ratio_req
	var prevented_pass: bool = considered > 0 and prevented_damage >= prevented_req
	var pass_flag: bool = ratio_pass or prevented_pass
	var reason: String = ""
	if considered <= 0:
		reason = "post_mit_unsupported" if missing_post_mit > 0 else "no_damage_reduction_samples"

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["missing_post_mit"] = missing_post_mit
	extras["pre_mit_incoming_total"] = total_pre_mit
	extras["post_mit_incoming_total"] = total_post_mit
	extras["incoming_total"] = total_incoming
	extras["shield_absorbed_total"] = total_shield
	RoleCommon.append_span(spans, "subject_damage_reduction_ratio", mitigation_ratio, ratio_req, ratio_pass, extras)
	RoleCommon.append_span(spans, "subject_damage_prevented_before_shield", prevented_damage, prevented_req, prevented_pass, extras)

	var messages: Array[String] = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("considered=%d" % considered)
	if missing_post_mit > 0:
		messages.append("missing_post_mit=%d" % missing_post_mit)
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
