extends RefCounted

# Approach: reset_mechanic (per-unit subject)
# Prefers direct reset/recast telemetry and post-first-reset snowball evidence.
# Falls back to kill/execute and post-peak damage shape when rows predate reset events.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_reset_mechanic"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "reset_mechanic: direct reset/recast events, chain length, reset timing, post-first-reset snowball impact, and counter-scenario sensitivity; falls back to chained kills, low-HP conversion, and post-peak damage on older rows."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "reset_mechanic")
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 2, "n": 4})
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var kill_cfg: Dictionary = metrics_cfg.get("kill_count", {})
	var event_cfg: Dictionary = metrics_cfg.get("reset_events", kill_cfg)
	var chain_cfg: Dictionary = metrics_cfg.get("reset_chain_length", metrics_cfg.get("reset_chain_length_proxy", {}))
	var proxy_chain_cfg: Dictionary = metrics_cfg.get("reset_chain_length_proxy", chain_cfg)
	var time_cfg: Dictionary = metrics_cfg.get("time_between_resets_s", {})
	var post_damage_cfg: Dictionary = metrics_cfg.get("post_first_reset_damage", {})
	var post_damage_share_cfg: Dictionary = metrics_cfg.get("post_first_reset_damage_share", {})
	var post_kill_cfg: Dictionary = metrics_cfg.get("post_first_reset_kills", {})
	var followup_cfg: Dictionary = metrics_cfg.get("first_reset_followup_s", {})
	var win_rate_cfg: Dictionary = metrics_cfg.get("reset_win_rate", {})
	var share_cfg: Dictionary = metrics_cfg.get("low_hp_kill_share", {})
	var falloff_cfg: Dictionary = metrics_cfg.get("falloff_after_peak", {})
	var kill_req: float = RoleCommon.resolve_min_threshold(kill_cfg, cost_band, scenario_label)
	var event_req: float = RoleCommon.resolve_min_threshold(event_cfg, cost_band, scenario_label)
	var chain_req: float = RoleCommon.resolve_min_threshold(chain_cfg, cost_band, scenario_label)
	var proxy_chain_req: float = RoleCommon.resolve_min_threshold(proxy_chain_cfg, cost_band, scenario_label)
	var time_max: float = RoleCommon.resolve_max_threshold(time_cfg, cost_band, scenario_label)
	var post_damage_req: float = RoleCommon.resolve_min_threshold(post_damage_cfg, cost_band, scenario_label)
	var post_damage_share_req: float = RoleCommon.resolve_min_threshold(post_damage_share_cfg, cost_band, scenario_label)
	var post_kill_req: float = RoleCommon.resolve_min_threshold(post_kill_cfg, cost_band, scenario_label)
	var followup_max: float = RoleCommon.resolve_max_threshold(followup_cfg, cost_band, scenario_label)
	var win_rate_req: float = RoleCommon.resolve_min_threshold(win_rate_cfg, cost_band, scenario_label)
	var share_req: float = RoleCommon.resolve_min_threshold(share_cfg, cost_band, scenario_label)
	var falloff_req: float = RoleCommon.resolve_min_threshold(falloff_cfg, cost_band, scenario_label)
	if kill_req <= 0.0:
		kill_req = 1.0
	if event_req <= 0.0:
		event_req = 1.0
	if chain_req <= 0.0:
		chain_req = 2.0
	if proxy_chain_req <= 0.0:
		proxy_chain_req = 2.0
	if time_max <= 0.0:
		time_max = 5.0
	if post_damage_req <= 0.0:
		post_damage_req = 1.0
	if post_damage_share_req <= 0.0:
		post_damage_share_req = 0.20
	if post_kill_req <= 0.0:
		post_kill_req = 1.0
	if followup_max <= 0.0:
		followup_max = 1.50
	if win_rate_req <= 0.0:
		win_rate_req = 0.50
	if share_req <= 0.0:
		share_req = 0.50
	if falloff_req <= 0.0:
		falloff_req = 0.25

	var kill_count: int = 0
	var low_hp_kills: int = 0
	var direct_supported: bool = false
	var reset_events: int = 0
	var reset_chain_length: int = 0
	var reset_time_samples: Array[float] = []
	var reset_targets: int = 0
	var post_damage: float = 0.0
	var post_damage_share_samples: Array[float] = []
	var post_kills: int = 0
	var post_targets: int = 0
	var followup_samples: Array[float] = []
	var reset_win_runs: int = 0
	var reset_win_count: int = 0
	var scenario_reset: Dictionary = {}
	var share_samples: Array[float] = []
	var falloff_samples: Array[float] = []
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var rec: Dictionary = _subject_pattern(entry, subject_id)
		if rec.is_empty():
			continue
		considered += 1
		direct_supported = _reset_supported(entry) or direct_supported
		reset_events += int(rec.get("reset_events", 0))
		reset_chain_length = max(reset_chain_length, int(rec.get("reset_chain_length", 0)))
		reset_targets += int(rec.get("reset_targets", 0))
		var min_between: float = float(rec.get("reset_time_between_min_s", 0.0))
		if min_between > 0.0:
			reset_time_samples.append(min_between)
		post_damage += float(rec.get("reset_post_first_damage", 0.0))
		post_damage_share_samples.append(float(rec.get("reset_post_first_damage_share", 0.0)))
		post_kills += int(rec.get("reset_post_first_kills", 0))
		post_targets += int(rec.get("reset_post_first_targets", 0))
		var followup_s: float = float(rec.get("reset_first_followup_s", -1.0))
		if followup_s >= 0.0:
			followup_samples.append(followup_s)
		if int(rec.get("reset_events", 0)) > 0:
			reset_win_runs += 1
			if _subject_won(entry, _subject_side(entry, subject_id)):
				reset_win_count += 1
		_bump_scenario_reset(scenario_reset, _scenario_for_entry(entry, scenario_label), rec, _subject_won(entry, _subject_side(entry, subject_id)))
		kill_count += int(rec.get("kill_count", 0))
		low_hp_kills += int(rec.get("low_hp_kill_count", 0))
		share_samples.append(float(rec.get("low_hp_kill_share", 0.0)))
		falloff_samples.append(float(rec.get("falloff_after_peak", 0.0)))

	var low_hp_share: float = float(low_hp_kills) / max(1.0, float(kill_count))
	if kill_count <= 0:
		low_hp_share = RoleCommon.median(share_samples)
	var falloff_value: float = RoleCommon.median(falloff_samples)
	var spans: Array = []
	var reason: String = "reset_event_telemetry_missing"
	if considered <= 0:
		reason = "no_samples"
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["low_hp_kill_count"] = low_hp_kills
	extras["direct_reset_supported"] = direct_supported

	if direct_supported:
		var time_between_value: float = RoleCommon.median(reset_time_samples)
		var post_damage_share: float = RoleCommon.median(post_damage_share_samples)
		var followup_value: float = RoleCommon.median(followup_samples)
		var reset_win_rate: float = float(reset_win_count) / max(1.0, float(reset_win_runs))
		var event_pass: bool = considered > 0 and float(reset_events) >= event_req
		var direct_chain_pass: bool = considered > 0 and float(reset_chain_length) >= chain_req
		var time_pass: bool = reset_time_samples.size() > 0 and time_between_value <= time_max
		var target_pass: bool = considered > 0 and reset_targets >= 1
		var post_damage_pass: bool = considered > 0 and post_damage >= post_damage_req
		var post_damage_share_pass: bool = post_damage_share_samples.size() > 0 and post_damage_share >= post_damage_share_req
		var post_kill_pass: bool = considered > 0 and float(post_kills) >= post_kill_req
		var followup_pass: bool = followup_samples.size() > 0 and followup_value <= followup_max
		var win_rate_pass: bool = reset_win_runs > 0 and reset_win_rate >= win_rate_req
		var direct_eval: Dictionary = RoleCommon.k_of_n([event_pass, direct_chain_pass, time_pass, target_pass], int(kcfg.get("k", 2)), int(kcfg.get("n", 4)))
		var direct_pass: bool = bool(direct_eval.get("pass", false))
		if direct_pass:
			extras["reason"] = "direct_reset_event_telemetry"
		elif considered > 0:
			extras["reason"] = "direct_reset_threshold_miss"
		extras["k_required"] = int(direct_eval.get("k", 2))
		extras["true_count"] = int(direct_eval.get("true_count", 0))
		extras["reset_targets"] = reset_targets
		extras["post_reset_semantics"] = true
		RoleCommon.append_span(spans, "subject_reset_event_count", reset_events, event_req, event_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_chain_length", reset_chain_length, chain_req, direct_chain_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_time_between_s", time_between_value, time_max, time_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_targets", reset_targets, 1.0, target_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_post_first_damage", post_damage, post_damage_req, post_damage_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_post_first_damage_share", post_damage_share, post_damage_share_req, post_damage_share_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_post_first_kills", post_kills, post_kill_req, post_kill_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_post_first_targets", post_targets, 1.0, post_targets > 0, extras)
		RoleCommon.append_span(spans, "subject_reset_first_followup_s", followup_value, followup_max, followup_pass, extras)
		RoleCommon.append_span(spans, "subject_reset_win_rate_after_reset", reset_win_rate, win_rate_req, win_rate_pass, extras)
		_append_counter_scenario_spans(spans, extras, scenario_reset, event_req, chain_req, post_damage_req, win_rate_req)
		return {
			"id": METRIC_ID,
			"version": VERSION,
			"pass": direct_pass,
			"spans": spans,
			"message": "scenario=%s; considered=%d; direct_reset=1; events=%d; chain=%d" % [scenario_label, considered, reset_events, reset_chain_length]
		}

	var kill_pass: bool = considered > 0 and float(kill_count) >= kill_req
	var chain_pass: bool = considered > 0 and float(kill_count) >= proxy_chain_req
	var share_pass: bool = considered > 0 and low_hp_share >= share_req
	var falloff_pass: bool = falloff_samples.size() > 0 and falloff_value >= falloff_req
	var proxy_eval: Dictionary = RoleCommon.k_of_n([kill_pass, chain_pass, share_pass, falloff_pass], int(kcfg.get("k", 2)), int(kcfg.get("n", 4)))
	var proxy_pass: bool = bool(proxy_eval.get("pass", false))
	extras["k_required"] = int(proxy_eval.get("k", 2))
	extras["true_count"] = int(proxy_eval.get("true_count", 0))
	RoleCommon.append_span(spans, "subject_reset_kill_count_proxy", kill_count, kill_req, kill_pass, extras)
	RoleCommon.append_span(spans, "subject_reset_chain_length_proxy", kill_count, proxy_chain_req, chain_pass, extras)
	RoleCommon.append_span(spans, "subject_reset_low_hp_kill_share_proxy", low_hp_share, share_req, share_pass, extras)
	RoleCommon.append_span(spans, "subject_reset_post_peak_falloff_proxy", falloff_value, falloff_req, falloff_pass, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": proxy_pass,
		"spans": spans,
		"message": "scenario=%s; considered=%d; reset_proxy=1" % [scenario_label, considered]
	}

func _reset_supported(entry: Dictionary) -> bool:
	var kernels: Dictionary = entry.get("kernels", {})
	var patterns: Dictionary = kernels.get("combat_patterns", {}) if (kernels is Dictionary) else {}
	return bool(patterns.get("reset_supported", false)) if (patterns is Dictionary) else false

func _subject_pattern(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var patterns: Dictionary = kernels.get("combat_patterns", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = patterns.get("per_unit", {}) if (patterns is Dictionary) else {}
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

func _scenario_for_entry(entry: Dictionary, fallback: String) -> String:
	var context: Dictionary = entry.get("context", {}) if (entry is Dictionary) else {}
	var label: String = String(context.get("scenario", fallback)) if (context is Dictionary) else fallback
	if label == "":
		label = fallback
	return label

func _subject_won(entry: Dictionary, subject_side: String) -> bool:
	var outcome: Dictionary = entry.get("outcome", {}) if (entry is Dictionary) else {}
	if not (outcome is Dictionary):
		return false
	var winner_side: String = String(outcome.get("winner_side", ""))
	if winner_side == "":
		var winner: String = String(outcome.get("winner", outcome.get("result", ""))).to_lower()
		if winner == "a" or winner == "team_a":
			winner_side = "a"
		elif winner == "b" or winner == "team_b":
			winner_side = "b"
		elif winner == "player":
			winner_side = "a"
		elif winner == "enemy":
			winner_side = "b"
	return winner_side != "" and winner_side == subject_side

func _bump_scenario_reset(stats: Dictionary, label: String, rec: Dictionary, subject_won: bool) -> void:
	var key: String = label.strip_edges().to_lower()
	if key == "":
		key = "neutral"
	var scenario_rec: Dictionary = stats.get(key, {})
	scenario_rec["reset_events"] = float(scenario_rec.get("reset_events", 0.0)) + float(rec.get("reset_events", 0))
	scenario_rec["reset_chain_length"] = max(float(scenario_rec.get("reset_chain_length", 0.0)), float(rec.get("reset_chain_length", 0)))
	scenario_rec["reset_post_first_damage"] = float(scenario_rec.get("reset_post_first_damage", 0.0)) + float(rec.get("reset_post_first_damage", 0.0))
	if int(rec.get("reset_events", 0)) > 0:
		scenario_rec["reset_win_runs"] = float(scenario_rec.get("reset_win_runs", 0.0)) + 1.0
		scenario_rec["reset_win_count"] = float(scenario_rec.get("reset_win_count", 0.0)) + (1.0 if subject_won else 0.0)
	stats[key] = scenario_rec

func _append_counter_scenario_spans(spans: Array, extras: Dictionary, scenario_reset: Dictionary, event_req: float, chain_req: float, damage_req: float, win_rate_req: float) -> void:
	var event_delta: Dictionary = _scenario_delta(scenario_reset, "reset_events", PackedStringArray(["sustain", "counter", "anti_reset", "anti-reset"]))
	var chain_delta: Dictionary = _scenario_delta(scenario_reset, "reset_chain_length", PackedStringArray(["sustain", "counter", "anti_reset", "anti-reset"]))
	var damage_delta: Dictionary = _scenario_delta(scenario_reset, "reset_post_first_damage", PackedStringArray(["sustain", "counter", "anti_reset", "anti-reset"]))
	var win_delta: Dictionary = _scenario_win_rate_delta(scenario_reset, PackedStringArray(["sustain", "counter", "anti_reset", "anti-reset"]))
	if event_delta.is_empty() and chain_delta.is_empty() and damage_delta.is_empty() and win_delta.is_empty():
		return
	var delta_extras: Dictionary = extras.duplicate()
	delta_extras["reason"] = "reset_counter_scenario_delta"
	if not event_delta.is_empty():
		var event_drop: float = max(0.0, float(event_delta.get("baseline", 0.0)) - float(event_delta.get("counter", 0.0)))
		RoleCommon.append_span(spans, "subject_reset_counter_event_drop", event_drop, event_req, event_drop >= event_req, delta_extras)
	if not chain_delta.is_empty():
		var chain_drop: float = max(0.0, float(chain_delta.get("baseline", 0.0)) - float(chain_delta.get("counter", 0.0)))
		RoleCommon.append_span(spans, "subject_reset_counter_chain_drop", chain_drop, max(1.0, chain_req - 1.0), chain_drop >= max(1.0, chain_req - 1.0), delta_extras)
	if not damage_delta.is_empty():
		var damage_drop: float = max(0.0, float(damage_delta.get("baseline", 0.0)) - float(damage_delta.get("counter", 0.0)))
		RoleCommon.append_span(spans, "subject_reset_counter_post_damage_drop", damage_drop, damage_req, damage_drop >= damage_req, delta_extras)
	if not win_delta.is_empty():
		var win_drop: float = max(0.0, float(win_delta.get("baseline", 0.0)) - float(win_delta.get("counter", 0.0)))
		RoleCommon.append_span(spans, "subject_reset_counter_win_rate_drop", win_drop, win_rate_req, win_drop >= win_rate_req, delta_extras)

func _scenario_delta(stats: Dictionary, field: String, counter_tokens: PackedStringArray) -> Dictionary:
	var baseline_label: String = _baseline_label(stats)
	var counter_label: String = _counter_label(stats, counter_tokens)
	if baseline_label == "" or counter_label == "":
		return {}
	var baseline_rec: Dictionary = stats.get(baseline_label, {})
	var counter_rec: Dictionary = stats.get(counter_label, {})
	return {
		"baseline_label": baseline_label,
		"counter_label": counter_label,
		"baseline": float(baseline_rec.get(field, 0.0)),
		"counter": float(counter_rec.get(field, 0.0))
	}

func _scenario_win_rate_delta(stats: Dictionary, counter_tokens: PackedStringArray) -> Dictionary:
	var baseline_label: String = _baseline_label(stats)
	var counter_label: String = _counter_label(stats, counter_tokens)
	if baseline_label == "" or counter_label == "":
		return {}
	var baseline_rate: float = _scenario_win_rate(stats.get(baseline_label, {}))
	var counter_rate: float = _scenario_win_rate(stats.get(counter_label, {}))
	return {
		"baseline_label": baseline_label,
		"counter_label": counter_label,
		"baseline": baseline_rate,
		"counter": counter_rate
	}

func _baseline_label(stats: Dictionary) -> String:
	for label_value in stats.keys():
		var label: String = String(label_value).to_lower()
		if label == "neutral" or label.find("baseline") >= 0:
			return label
	for label_value_fallback in stats.keys():
		var fallback: String = String(label_value_fallback).to_lower()
		if not _label_has_token(fallback, PackedStringArray(["sustain", "counter", "anti_reset", "anti-reset"])):
			return fallback
	return ""

func _counter_label(stats: Dictionary, tokens: PackedStringArray) -> String:
	for label_value in stats.keys():
		var label: String = String(label_value).to_lower()
		if _label_has_token(label, tokens):
			return label
	return ""

func _label_has_token(label: String, tokens: PackedStringArray) -> bool:
	for token in tokens:
		if label.find(String(token).to_lower()) >= 0:
			return true
	return false

func _scenario_win_rate(rec: Dictionary) -> float:
	var runs: float = float(rec.get("reset_win_runs", 0.0))
	if runs <= 0.0:
		return 0.0
	return float(rec.get("reset_win_count", 0.0)) / runs

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for key in sims.keys():
		var side: String = _subject_side(sims.get(key, {}), subject_id)
		if side != "":
			return side
	return ""
