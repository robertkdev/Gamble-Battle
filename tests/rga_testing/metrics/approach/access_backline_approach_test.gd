extends RefCounted

# Approach: access_backline (per-unit subject)
# Pass condition: subject reaches enemy backline first within the configured time bound
# across sims with pass_fraction >= threshold.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_access_backline"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["mobility", "zones"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "access_backline: subject reaches enemy backline first within time bound with sufficient frequency."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "access_backline")
	if cfg.is_empty():
		cfg = RoleCommon.approach_threshold(thresholds_all, "dive")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var bc_cfg: Dictionary = metrics_cfg.get("first_backline_contact", {})
	var pass_frac_cfg: Dictionary = bc_cfg.get("pass_fraction", {})
	var time_cfg: Dictionary = bc_cfg.get("time_s", {})
	var cast_window_cfg: Dictionary = bc_cfg.get("cast_window_s", {})
	var cast_grace_cfg: Dictionary = bc_cfg.get("cast_pre_signal_grace_s", {})
	var pass_frac_req: float = RoleCommon.resolve_min_threshold(pass_frac_cfg, cost_band, scenario_label)
	var time_bound: float = RoleCommon.resolve_max_threshold(time_cfg, cost_band, scenario_label)
	var cast_window_s: float = RoleCommon.resolve_max_threshold(cast_window_cfg, cost_band, scenario_label)
	var cast_pre_signal_grace_s: float = RoleCommon.resolve_max_threshold(cast_grace_cfg, cost_band, scenario_label)
	if time_bound <= 0.0:
		time_bound = 3.5
	if cast_window_s <= 0.0:
		cast_window_s = 1.5
	if cast_pre_signal_grace_s <= 0.0:
		cast_pre_signal_grace_s = 0.1

	var considered: int = 0
	var success: int = 0
	var best_contact_s: float = -1.0
	var best_first_cast_s: float = -1.0
	var success_reason: String = ""
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var kernels: Dictionary = entry.get("kernels", {})
		var backline_access: Dictionary = kernels.get("backline_access", {})
		if not (backline_access is Dictionary) or not bool(backline_access.get("supported", false)):
			continue
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		var side_block: Dictionary = backline_access.get(side, {})
		var entered_by_unit: Dictionary = side_block.get("entered_by_unit", {})
		considered += 1
		var raw_contact: Variant = entered_by_unit.get(subject_id, null)
		var has_contact: bool = typeof(raw_contact) == TYPE_FLOAT or typeof(raw_contact) == TYPE_INT
		if not has_contact:
			continue
		var contact_s: float = float(raw_contact)
		var first_cast_s: float = _subject_first_cast_s(entry, subject_id, side)
		var fast_contact_ok: bool = contact_s <= time_bound
		var cast_relative_ok: bool = first_cast_s >= 0.0 and contact_s >= (first_cast_s - cast_pre_signal_grace_s) and (contact_s - first_cast_s) <= cast_window_s
		if best_contact_s < 0.0 or contact_s < best_contact_s:
			best_contact_s = contact_s
			best_first_cast_s = first_cast_s
		if fast_contact_ok or cast_relative_ok:
			success += 1
			success_reason = "fast_contact" if fast_contact_ok else "cast_relative_contact"

	var frac: float = float(success) / max(1.0, float(considered))
	var pass_flag: bool = frac >= pass_frac_req
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("kernel_unsupported" if considered <= 0 else ""))
	extras["time_bound_s"] = time_bound
	extras["cast_window_s"] = cast_window_s
	extras["cast_pre_signal_grace_s"] = cast_pre_signal_grace_s
	extras["subject_first_backline_contact_s"] = best_contact_s
	extras["subject_first_cast_s"] = best_first_cast_s
	extras["success_reason"] = success_reason
	RoleCommon.append_span(spans, "subject_first_backline_frac", frac, pass_frac_req, pass_flag, extras)

	var messages: Array[String] = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("considered=%d" % considered)
	messages.append("success=%d" % success)

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
	for unit_id in team_b:
		if String(unit_id) == sid:
			return "b"
	return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for key in sims.keys():
		var side: String = _subject_side(sims.get(key, {}), subject_id)
		if side != "":
			return side
	return ""

func _subject_first_cast_s(entry: Dictionary, subject_id: String, side: String) -> float:
	var units: Dictionary = entry.get("units", {})
	if not (units is Dictionary):
		return -1.0
	var arr: Array = units.get(side, [])
	if not (arr is Array):
		return -1.0
	for value in arr:
		if not (value is Dictionary):
			continue
		var unit_entry: Dictionary = value
		if String(unit_entry.get("unit_id", "")) == subject_id:
			return float(unit_entry.get("first_cast_s", -1.0))
	return -1.0
