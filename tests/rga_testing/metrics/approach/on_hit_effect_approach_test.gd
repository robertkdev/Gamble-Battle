extends RefCounted

# Approach: on_hit_effect (per-unit subject)
# Requires explicit on-hit proc telemetry. Current ability-side buffs/debuffs do
# not satisfy this metric because the design doc defines on-hit as an additional
# effect with each basic attack.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_on_hit_effect"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["buffs"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "on_hit_effect: subject emits explicit basic-attack on-hit proc evidence."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "on_hit_effect")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var proc_cfg: Dictionary = metrics_cfg.get("on_hit_effects", {})
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var cost_band: int = int(ident.get("cost", 3))
	var proc_req: float = RoleCommon.resolve_min_threshold(proc_cfg, cost_band, scenario_label)
	if proc_req <= 0.0:
		proc_req = 1.0

	var procs: int = 0
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var rec: Dictionary = _subject_buff_source(entry, subject_id)
		if rec.is_empty():
			if _subject_side(entry, subject_id) != "":
				considered += 1
			continue
		considered += 1
		procs += int(rec.get("on_hit_effects", 0))

	var pass_flag: bool = considered > 0 and float(procs) >= proc_req
	var reason: String = "no_on_hit_proc_events"
	if considered <= 0:
		reason = "no_samples"
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	RoleCommon.append_span(spans, "subject_on_hit_proc_events", procs, proc_req, pass_flag, extras)
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; explicit_on_hit_procs=%d" % [scenario_label, considered, procs]
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
