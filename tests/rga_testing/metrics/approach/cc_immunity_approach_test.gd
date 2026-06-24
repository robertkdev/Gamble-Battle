extends RefCounted

# Approach: cc_immunity (per-unit subject)
# Pass condition: subject grants/receives CC immunity or prevents an incoming CC.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_cc_immunity"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["buffs"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "cc_immunity: subject grants or receives CC immunity, or CC is prevented while subject is immune."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "cc_immunity")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var applied_cfg: Dictionary = metrics_cfg.get("cc_immunity_applied", {})
	var prevented_cfg: Dictionary = metrics_cfg.get("cc_prevented", {})
	var counter_cfg: Dictionary = metrics_cfg.get("counter_cooldown_trade_s", {})
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var cost_band: int = int(ident.get("cost", 3))
	var applied_req: float = RoleCommon.resolve_min_threshold(applied_cfg, cost_band, scenario_label)
	var prevented_req: float = RoleCommon.resolve_min_threshold(prevented_cfg, cost_band, scenario_label)
	var counter_req: float = RoleCommon.resolve_min_threshold(counter_cfg, cost_band, scenario_label)
	if applied_req <= 0.0:
		applied_req = 1.0
	if prevented_req <= 0.0:
		prevented_req = 1.0
	if counter_req <= 0.0:
		counter_req = 1.0

	var immunity_source: int = 0
	var immunity_received: int = 0
	var prevented_as_target: int = 0
	var counter_cooldown_trade_s: float = 0.0
	var cooldown_trade_efficiency: float = 0.0
	var threat_draw_casters: int = 0
	var key_threat_share: float = 0.0
	var direct_cooldown_supported: bool = false
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var source_rec: Dictionary = _subject_buff_source(entry, subject_id)
		var target_rec: Dictionary = _subject_buff_target(entry, subject_id)
		var cooldown_rec: Dictionary = _subject_cooldown_pressure(entry, subject_id)
		if source_rec.is_empty() and target_rec.is_empty() and cooldown_rec.is_empty():
			if _subject_side(entry, subject_id) != "":
				considered += 1
			continue
		considered += 1
		immunity_source += int(source_rec.get("cc_immunity", 0))
		immunity_received += int(target_rec.get("cc_immunity_received", 0))
		prevented_as_target += int(target_rec.get("cc_prevented", 0))
		if not cooldown_rec.is_empty():
			direct_cooldown_supported = true
			counter_cooldown_trade_s += float(cooldown_rec.get("cooldowns_forced_s", 0.0))
			cooldown_trade_efficiency = max(cooldown_trade_efficiency, float(cooldown_rec.get("cooldown_trade_efficiency", 0.0)))
			threat_draw_casters += int(cooldown_rec.get("cooldown_threat_draw_casters", 0))
			key_threat_share = max(key_threat_share, float(cooldown_rec.get("cooldown_key_threat_share", 0.0)))

	var applied_total: int = immunity_source + immunity_received
	var applied_pass: bool = considered > 0 and float(applied_total) >= applied_req
	var prevented_pass: bool = considered > 0 and float(prevented_as_target) >= prevented_req
	var counter_pass: bool = considered > 0 and direct_cooldown_supported and (applied_total > 0 or prevented_as_target > 0) and counter_cooldown_trade_s >= counter_req
	var pass_flag: bool = applied_pass or prevented_pass or counter_pass
	var reason: String = "no_samples" if considered <= 0 else ""
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["direct_cooldown_pressure_supported"] = direct_cooldown_supported
	RoleCommon.append_span(spans, "subject_cc_immunity_applied_or_received", applied_total, applied_req, applied_pass, extras)
	RoleCommon.append_span(spans, "subject_cc_prevented_as_target", prevented_as_target, prevented_req, prevented_pass, extras)
	RoleCommon.append_span(spans, "subject_cc_immunity_counter_cooldown_trade_s", counter_cooldown_trade_s, counter_req, counter_pass, extras)
	RoleCommon.append_span(spans, "subject_cc_immunity_cooldown_trade_efficiency", cooldown_trade_efficiency, 1.0, direct_cooldown_supported and cooldown_trade_efficiency >= 1.0, extras)
	RoleCommon.append_span(spans, "subject_cc_immunity_threat_draw_casters", float(threat_draw_casters), 1.0, direct_cooldown_supported and threat_draw_casters >= 1, extras)
	RoleCommon.append_span(spans, "subject_cc_immunity_key_threat_share", key_threat_share, 0.50, direct_cooldown_supported and key_threat_share >= 0.50, extras)
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; applied=%d; prevented=%d; cooldown_trade=%.2f; cooldown_efficiency=%.2f" % [scenario_label, considered, applied_total, prevented_as_target, counter_cooldown_trade_s, cooldown_trade_efficiency]
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

func _subject_buff_target(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var buffs: Dictionary = kernels.get("buff_presence", {}) if (kernels is Dictionary) else {}
	var target_unit: Dictionary = buffs.get("target_unit", {}) if (buffs is Dictionary) else {}
	var side_map: Dictionary = target_unit.get(side, {}) if (target_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_cooldown_pressure(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var pressure: Dictionary = kernels.get("cooldown_pressure", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = pressure.get("per_unit", {}) if (pressure is Dictionary) else {}
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
