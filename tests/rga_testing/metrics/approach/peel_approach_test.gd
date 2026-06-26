extends RefCounted

# Approach: Peel (per-unit subject)
# Pass condition: any of
#  - subject EHP ratio (healing + shields absorbed over incoming) >= threshold
#  - source-attributed ally protection utility from the subject >= threshold
#  - team peel_saves >= threshold (fallback proxy)

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_peel"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "Peel: subject EHP, source-owned ally protection utility, or team peel saves meets threshold."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "peel")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var ehp_cfg: Dictionary = metrics_cfg.get("ehp_ratio", {})
	var peel_cfg: Dictionary = metrics_cfg.get("peel_saves", {})
	var ehp_req: float = float(RoleCommon.resolve_min_threshold(ehp_cfg, cost_band, scenario_label))
	var peel_req: float = float(RoleCommon.resolve_min_threshold(peel_cfg, cost_band, scenario_label))

	var total_incoming: float = 0.0
	var total_heal: float = 0.0
	var total_shield: float = 0.0
	var team_peel_total: int = 0
	var ally_protection_events: int = 0
	var ally_protection_magnitude: float = 0.0
	var cc_immunity_grants: int = 0
	var cleanse_total: int = 0
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		considered += 1
		# Per-unit incoming from aggregates.units
		var units: Dictionary = entry.get("units", {})
		var arr: Array = units.get(side, [])
		if arr is Array:
			for u in arr:
				if not (u is Dictionary):
					continue
				if String(u.get("unit_id", "")) != subject_id:
					continue
				total_incoming += float(u.get("incoming", 0.0))
				break
		# Per-unit healing/shield contributions from kernels.support
		var kernels: Dictionary = entry.get("kernels", {})
		var support: Dictionary = kernels.get("support", {})
		if support is Dictionary:
			var heal_map: Dictionary = support.get("healing_per_unit", {})
			var side_heal: Dictionary = heal_map.get(side, {}) if heal_map is Dictionary else {}
			if side_heal is Dictionary and side_heal.has(subject_id):
				var hrec: Dictionary = side_heal.get(subject_id, {})
				total_heal += float(hrec.get("healed", 0))
				# Overheal contributes to EHP sustainability as well
				total_heal += float(hrec.get("overheal", 0))
			var shield_map: Dictionary = support.get("shield_absorbed_per_unit", {})
			var side_sh: Dictionary = shield_map.get(side, {}) if shield_map is Dictionary else {}
			if side_sh is Dictionary and side_sh.has(subject_id):
				var srec: Dictionary = side_sh.get(subject_id, {})
				total_shield += float(srec.get("absorbed", 0))
		# Team peel saves (fallback)
		var derived: Dictionary = entry.get("derived", {})
		var d_side: Dictionary = derived.get(side, {})
		if d_side is Dictionary:
			team_peel_total += int(d_side.get("peel_saves", 0))
		var source_buff: Dictionary = _subject_buff_source(entry, side, subject_id)
		if not source_buff.is_empty():
			var ally_buffs_to_others: int = int(source_buff.get("ally_buffs_to_others", 0))
			var source_cc_immunity: int = int(source_buff.get("cc_immunity", 0))
			var source_cleanse: int = int(source_buff.get("cleanse_applied", 0))
			ally_protection_events += ally_buffs_to_others + source_cleanse
			ally_protection_magnitude += float(source_buff.get("ally_buff_magnitude_to_others", 0.0))
			cc_immunity_grants += source_cc_immunity
			cleanse_total += source_cleanse

	var ehp_ratio: float = ( (total_heal + total_shield) / max(1.0, total_incoming) )
	var ehp_pass: bool = (ehp_ratio >= ehp_req and considered > 0)
	var peel_pass: bool = (team_peel_total >= int(round(peel_req)))
	var ally_protection_pass: bool = (ally_protection_events >= int(round(peel_req)) and considered > 0)
	var ally_protection_magnitude_pass: bool = (ally_protection_magnitude >= 25.0 and considered > 0)
	var k_any: bool = ehp_pass or peel_pass or ally_protection_pass or ally_protection_magnitude_pass
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_samples" if considered <= 0 else ""))
	extras["incoming_total"] = total_incoming
	extras["healed_total"] = total_heal
	extras["shield_absorbed_total"] = total_shield
	extras["ally_protection_events"] = ally_protection_events
	extras["ally_protection_magnitude"] = ally_protection_magnitude
	extras["cc_immunity_grants"] = cc_immunity_grants
	extras["cleanse_applied"] = cleanse_total
	var team_peel_extra: Dictionary = extras.duplicate()
	var team_peel_ok: Variant = peel_pass
	if k_any and not peel_pass and (ehp_pass or ally_protection_pass or ally_protection_magnitude_pass):
		team_peel_ok = null
		team_peel_extra["reason"] = "alternate_peel_evidence_satisfied"
	RoleCommon.append_span(spans, "subject_ehp_ratio", ehp_ratio, ehp_req, ehp_pass, extras)
	RoleCommon.append_span(spans, "subject_peel_ally_protection_events", ally_protection_events, peel_req, ally_protection_pass, extras)
	RoleCommon.append_span(spans, "subject_peel_ally_protection_magnitude", ally_protection_magnitude, 25.0, ally_protection_magnitude_pass, extras)
	RoleCommon.append_span(spans, "subject_peel_cc_immunity_grants", cc_immunity_grants, 1.0, cc_immunity_grants >= 1, extras)
	RoleCommon.append_span(spans, "subject_peel_cleanse_applied", cleanse_total, 1.0, cleanse_total >= 1, extras)
	RoleCommon.append_span(spans, "team_peel_saves_total", team_peel_total, peel_req, team_peel_ok, team_peel_extra)

	var messages: Array = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("considered=%d" % considered)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": k_any,
		"spans": spans,
		"message": "; ".join(messages)
	}

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var c: Dictionary = entry.get("context", {})
	var a: Array = c.get("team_a_ids", [])
	var b: Array = c.get("team_b_ids", [])
	var sid: String = String(subject_id)
	for x in a:
		if String(x) == sid:
			return "a"
	for y in b:
		if String(y) == sid:
			return "b"
	return ""

func _subject_buff_source(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var buff_presence: Dictionary = kernels.get("buff_presence", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = buff_presence.get("per_unit", {}) if (buff_presence is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for k in sims.keys():
		var s: String = _subject_side(sims.get(k, {}), subject_id)
		if s != "":
			return s
	return ""
