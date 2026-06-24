extends RefCounted

# Support Role Identity Test
# Pass condition: 1-of-2
#  - buff/debuff presence per ally >= threshold (requires events)
#  - proxies (any): ehp_ratio OR peel_saves

const VERSION := "1.0.0"
const METRIC_ID := "role_support_identity"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS = ["base"] # buff events optional; proxies work with base/cc/targets

func get_metadata() -> Dictionary:
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "required_capabilities": REQUIRED_CAPS,
        "description": "Support identity via buff/debuff presence or proxies (eHP ratio or peel saves)."
    }

func run_metric(payload: Dictionary = {}) -> Dictionary:
    var ctx: Dictionary = payload.get("context", {})
    var sims: Dictionary = ctx.get("sims", {}) if ctx is Dictionary else {}
    if sims.is_empty():
        return RoleCommon.fail_result([], ["no_sims_in_context"])

    var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)

    var thresholds_all: Dictionary = RoleCommon.load_thresholds()
    var cfg: Dictionary = RoleCommon.role_threshold(thresholds_all, "support")
    var kcfg: Dictionary = cfg.get("k_of_n", {"k": 1, "n": 2})
    var metrics_cfg: Dictionary = cfg.get("metrics", {})
    var bp_cfg: Dictionary = metrics_cfg.get("buff_presence", {})
    var proxies_cfg: Dictionary = metrics_cfg.get("proxies", {})

    var scenario_label: String = String(ctx.get("scenario", "neutral"))
    var assumed_cost_band: int = 3

    var events_req: Array = bp_cfg.get("requires_events", []) if bp_cfg is Dictionary else []
    var per_ally_cfg: Dictionary = bp_cfg.get("events_per_ally_min", {})
    var per_ally_min: float = float(RoleCommon.resolve_min_threshold(per_ally_cfg, assumed_cost_band, scenario_label))

    var proxy_any: Array = proxies_cfg.get("any", []) if proxies_cfg is Dictionary else []
    var ehp_min: float = _resolve_any(proxy_any, "ehp_ratio", assumed_cost_band, scenario_label, 0.15)
    var peel_min: float = _resolve_any(proxy_any, "peel_saves", assumed_cost_band, scenario_label, 1.0)

    # Aggregators across sims
    var per_ally_vals: Dictionary = {"a": [], "b": []}
    var peel_vals: Dictionary = {"a": [], "b": []}
    # Accumulator for eHP proxy components per side
    var ehp_acc: Dictionary = {"a": {"opp_damage": 0.0, "healing_plus_shield": 0.0}, "b": {"opp_damage": 0.0, "healing_plus_shield": 0.0}}
    var events_supported: bool = false

    var subj_id: String = (String(subject_set.keys()[0]) if (subject_set is Dictionary and not subject_set.is_empty()) else "")
    var subj_incoming_total: float = 0.0
    var subj_heal_total: float = 0.0
    var subj_shield_total: float = 0.0
    var subj_support_events: int = 0
    var subj_ally_buff_events: int = 0
    var subj_ally_buff_magnitude: float = 0.0
    var subj_cc_immunity: int = 0
    var subj_cleanse_applied: int = 0
    var subj_considered: int = 0
    for key in sims.keys():
        var entry: Dictionary = sims.get(key, {})
        var kernels: Dictionary = entry.get("kernels", {})
        var teams: Dictionary = entry.get("teams", {})
        var ta: Dictionary = teams.get("a", {})
        var tb: Dictionary = teams.get("b", {})
        var dmg_a_out: float = float(ta.get("damage", 0))
        var dmg_b_out: float = float(tb.get("damage", 0))
        # Denominator: opponent damage dealt
        ehp_acc["a"]["opp_damage"] = float(ehp_acc["a"].get("opp_damage", 0.0)) + dmg_b_out
        ehp_acc["b"]["opp_damage"] = float(ehp_acc["b"].get("opp_damage", 0.0)) + dmg_a_out
        # Numerator: (healing + shield) for our team
        ehp_acc["a"]["healing_plus_shield"] = float(ehp_acc["a"].get("healing_plus_shield", 0.0)) + float(ta.get("healing", 0)) + float(ta.get("shield", 0))
        ehp_acc["b"]["healing_plus_shield"] = float(ehp_acc["b"].get("healing_plus_shield", 0.0)) + float(tb.get("healing", 0)) + float(tb.get("shield", 0))

        var der: Dictionary = entry.get("derived", {})
        if der is Dictionary:
            for s in ["a","b"]:
                var obj: Dictionary = der.get(s, {})
                if obj is Dictionary and obj.has("peel_saves"):
                    (peel_vals[s] as Array).append(float(obj.get("peel_saves", 0)))

        var bp: Dictionary = kernels.get("buff_presence", {})
        if bp is Dictionary:
            if bool(bp.get("supported", false)):
                events_supported = true
            for s2 in ["a","b"]:
                var obj2: Dictionary = bp.get(s2, {})
                if obj2 is Dictionary and obj2.has("events_per_ally"):
                    (per_ally_vals[s2] as Array).append(float(obj2.get("events_per_ally", 0.0)))
        # Subject per-unit EHP attribution using kernels.support
        if subj_id != "":
            var side: String = _subject_side(entry, subj_id)
            if side != "":
                subj_considered += 1
                var units: Dictionary = entry.get("units", {})
                var arr: Array = units.get(side, [])
                if arr is Array:
                    for u in arr:
                        if u is Dictionary and String(u.get("unit_id", "")) == subj_id:
                            subj_incoming_total += float(u.get("incoming", 0.0))
                            break
                var support: Dictionary = kernels.get("support", {})
                if support is Dictionary:
                    var heal_map: Dictionary = support.get("healing_per_unit", {})
                    var side_heal: Dictionary = heal_map.get(side, {}) if heal_map is Dictionary else {}
                    if side_heal is Dictionary and side_heal.has(subj_id):
                        var hr: Dictionary = side_heal.get(subj_id, {})
                        subj_heal_total += float(hr.get("healed", 0)) + float(hr.get("overheal", 0))
                    var sh_map: Dictionary = support.get("shield_absorbed_per_unit", {})
                    var side_sh: Dictionary = sh_map.get(side, {}) if sh_map is Dictionary else {}
                    if side_sh is Dictionary and side_sh.has(subj_id):
                        var sr: Dictionary = side_sh.get(subj_id, {})
                        subj_shield_total += float(sr.get("absorbed", 0))
                var subject_buff: Dictionary = _subject_buff_source(entry, side, subj_id)
                if not subject_buff.is_empty():
                    var ally_buffs_to_others: int = int(subject_buff.get("ally_buffs_to_others", 0))
                    var cleanse_applied: int = int(subject_buff.get("cleanse_applied", 0))
                    subj_ally_buff_events += ally_buffs_to_others
                    subj_ally_buff_magnitude += float(subject_buff.get("ally_buff_magnitude_to_others", 0.0))
                    subj_cc_immunity += int(subject_buff.get("cc_immunity", 0))
                    subj_cleanse_applied += cleanse_applied
                    subj_support_events += ally_buffs_to_others + int(subject_buff.get("enemy_debuffs", 0)) + cleanse_applied

    var per_ally_med: Dictionary = {"a": RoleCommon.median(per_ally_vals["a"]), "b": RoleCommon.median(per_ally_vals["b"]) }
    var peel_med: Dictionary = {"a": RoleCommon.median(peel_vals["a"]), "b": RoleCommon.median(peel_vals["b"]) }
    var ehp_ratio: Dictionary = {"a": 0.0, "b": 0.0}
    for s3 in ["a","b"]:
        var denom: float = float(ehp_acc[s3].get("opp_damage", 0.0))
        var numer: float = float(ehp_acc[s3].get("healing_plus_shield", 0.0))
        ehp_ratio[s3] = (numer / max(1.0, denom)) if denom > 0.0 else 0.0

    var bp_pass: Dictionary = {"a": false, "b": false}
    if events_supported and per_ally_min > 0.0:
        bp_pass["a"] = (per_ally_med["a"] >= per_ally_min)
        bp_pass["b"] = (per_ally_med["b"] >= per_ally_min)

    var proxy_pass: Dictionary = {"a": false, "b": false}
    var ehp_pass: Dictionary = {"a": false, "b": false}
    var peel_pass: Dictionary = {"a": false, "b": false}
    for s4 in ["a","b"]:
        var ok_ehp: bool = (ehp_ratio[s4] >= ehp_min)
        var ok_peel: bool = (peel_med[s4] >= peel_min)
        ehp_pass[s4] = ok_ehp
        peel_pass[s4] = ok_peel
        proxy_pass[s4] = (ok_ehp or ok_peel)

    # 1-of-2 per side
    var side_pass: Dictionary = {"a": (bp_pass["a"] or proxy_pass["a"]), "b": (bp_pass["b"] or proxy_pass["b"]) }
    var eval: Dictionary = RoleCommon.k_of_n([side_pass["a"], side_pass["b"]], int(kcfg.get("k", 1)), int(kcfg.get("n", 2)))

    var spans: Array = []
    RoleCommon.append_span(spans, "events_per_ally_med_a", per_ally_med["a"], per_ally_min, bp_pass["a"], {"events_supported": events_supported})
    RoleCommon.append_span(spans, "events_per_ally_med_b", per_ally_med["b"], per_ally_min, bp_pass["b"], {"events_supported": events_supported})
    RoleCommon.append_span(spans, "ehp_ratio_a", ehp_ratio["a"], ehp_min, bool(ehp_pass["a"]))
    RoleCommon.append_span(spans, "ehp_ratio_b", ehp_ratio["b"], ehp_min, bool(ehp_pass["b"]))
    RoleCommon.append_span(spans, "peel_saves_med_a", peel_med["a"], peel_min, bool(peel_pass["a"]))
    RoleCommon.append_span(spans, "peel_saves_med_b", peel_med["b"], peel_min, bool(peel_pass["b"]))

    var messages: Array = []
    if not events_supported:
        messages.append("buff_presence_unsupported; using_proxies")
    messages.append("scenario=%s" % scenario_label)

    if subject_set is Dictionary and not subject_set.is_empty():
        var subj_ehp_ratio: float = ( (subj_heal_total + subj_shield_total) / max(1.0, subj_incoming_total) )
        var ok_ehp: bool = (subj_ehp_ratio >= ehp_min)
        var ok_subject_support: bool = (subj_support_events >= 1)
        var ok_subject_magnitude: bool = (subj_ally_buff_magnitude >= 25.0)
        var sidex: String = _any_side_for_subject(sims, subj_id)
        var ex: Dictionary = RoleCommon.subject_extras(sidex, subj_id, ("no_samples" if subj_considered <= 0 else ""))
        ex["incoming_total"] = subj_incoming_total
        ex["healed_total"] = subj_heal_total
        ex["shield_absorbed_total"] = subj_shield_total
        ex["subject_support_events"] = subj_support_events
        ex["subject_ally_buff_events"] = subj_ally_buff_events
        ex["subject_ally_buff_magnitude"] = subj_ally_buff_magnitude
        ex["subject_cc_immunity"] = subj_cc_immunity
        ex["subject_cleanse_applied"] = subj_cleanse_applied
        RoleCommon.append_span(spans, "subject_ehp_ratio", subj_ehp_ratio, ehp_min, ok_ehp, ex)
        RoleCommon.append_span(spans, "subject_support_events", subj_support_events, 1.0, ok_subject_support, ex)
        RoleCommon.append_span(spans, "subject_support_ally_buff_magnitude", subj_ally_buff_magnitude, 25.0, ok_subject_magnitude, ex)
        RoleCommon.append_span(spans, "subject_support_cc_immunity", subj_cc_immunity, 1.0, subj_cc_immunity >= 1, ex)
        RoleCommon.append_span(spans, "subject_support_cleanse_applied", subj_cleanse_applied, 1.0, subj_cleanse_applied >= 1, ex)
        var pass_subj: bool = (ok_ehp or ok_subject_support or ok_subject_magnitude or (peel_med.get(sidex, 0.0) >= peel_min))
        return {
            "id": METRIC_ID,
            "version": VERSION,
            "pass": pass_subj,
            "spans": spans,
            "message": "; ".join(messages)
        }

    return {
        "id": METRIC_ID,
        "version": VERSION,
        "pass": bool(eval.get("pass", false)),
        "spans": spans,
        "message": "; ".join(messages)
    }

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

func _subject_buff_source(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
    var kernels: Dictionary = entry.get("kernels", {})
    var buff_presence: Dictionary = kernels.get("buff_presence", {}) if (kernels is Dictionary) else {}
    var per_unit: Dictionary = buff_presence.get("per_unit", {}) if (buff_presence is Dictionary) else {}
    var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
    var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
    return rec if rec is Dictionary else {}

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
    for k in sims.keys():
        var s: String = _subject_side(sims.get(k, {}), subject_id)
        if s != "":
            return s
    return "a"

func _resolve_any(list: Array, metric_name: String, cost: int, scenario: String, def: float) -> float:
    if list == null:
        return def
    for entry in list:
        if entry is Dictionary and String(entry.get("metric", "")) == metric_name:
            return float(RoleCommon.resolve_min_threshold(entry, cost, scenario))
    return def
