extends RefCounted

# Approach: debuff (per-unit subject)
# Pass condition: subject applies negative effects or stat reductions to enemies.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_debuff"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["buffs"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "debuff: subject applies enemy stat reductions or negative tagged effects."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "debuff")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var enemy_cfg: Dictionary = metrics_cfg.get("enemy_debuffs", {})
	var magnitude_cfg: Dictionary = metrics_cfg.get("debuff_magnitude", {})
	var cleanse_cfg: Dictionary = metrics_cfg.get("cleanse_pressure", {})
	var bait_cfg: Dictionary = metrics_cfg.get("cleanse_bait_rate", {})
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var cost_band: int = int(ident.get("cost", 3))
	var enemy_req: float = RoleCommon.resolve_min_threshold(enemy_cfg, cost_band, scenario_label)
	var magnitude_req: float = RoleCommon.resolve_min_threshold(magnitude_cfg, cost_band, scenario_label)
	var cleanse_req: float = RoleCommon.resolve_min_threshold(cleanse_cfg, cost_band, scenario_label)
	var bait_req: float = RoleCommon.resolve_min_threshold(bait_cfg, cost_band, scenario_label)
	if enemy_req <= 0.0:
		enemy_req = 1.0
	if magnitude_req <= 0.0:
		magnitude_req = 1.0
	if cleanse_req <= 0.0:
		cleanse_req = 1.0
	if bait_req <= 0.0:
		bait_req = 0.25

	var enemy_debuffs: int = 0
	var debuff_magnitude: float = 0.0
	var cleanse_pressure: int = 0
	var cleanse_bait_rate: float = 0.0
	var scenario_counterplay: Dictionary = {}
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var rec: Dictionary = _subject_buff_source(entry, subject_id)
		var counterplay_rec: Dictionary = _subject_counterplay_pressure(entry, subject_id)
		var sim_label: String = _scenario_for_entry(entry, scenario_label)
		if rec.is_empty():
			if _subject_side(entry, subject_id) != "":
				considered += 1
				cleanse_pressure += int(counterplay_rec.get("cleanse_pressure_events", 0))
				cleanse_bait_rate = max(cleanse_bait_rate, float(counterplay_rec.get("cleanse_bait_rate", 0.0)))
				_bump_scenario_counterplay(scenario_counterplay, sim_label, counterplay_rec)
			continue
		considered += 1
		enemy_debuffs += int(rec.get("enemy_debuffs", 0))
		debuff_magnitude += float(rec.get("debuff_magnitude", 0.0))
		cleanse_pressure += int(counterplay_rec.get("cleanse_pressure_events", 0))
		cleanse_bait_rate = max(cleanse_bait_rate, float(counterplay_rec.get("cleanse_bait_rate", 0.0)))
		_bump_scenario_counterplay(scenario_counterplay, sim_label, counterplay_rec)

	var enemy_pass: bool = considered > 0 and float(enemy_debuffs) >= enemy_req
	var magnitude_pass: bool = considered > 0 and debuff_magnitude >= magnitude_req
	var cleanse_pass: bool = considered > 0 and float(cleanse_pressure) >= cleanse_req
	var bait_pass: bool = considered > 0 and cleanse_bait_rate >= bait_req
	var pass_flag: bool = enemy_pass or magnitude_pass or cleanse_pass or bait_pass
	var direct_debuff_pass: bool = enemy_pass or magnitude_pass
	var reason: String = "no_samples" if considered <= 0 else ""
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	var cleanse_extra: Dictionary = extras.duplicate()
	var cleanse_ok: Variant = cleanse_pass
	if pass_flag and direct_debuff_pass and not cleanse_pass:
		cleanse_ok = null
		cleanse_extra["reason"] = "alternate_debuff_evidence_satisfied"
	var bait_extra: Dictionary = extras.duplicate()
	var bait_ok: Variant = bait_pass
	if pass_flag and direct_debuff_pass and not bait_pass:
		bait_ok = null
		bait_extra["reason"] = "alternate_debuff_evidence_satisfied"
	RoleCommon.append_span(spans, "subject_debuff_enemy_events", enemy_debuffs, enemy_req, enemy_pass, extras)
	RoleCommon.append_span(spans, "subject_debuff_magnitude", debuff_magnitude, magnitude_req, magnitude_pass, extras)
	RoleCommon.append_span(spans, "subject_debuff_cleanse_pressure", cleanse_pressure, cleanse_req, cleanse_ok, cleanse_extra)
	RoleCommon.append_span(spans, "subject_debuff_cleanse_bait_rate", cleanse_bait_rate, bait_req, bait_ok, bait_extra)
	var cleanse_delta: Dictionary = _scenario_delta(scenario_counterplay, "cleanse_pressure_events", PackedStringArray(["cleanse", "counter", "anti_dot", "anti-dot", "tenacity"]))
	if not cleanse_delta.is_empty():
		var delta_value: float = float(cleanse_delta.get("delta", 0.0))
		var delta_pass: bool = delta_value >= cleanse_req
		var delta_extras: Dictionary = extras.duplicate(true)
		delta_extras["reason"] = "scenario_cleanse_delta"
		delta_extras["baseline_scenario"] = String(cleanse_delta.get("baseline", ""))
		delta_extras["counter_scenario"] = String(cleanse_delta.get("counter", ""))
		var delta_ok: Variant = delta_pass
		if pass_flag and direct_debuff_pass and not delta_pass:
			delta_ok = null
			delta_extras["reason"] = "alternate_debuff_evidence_satisfied"
		RoleCommon.append_span(spans, "subject_debuff_cleanse_scenario_delta", delta_value, cleanse_req, delta_ok, delta_extras)
		pass_flag = pass_flag or delta_pass
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; enemy_debuffs=%d; cleanse_pressure=%d" % [scenario_label, considered, enemy_debuffs, cleanse_pressure]
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

func _subject_counterplay_pressure(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var pressure: Dictionary = kernels.get("counterplay_pressure", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = pressure.get("per_unit", {}) if (pressure is Dictionary) else {}
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
	scenario_rec["cleanse_pressure_events"] = float(scenario_rec.get("cleanse_pressure_events", 0.0)) + float(rec.get("cleanse_pressure_events", 0))
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

func _baseline_label(stats: Dictionary) -> String:
	if stats.has("neutral"):
		return "neutral"
	for label_value in stats.keys():
		var label: String = String(label_value)
		if not _label_has_token(label, PackedStringArray(["cleanse", "counter", "anti_dot", "anti-dot", "tenacity"])):
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
