extends RefCounted
class_name RoleCommon

# Shared helpers for role metrics. No role-specific test logic here.
# Provides:
# - K-of-N evaluator
# - Cost-band statistics + z-score helpers
# - Safe getters for nested dictionaries/arrays
# - Telemetry capability checks
# - Standardized span/message/result helpers
# - Threshold loader + relaxations helpers (roles_thresholds.json)

const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const DEFAULT_THRESHOLDS_PATH := "res://tests/rga_testing/metrics/roles/roles_thresholds.json"
const EPS := 1e-9

# Default tolerance used when metric-specific and schema defaults are absent
const DEFAULT_TOLERANCE := 0.10

# Cache for identity lookups by unit_id
static var _identity_cache: Dictionary = {}

# ------------------------ Thresholds ------------------------------------

static func load_thresholds(path: String = DEFAULT_THRESHOLDS_PATH) -> Dictionary:
	var p := String(path).strip_edges()
	if p == "":
		p = DEFAULT_THRESHOLDS_PATH
	var fa := FileAccess.open(p, FileAccess.READ)
	if fa == null:
		return {}
	var txt := fa.get_as_text()
	fa.close()
	if String(txt).strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

static func role_threshold(thresholds: Dictionary, role_id: String) -> Dictionary:
	var roles: Dictionary = thresholds.get("roles", {})
	var key := String(role_id).strip_edges().to_lower()
	return roles.get(key, {}) if roles is Dictionary else {}

# New: goal/approach threshold accessors for centralized config
static func goal_threshold(thresholds: Dictionary, goal_id: String) -> Dictionary:
	var goals: Dictionary = thresholds.get("goals", {})
	var key := String(goal_id).strip_edges().to_lower()
	return goals.get(key, {}) if goals is Dictionary else {}

static func approach_threshold(thresholds: Dictionary, approach_id: String) -> Dictionary:
	var apps: Dictionary = thresholds.get("approaches", {})
	var key := String(approach_id).strip_edges().to_lower()
	return apps.get(key, {}) if apps is Dictionary else {}

static func per_cost(metric_cfg: Dictionary, cost: int, default_value := 0.0):
	if metric_cfg == null:
		return default_value
	var pc: Dictionary = metric_cfg.get("per_cost", {})
	if not (pc is Dictionary):
		return default_value
	var key := str(cost)
	if pc.has(key):
		return pc.get(key)
	# Fallback to nearest available numeric key if any
	var best_key := ""
	var best_dist: float = INF
	for k in pc.keys():
		var s := String(k)
		if not s.is_valid_int():
			continue
		var v: int = int(s)
		var d: int = abs(v - int(cost))
		if d < best_dist:
			best_dist = d
			best_key = s
	return pc.get(best_key, default_value)

static func resolve_min_threshold(metric_cfg: Dictionary, cost: int, scenario: String = "neutral") -> float:
	var base_v: float = 0.0
	if metric_cfg.has("min_by_cost") and (metric_cfg.get("min_by_cost") is Dictionary):
		var m: Dictionary = metric_cfg.get("min_by_cost", {})
		var key := str(cost)
		base_v = float(m.get(key, m.get(str(int(cost)), 0.0)))
	else:
		base_v = float(per_cost(metric_cfg, cost, 0.0))
	var relax: Dictionary = metric_cfg.get("relaxations", {})
	if relax is Dictionary and relax.has(scenario):
		var r: Dictionary = relax.get(scenario, {})
		var out: float = base_v
		if r.has("multiplier"):
			out = base_v * float(r.get("multiplier", 1.0))
		if r.has("offset"):
			out += float(r.get("offset", 0.0))
		if r.has("floor"):
			out = max(float(r.get("floor", out)), out)
		if r.has("min_value"):
			out = max(float(r.get("min_value", out)), out)
		return out
	return base_v

static func resolve_max_threshold(metric_cfg: Dictionary, cost: int, scenario: String = "neutral") -> float:
	var base_v: float = 0.0
	if metric_cfg.has("max_by_cost") and (metric_cfg.get("max_by_cost") is Dictionary):
		var m: Dictionary = metric_cfg.get("max_by_cost", {})
		var key := str(cost)
		base_v = float(m.get(key, m.get(str(int(cost)), 0.0)))
	else:
		base_v = float(per_cost(metric_cfg, cost, 0.0))
	var relax: Dictionary = metric_cfg.get("relaxations", {})
	if relax is Dictionary and relax.has(scenario):
		var r: Dictionary = relax.get(scenario, {})
		# Prefer explicit max_* overrides when present
		if r.has("max_time_s"):
			return float(r.get("max_time_s", base_v))
		if r.has("max_value"):
			return float(r.get("max_value", base_v))
		var out: float = base_v
		if r.has("multiplier"):
			out = base_v * float(r.get("multiplier", 1.0))
		if r.has("offset"):
			out += float(r.get("offset", 0.0))
		if r.has("ceil"):
			out = min(float(r.get("ceil", out)), out)
		return out
	return base_v

# Returns a tolerance to apply for a metric config; falls back to schema default or a constant
static func resolve_tolerance(thresholds_root: Dictionary, metric_cfg: Dictionary, fallback: float = DEFAULT_TOLERANCE) -> float:
	if metric_cfg != null and metric_cfg.has("tolerance"):
		var tv = metric_cfg.get("tolerance")
		if typeof(tv) == TYPE_FLOAT or typeof(tv) == TYPE_INT:
			return float(tv)
	if thresholds_root != null:
		var schema: Dictionary = thresholds_root.get("schema", {}) if thresholds_root is Dictionary else {}
		if schema is Dictionary and schema.has("default_tolerance"):
			var dv = schema.get("default_tolerance")
			if typeof(dv) == TYPE_FLOAT or typeof(dv) == TYPE_INT:
				return float(dv)
	return fallback

# Evaluate a simple min/max band with tolerance. Returns a Dictionary:
# { ok: bool, lean_low: bool, lean_high: bool, over_max: bool, min: float|null, max: float|null }
static func eval_min_max(v: float, min_v: Variant, max_v: Variant, tol: float) -> Dictionary:
	var have_min := (typeof(min_v) == TYPE_FLOAT or typeof(min_v) == TYPE_INT)
	var have_max := (typeof(max_v) == TYPE_FLOAT or typeof(max_v) == TYPE_INT)
	var lo_ok := true
	var hi_ok := true
	var lean_low := false
	var lean_high := false
	if have_min:
		var mn := float(min_v)
		if v < mn * (1.0 - tol):
			lo_ok = false
		elif v < mn:
			lean_low = true
	if have_max:
		var mx := float(max_v)
		if v > mx * (1.0 + tol):
			hi_ok = false
		elif v > mx:
			lean_high = true
	var min_value: Variant = null
	if have_min:
		min_value = float(min_v)
	var max_value: Variant = null
	if have_max:
		max_value = float(max_v)
	return {
		"ok": (lo_ok and hi_ok and (not lean_low) and (not lean_high)),
		"lean_low": lean_low and (not have_max or v <= float(max_v) * (1.0 + tol)),
		"lean_high": lean_high and (not have_min or v >= float(min_v) * (1.0 - tol)),
		"over_max": have_max and (v > float(max_v) * (1.0 + tol)),
		"min": min_value,
		"max": max_value
	}

# ------------------------ K-of-N ----------------------------------------

static func k_of_n(passes: Array, k_required: int, n_total: int) -> Dictionary:
	var n: int = max(0, int(n_total))
	var k: int = clamp(int(k_required), 0, n)
	var true_count := 0
	for v in passes:
		if bool(v):
			true_count += 1
	return {
		"k": k,
		"n": n,
		"true_count": true_count,
		"pass": (true_count >= k)
	}

static func k_of_n_from_bools(passes: Array[bool], k_required: int) -> Dictionary:
	var n := passes.size()
	return k_of_n(passes, k_required, n)

# ------------------------ Stats & Z-scores -------------------------------

static func mean(arr: Array) -> float:
	if arr == null or arr.is_empty():
		return 0.0
	var s := 0.0
	var c := 0
	for v in arr:
		s += float(v)
		c += 1
	return (s / max(1.0, float(c)))

static func variance(arr: Array, mu: float = NAN) -> float:
	if arr == null or arr.is_empty():
		return 0.0
	var m: float = mu if is_finite(mu) else mean(arr)
	var acc := 0.0
	var c := 0
	for v in arr:
		var d := float(v) - m
		acc += d * d
		c += 1
	return (acc / max(1.0, float(c)))

static func stddev(arr: Array, mu: float = NAN) -> float:
	return sqrt(max(0.0, variance(arr, mu)))

static func median(arr: Array) -> float:
	if arr == null or arr.is_empty():
		return 0.0
	var tmp: Array = []
	for v in arr:
		tmp.append(float(v))
	tmp.sort()
	var n := tmp.size()
	var mid := int(float(n) * 0.5)
	if n % 2 == 1:
		return float(tmp[mid])
	return 0.5 * (float(tmp[mid - 1]) + float(tmp[mid]))

static func z_from_band(value: float, band_values: Array) -> float:
	if band_values == null or band_values.is_empty():
		return 0.0
	var m := mean(band_values)
	var sd := stddev(band_values, m)
	if sd <= EPS:
		return 0.0
	return (float(value) - m) / sd

static func multiplier_vs_median(value: float, med: float) -> float:
	var v := float(value)
	var m := float(med)
	if abs(m) <= EPS:
		if abs(v) <= EPS:
			return 1.0
		return INF
	return v / m

# ------------------------ Safe getters ----------------------------------

static func has_nested(obj, path: Array) -> bool:
	var cur = obj
	for p in path:
		if not (cur is Dictionary):
			return false
		var key := String(p)
		if not cur.has(key):
			return false
		cur = cur[key]
	return true

static func get_nested(obj, path: Array, default_value = null):
	var cur = obj
	for p in path:
		if not (cur is Dictionary):
			return default_value
		var key := String(p)
		if not cur.has(key):
			return default_value
		cur = cur[key]
	return cur

static func safe_float(d: Dictionary, key: String, def: float = 0.0) -> float:
	if d == null:
		return def
	if not d.has(key):
		return def
	var v = d.get(key)
	if v is float:
		return float(v)
	if v is int:
		return float(int(v))
	var s := str(v)
	if s.is_valid_float():
		return float(s)
	if s.is_valid_int():
		return float(int(s))
	return def

static func safe_int(d: Dictionary, key: String, def: int = 0) -> int:
	if d == null:
		return def
	if not d.has(key):
		return def
	var v = d.get(key)
	if v is int:
		return int(v)
	if v is float:
		return int(round(float(v)))
	var s := str(v)
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return int(round(float(s)))
	return def

static func safe_array(d: Dictionary, key: String) -> Array:
	if d == null:
		return []
	var v = d.get(key)
	return (v as Array) if (v is Array) else []

static func safe_dict(d: Dictionary, key: String) -> Dictionary:
	if d == null:
		return {}
	var v = d.get(key)
	return (v as Dictionary) if (v is Dictionary) else {}

# ------------------------ Capability checks -----------------------------

static func normalize_caps(caps) -> PackedStringArray:
	return TelemetryCapabilities.normalize(caps)

static func check_caps(available_caps, required_caps) -> Dictionary:
	var have := {}
	for c in normalize_caps(available_caps):
		have[String(c)] = true
	var missing: Array = []
	var req: Array = []
	if required_caps is Array or required_caps is PackedStringArray:
		for r in required_caps:
			var s := String(r).strip_edges().to_lower()
			if s == "":
				continue
			req.append(s)
	elif typeof(required_caps) == TYPE_STRING:
		req = [String(required_caps).strip_edges().to_lower()]
	for need in req:
		if not have.has(need):
			missing.append(need)
	return {"ok": missing.is_empty(), "missing": missing}

# ------------------------ Result & spans --------------------------------

static func span(label: String, value, want: Variant = null, ok: Variant = null, extra: Dictionary = {}) -> Dictionary:
	var d := {
		"label": String(label),
		"value": value
	}
	if want != null:
		d["want"] = want
	if ok != null:
		d["ok"] = bool(ok)
	# merge extras
	if extra is Dictionary:
		for k in extra.keys():
			d[k] = extra[k]
	return d

static func append_span(spans: Array, label: String, value, want: Variant = null, ok: Variant = null, extra: Dictionary = {}) -> void:
	if spans == null:
		return
	spans.append(span(label, value, want, ok, extra))

static func make_result(pass_flag: bool, spans: Array = [], messages: Array = []) -> Dictionary:
	var msg := ""
	if messages is Array and messages.size() > 0:
		var parts: Array[String] = []
		for m in messages:
			parts.append(String(m))
		msg = "; ".join(parts)
	return {"pass": bool(pass_flag), "spans": (spans if spans is Array else []), "message": msg}

static func pass_result(spans: Array = [], messages: Array = []) -> Dictionary:
	return make_result(true, spans, messages)

static func fail_result(spans: Array = [], messages: Array = []) -> Dictionary:
	return make_result(false, spans, messages)

# ------------------------ Misc helpers ----------------------------------

static func fraction(numer: float, denom: float) -> float:
	var d := float(denom)
	if abs(d) <= EPS:
		return 0.0
	return float(numer) / d

static func clamp01(v: float) -> float:
	return clamp(v, 0.0, 1.0)

static func bool_to_int(b: bool) -> int:
	return (1 if b else 0)

# ------------------------ Subject filter --------------------------------

# Normalize and build a set from payload.subject_unit_ids for quick membership checks.
# Semantics: if the set is empty, filtering is disabled and all units are considered.
static func subject_set_from_payload(payload: Dictionary) -> Dictionary:
	var subject_ids: Dictionary = {}
	if not (payload is Dictionary):
		return subject_ids
	var ids = (payload as Dictionary).get("subject_unit_ids", [])
	var arr: Array = []
	if ids is Array:
		arr = ids
	elif ids is PackedStringArray:
		for v in (ids as PackedStringArray):
			arr.append(v)
	elif typeof(ids) == TYPE_STRING:
		arr = [String(ids)]
	for v2 in arr:
		var s := String(v2).strip_edges()
		if s == "":
			continue
		subject_ids[s] = true
	return subject_ids

# Returns true when filtering is disabled or when uid is in the subject set.
static func subject_included(uid: String, subject_set: Dictionary) -> bool:
	if subject_set == null or (subject_set is Dictionary and (subject_set as Dictionary).is_empty()):
		return true
	return (subject_set as Dictionary).has(String(uid))

# ------------------------ Identity resolution ---------------------------

# Resolves the assigned identity for a unit id via UnitFactory with simple caching.
# Returns Dictionary: { unit_id, primary_role, primary_goal, approaches, cost, level }
static func get_identity(unit_id: String) -> Dictionary:
	var uid := String(unit_id).strip_edges()
	if uid == "":
		return {}
	if _identity_cache.has(uid):
		return _identity_cache.get(uid, {})
	var u = UnitFactory.spawn(uid)
	if u == null:
		return {}
	var out := {
		"unit_id": uid,
		"primary_role": String(u.get_primary_role()),
		"primary_goal": String(u.get_primary_goal()),
		"approaches": u.get_approaches(),
		"cost": int(u.cost),
		"level": int(u.level)
	}
	_identity_cache[uid] = out
	return out

static func clear_identity_cache() -> void:
	_identity_cache.clear()

# Build standardized per-unit extras for spans.
# Keys: { subject_side, unit_id, subject_role, reason }
static func subject_extras(subject_side: String, unit_id: String, reason: String = "") -> Dictionary:
	var uid := String(unit_id)
	var ident: Dictionary = get_identity(uid)
	return {
		"subject_side": String(subject_side),
		"unit_id": uid,
		"subject_role": String(ident.get("primary_role", "")),
		"reason": String(reason)
	}

# Lightweight checker for kernel support flags in aggregates.kernels.
static func kernel_supported(kernels: Dictionary, kernel_key: String) -> bool:
	if not (kernels is Dictionary):
		return false
	var block = (kernels as Dictionary).get(kernel_key, {})
	if not (block is Dictionary):
		return false
	return bool((block as Dictionary).get("supported", false))
