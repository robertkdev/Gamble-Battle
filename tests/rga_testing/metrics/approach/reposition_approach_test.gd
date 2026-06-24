extends RefCounted

# Approach: reposition (per-unit subject)
# Pass condition: subject shows mobility/displacement consistent with kiting,
# dodging, or short-range reposition tools.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_reposition"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["mobility"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "reposition: subject max step, post-cast movement, and path distance."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "reposition")
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 1, "n": 3})
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var step_cfg: Dictionary = metrics_cfg.get("max_step_tiles", {})
	var post_cast_cfg: Dictionary = metrics_cfg.get("post_cast_displacement_tiles", {})
	var path_cfg: Dictionary = metrics_cfg.get("total_path_tiles", {})
	var step_req: float = RoleCommon.resolve_min_threshold(step_cfg, cost_band, scenario_label)
	var post_cast_req: float = RoleCommon.resolve_min_threshold(post_cast_cfg, cost_band, scenario_label)
	var path_req: float = RoleCommon.resolve_min_threshold(path_cfg, cost_band, scenario_label)
	if step_req <= 0.0:
		step_req = 0.75
	if post_cast_req <= 0.0:
		post_cast_req = 1.0
	if path_req <= 0.0:
		path_req = 3.0

	var step_samples: Array[float] = []
	var post_cast_samples: Array[float] = []
	var path_samples: Array[float] = []
	var reposition_steps: int = 0
	var considered: int = 0
	for key in sims.keys():
		var rec: Dictionary = _subject_control(sims.get(key, {}), subject_id)
		if rec.is_empty():
			continue
		considered += 1
		step_samples.append(float(rec.get("max_step_tiles", 0.0)))
		post_cast_samples.append(float(rec.get("post_cast_displacement_tiles", 0.0)))
		path_samples.append(float(rec.get("total_path_tiles", 0.0)))
		reposition_steps += int(rec.get("reposition_steps", 0))

	var step_value: float = RoleCommon.median(step_samples)
	var post_cast_value: float = RoleCommon.median(post_cast_samples)
	var path_value: float = RoleCommon.median(path_samples)
	var step_pass: bool = step_samples.size() > 0 and step_value >= step_req
	var post_cast_pass: bool = post_cast_samples.size() > 0 and post_cast_value >= post_cast_req
	var path_pass: bool = path_samples.size() > 0 and path_value >= path_req
	var eval: Dictionary = RoleCommon.k_of_n([step_pass, post_cast_pass, path_pass], int(kcfg.get("k", 1)), int(kcfg.get("n", 3)))
	var pass_flag: bool = bool(eval.get("pass", false))

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_samples" if considered <= 0 else ""))
	extras["considered"] = considered
	extras["reposition_steps"] = reposition_steps
	extras["k_required"] = int(eval.get("k", 1))
	extras["true_count"] = int(eval.get("true_count", 0))
	RoleCommon.append_span(spans, "subject_max_step_tiles_med", step_value, step_req, step_pass, extras)
	RoleCommon.append_span(spans, "subject_post_cast_displacement_tiles_med", post_cast_value, post_cast_req, post_cast_pass, extras)
	RoleCommon.append_span(spans, "subject_total_path_tiles_med", path_value, path_req, path_pass, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; reposition_steps=%d" % [scenario_label, considered, reposition_steps]
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
