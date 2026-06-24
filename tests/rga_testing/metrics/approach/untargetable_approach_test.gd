extends RefCounted

# Approach: untargetable (per-unit subject)
# Prefers direct targetability-window and threat-dodge telemetry. Falls back to
# older pressure-avoidance proxies when rows predate targetability events.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_untargetable"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base", "buffs", "mobility"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "untargetable: direct untargetable frame share, key-threat dodge rate, and cooldown trade; falls back to low incoming share, survival, mobility, and CC-prevention proxies on older rows."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "untargetable")
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 2, "n": 4})
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var frames_cfg: Dictionary = metrics_cfg.get("untargetable_frames_pct", {})
	var time_cfg: Dictionary = metrics_cfg.get("untargetable_time_s", {})
	var dodge_cfg: Dictionary = metrics_cfg.get("key_threat_dodge_rate", {})
	var cooldown_cfg: Dictionary = metrics_cfg.get("cooldown_trade_s", {})
	var incoming_cfg: Dictionary = metrics_cfg.get("incoming_share", {})
	var survival_cfg: Dictionary = metrics_cfg.get("survival_s", {})
	var mobility_cfg: Dictionary = metrics_cfg.get("post_cast_displacement_tiles", {})
	var cc_cfg: Dictionary = metrics_cfg.get("cc_prevented", {})
	var frames_req: float = RoleCommon.resolve_min_threshold(frames_cfg, cost_band, scenario_label)
	var time_req: float = RoleCommon.resolve_min_threshold(time_cfg, cost_band, scenario_label)
	var dodge_req: float = RoleCommon.resolve_min_threshold(dodge_cfg, cost_band, scenario_label)
	var cooldown_req: float = RoleCommon.resolve_min_threshold(cooldown_cfg, cost_band, scenario_label)
	var incoming_max: float = RoleCommon.resolve_max_threshold(incoming_cfg, cost_band, scenario_label)
	var survival_req: float = RoleCommon.resolve_min_threshold(survival_cfg, cost_band, scenario_label)
	var mobility_req: float = RoleCommon.resolve_min_threshold(mobility_cfg, cost_band, scenario_label)
	var cc_req: float = RoleCommon.resolve_min_threshold(cc_cfg, cost_band, scenario_label)
	if frames_req <= 0.0:
		frames_req = 0.05
	if time_req <= 0.0:
		time_req = 0.50
	if dodge_req <= 0.0:
		dodge_req = 0.50
	if cooldown_req <= 0.0:
		cooldown_req = 1.0
	if incoming_max <= 0.0:
		incoming_max = 0.25
	if survival_req <= 0.0:
		survival_req = 8.0
	if mobility_req <= 0.0:
		mobility_req = 1.0
	if cc_req <= 0.0:
		cc_req = 1.0

	var direct_supported: bool = false
	var direct_considered: int = 0
	var window_count: int = 0
	var untargetable_time: float = 0.0
	var frames_samples: Array[float] = []
	var key_threats_faced: int = 0
	var key_threats_dodged: int = 0
	var cooldown_trade: float = 0.0
	var incoming_total: float = 0.0
	var team_incoming_total: float = 0.0
	var survival_samples: Array[float] = []
	var mobility_samples: Array[float] = []
	var cc_prevented: int = 0
	var proxy_considered: int = 0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		direct_supported = _targetability_supported(entry) or direct_supported
		if _targetability_supported(entry):
			direct_considered += 1
			var targetability_rec: Dictionary = _subject_targetability(entry, side, subject_id)
			if not targetability_rec.is_empty():
				window_count += int(targetability_rec.get("untargetable_windows", 0))
				untargetable_time += float(targetability_rec.get("untargetable_time_s", 0.0))
				frames_samples.append(float(targetability_rec.get("untargetable_frames_pct", 0.0)))
				key_threats_faced += int(targetability_rec.get("key_threats_faced", 0))
				key_threats_dodged += int(targetability_rec.get("key_threats_dodged", 0))
				cooldown_trade += float(targetability_rec.get("cooldown_trade_s", 0.0))
		var unit_rec: Dictionary = _subject_unit(entry, side, subject_id)
		if unit_rec.is_empty():
			continue
		proxy_considered += 1
		incoming_total += max(float(unit_rec.get("incoming", 0.0)), float(unit_rec.get("pre_mit_incoming", 0.0)))
		team_incoming_total += _team_incoming(entry, side)
		survival_samples.append(float(unit_rec.get("time_alive_s", 0.0)))
		var control_rec: Dictionary = _subject_control(entry, side, subject_id)
		if not control_rec.is_empty():
			mobility_samples.append(float(control_rec.get("post_cast_displacement_tiles", 0.0)))
		var target_rec: Dictionary = _subject_buff_target(entry, side, subject_id)
		cc_prevented += int(target_rec.get("cc_prevented", 0))

	var spans: Array = []
	var reason: String = "targetability_window_telemetry_missing"
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["direct_targetability_supported"] = direct_supported

	if direct_supported:
		var frames_value: float = RoleCommon.median(frames_samples)
		var dodge_rate: float = 0.0
		if key_threats_faced > 0:
			dodge_rate = float(key_threats_dodged) / max(1.0, float(key_threats_faced))
		var frames_pass: bool = direct_considered > 0 and frames_value >= frames_req
		var time_pass: bool = direct_considered > 0 and untargetable_time >= time_req
		var dodge_pass: bool = direct_considered > 0 and key_threats_faced > 0 and dodge_rate >= dodge_req
		var cooldown_pass: bool = direct_considered > 0 and cooldown_trade >= cooldown_req
		var direct_eval: Dictionary = RoleCommon.k_of_n([frames_pass, time_pass, dodge_pass, cooldown_pass], int(kcfg.get("k", 2)), int(kcfg.get("n", 4)))
		var direct_pass: bool = bool(direct_eval.get("pass", false))
		if direct_pass:
			extras["reason"] = "direct_targetability_telemetry"
		elif direct_considered > 0:
			extras["reason"] = "direct_targetability_threshold_miss"
		else:
			extras["reason"] = "no_samples"
		extras["considered"] = direct_considered
		extras["k_required"] = int(direct_eval.get("k", 2))
		extras["true_count"] = int(direct_eval.get("true_count", 0))
		extras["untargetable_windows"] = window_count
		extras["key_threats_faced"] = key_threats_faced
		extras["key_threats_dodged"] = key_threats_dodged
		RoleCommon.append_span(spans, "subject_untargetable_frames_pct", frames_value, frames_req, frames_pass, extras)
		RoleCommon.append_span(spans, "subject_untargetable_time_s", untargetable_time, time_req, time_pass, extras)
		RoleCommon.append_span(spans, "subject_untargetable_key_threat_dodge_rate", dodge_rate, dodge_req, dodge_pass, extras)
		RoleCommon.append_span(spans, "subject_untargetable_cooldown_trade_s", cooldown_trade, cooldown_req, cooldown_pass, extras)
		return {
			"id": METRIC_ID,
			"version": VERSION,
			"pass": direct_pass,
			"spans": spans,
			"message": "scenario=%s; considered=%d; direct_untargetable=1; frames_pct=%.3f; key_dodge_rate=%.3f" % [scenario_label, direct_considered, frames_value, dodge_rate]
		}

	var incoming_share: float = incoming_total / max(1.0, team_incoming_total)
	var survival_value: float = RoleCommon.median(survival_samples)
	var mobility_value: float = RoleCommon.median(mobility_samples)
	var incoming_pass: bool = proxy_considered > 0 and incoming_share <= incoming_max
	var survival_pass: bool = survival_samples.size() > 0 and survival_value >= survival_req
	var mobility_pass: bool = mobility_samples.size() > 0 and mobility_value >= mobility_req
	var cc_pass: bool = proxy_considered > 0 and float(cc_prevented) >= cc_req
	var eval: Dictionary = RoleCommon.k_of_n([incoming_pass, survival_pass, mobility_pass, cc_pass], int(kcfg.get("k", 2)), int(kcfg.get("n", 4)))
	var pass_flag: bool = bool(eval.get("pass", false))

	if proxy_considered <= 0:
		extras["reason"] = "no_samples"
	extras["considered"] = proxy_considered
	extras["k_required"] = int(eval.get("k", 2))
	extras["true_count"] = int(eval.get("true_count", 0))
	RoleCommon.append_span(spans, "subject_untargetable_incoming_share_proxy", incoming_share, incoming_max, incoming_pass, extras)
	RoleCommon.append_span(spans, "subject_untargetable_survival_s_proxy", survival_value, survival_req, survival_pass, extras)
	RoleCommon.append_span(spans, "subject_untargetable_post_cast_displacement_proxy", mobility_value, mobility_req, mobility_pass, extras)
	RoleCommon.append_span(spans, "subject_untargetable_cc_prevented_proxy", cc_prevented, cc_req, cc_pass, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; proxy_untargetable=1" % [scenario_label, proxy_considered]
	}

func _targetability_supported(entry: Dictionary) -> bool:
	var kernels: Dictionary = entry.get("kernels", {})
	var targetability: Dictionary = kernels.get("targetability", {}) if (kernels is Dictionary) else {}
	return bool(targetability.get("supported", false)) if (targetability is Dictionary) else false

func _subject_targetability(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var targetability: Dictionary = kernels.get("targetability", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = targetability.get("per_unit", {}) if (targetability is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_unit(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var units: Dictionary = entry.get("units", {})
	var arr: Array = units.get(side, []) if (units is Dictionary) else []
	for value in arr:
		if not (value is Dictionary):
			continue
		var unit_entry: Dictionary = value
		if String(unit_entry.get("unit_id", "")) == subject_id:
			return unit_entry
	return {}

func _subject_control(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var control: Dictionary = kernels.get("control_mobility", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = control.get("per_unit", {}) if (control is Dictionary) else {}
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

func _team_incoming(entry: Dictionary, side: String) -> float:
	var units: Dictionary = entry.get("units", {})
	var arr: Array = units.get(side, []) if (units is Dictionary) else []
	var total: float = 0.0
	for value in arr:
		if value is Dictionary:
			var unit_entry: Dictionary = value
			total += max(float(unit_entry.get("incoming", 0.0)), float(unit_entry.get("pre_mit_incoming", 0.0)))
	return total

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
