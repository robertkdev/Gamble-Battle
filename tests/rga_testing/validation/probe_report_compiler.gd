extends RefCounted
class_name ProbeReportCompiler

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")
const RoleVerdicts := preload("res://tests/rga_testing/validation/role_verdicts.gd")

const APPROACH_METRIC_IDS := {
	"access_backline": "approach_access_backline",
	"amp": "approach_amp",
	"aoe": "approach_aoe",
	"burst": "approach_burst",
	"cc_immunity": "approach_cc_immunity",
	"damage_reduction": "approach_damage_reduction",
	"debuff": "approach_debuff",
	"dot": "approach_dot",
	"dive": "approach_dive",
	"disrupt": "approach_disrupt",
	"engage": "approach_engage",
	"execute": "approach_execute",
	"long_range": "approach_long_range",
	"lockdown": "approach_lockdown",
	"on_hit_effect": "approach_on_hit_effect",
	"peel": "approach_peel",
	"poke": "approach_poke",
	"ramp": "approach_ramp",
	"redirect": "approach_redirect",
	"reposition": "approach_reposition",
	"reset_mechanic": "approach_reset_mechanic",
	"sustain": "approach_sustain",
	"untargetable": "approach_untargetable",
	"zone": "approach_zone"
}

const GOAL_DIRECT_METRIC_ID: String = "goal_primary"

const GOAL_PROXY_METRIC_IDS := {
	"assassin.backline_elimination": ["assassin_backline_elimination", "approach_access_backline"],
	"assassin.cleanup_execution": ["approach_execute"],
	"assassin.disrupt_and_escape": ["approach_disrupt", "approach_untargetable", "approach_reposition"],
	"brawler.attrition_dps": ["approach_sustain", "approach_ramp"],
	"brawler.frontline_disruption": ["approach_disrupt", "approach_lockdown", "approach_damage_reduction"],
	"brawler.skirmish_dive": ["approach_access_backline", "approach_reposition", "approach_disrupt"],
	"mage.area_denial_zone": ["approach_zone", "approach_aoe", "approach_debuff"],
	"mage.pick_burst": ["approach_burst"],
	"mage.sustained_dps": ["approach_zone", "approach_aoe", "approach_ramp"],
	"mage.wombo_combo_burst": ["approach_burst", "approach_aoe"],
	"marksman.backline_siege": ["approach_long_range", "approach_ramp", "approach_aoe"],
	"marksman.sustained_dps": ["approach_ramp", "approach_on_hit_effect", "approach_long_range"],
	"marksman.tank_shredding": ["approach_debuff", "approach_ramp", "approach_long_range"],
	"support.peel_carry": ["approach_peel", "approach_cc_immunity", "approach_amp"],
	"support.team_amplification": ["approach_amp", "approach_peel", "approach_sustain"],
	"support.enemy_lockdown": ["approach_lockdown"],
	"support.formation_breaking": ["approach_disrupt", "approach_zone"],
	"support.initiate_fight": ["approach_engage", "approach_disrupt"],
	"tank.frontline_absorb": ["approach_damage_reduction", "approach_sustain", "approach_redirect"],
	"tank.team_fortification": ["approach_amp", "approach_damage_reduction", "approach_sustain"],
	"tank.initiate_fight": ["approach_engage"],
	"tank.single_target_lockdown": ["approach_lockdown"]
}

# Compiles a per-unit identity probe report from a RoleMetrics context and MetricRegistry output.
# Returns a Dictionary with shape:
# {
# 	unit_id: String,
# 	assigned_identity: { unit_id, primary_role, primary_goal, approaches, cost, level },
# 	runs: { run_id, sims_count, scenarios: String[], opponents: String[], rows_path, files: String[] },
# 	verdicts: { roles: Dictionary, goals: Dictionary, approaches: Dictionary },
# 	evidence: { rows_path: String, files: String[] }
# }
static func compile(subject_id: String, ctx: Dictionary, registry_result: Dictionary, options: Dictionary = {}) -> Dictionary:
	var uid := String(subject_id)
	var assigned_identity: Dictionary = RoleCommon.get_identity(uid)
	var sims: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	var files_arr: Array = ctx.get("files", []) if (ctx is Dictionary) else []
	var sims_count: int = (sims.size() if sims is Dictionary else 0)
	var scenarios: Array[String] = _collect_scenarios(sims)
	var opponents: Array[String] = _collect_opponents(sims, uid)
	var caps_present = (ctx.get("caps_present", []) if (ctx is Dictionary) else [])
	var run_id := String(options.get("run_id", ""))
	var rows_path := String(options.get("rows_path", ""))

	# Build per-role verdicts using rubric (PASS/LEAN/FAIL) and reasons
	var metrics: Array = registry_result.get("metrics", []) if (registry_result is Dictionary) else []
	var role_verdicts: Dictionary = RoleVerdicts.compute(metrics, options)
	# Augment: include per-role deltas computed from subject spans
	var deltas_per_role: Dictionary = _collect_deltas_by_role(uid, metrics)
	for rk in role_verdicts.keys():
		var v: Dictionary = role_verdicts.get(rk, {})
		if v is Dictionary:
			v["deltas"] = deltas_per_role.get(rk, {})
			role_verdicts[rk] = v
	var verdicts := {
		"roles": role_verdicts,
		"goals": _compile_goal_verdicts(assigned_identity, metrics),
		"approaches": _compile_approach_verdicts(assigned_identity, metrics)
	}

	return {
		"unit_id": uid,
		"assigned_identity": assigned_identity,
		"runs": {
			"run_id": run_id,
			"sims_count": sims_count,
			"scenarios": scenarios,
			"opponents": opponents,
			"caps_present": caps_present,
			"rows_path": rows_path,
			"files": files_arr,
			"scenario_counts": _scenario_counts(sims)
		},
		"verdicts": verdicts,
		"evidence": {
			"rows_path": rows_path,
			"files": files_arr
		}
	}

static func write(report: Dictionary) -> String:
	var uid := String(report.get("unit_id", "subject"))
	var dir_path := "user://identity_reports"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var out_path := "%s/%s.json" % [dir_path, uid]
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("ProbeReportCompiler: failed to open file for write: " + out_path)
		return ""
	var txt := JSON.stringify(report)
	f.store_string(txt)
	f.flush()
	f.close()
	return out_path

static func print_summary(report: Dictionary) -> void:
	var uid := String(report.get("unit_id", ""))
	var assigned: Dictionary = report.get("assigned_identity", {})
	var role := String(assigned.get("primary_role", ""))
	var goal := String(assigned.get("primary_goal", ""))
	print("Report ", uid, " role=", role, " goal=", goal)
	var roles_block: Dictionary = (report.get("verdicts", {}) as Dictionary).get("roles", {})
	for rk in roles_block.keys():
		var v: Dictionary = roles_block.get(rk, {})
		var status := String(v.get("status", "FAIL"))
		var pr := float(v.get("pass_rate", 0.0))
		var margin := float(v.get("margin", 0.0))
		var samples := int(v.get("samples", 0))
		print("  ", rk, ": ", status, " pass=", _fmt_num(pr, 2), " margin=", _fmt_num(margin, 2), " n=", samples)
		var reasons: Array = v.get("reasons", [])
		var n: int = min(3, reasons.size())
		for i in range(n):
			print("    ", String(reasons[i]))
	var goals_block: Dictionary = (report.get("verdicts", {}) as Dictionary).get("goals", {})
	for goal_key in goals_block.keys():
		var goal_verdict: Dictionary = goals_block.get(goal_key, {})
		print("  goal ", String(goal_key), ": ", String(goal_verdict.get("status", "UNTESTED")))
	var approaches_block: Dictionary = (report.get("verdicts", {}) as Dictionary).get("approaches", {})
	for approach_key in approaches_block.keys():
		var approach_verdict: Dictionary = approaches_block.get(approach_key, {})
		print("  approach ", String(approach_key), ": ", String(approach_verdict.get("status", "UNTESTED")))

# --- helpers -------------------------------------------------------------

static func _collect_scenarios(sims: Dictionary) -> Array[String]:
	var scenario_set: Dictionary = {}
	if sims is Dictionary:
		for k in sims.keys():
			var e: Dictionary = sims.get(k, {})
			var ctx_e: Dictionary = e.get("context", {})
			var scen := String(ctx_e.get("scenario_label", ""))
			if scen != "":
				scenario_set[scen] = true
	var out: Array[String] = []
	for kk in scenario_set.keys():
		out.append(String(kk))
	out.sort()
	return out

static func _collect_opponents(sims: Dictionary, subject_id: String) -> Array[String]:
	var opponent_set: Dictionary = {}
	if sims is Dictionary:
		for k in sims.keys():
			var e: Dictionary = sims.get(k, {})
			var ctx_e: Dictionary = e.get("context", {})
			var a: Array = ctx_e.get("team_a_ids", [])
			var b: Array = ctx_e.get("team_b_ids", [])
			var subj := String(subject_id)
			var subj_in_a := false
			var subj_in_b := false
			for x in a:
				if String(x) == subj: subj_in_a = true
			for y in b:
				if String(y) == subj: subj_in_b = true
			if subj_in_a:
				for opp in b: opponent_set[String(opp)] = true
			elif subj_in_b:
				for opp2 in a: opponent_set[String(opp2)] = true
	var out: Array[String] = []
	for kk in opponent_set.keys(): out.append(String(kk))
	out.sort()
	return out

static func _scenario_counts(sims: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	if sims is Dictionary:
		for k in sims.keys():
			var e: Dictionary = sims.get(k, {})
			var ctx_e: Dictionary = e.get("context", {})
			var scen := String(ctx_e.get("scenario_label", ""))
			if scen == "":
				continue
			counts[scen] = int(counts.get(scen, 0)) + 1
	return counts

static func _compile_goal_verdicts(assigned_identity: Dictionary, metrics: Array) -> Dictionary:
	var out: Dictionary = {}
	var goal_id: String = String(assigned_identity.get("primary_goal", "")).strip_edges().to_lower()
	if goal_id == "":
		return out
	var direct_metric: Dictionary = _metric_by_id(metrics, GOAL_DIRECT_METRIC_ID)
	if not direct_metric.is_empty():
		out[goal_id] = _verdict_from_metric_ids([GOAL_DIRECT_METRIC_ID], metrics, false)
		return out
	var proxy_metric_ids: Array = GOAL_PROXY_METRIC_IDS.get(goal_id, [])
	out[goal_id] = _verdict_from_metric_ids(proxy_metric_ids, metrics, true)
	return out

static func _compile_approach_verdicts(assigned_identity: Dictionary, metrics: Array) -> Dictionary:
	var out: Dictionary = {}
	var approaches: Array = assigned_identity.get("approaches", [])
	for raw_approach in approaches:
		var approach_id: String = String(raw_approach).strip_edges().to_lower()
		if approach_id == "":
			continue
		var metric_id: String = String(APPROACH_METRIC_IDS.get(approach_id, ""))
		var metric_ids: Array = []
		if metric_id != "":
			metric_ids.append(metric_id)
		out[approach_id] = _verdict_from_metric_ids(metric_ids, metrics, false)
	return out

static func _verdict_from_metric_ids(metric_ids: Array, metrics: Array, proxy: bool) -> Dictionary:
	var ids: Array[String] = []
	for raw_id in metric_ids:
		var id_value: String = String(raw_id).strip_edges()
		if id_value != "":
			ids.append(id_value)
	if ids.is_empty():
		return {
			"status": "UNTESTED",
			"metric_ids": [],
			"matched_metric_ids": [],
			"reason": "no_metric_mapping"
		}

	var matched_metric_ids: Array[String] = []
	var messages: Array[String] = []
	var span_labels: Array[String] = []
	var any_pass: bool = false
	var any_fail: bool = false
	var any_error: bool = false
	var any_skipped: bool = false
	for id_value in ids:
		var metric: Dictionary = _metric_by_id(metrics, id_value)
		if metric.is_empty():
			continue
		matched_metric_ids.append(id_value)
		var status: String = String(metric.get("status", "")).strip_edges().to_lower()
		match status:
			"pass":
				any_pass = true
			"fail":
				any_fail = true
			"error":
				any_error = true
			"skipped":
				any_skipped = true
		var message: String = String(metric.get("message", "")).strip_edges()
		if message != "":
			messages.append(message)
		var spans: Array = metric.get("spans", [])
		for span in spans:
			if not (span is Dictionary):
				continue
			var label: String = String((span as Dictionary).get("label", "")).strip_edges()
			if label != "":
				span_labels.append(label)

	if matched_metric_ids.is_empty():
		return {
			"status": "MISSING_RUN",
			"metric_ids": ids,
			"matched_metric_ids": [],
			"reason": "mapped_metric_not_run"
		}

	var status_out: String = "ERROR"
	if any_pass:
		status_out = "PROXY_PASS" if proxy else "PASS"
	elif any_fail:
		status_out = "PROXY_FAIL" if proxy else "FAIL"
	elif any_error:
		status_out = "ERROR"
	elif any_skipped:
		status_out = "SKIPPED"
	return {
		"status": status_out,
		"metric_ids": ids,
		"matched_metric_ids": matched_metric_ids,
		"messages": messages,
		"span_labels": span_labels,
		"proxy": proxy
	}

static func _metric_by_id(metrics: Array, metric_id: String) -> Dictionary:
	for metric in metrics:
		if not (metric is Dictionary):
			continue
		if String((metric as Dictionary).get("id", "")) == metric_id:
			return metric as Dictionary
	return {}

static func _compile_role_verdicts(subject_id: String, registry_result: Dictionary, sims_count: int) -> Dictionary:
	var out: Dictionary = {}
	var metrics: Array = registry_result.get("metrics", []) if (registry_result is Dictionary) else []
	for m in metrics:
		if not (m is Dictionary):
			continue
		var mid := String(m.get("id", ""))
		if not mid.begins_with("role_"):
			continue
		var role_key := _role_from_metric_id(mid)
		var status := String(m.get("status", "fail"))
		var spans: Array = m.get("spans", [])
		var subj_spans: Array = _spans_for_subject(spans, subject_id)
		var margin: Variant = _best_margin_from_spans(subj_spans)
		var reasons := _reasons_from_spans(subj_spans)
		var span_labels := _labels_from_spans(subj_spans)
		var deltas := _deltas_from_spans(subj_spans)
		var supported := _supported_from_spans(subj_spans)
		var samples := _samples_from_spans_or_default(subj_spans, sims_count)
		out[role_key] = {
			"metric_id": mid,
			"pass": (status == "pass"),
			"margin": margin,
			"samples": samples,
			"supported": supported,
			"reasons": reasons,
			"span_labels": span_labels,
			"deltas": deltas
		}
	return out

static func _collect_deltas_by_role(subject_id: String, metrics: Array) -> Dictionary:
	var out: Dictionary = {}
	for m in metrics:
		if not (m is Dictionary):
			continue
		var mid := String(m.get("id", ""))
		if not mid.begins_with("role_"):
			continue
		var role_key := _role_from_metric_id(mid)
		var spans: Array = m.get("spans", [])
		var subj_spans: Array = _spans_for_subject(spans, subject_id)
		var deltas := _deltas_from_spans(subj_spans)
		var prev: Dictionary = out.get(role_key, {})
		for k in deltas.keys():
			prev[String(k)] = deltas.get(k)
		out[role_key] = prev
	return out

static func _role_from_metric_id(metric_id: String) -> String:
	var s := String(metric_id)
	if not s.begins_with("role_"):
		return s
	s = s.substr(5)
	if s.ends_with("_identity"):
		return s.substr(0, s.length() - 9)
	var idx := s.find("_")
	if idx >= 0:
		return s.substr(0, idx)
	return s

static func _spans_for_subject(spans: Array, subject_id: String) -> Array:
	var out: Array = []
	for s in spans:
		if not (s is Dictionary):
			continue
		if _span_matches_subject(s, subject_id):
			out.append(s)
	return out

static func _best_margin_from_spans(spans: Array):
	var best_set := false
	var best_val: float = 0.0
	for s in spans:
		var v = (s as Dictionary).get("value", null)
		var w = (s as Dictionary).get("want", null)
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and (typeof(w) == TYPE_FLOAT or typeof(w) == TYPE_INT):
			var margin: float = float(v) - float(w)
			if not best_set or margin > best_val:
				best_val = margin
				best_set = true
	var result: Variant = null
	if best_set:
		result = best_val
	return result

static func _reasons_from_spans(spans: Array) -> Array[String]:
	var reason_set: Dictionary = {}
	for s in spans:
		if not (s is Dictionary):
			continue
		var reason := String((s as Dictionary).get("reason", ""))
		if reason != "":
			reason_set[reason] = true
	var out: Array[String] = []
	for k in reason_set.keys():
		out.append(String(k))
	out.sort()
	return out

static func _labels_from_spans(spans: Array) -> Array[String]:
	var out: Array[String] = []
	for s in spans:
		if not (s is Dictionary):
			continue
		out.append(String((s as Dictionary).get("label", "")))
	out.sort()
	return out

static func _span_matches_subject(span: Dictionary, subject_id: String) -> bool:
	var uid := String(span.get("unit_id", ""))
	if uid != "":
		return uid == String(subject_id)
	return true

static func _deltas_from_spans(spans: Array) -> Dictionary:
	var out: Dictionary = {}
	for s in spans:
		if not (s is Dictionary):
			continue
		var label := String(s.get("label", ""))
		var v = s.get("value", null)
		var w = s.get("want", null)
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and (typeof(w) == TYPE_FLOAT or typeof(w) == TYPE_INT):
			out[label] = float(v) - float(w)
	return out

static func _supported_from_spans(spans: Array) -> bool:
	if spans.is_empty():
		return false
	var any_supported := false
	for s in spans:
		if not (s is Dictionary):
			continue
		var reason := String(s.get("reason", ""))
		if reason == "kernel_unsupported":
			return false
		if s.has("backline_access_supported") and not bool(s.get("backline_access_supported")):
			return false
		if s.has("events_supported") and not bool(s.get("events_supported")):
			return false
		any_supported = true
	return any_supported

static func _samples_from_spans_or_default(spans: Array, fallback: int) -> int:
	for s in spans:
		if not (s is Dictionary):
			continue
		if s.has("samples"):
			var v = s.get("samples")
			if typeof(v) == TYPE_INT:
				return int(v)
		if s.has("considered"):
			var c = s.get("considered")
			if typeof(c) == TYPE_INT:
				return int(c)
	return int(fallback)

static func _fmt_num(v: Variant, decimals: int = 2) -> String:
	if v == null:
		return "<null>"
	var t := typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		var fmt := "%0." + str(decimals) + "f"
		return fmt % float(v)
	return String(v)
