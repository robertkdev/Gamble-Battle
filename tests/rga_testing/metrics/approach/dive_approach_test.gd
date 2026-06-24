extends RefCounted

# Approach: Dive (per-unit subject)
# Pass condition: subject reaches enemy backline first (rank 1) within time bound
# across sims with pass_fraction >= threshold.

const VERSION := "1.0.0"
const METRIC_ID := "approach_dive"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS = ["mobility", "zones"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "Dive: subject reaches enemy backline first within time bound with sufficient frequency."
	}

func run_metric(payload: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = payload.get("context", {})
	var sims: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	if sims.is_empty():
		return RoleCommon.fail_result([], ["no_sims_in_context"])

	# Resolve subject and thresholds
	var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)
	if subject_set.is_empty():
		return RoleCommon.fail_result([], ["no_subject_specified"])
	var subject_id: String = String(subject_set.keys()[0])
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var cost_band: int = int(ident.get("cost", 3))
	var scenario_label: String = String(ctx.get("scenario", "neutral"))
	var thresholds_all: Dictionary = RoleCommon.load_thresholds()
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "dive")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var bc_cfg: Dictionary = metrics_cfg.get("first_backline_contact", {})
	var pass_frac_cfg: Dictionary = bc_cfg.get("pass_fraction", {})
	var time_cfg: Dictionary = bc_cfg.get("time_s", {})
	var pass_frac_req: float = RoleCommon.resolve_min_threshold(pass_frac_cfg, cost_band, scenario_label)
	var time_bound: float = RoleCommon.resolve_max_threshold(time_cfg, cost_band, scenario_label)
	if time_bound <= 0.0:
		time_bound = 3.5

	# Evaluate across sims for subject side only
	var considered: int = 0
	var success: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var kernels: Dictionary = entry.get("kernels", {})
		var ba: Dictionary = kernels.get("backline_access", {})
		if not (ba is Dictionary) or not bool(ba.get("supported", false)):
			continue
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		var side_block: Dictionary = ba.get(side, {})
		var tv: float = RoleCommon.safe_float(side_block, "first_backline_contact_s", -1.0)
		var uid_val: String = String(side_block.get("first_backline_unit_id", ""))
		if tv < 0.0:
			continue
		considered += 1
		if uid_val == subject_id and tv <= time_bound:
			success += 1

	var frac: float = (float(success) / max(1.0, float(considered)))
	var pass_flag: bool = (frac >= pass_frac_req)
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("kernel_unsupported" if considered <= 0 else ""))
	extras["time_bound_s"] = time_bound
	RoleCommon.append_span(spans, "subject_first_backline_frac", frac, pass_frac_req, pass_flag, extras)

	var messages: Array = []
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
	var c: Dictionary = entry.get("context", {})
	var a: Array = c.get("team_a_ids", [])
	var b: Array = c.get("team_b_ids", [])
	var sid := String(subject_id)
	for x in a:
		if String(x) == sid:
			return "a"
	for y in b:
		if String(y) == sid:
			return "b"
	return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for k in sims.keys():
		var s := _subject_side(sims.get(k, {}), subject_id)
		if s != "":
			return s
	return ""
