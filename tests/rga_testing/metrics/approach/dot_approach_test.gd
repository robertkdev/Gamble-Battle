extends RefCounted

# Approach: dot (per-unit subject)
# Prefers direct damage-over-time tick ownership. Falls back to older proxy
# debuff/proc/damage-shape evidence when rows predate dot tick telemetry.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_dot"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base", "buffs"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "dot: source-owned DoT tick events, tick damage, and touched targets; falls back to proxy debuff/proc/sustained-shape evidence on older rows."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "dot")
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 2, "n": 4})
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var debuff_cfg: Dictionary = metrics_cfg.get("debuff_events", {})
	var proc_cfg: Dictionary = metrics_cfg.get("on_hit_effects", {})
	var ratio_cfg: Dictionary = metrics_cfg.get("late_early_dps_ratio", {})
	var duration_cfg: Dictionary = metrics_cfg.get("dot_uptime_s", metrics_cfg.get("debuff_duration", {}))
	var debuff_req: float = RoleCommon.resolve_min_threshold(debuff_cfg, cost_band, scenario_label)
	var proc_req: float = RoleCommon.resolve_min_threshold(proc_cfg, cost_band, scenario_label)
	var ratio_req: float = RoleCommon.resolve_min_threshold(ratio_cfg, cost_band, scenario_label)
	var duration_req: float = RoleCommon.resolve_min_threshold(duration_cfg, cost_band, scenario_label)
	if debuff_req <= 0.0:
		debuff_req = 1.0
	if proc_req <= 0.0:
		proc_req = 1.0
	if ratio_req <= 0.0:
		ratio_req = 1.0
	if duration_req <= 0.0:
		duration_req = 1.0

	var debuff_events: int = 0
	var on_hit_events: int = 0
	var debuff_duration: float = 0.0
	var dot_tick_supported: bool = false
	var dot_tick_events: int = 0
	var dot_tick_damage: float = 0.0
	var dot_tick_targets: int = 0
	var dot_uptime_s: float = 0.0
	var dot_duration_applied_s: float = 0.0
	var scenario_dot: Dictionary = {}
	var ratio_samples: Array[float] = []
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		considered += 1
		var source_rec: Dictionary = _subject_buff_source(entry, side, subject_id)
		var target_rec: Dictionary = _subject_buff_target(entry, side, subject_id)
		var pattern_rec: Dictionary = _subject_pattern(entry, side, subject_id)
		var counterplay_rec: Dictionary = _subject_counterplay_pressure(entry, side, subject_id)
		dot_tick_supported = _dot_supported(entry) or dot_tick_supported
		dot_tick_events += int(source_rec.get("dot_tick_events", 0))
		dot_tick_damage += float(source_rec.get("dot_tick_damage", 0.0))
		dot_tick_targets += int(source_rec.get("dot_tick_targets", 0))
		dot_uptime_s += float(source_rec.get("dot_uptime_s", 0.0))
		dot_duration_applied_s += float(source_rec.get("dot_duration_applied_s", 0.0))
		debuff_events += int(source_rec.get("enemy_debuffs", 0))
		on_hit_events += int(source_rec.get("on_hit_effects", 0))
		debuff_duration += float(target_rec.get("debuff_duration", 0.0))
		_bump_scenario_dot(scenario_dot, _scenario_for_entry(entry, scenario_label), source_rec, counterplay_rec)
		if not pattern_rec.is_empty() and float(pattern_rec.get("total_damage", 0.0)) > 0.0:
			ratio_samples.append(float(pattern_rec.get("late_early_dps_ratio", 0.0)))

	var ratio_value: float = RoleCommon.median(ratio_samples)
	var spans: Array = []
	var reason: String = "dot_tick_telemetry_missing"
	if considered <= 0:
		reason = "no_samples"
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["direct_tick_supported"] = dot_tick_supported

	if dot_tick_supported:
		var tick_req: float = max(1.0, debuff_req)
		var damage_req: float = max(1.0, proc_req)
		var target_req: float = 1.0
		var tick_pass: bool = considered > 0 and float(dot_tick_events) >= tick_req
		var damage_pass: bool = considered > 0 and dot_tick_damage >= damage_req
		var target_pass: bool = considered > 0 and float(dot_tick_targets) >= target_req
		var uptime_pass: bool = considered > 0 and dot_uptime_s >= duration_req
		var ratio_pass_direct: bool = ratio_samples.size() > 0 and ratio_value >= ratio_req
		var direct_eval: Dictionary = RoleCommon.k_of_n([tick_pass, damage_pass, target_pass, uptime_pass, ratio_pass_direct], int(kcfg.get("k", 2)), int(kcfg.get("n", 5)))
		var direct_pass: bool = bool(direct_eval.get("pass", false))
		if direct_pass:
			extras["reason"] = "direct_dot_tick_telemetry"
		elif considered > 0:
			extras["reason"] = "direct_dot_tick_threshold_miss"
		extras["k_required"] = int(direct_eval.get("k", 2))
		extras["true_count"] = int(direct_eval.get("true_count", 0))
		RoleCommon.append_span(spans, "subject_dot_tick_events", dot_tick_events, tick_req, tick_pass, extras)
		RoleCommon.append_span(spans, "subject_dot_tick_damage", dot_tick_damage, damage_req, damage_pass, extras)
		RoleCommon.append_span(spans, "subject_dot_tick_targets", dot_tick_targets, target_req, target_pass, extras)
		RoleCommon.append_span(spans, "subject_dot_uptime_s", dot_uptime_s, duration_req, uptime_pass, extras)
		RoleCommon.append_span(spans, "subject_dot_duration_applied_s_context", dot_duration_applied_s, duration_req, dot_duration_applied_s >= duration_req, extras)
		RoleCommon.append_span(spans, "subject_dot_late_early_dps_context", ratio_value, ratio_req, ratio_pass_direct, extras)
		_append_anti_dot_delta_spans(spans, extras, scenario_dot, max(1.0, damage_req), max(1.0, duration_req))
		return {
			"id": METRIC_ID,
			"version": VERSION,
			"pass": direct_pass,
			"spans": spans,
			"message": "scenario=%s; considered=%d; direct_dot=1; ticks=%d; damage=%.2f; uptime=%.2f" % [scenario_label, considered, dot_tick_events, dot_tick_damage, dot_uptime_s]
		}

	var debuff_pass: bool = considered > 0 and float(debuff_events) >= debuff_req
	var proc_pass: bool = considered > 0 and float(on_hit_events) >= proc_req
	var ratio_pass: bool = ratio_samples.size() > 0 and ratio_value >= ratio_req
	var duration_pass: bool = considered > 0 and debuff_duration >= duration_req
	var proxy_eval: Dictionary = RoleCommon.k_of_n([debuff_pass, proc_pass, ratio_pass, duration_pass], int(kcfg.get("k", 2)), int(kcfg.get("n", 4)))
	var proxy_pass: bool = bool(proxy_eval.get("pass", false))
	extras["k_required"] = int(proxy_eval.get("k", 2))
	extras["true_count"] = int(proxy_eval.get("true_count", 0))
	RoleCommon.append_span(spans, "subject_dot_debuff_events_proxy", debuff_events, debuff_req, debuff_pass, extras)
	RoleCommon.append_span(spans, "subject_dot_on_hit_proc_proxy", on_hit_events, proc_req, proc_pass, extras)
	RoleCommon.append_span(spans, "subject_dot_late_early_dps_proxy", ratio_value, ratio_req, ratio_pass, extras)
	RoleCommon.append_span(spans, "subject_dot_debuff_duration_proxy", debuff_duration, duration_req, duration_pass, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": proxy_pass,
		"spans": spans,
		"message": "scenario=%s; considered=%d; proxy_dot=1" % [scenario_label, considered]
	}

func _dot_supported(entry: Dictionary) -> bool:
	var kernels: Dictionary = entry.get("kernels", {})
	var buffs: Dictionary = kernels.get("buff_presence", {}) if (kernels is Dictionary) else {}
	return bool(buffs.get("dot_tick_supported", false)) if (buffs is Dictionary) else false

func _subject_pattern(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var patterns: Dictionary = kernels.get("combat_patterns", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = patterns.get("per_unit", {}) if (patterns is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_buff_source(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var buffs: Dictionary = kernels.get("buff_presence", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = buffs.get("per_unit", {}) if (buffs is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_buff_target(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var buffs: Dictionary = kernels.get("buff_presence", {}) if (kernels is Dictionary) else {}
	var target_unit: Dictionary = buffs.get("target_unit", {}) if (buffs is Dictionary) else {}
	var side_map: Dictionary = target_unit.get(side, {}) if (target_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_counterplay_pressure(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var pressure: Dictionary = kernels.get("counterplay_pressure", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = pressure.get("per_unit", {}) if (pressure is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var context: Dictionary = entry.get("context", {})
	var team_a: Array = context.get("team_a_ids", []) if (context is Dictionary) else []
	var team_b: Array = context.get("team_b_ids", []) if (context is Dictionary) else []
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

func _scenario_for_entry(entry: Dictionary, fallback: String) -> String:
	var context: Dictionary = entry.get("context", {}) if (entry is Dictionary) else {}
	var label: String = ""
	if context is Dictionary:
		label = String(context.get("scenario_label", "")).strip_edges().to_lower()
		if label == "":
			var map_params: Dictionary = context.get("map_params", {}) if (context is Dictionary) else {}
			if map_params is Dictionary:
				label = String(map_params.get("scenario_label", "")).strip_edges().to_lower()
	if label == "":
		label = String(fallback).strip_edges().to_lower()
	if label == "":
		label = "neutral"
	return label

func _bump_scenario_dot(stats: Dictionary, label: String, source_rec: Dictionary, counterplay_rec: Dictionary) -> void:
	var scenario_label: String = String(label).strip_edges().to_lower()
	if scenario_label == "":
		scenario_label = "neutral"
	var scenario_rec: Dictionary = stats.get(scenario_label, {})
	scenario_rec["samples"] = int(scenario_rec.get("samples", 0)) + 1
	for field in ["dot_tick_events", "dot_tick_damage", "dot_uptime_s", "dot_duration_applied_s"]:
		scenario_rec[String(field)] = float(scenario_rec.get(String(field), 0.0)) + float(source_rec.get(String(field), 0.0))
	scenario_rec["cleanse_pressure_events"] = float(scenario_rec.get("cleanse_pressure_events", 0.0)) + float(counterplay_rec.get("cleanse_pressure_events", 0))
	stats[scenario_label] = scenario_rec

func _append_anti_dot_delta_spans(spans: Array, extras: Dictionary, scenario_dot: Dictionary, damage_req: float, uptime_req: float) -> void:
	var damage_delta: Dictionary = _scenario_delta(scenario_dot, "dot_tick_damage", PackedStringArray(["anti_dot", "anti-dot", "cleanse", "counter"]))
	if damage_delta.is_empty():
		return
	var baseline_label: String = String(damage_delta.get("baseline", ""))
	var counter_label: String = String(damage_delta.get("counter", ""))
	var damage_drop: float = float(damage_delta.get("baseline_value", 0.0)) - float(damage_delta.get("counter_value", 0.0))
	var events_delta: Dictionary = _scenario_delta(scenario_dot, "dot_tick_events", PackedStringArray(["anti_dot", "anti-dot", "cleanse", "counter"]))
	var uptime_delta: Dictionary = _scenario_delta(scenario_dot, "dot_uptime_s", PackedStringArray(["anti_dot", "anti-dot", "cleanse", "counter"]))
	var cleanse_delta: Dictionary = _scenario_delta(scenario_dot, "cleanse_pressure_events", PackedStringArray(["anti_dot", "anti-dot", "cleanse", "counter"]))
	var events_drop: float = float(events_delta.get("baseline_value", 0.0)) - float(events_delta.get("counter_value", 0.0))
	var uptime_drop: float = float(uptime_delta.get("baseline_value", 0.0)) - float(uptime_delta.get("counter_value", 0.0))
	var cleanse_gain: float = float(cleanse_delta.get("counter_value", 0.0)) - float(cleanse_delta.get("baseline_value", 0.0))
	var delta_extras: Dictionary = extras.duplicate(true)
	delta_extras["reason"] = "scenario_anti_dot_delta"
	delta_extras["baseline_scenario"] = baseline_label
	delta_extras["counter_scenario"] = counter_label
	RoleCommon.append_span(spans, "subject_dot_anti_dot_tick_damage_drop", damage_drop, damage_req, damage_drop >= damage_req, delta_extras)
	RoleCommon.append_span(spans, "subject_dot_anti_dot_tick_event_drop", events_drop, 1.0, events_drop >= 1.0, delta_extras)
	RoleCommon.append_span(spans, "subject_dot_anti_dot_uptime_drop_s", uptime_drop, uptime_req, uptime_drop >= uptime_req, delta_extras)
	RoleCommon.append_span(spans, "subject_dot_anti_dot_cleanse_pressure_delta", cleanse_gain, 1.0, cleanse_gain >= 1.0, delta_extras)

func _scenario_delta(stats: Dictionary, field: String, counter_tokens: PackedStringArray) -> Dictionary:
	if stats.size() < 2:
		return {}
	var baseline_label: String = _baseline_label(stats)
	var counter_label: String = _counter_label(stats, counter_tokens, baseline_label)
	if baseline_label == "" or counter_label == "":
		return {}
	var baseline_value: float = _scenario_rate(stats, baseline_label, field)
	var counter_value: float = _scenario_rate(stats, counter_label, field)
	return {
		"baseline": baseline_label,
		"counter": counter_label,
		"baseline_value": baseline_value,
		"counter_value": counter_value,
		"delta": counter_value - baseline_value
	}

func _baseline_label(stats: Dictionary) -> String:
	if stats.has("neutral"):
		return "neutral"
	for label_value in stats.keys():
		var label: String = String(label_value)
		if not _label_has_token(label, PackedStringArray(["anti_dot", "anti-dot", "cleanse", "counter"])):
			return label
	return ""

func _counter_label(stats: Dictionary, tokens: PackedStringArray, baseline_label: String) -> String:
	for label_value in stats.keys():
		var label: String = String(label_value)
		if label == baseline_label:
			continue
		if _label_has_token(label, tokens):
			return label
	return ""

func _label_has_token(label: String, tokens: PackedStringArray) -> bool:
	var low_label: String = String(label).strip_edges().to_lower()
	for token_value in tokens:
		var token: String = String(token_value).strip_edges().to_lower()
		if token != "" and low_label.find(token) >= 0:
			return true
	return false

func _scenario_rate(stats: Dictionary, label: String, field: String) -> float:
	var rec: Dictionary = stats.get(label, {})
	var samples: float = max(1.0, float(rec.get("samples", 0)))
	return float(rec.get(field, 0.0)) / samples
