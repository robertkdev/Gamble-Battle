extends RefCounted

# Approach: Zone (per-unit subject)
# Prefer direct zone-exposure telemetry: the subject projects a persistent
# zone/hazard onto enemies. Subject-side zone occupancy remains a fallback for
# older rows that only expose formation positioning.

const VERSION: String = "1.1.0"
const METRIC_ID: String = "approach_zone"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["mobility", "zones"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "zone: direct subject-owned zone/hazard exposure, with positioning occupancy fallback."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "zone")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var share_cfg: Dictionary = metrics_cfg.get("frontline_zone_share", {})
	var events_cfg: Dictionary = metrics_cfg.get("zone_exposure_events", {})
	var targets_cfg: Dictionary = metrics_cfg.get("zone_exposure_targets", {})
	var time_cfg: Dictionary = metrics_cfg.get("zone_exposure_time_s", {})
	var damage_cfg: Dictionary = metrics_cfg.get("zone_exposure_damage", {})
	var radius_cfg: Dictionary = metrics_cfg.get("zone_radius_tiles_max", {})
	var share_req: float = float(RoleCommon.resolve_min_threshold(share_cfg, cost_band, scenario_label))
	var events_req: float = float(RoleCommon.resolve_min_threshold(events_cfg, cost_band, scenario_label))
	var targets_req: float = float(RoleCommon.resolve_min_threshold(targets_cfg, cost_band, scenario_label))
	var time_req: float = float(RoleCommon.resolve_min_threshold(time_cfg, cost_band, scenario_label))
	var damage_req: float = float(RoleCommon.resolve_min_threshold(damage_cfg, cost_band, scenario_label))
	var radius_req: float = float(RoleCommon.resolve_min_threshold(radius_cfg, cost_band, scenario_label))
	if share_req <= 0.0:
		share_req = 0.55
	if events_req <= 0.0:
		events_req = 1.0
	if targets_req <= 0.0:
		targets_req = 1.0
	if time_req <= 0.0:
		time_req = 1.0
	if damage_req <= 0.0:
		damage_req = 1.0
	if radius_req <= 0.0:
		radius_req = 1.0

	var samples: Array[float] = []
	var direct_supported: bool = false
	var direct_samples: int = 0
	var direct_events: int = 0
	var direct_targets: int = 0
	var direct_time_s: float = 0.0
	var direct_damage: float = 0.0
	var direct_radius: float = 0.0
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		if _zone_exposure_supported(entry):
			direct_supported = true
			var zone_rec: Dictionary = _subject_zone_record(entry, side, subject_id)
			if not zone_rec.is_empty():
				direct_samples += 1
				direct_events += int(zone_rec.get("zone_exposure_events", 0))
				direct_targets = max(direct_targets, int(zone_rec.get("zone_exposure_targets", 0)))
				direct_time_s += float(zone_rec.get("zone_exposure_time_s", 0.0))
				direct_damage += float(zone_rec.get("zone_exposure_damage", 0.0))
				direct_radius = max(direct_radius, float(zone_rec.get("zone_radius_tiles_max", 0.0)))
		var kernels: Dictionary = entry.get("kernels", {})
		var pos: Dictionary = kernels.get("positioning", {})
		if not (pos is Dictionary):
			continue
		var side_block: Dictionary = pos.get(side, {})
		var v: float = float(side_block.get("frontline_zone_share", -1.0))
		if v >= 0.0:
			samples.append(v)

	var med: float = _median(samples)
	var events_pass: bool = direct_samples > 0 and float(direct_events) >= events_req
	var targets_pass: bool = direct_samples > 0 and float(direct_targets) >= targets_req
	var time_pass: bool = direct_samples > 0 and direct_time_s >= time_req
	var damage_pass: bool = direct_samples > 0 and direct_damage >= damage_req
	var radius_pass: bool = direct_samples > 0 and direct_radius >= radius_req
	var direct_k_cfg: Dictionary = cfg.get("k_of_n", {})
	var direct_k_required: int = int(direct_k_cfg.get("k", 2)) if (direct_k_cfg is Dictionary) else 2
	var direct_pass: bool = _k_of_n([events_pass, targets_pass, time_pass, damage_pass, radius_pass], max(1, direct_k_required))
	var fallback_pass: bool = (med >= share_req and samples.size() > 0)
	var pass_flag: bool = direct_pass if direct_supported else fallback_pass
	var reason: String = "direct_zone_exposure" if direct_supported else "zone_occupancy_fallback"
	if direct_supported and not direct_pass:
		reason = "no_direct_zone_exposure"
	elif samples.is_empty() and not direct_supported:
		reason = "no_samples"
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, reason)
	extras["direct_supported"] = direct_supported
	extras["direct_samples"] = direct_samples
	extras["fallback_pass"] = fallback_pass
	RoleCommon.append_span(spans, "subject_zone_exposure_events", direct_events, events_req, events_pass, extras)
	RoleCommon.append_span(spans, "subject_zone_exposure_targets", direct_targets, targets_req, targets_pass, extras)
	RoleCommon.append_span(spans, "subject_zone_exposure_time_s", direct_time_s, time_req, time_pass, extras)
	RoleCommon.append_span(spans, "subject_zone_exposure_damage", direct_damage, damage_req, damage_pass, extras)
	RoleCommon.append_span(spans, "subject_zone_radius_tiles_max", direct_radius, radius_req, radius_pass, extras)
	RoleCommon.append_span(spans, "subject_frontline_zone_share_med", med, share_req, fallback_pass, extras)

	var messages: Array = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("samples=%d" % samples.size())
	messages.append("mode=%s" % ("direct" if direct_supported else "fallback"))
	messages.append("direct_events=%d" % direct_events)
	messages.append("direct_targets=%d" % direct_targets)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "; ".join(messages)
	}

func _median(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var a: Array = []
	for v in arr:
		a.append(float(v))
	a.sort()
	var n: int = a.size()
	var mid: int = n / 2
	if (n % 2) == 1:
		return float(a[mid])
	return 0.5 * (float(a[mid - 1]) + float(a[mid]))

func _zone_exposure_supported(entry: Dictionary) -> bool:
	var kernels: Dictionary = entry.get("kernels", {})
	var zone_block: Dictionary = kernels.get("zone_exposure", {}) if (kernels is Dictionary) else {}
	return bool(zone_block.get("supported", false)) if (zone_block is Dictionary) else false

func _subject_zone_record(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var zone_block: Dictionary = kernels.get("zone_exposure", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = zone_block.get("per_unit", {}) if (zone_block is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var c: Dictionary = entry.get("context", {})
	var a: Array = c.get("team_a_ids", [])
	var b: Array = c.get("team_b_ids", [])
	var sid: String = String(subject_id)
	for x in a:
		if String(x) == sid:
			return "a"
	for y in b:
		if String(y) == sid:
			return "b"
	return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for k in sims.keys():
		var s: String = _subject_side(sims.get(k, {}), subject_id)
		if s != "":
			return s
	return ""

func _k_of_n(values: Array[bool], k_required: int) -> bool:
	var true_count: int = 0
	for value in values:
		if bool(value):
			true_count += 1
	return true_count >= int(k_required)
