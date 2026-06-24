extends RefCounted
class_name RoleVerdicts

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

# Aggregates role_* metric outputs into per-role verdicts with reasons.
# Input shape (from MetricRegistry.run_all):
#   metrics: Array[Dictionary] where each has keys: id, status, spans, message, details
# Returns: Dictionary role -> { status, pass_rate, margin, samples, reasons[], span_labels[], details }

const DEFAULT_PASS_THRESHOLD := 0.60
const DEFAULT_LEAN_THRESHOLD := 0.40
const STRONG_MARGIN := 0.10
const DEFAULT_TOLERANCE := 0.10

static func compute(metrics, opts: Dictionary = {}) -> Dictionary:
	var per_role: Dictionary = {}
	for m in metrics:
		if not (m is Dictionary):
			continue
		var id: String = String(m.get("id", ""))
		if id == "":
			continue
		var role: String = _role_from_metric_id(id)
		if role == "":
			continue
		var arr: Array = per_role.get(role, [])
		arr.append(m)
		per_role[role] = arr
	var out: Dictionary = {}
	# Load thresholds root for tolerance hints (optional)
	var thresholds_root: Dictionary = RoleCommon.load_thresholds()
	for role_key in per_role.keys():
		var ms: Array = per_role.get(role_key, [])
		out[role_key] = _summarize_role(String(role_key), ms, opts, thresholds_root)
	return out

static func _summarize_role(_role_id: String, metrics: Array, opts: Dictionary, thresholds_root: Dictionary) -> Dictionary:
	var pass_thr: float = float(opts.get("pass_threshold", DEFAULT_PASS_THRESHOLD))
	var lean_thr: float = float(opts.get("lean_threshold", DEFAULT_LEAN_THRESHOLD))
	var strong_margin: float = float(opts.get("strong_margin", STRONG_MARGIN))
	var tol: float = 0.0
	if thresholds_root is Dictionary:
		var schema: Dictionary = thresholds_root.get("schema", {})
		tol = float(schema.get("default_tolerance", DEFAULT_TOLERANCE)) if schema is Dictionary else DEFAULT_TOLERANCE
	else:
		tol = DEFAULT_TOLERANCE

	var req_total: int = 0
	var req_ok: int = 0
	var best_margin: float = -INF
	var worst_margin: float = INF
	var reasons: Array[String] = []
	var used_labels: Dictionary = {}

	# Fit/overperformance accumulators
	var fit_sum: float = 0.0
	var fit_n: int = 0
	var over_sum: int = 0
	var over_n: int = 0
	var metric_pass_count: int = 0

	# Collect requirement spans (those with want + ok) across all matching metrics
	var all_req_spans: Array[Dictionary] = []
	for m in metrics:
		if String(m.get("status", "")).to_lower() == "pass":
			metric_pass_count += 1
		var spans: Array = m.get("spans", [])
		if not (spans is Array):
			continue
		for s in spans:
			if not (s is Dictionary):
				continue
			var has_want: bool = (s as Dictionary).has("want")
			var has_ok: bool = (s as Dictionary).has("ok")
			if not (has_want and has_ok):
				continue
			all_req_spans.append(s)

	# Compute pass fraction and margins
	for s2 in all_req_spans:
		var ok: bool = bool(s2.get("ok", false))
		var value: Variant = s2.get("value", null)
		var want: Variant = s2.get("want", null)
		var label: String = String(s2.get("label", ""))
		if _is_number(value) and _is_number(want):
			var v: float = float(value)
			var w: float = float(want)
			var margin: float = v - w
			best_margin = max(best_margin, margin)
			worst_margin = min(worst_margin, margin)
			# Build readable reason line and keep a few top ones
			var sym: String = (">=" if v >= w else "<")
			var line: String = "%s %0.2f %s %0.2f" % [label, v, sym, w]
			var extra_reason: String = String(s2.get("reason", "")).strip_edges()
			if extra_reason != "":
				line += "; " + extra_reason
			if reasons.size() < 6 and not used_labels.has(label):
				reasons.append(line)
				used_labels[label] = true
		# Count requirement outcomes regardless of numeric types (ok implies counted)
		req_total += 1
		if ok:
			req_ok += 1

		# Compute a simple fit component and overperformance based on optional req_*_max in span
		if _is_number(value):
			var vnum: float = float(value)
			# Detect optional max in span (keys ending with _max)
			var max_val: Variant = null
			for k in s2.keys():
				var ks: String = String(k)
				if ks.begins_with("req_") and ks.ends_with("_max"):
					max_val = s2.get(k)
					break
			# Evaluate band with tolerance
			var eval := RoleCommon.eval_min_max(vnum, want, max_val, tol)
			# Fit component: 1 for ok, 0.5 for lean, 0 for failure
			var fit_c: float = 0.0
			if bool(eval.get("ok", false)):
				fit_c = 1.0
			elif bool(eval.get("lean_low", false)) or bool(eval.get("lean_high", false)):
				fit_c = 0.5
			fit_sum += fit_c
			fit_n += 1
			# Overperformance if over max
			if bool(eval.get("over_max", false)):
				over_sum += 1
				over_n += 1
			elif max_val != null:
				over_n += 1

	var pass_rate: float = (float(req_ok) / max(1.0, float(req_total)))
	var fit_score: float = (fit_sum / max(1.0, float(fit_n)))
	var overperformance_score: float = (float(over_sum) / max(1.0, float(over_n)))
	# Determine status
	var status: String = "FAIL"
	if metric_pass_count > 0:
		status = "PASS"
	elif pass_rate >= pass_thr:
		status = "PASS"
	elif pass_rate >= lean_thr or best_margin >= strong_margin:
		status = "LEAN"

	# Span labels for provenance
	var span_labels: Array[String] = []
	for lbl in used_labels.keys():
		span_labels.append(String(lbl))

	return {
		"status": status,
		"pass_rate": pass_rate,
		"margin": (best_margin if best_margin > -INF else 0.0),
		"samples": req_total,
		"reasons": reasons,
		"span_labels": span_labels,
		"details": {
			"req_ok": req_ok,
			"req_total": req_total,
			"best_margin": (best_margin if best_margin > -INF else 0.0),
			"worst_margin": (worst_margin if worst_margin < INF else 0.0),
			"fit_score": fit_score,
			"overperformance_score": overperformance_score
		}
	}

static func _role_from_metric_id(metric_id: String) -> String:
	var s := String(metric_id).strip_edges().to_lower()
	# Accept role_<role>_identity or <role>_role_identity
	if s.begins_with("role_") and s.ends_with("_identity"):
		return s.substr(5, s.length() - 5 - 9)
	if s.ends_with("_role_identity"):
		return s.substr(0, s.length() - String("_role_identity").length())
	return ""

static func _is_number(v) -> bool:
	var t := typeof(v)
	return (t == TYPE_FLOAT or t == TYPE_INT)
