extends RefCounted

# Approach: lockdown (per-unit subject)
# Pass condition: subject contributes enough CC duration or events against
# priority targets.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_lockdown"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["cc"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "lockdown: subject CC seconds or events on priority targets."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "lockdown")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var seconds_cfg: Dictionary = metrics_cfg.get("lockdown_seconds_on_priority", {})
	var events_cfg: Dictionary = metrics_cfg.get("lockdown_events_on_priority", {})
	var cleanse_cfg: Dictionary = metrics_cfg.get("cleanse_pressure", {})
	var tenacity_cfg: Dictionary = metrics_cfg.get("tenacity_tax_s", {})
	var seconds_req: float = RoleCommon.resolve_min_threshold(seconds_cfg, cost_band, scenario_label)
	var events_req: float = RoleCommon.resolve_min_threshold(events_cfg, cost_band, scenario_label)
	var cleanse_req: float = RoleCommon.resolve_min_threshold(cleanse_cfg, cost_band, scenario_label)
	var tenacity_req: float = RoleCommon.resolve_min_threshold(tenacity_cfg, cost_band, scenario_label)
	if seconds_req <= 0.0:
		seconds_req = 1.0
	if events_req <= 0.0:
		events_req = 1.0
	if cleanse_req <= 0.0:
		cleanse_req = 1.0
	if tenacity_req <= 0.0:
		tenacity_req = 0.25

	var total_seconds: float = 0.0
	var total_events: int = 0
	var cleanse_pressure: int = 0
	var tenacity_tax_s: float = 0.0
	var scenario_counterplay: Dictionary = {}
	var considered: int = 0
	var kernel_missing: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		considered += 1
		var counterplay_rec: Dictionary = _subject_counterplay_pressure(entry, side, subject_id)
		cleanse_pressure += int(counterplay_rec.get("cleanse_pressure_events", 0))
		tenacity_tax_s += float(counterplay_rec.get("tenacity_tax_s", 0.0))
		tenacity_tax_s += float(counterplay_rec.get("cc_prevented_by_immunity", 0))
		_bump_scenario_counterplay(scenario_counterplay, _scenario_for_entry(entry, scenario_label), counterplay_rec)
		var kernels: Dictionary = entry.get("kernels", {})
		var lockdown: Dictionary = kernels.get("lockdown", {}) if (kernels is Dictionary) else {}
		if not (lockdown is Dictionary) or lockdown.is_empty():
			kernel_missing += 1
			continue
		var side_block: Dictionary = lockdown.get(side, {})
		var per_unit: Dictionary = side_block.get("per_unit", {}) if (side_block is Dictionary) else {}
		if not (per_unit is Dictionary):
			continue
		var rec: Dictionary = per_unit.get(subject_id, {})
		if not (rec is Dictionary) or rec.is_empty():
			continue
		total_seconds += float(rec.get("seconds_on_priority", 0.0))
		total_events += int(rec.get("events", 0))

	var seconds_pass: bool = considered > 0 and total_seconds >= seconds_req
	var events_pass: bool = considered > 0 and float(total_events) >= events_req
	var cleanse_pass: bool = considered > 0 and float(cleanse_pressure) >= cleanse_req
	var tenacity_pass: bool = considered > 0 and tenacity_tax_s >= tenacity_req
	var pass_flag: bool = seconds_pass or events_pass or cleanse_pass or tenacity_pass
	var direct_lockdown_pass: bool = seconds_pass or events_pass
	var reason: String = ""
	if considered <= 0:
		reason = "no_samples"
	elif kernel_missing >= considered and not cleanse_pass and not tenacity_pass:
		reason = "kernel_unsupported"

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["kernel_missing"] = kernel_missing
	var cleanse_extra: Dictionary = extras.duplicate()
	var cleanse_ok: Variant = cleanse_pass
	if pass_flag and direct_lockdown_pass and not cleanse_pass:
		cleanse_ok = null
		cleanse_extra["reason"] = "alternate_lockdown_evidence_satisfied"
	var tenacity_extra: Dictionary = extras.duplicate()
	var tenacity_ok: Variant = tenacity_pass
	if pass_flag and direct_lockdown_pass and not tenacity_pass:
		tenacity_ok = null
		tenacity_extra["reason"] = "alternate_lockdown_evidence_satisfied"
	RoleCommon.append_span(spans, "subject_lockdown_seconds_on_priority", total_seconds, seconds_req, seconds_pass, extras)
	RoleCommon.append_span(spans, "subject_lockdown_events_on_priority", total_events, events_req, events_pass, extras)
	RoleCommon.append_span(spans, "subject_lockdown_cleanse_pressure", cleanse_pressure, cleanse_req, cleanse_ok, cleanse_extra)
	RoleCommon.append_span(spans, "subject_lockdown_tenacity_tax_s", tenacity_tax_s, tenacity_req, tenacity_ok, tenacity_extra)
	var cleanse_delta: Dictionary = _scenario_delta(scenario_counterplay, "cleanse_pressure_events", PackedStringArray(["cleanse", "counter"]))
	if not cleanse_delta.is_empty():
		var cleanse_delta_value: float = float(cleanse_delta.get("delta", 0.0))
		var cleanse_delta_pass: bool = cleanse_delta_value >= cleanse_req
		var cleanse_delta_extras: Dictionary = extras.duplicate(true)
		cleanse_delta_extras["reason"] = "scenario_cleanse_delta"
		cleanse_delta_extras["baseline_scenario"] = String(cleanse_delta.get("baseline", ""))
		cleanse_delta_extras["counter_scenario"] = String(cleanse_delta.get("counter", ""))
		var cleanse_delta_ok: Variant = cleanse_delta_pass
		if pass_flag and direct_lockdown_pass and not cleanse_delta_pass:
			cleanse_delta_ok = null
			cleanse_delta_extras["reason"] = "alternate_lockdown_evidence_satisfied"
		RoleCommon.append_span(spans, "subject_lockdown_cleanse_scenario_delta", cleanse_delta_value, cleanse_req, cleanse_delta_ok, cleanse_delta_extras)
		pass_flag = pass_flag or cleanse_delta_pass
	var tenacity_delta: Dictionary = _scenario_delta(scenario_counterplay, "tenacity_tax_s", PackedStringArray(["tenacity", "high_tenacity", "counter"]))
	if not tenacity_delta.is_empty():
		var tenacity_delta_value: float = float(tenacity_delta.get("delta", 0.0))
		var tenacity_delta_pass: bool = tenacity_delta_value >= tenacity_req
		var tenacity_delta_extras: Dictionary = extras.duplicate(true)
		tenacity_delta_extras["reason"] = "scenario_high_tenacity_delta"
		tenacity_delta_extras["baseline_scenario"] = String(tenacity_delta.get("baseline", ""))
		tenacity_delta_extras["counter_scenario"] = String(tenacity_delta.get("counter", ""))
		var tenacity_delta_ok: Variant = tenacity_delta_pass
		if pass_flag and direct_lockdown_pass and not tenacity_delta_pass:
			tenacity_delta_ok = null
			tenacity_delta_extras["reason"] = "alternate_lockdown_evidence_satisfied"
		RoleCommon.append_span(spans, "subject_lockdown_high_tenacity_tax_delta_s", tenacity_delta_value, tenacity_req, tenacity_delta_ok, tenacity_delta_extras)
		pass_flag = pass_flag or tenacity_delta_pass
	var effective_drop: Dictionary = _scenario_effective_drop(scenario_counterplay, PackedStringArray(["tenacity", "high_tenacity", "counter"]))
	if not effective_drop.is_empty():
		var effective_drop_value: float = float(effective_drop.get("delta", 0.0))
		var effective_drop_pass: bool = effective_drop_value >= tenacity_req
		var effective_drop_extras: Dictionary = extras.duplicate(true)
		effective_drop_extras["reason"] = "scenario_high_tenacity_effective_drop"
		effective_drop_extras["baseline_scenario"] = String(effective_drop.get("baseline", ""))
		effective_drop_extras["counter_scenario"] = String(effective_drop.get("counter", ""))
		var effective_drop_ok: Variant = effective_drop_pass
		if pass_flag and direct_lockdown_pass and not effective_drop_pass:
			effective_drop_ok = null
			effective_drop_extras["reason"] = "alternate_lockdown_evidence_satisfied"
		RoleCommon.append_span(spans, "subject_lockdown_high_tenacity_effective_drop_s", effective_drop_value, tenacity_req, effective_drop_ok, effective_drop_extras)

	var messages: Array[String] = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("considered=%d" % considered)
	messages.append("events=%d" % total_events)
	messages.append("cleanse_pressure=%d" % cleanse_pressure)
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
	for unit_id_b in team_b:
		if String(unit_id_b) == sid:
			return "b"
	return ""

func _subject_counterplay_pressure(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var pressure: Dictionary = kernels.get("counterplay_pressure", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = pressure.get("per_unit", {}) if (pressure is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

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

func _bump_scenario_counterplay(stats: Dictionary, label: String, rec: Dictionary) -> void:
	if not (rec is Dictionary):
		return
	var scenario_label: String = String(label).strip_edges().to_lower()
	if scenario_label == "":
		scenario_label = "neutral"
	var scenario_rec: Dictionary = stats.get(scenario_label, {})
	scenario_rec["samples"] = int(scenario_rec.get("samples", 0)) + 1
	for field in ["cleanse_pressure_events", "tenacity_tax_s", "cc_raw_duration_s", "cc_effective_duration_s"]:
		scenario_rec[String(field)] = float(scenario_rec.get(String(field), 0.0)) + float(rec.get(String(field), 0.0))
	stats[scenario_label] = scenario_rec

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

func _scenario_effective_drop(stats: Dictionary, counter_tokens: PackedStringArray) -> Dictionary:
	if stats.size() < 2:
		return {}
	var baseline_label: String = _baseline_label(stats)
	var counter_label: String = _counter_label(stats, counter_tokens, baseline_label)
	if baseline_label == "" or counter_label == "":
		return {}
	var baseline_effective: float = _scenario_rate(stats, baseline_label, "cc_effective_duration_s")
	var counter_effective: float = _scenario_rate(stats, counter_label, "cc_effective_duration_s")
	return {
		"baseline": baseline_label,
		"counter": counter_label,
		"baseline_value": baseline_effective,
		"counter_value": counter_effective,
		"delta": baseline_effective - counter_effective
	}

func _baseline_label(stats: Dictionary) -> String:
	if stats.has("neutral"):
		return "neutral"
	for label_value in stats.keys():
		var label: String = String(label_value)
		if not _label_has_token(label, PackedStringArray(["cleanse", "counter", "tenacity", "high_tenacity"])):
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
