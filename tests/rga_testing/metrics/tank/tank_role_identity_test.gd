extends RefCounted

# Tank Role Identity Test (per-unit)
# Pass condition (per unit): 2-of-2
#  - soak_index(unit) >= threshold, where soak_index = (mitigated + shield) / incoming
#  - focus_survival_s(unit) >= threshold, falling back to time_alive_s when focus kernels are unavailable
# Overall metric passes if any unit on side A or B passes both conditions.
# Thresholds source: roles_thresholds.json (per-cost; scenario relaxations applied)

const VERSION := "1.0.0"
const METRIC_ID := "role_tank_identity"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

# Require only base capabilities for this metric; it will opportunistically
# use focus kernels if present, otherwise it falls back to time_alive_s.
const REQUIRED_CAPS = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "Tank identity via soak_index and focus_survival_s (fallback to time_alive)."
	}

func run_metric(payload: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = payload.get("context", {})
	# Subject filter (optional): when provided, metrics should only consider these unit_ids
	var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)
	var has_subjects := (subject_set is Dictionary and not (subject_set as Dictionary).is_empty())
	# Expect RoleMetricsContextBuilder.build() shape
	var sims: Dictionary = ctx.get("sims", {}) if ctx is Dictionary else {}
	if sims.is_empty():
		return RoleCommon.fail_result([], ["no_sims_in_context"])

	# Load thresholds for tank
	var thresholds_all: Dictionary = RoleCommon.load_thresholds()
	var tank_cfg: Dictionary = RoleCommon.role_threshold(thresholds_all, "tank")
	var metrics_cfg: Dictionary = tank_cfg.get("metrics", {})
	var soak_cfg: Dictionary = metrics_cfg.get("soak_index", {})
	var focus_cfg: Dictionary = metrics_cfg.get("focus_survival_s", {})
	var time_alive_cfg: Dictionary = tank_cfg.get("fallback", {}).get("time_alive_s", {})

	# Scenario hint (neutral|counter|unknown)
	var scenario_label := String(ctx.get("scenario", "neutral"))

	var fallback_cost_band: int = 3

	# Per-unit accumulators across sims, keyed by unit_id per side
	var per_unit = {
		"a": {}, # uid -> { incoming: float, soaked: float, tl_sum: float, tl_n: int, f_sum: float, f_n: int }
		"b": {}
	}

	# Walk sims and collect base aggregates and kernel-derived focus
	var focus_supported_any: bool = false
	for sim_idx in sims.keys():
		var entry: Dictionary = sims.get(sim_idx, {})
		if not (entry is Dictionary):
			continue
		var units: Dictionary = entry.get("units", {})
		var kernels: Dictionary = entry.get("kernels", {})

		# Per-unit base aggregates
		for side in ["a", "b"]:
			var arr: Array = units.get(side, [])
			if not (arr is Array):
				continue
			for u in arr:
				if not (u is Dictionary):
					continue
				var uid := String(u.get("unit_id", ""))
				if uid == "":
					continue
				# Inclusion policy: if subject filter present, honor it; otherwise restrict to primary_role == tank
				var include := false
				if has_subjects:
					include = RoleCommon.subject_included(uid, subject_set)
				else:
					var ident := RoleCommon.get_identity(uid)
					include = (String(ident.get("primary_role", "")).strip_edges().to_lower() == "tank")
				if not include:
					continue
				var bucket: Dictionary = (per_unit[side] as Dictionary).get(uid, {"incoming": 0.0, "soaked": 0.0, "tl_sum": 0.0, "tl_n": 0, "f_sum": 0.0, "f_n": 0})
				bucket["incoming"] = float(bucket.get("incoming", 0.0)) + float(u.get("incoming", 0.0))
				var soaked_now: float = float(u.get("mitigated", 0.0)) + float(u.get("shield", 0.0))
				bucket["soaked"] = float(bucket.get("soaked", 0.0)) + soaked_now
				bucket["tl_sum"] = float(bucket.get("tl_sum", 0.0)) + float(u.get("time_alive_s", 0.0))
				bucket["tl_n"] = int(bucket.get("tl_n", 0)) + 1
				(per_unit[side] as Dictionary)[uid] = bucket

		var focus: Dictionary = kernels.get("focus_survival", {})
		if focus is Dictionary and bool(focus.get("supported", false)):
			var per_focus: Dictionary = focus.get("focus_survival_per_unit", {})
			for side2 in ["a", "b"]:
				var side_focus: Dictionary = per_focus.get(side2, {})
				if not (side_focus is Dictionary):
					continue
				for uid2 in side_focus.keys():
					var uid2s: String = String(uid2)
					if uid2s == "":
						continue
					var include2: bool = false
					if has_subjects:
						include2 = RoleCommon.subject_included(uid2s, subject_set)
					else:
						var ident2: Dictionary = RoleCommon.get_identity(uid2s)
						include2 = (String(ident2.get("primary_role", "")).strip_edges().to_lower() == "tank")
					if not include2:
						continue
					var bucket2: Dictionary = (per_unit[side2] as Dictionary).get(uid2s, {"incoming": 0.0, "soaked": 0.0, "tl_sum": 0.0, "tl_n": 0, "f_sum": 0.0, "f_n": 0})
					bucket2["f_sum"] = float(bucket2.get("f_sum", 0.0)) + _focus_survival_seconds(side_focus.get(uid2, 0.0))
					bucket2["f_n"] = int(bucket2.get("f_n", 0)) + 1
					(per_unit[side2] as Dictionary)[uid2s] = bucket2
					focus_supported_any = true

	# Evaluate per-unit conditions and count passers per side
	var spans: Array = []
	var side_pass: Dictionary = {"a": false, "b": false}
	for side3 in ["a", "b"]:
		var pass_count := 0
		var pu: Dictionary = per_unit.get(side3, {})
		if pu is Dictionary:
			for uid in pu.keys():
				var rec: Dictionary = pu.get(uid, {})
				# Guard again to avoid accidental inclusion if map was pre-populated
				var uid3 := String(uid)
				var include3 := false
				if has_subjects:
					include3 = RoleCommon.subject_included(uid3, subject_set)
				else:
					var ident3 := RoleCommon.get_identity(uid3)
					include3 = (String(ident3.get("primary_role", "")).strip_edges().to_lower() == "tank")
				if not include3:
					continue
				var ident4: Dictionary = RoleCommon.get_identity(uid3)
				var cost_band: int = int(ident4.get("cost", fallback_cost_band))
				if cost_band <= 0:
					cost_band = fallback_cost_band
				var soak_min: float = float(RoleCommon.resolve_min_threshold(soak_cfg, cost_band, scenario_label))
				var focus_min: float = float(RoleCommon.resolve_min_threshold(focus_cfg, cost_band, scenario_label))
				var time_alive_min: float = float(RoleCommon.resolve_min_threshold(time_alive_cfg, cost_band, scenario_label))
				var inc: float = float(rec.get("incoming", 0.0))
				var soaked2: float = float(rec.get("soaked", 0.0))
				var soak_idx_u: float = (soaked2 / inc) if inc > 0.0 else 0.0
				var tl_n: int = int(rec.get("tl_n", 0))
				var tl_avg: float = (float(rec.get("tl_sum", 0.0)) / max(1.0, float(tl_n)))
				var cond_soak_u := (soak_idx_u >= soak_min)
				var f_n: int = int(rec.get("f_n", 0))
				var focus_avg: float = (float(rec.get("f_sum", 0.0)) / max(1.0, float(f_n)))
				var cond_focus_u: bool = false
				var reason_str: String = "focus_survival_s"
				if focus_supported_any and f_n > 0:
					cond_focus_u = focus_avg >= focus_min
				else:
					cond_focus_u = tl_avg >= time_alive_min
					reason_str = "time_alive_s"
				var extras := RoleCommon.subject_extras(side3, String(uid), reason_str)
				extras["soak_index"] = soak_idx_u
				extras["time_alive_avg_s"] = tl_avg
				var focus_avg_value: Variant = null
				if focus_supported_any and f_n > 0:
					focus_avg_value = focus_avg
				extras["focus_survival_avg_s"] = focus_avg_value
				# Requirements and booleans for clearer reporting
				extras["req_soak_min"] = soak_min
				extras["req_focus_s"] = focus_min
				extras["req_time_alive_s"] = time_alive_min
				extras["focus_supported"] = focus_supported_any
				extras["soak_ok"] = cond_soak_u
				extras["survivability_ok"] = cond_focus_u
				if cond_soak_u and cond_focus_u:
					pass_count += 1
					RoleCommon.append_span(spans, "unit_pass", 1, 1, true, extras)
				else:
					# Emit a failing per-unit span with details so callers can see why
					RoleCommon.append_span(spans, "unit_pass", 0, 1, false, extras)
		side_pass[side3] = (pass_count > 0)
		RoleCommon.append_span(spans, "%s_unit_pass_count" % side3, pass_count, 1, side_pass[side3])

	var pass_flag := bool(side_pass["a"]) or bool(side_pass["b"])
	var messages: Array = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("a_pass=%s" % ("true" if side_pass["a"] else "false"))
	messages.append("b_pass=%s" % ("true" if side_pass["b"] else "false"))

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "; ".join(messages)
	}

func _focus_survival_seconds(raw: Variant) -> float:
	if raw == null:
		return 0.0
	if raw is Dictionary:
		var avg_s: Variant = (raw as Dictionary).get("avg_s", 0.0)
		return 0.0 if avg_s == null else float(avg_s)
	return float(raw)
