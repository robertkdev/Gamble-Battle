extends RefCounted

# Approach: redirect (per-unit subject)
# Prefer direct redirect telemetry: the subject actively prevents damage,
# taunts/body-blocks enemies, accepts post-redirect risk, or pulls enemy focus
# through target swaps. Pressure share remains a fallback diagnostic for older
# rows where redirect telemetry is unavailable.

const VERSION: String = "1.1.0"
const METRIC_ID: String = "approach_redirect"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base", "targets"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "redirect: direct taunt/body-block/threat-swap/prevention evidence, with pressure-share fallback diagnostics."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "redirect")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var events_cfg: Dictionary = metrics_cfg.get("redirect_events", {})
	var redirected_cfg: Dictionary = metrics_cfg.get("redirected_damage_prevented", {})
	var focus_start_cfg: Dictionary = metrics_cfg.get("focus_start_events", {})
	var target_swap_cfg: Dictionary = metrics_cfg.get("target_swap_events", {})
	var focus_time_cfg: Dictionary = metrics_cfg.get("enemy_focus_time_s", {})
	var taunt_cfg: Dictionary = metrics_cfg.get("taunt_events", {})
	var body_block_cfg: Dictionary = metrics_cfg.get("body_block_events", {})
	var body_block_prevented_cfg: Dictionary = metrics_cfg.get("body_block_damage_prevented", {})
	var end_risk_cfg: Dictionary = metrics_cfg.get("redirect_end_risk_events", {})
	var end_risk_time_cfg: Dictionary = metrics_cfg.get("redirect_end_risk_s", {})
	var share_cfg: Dictionary = metrics_cfg.get("incoming_share", {})
	var incoming_cfg: Dictionary = metrics_cfg.get("incoming_total", {})
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var cost_band: int = int(ident.get("cost", 3))
	var events_req: float = RoleCommon.resolve_min_threshold(events_cfg, cost_band, scenario_label)
	var redirected_req: float = RoleCommon.resolve_min_threshold(redirected_cfg, cost_band, scenario_label)
	var focus_start_req: float = RoleCommon.resolve_min_threshold(focus_start_cfg, cost_band, scenario_label)
	var target_swap_req: float = RoleCommon.resolve_min_threshold(target_swap_cfg, cost_band, scenario_label)
	var focus_time_req: float = RoleCommon.resolve_min_threshold(focus_time_cfg, cost_band, scenario_label)
	var taunt_req: float = RoleCommon.resolve_min_threshold(taunt_cfg, cost_band, scenario_label)
	var body_block_req: float = RoleCommon.resolve_min_threshold(body_block_cfg, cost_band, scenario_label)
	var body_block_prevented_req: float = RoleCommon.resolve_min_threshold(body_block_prevented_cfg, cost_band, scenario_label)
	var end_risk_req: float = RoleCommon.resolve_min_threshold(end_risk_cfg, cost_band, scenario_label)
	var end_risk_time_req: float = RoleCommon.resolve_min_threshold(end_risk_time_cfg, cost_band, scenario_label)
	var share_req: float = RoleCommon.resolve_min_threshold(share_cfg, cost_band, scenario_label)
	var incoming_req: float = RoleCommon.resolve_min_threshold(incoming_cfg, cost_band, scenario_label)
	if events_req <= 0.0:
		events_req = 1.0
	if redirected_req <= 0.0:
		redirected_req = 1.0
	if focus_start_req <= 0.0:
		focus_start_req = 1.0
	if target_swap_req <= 0.0:
		target_swap_req = 1.0
	if focus_time_req <= 0.0:
		focus_time_req = 1.0
	if taunt_req <= 0.0:
		taunt_req = 1.0
	if body_block_req <= 0.0:
		body_block_req = 1.0
	if body_block_prevented_req <= 0.0:
		body_block_prevented_req = 1.0
	if end_risk_req <= 0.0:
		end_risk_req = 1.0
	if end_risk_time_req <= 0.0:
		end_risk_time_req = 0.5
	if share_req <= 0.0:
		share_req = 0.25
	if incoming_req <= 0.0:
		incoming_req = 100.0

	var direct_supported: bool = false
	var direct_samples: int = 0
	var direct_events: int = 0
	var direct_damage: float = 0.0
	var ally_damage_prevented: float = 0.0
	var focus_start_events: int = 0
	var target_swap_events: int = 0
	var enemy_focus_time_s: float = 0.0
	var taunt_events: int = 0
	var taunt_duration_s: float = 0.0
	var body_block_events: int = 0
	var body_block_prevented: float = 0.0
	var explicit_threat_swap_events: int = 0
	var end_risk_events: int = 0
	var end_risk_s: float = 0.0
	var subject_incoming: float = 0.0
	var team_incoming: float = 0.0
	var considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		if _redirect_supported(entry):
			direct_supported = true
			direct_samples += 1
			var redirect_rec: Dictionary = _subject_redirect_record(entry, side, subject_id)
			direct_events += int(redirect_rec.get("redirect_events", 0))
			direct_damage += float(redirect_rec.get("redirected_damage_prevented", 0.0))
			ally_damage_prevented += float(redirect_rec.get("ally_damage_prevented", 0.0))
			focus_start_events += int(redirect_rec.get("focus_start_events", 0))
			target_swap_events += int(redirect_rec.get("target_swap_to_subject_events", 0))
			enemy_focus_time_s += float(redirect_rec.get("enemy_focus_time_s", 0.0))
			taunt_events += int(redirect_rec.get("taunt_events", 0))
			taunt_duration_s += float(redirect_rec.get("taunt_duration_s", 0.0))
			body_block_events += int(redirect_rec.get("body_block_events", 0))
			body_block_prevented += float(redirect_rec.get("body_block_damage_prevented", 0.0))
			explicit_threat_swap_events += int(redirect_rec.get("explicit_threat_swap_events", 0))
			end_risk_events += int(redirect_rec.get("redirect_end_risk_events", 0))
			end_risk_s += float(redirect_rec.get("redirect_end_risk_s", 0.0))
		var subject_unit: Dictionary = _subject_unit(entry, side, subject_id)
		if subject_unit.is_empty():
			considered += 1
			continue
		considered += 1
		var subj_value: float = max(float(subject_unit.get("incoming", 0.0)), float(subject_unit.get("pre_mit_incoming", 0.0)))
		subject_incoming += subj_value
		team_incoming += _team_incoming(entry, side)

	var incoming_share: float = subject_incoming / max(1.0, team_incoming)
	var events_pass: bool = direct_samples > 0 and float(direct_events) >= events_req
	var redirected_pass: bool = direct_samples > 0 and direct_damage >= redirected_req
	var focus_start_pass: bool = direct_samples > 0 and float(focus_start_events) >= focus_start_req
	var target_swap_pass: bool = direct_samples > 0 and float(target_swap_events) >= target_swap_req
	var focus_time_pass: bool = direct_samples > 0 and enemy_focus_time_s >= focus_time_req
	var focus_pass: bool = target_swap_pass or (focus_start_pass and focus_time_pass)
	var taunt_pass: bool = direct_samples > 0 and float(taunt_events) >= taunt_req
	var body_block_pass: bool = direct_samples > 0 and (float(body_block_events) >= body_block_req or body_block_prevented >= body_block_prevented_req)
	var explicit_threat_swap_pass: bool = direct_samples > 0 and float(explicit_threat_swap_events) >= target_swap_req
	var end_risk_pass: bool = direct_samples > 0 and (float(end_risk_events) >= end_risk_req or end_risk_s >= end_risk_time_req)
	var semantic_pass: bool = taunt_pass or body_block_pass or explicit_threat_swap_pass or end_risk_pass
	var direct_pass: bool = events_pass or redirected_pass or focus_pass or semantic_pass
	var share_pass: bool = considered > 0 and incoming_share >= share_req
	var incoming_pass: bool = considered > 0 and subject_incoming >= incoming_req
	var proxy_pass: bool = share_pass or incoming_pass
	var pass_flag: bool = direct_pass if direct_supported else proxy_pass
	var reason: String = "direct_redirect_evidence" if direct_supported else "redirect_focus_proxy_fallback"
	if direct_supported and not direct_pass:
		reason = "no_direct_redirect_events"
	elif considered <= 0:
		reason = "no_samples"
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["considered"] = considered
	extras["direct_supported"] = direct_supported
	extras["direct_samples"] = direct_samples
	extras["team_incoming_total"] = team_incoming
	extras["proxy_pass"] = proxy_pass
	RoleCommon.append_span(spans, "subject_redirect_events", direct_events, events_req, events_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_damage_prevented", direct_damage, redirected_req, redirected_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_ally_damage_prevented", ally_damage_prevented, null, true, extras)
	RoleCommon.append_span(spans, "subject_redirect_focus_start_events", focus_start_events, focus_start_req, focus_start_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_target_swap_events", target_swap_events, target_swap_req, target_swap_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_enemy_focus_time_s", enemy_focus_time_s, focus_time_req, focus_time_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_taunt_events", taunt_events, taunt_req, taunt_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_taunt_duration_s", taunt_duration_s, null, true, extras)
	RoleCommon.append_span(spans, "subject_redirect_body_block_events", body_block_events, body_block_req, body_block_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_body_block_damage_prevented", body_block_prevented, body_block_prevented_req, body_block_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_explicit_threat_swap_events", explicit_threat_swap_events, target_swap_req, explicit_threat_swap_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_end_risk_events", end_risk_events, end_risk_req, end_risk_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_end_risk_s", end_risk_s, end_risk_time_req, end_risk_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_incoming_share_proxy", incoming_share, share_req, share_pass, extras)
	RoleCommon.append_span(spans, "subject_redirect_incoming_total_proxy", subject_incoming, incoming_req, incoming_pass, extras)
	var mode: String = "direct" if direct_supported else "proxy_fallback"
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; mode=%s; direct_events=%d; direct_damage=%.1f; focus_swaps=%d; taunts=%d; body_blocks=%d; end_risk=%d; proxy_pass=%s" % [scenario_label, considered, mode, direct_events, direct_damage, target_swap_events, taunt_events, body_block_events, end_risk_events, str(proxy_pass)]
	}

func _redirect_supported(entry: Dictionary) -> bool:
	var kernels: Dictionary = entry.get("kernels", {})
	var redirect_block: Dictionary = kernels.get("redirect", {}) if (kernels is Dictionary) else {}
	return bool(redirect_block.get("supported", false)) if (redirect_block is Dictionary) else false

func _subject_redirect_record(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var redirect_block: Dictionary = kernels.get("redirect", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = redirect_block.get("per_unit", {}) if (redirect_block is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_unit(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var units: Dictionary = entry.get("units", {})
	if not (units is Dictionary):
		return {}
	var arr: Array = units.get(side, [])
	if not (arr is Array):
		return {}
	for value in arr:
		if not (value is Dictionary):
			continue
		var unit_entry: Dictionary = value
		if String(unit_entry.get("unit_id", "")) == subject_id:
			return unit_entry
	return {}

func _team_incoming(entry: Dictionary, side: String) -> float:
	var units: Dictionary = entry.get("units", {})
	if not (units is Dictionary):
		return 0.0
	var arr: Array = units.get(side, [])
	if not (arr is Array):
		return 0.0
	var total: float = 0.0
	for value in arr:
		if not (value is Dictionary):
			continue
		var unit_entry: Dictionary = value
		total += max(float(unit_entry.get("incoming", 0.0)), float(unit_entry.get("pre_mit_incoming", 0.0)))
	return total

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
