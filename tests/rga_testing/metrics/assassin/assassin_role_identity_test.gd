extends RefCounted

# Assassin Role Identity Test
# Pass condition: 1-of-1
#  - first_backline_contact rank = 1 in ≥ pass_fraction sims AND within time bound
# Uses backline_access kernel; falls back by skipping when unsupported.

const VERSION := "1.0.0"
const METRIC_ID := "role_assassin_identity"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS = ["targets"] # prefers targets; mobility/zones improve accuracy

func get_metadata() -> Dictionary:
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "required_capabilities": REQUIRED_CAPS,
        "description": "Assassin identity via subject backline access, with cast-relative support for mana-gated assassins."
    }

func run_metric(payload: Dictionary = {}) -> Dictionary:
    var ctx: Dictionary = payload.get("context", {})
    var sims: Dictionary = ctx.get("sims", {}) if ctx is Dictionary else {}
    if sims.is_empty():
        return RoleCommon.fail_result([], ["no_sims_in_context"])

    var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)

    var thresholds_all: Dictionary = RoleCommon.load_thresholds()
    var cfg: Dictionary = RoleCommon.role_threshold(thresholds_all, "assassin")
    var metrics_cfg: Dictionary = cfg.get("metrics", {})
    var bc_cfg: Dictionary = metrics_cfg.get("first_backline_contact", {})
    var pass_frac_cfg: Dictionary = bc_cfg.get("pass_fraction", {})
    var time_cfg: Dictionary = bc_cfg.get("time_s", {})
    var cast_window_cfg: Dictionary = bc_cfg.get("cast_window_s", {})
    var cast_grace_cfg: Dictionary = bc_cfg.get("cast_pre_signal_grace_s", {})

    var scenario_label := String(ctx.get("scenario", "neutral"))
    var assumed_cost_band := 3

    var pass_frac_req := float(RoleCommon.resolve_min_threshold(pass_frac_cfg, assumed_cost_band, scenario_label))
    var time_bound := float(RoleCommon.resolve_max_threshold(time_cfg, assumed_cost_band, scenario_label))
    var cast_window_s: float = float(RoleCommon.resolve_max_threshold(cast_window_cfg, assumed_cost_band, scenario_label))
    var cast_pre_signal_grace_s: float = float(RoleCommon.resolve_max_threshold(cast_grace_cfg, assumed_cost_band, scenario_label))
    if time_bound <= 0.0:
        time_bound = 3.5
    if cast_window_s <= 0.0:
        cast_window_s = 1.5
    if cast_pre_signal_grace_s <= 0.0:
        cast_pre_signal_grace_s = 0.1

    var total_considered := 0
    var a_first_count := 0
    var b_first_count := 0
    var spans: Array = []

    var unsupported_count := 0
    for key in sims.keys():
        var entry: Dictionary = sims.get(key, {})
        var kernels: Dictionary = entry.get("kernels", {})
        var ba: Dictionary = kernels.get("backline_access", {})
        var supported := (ba is Dictionary and bool(ba.get("supported", false)))
        if supported:
            var a_obj: Dictionary = ba.get("a", {})
            var b_obj: Dictionary = ba.get("b", {})
            var a_t = a_obj.get("first_backline_contact_s", null)
            var b_t = b_obj.get("first_backline_contact_s", null)
            var a_ok := (typeof(a_t) == TYPE_FLOAT or typeof(a_t) == TYPE_INT)
            var b_ok := (typeof(b_t) == TYPE_FLOAT or typeof(b_t) == TYPE_INT)
            if not a_ok and not b_ok:
                continue
            var at := (float(a_t) if a_ok else INF)
            var bt := (float(b_t) if b_ok else INF)
            if at == INF and bt == INF:
                continue
            total_considered += 1
            if at <= bt and at <= time_bound:
                a_first_count += 1
            elif bt < at and bt <= time_bound:
                b_first_count += 1
        else:
            # Fallback: use frontline_window kernel (presence of backline share within window)
            unsupported_count += 1
            var flw: Dictionary = kernels.get("frontline_window", {})
            if flw is Dictionary and bool(flw.get("supported", false)):
                var a_fw: Dictionary = flw.get("a", {})
                var b_fw: Dictionary = flw.get("b", {})
                var a_bl: float = float(a_fw.get("backline_share_0_4s", 0.0))
                var b_bl: float = float(b_fw.get("backline_share_0_4s", 0.0))
                # Only consider decisive cases in the time window
                if a_bl > 0.0 or b_bl > 0.0:
                    total_considered += 1
                    if a_bl > 0.0 and b_bl <= 0.0:
                        a_first_count += 1
                    elif b_bl > 0.0 and a_bl <= 0.0:
                        b_first_count += 1

    var a_frac: float = float(a_first_count) / max(1.0, float(total_considered))
    var b_frac: float = float(b_first_count) / max(1.0, float(total_considered))
    var a_pass: bool = (a_frac >= pass_frac_req)
    var b_pass: bool = (b_frac >= pass_frac_req)
    var a_span_ok: Variant = a_pass
    var b_span_ok: Variant = b_pass
    var a_reason_str: String = ("" if total_considered > 0 else "kernel_unsupported")
    var b_reason_str: String = a_reason_str

    var messages: Array = []
    messages.append("scenario=%s" % scenario_label)
    if total_considered <= 0:
        messages.append("backline_access_unsupported_or_no_samples")
    messages.append("total_considered=%d" % total_considered)

    # If subject specified, compute subject-only fraction using unit_id attribution
    if subject_set is Dictionary and not subject_set.is_empty():
        var subj_id := String(subject_set.keys()[0])
        var subj_considered := 0
        var subj_success := 0
        var subj_contact_s: float = -1.0
        var subj_first_cast_s: float = -1.0
        var subj_success_reason: String = ""
        for key2 in sims.keys():
            var e2: Dictionary = sims.get(key2, {})
            var k2: Dictionary = e2.get("kernels", {})
            var ba2: Dictionary = k2.get("backline_access", {})
            if not (ba2 is Dictionary) or not bool(ba2.get("supported", false)):
                continue
            var s_side := _subject_side(e2, subj_id)
            if s_side == "":
                continue
            var sobj: Dictionary = ba2.get(s_side, {})
            var entered_by_unit: Dictionary = sobj.get("entered_by_unit", {})
            var tt = entered_by_unit.get(subj_id, null)
            var have := (typeof(tt) == TYPE_FLOAT or typeof(tt) == TYPE_INT)
            subj_considered += 1
            if not have:
                continue
            var contact_s: float = float(tt)
            var first_cast_s: float = _subject_first_cast_s(e2, subj_id, s_side)
            var fast_contact_ok: bool = contact_s <= time_bound
            var cast_relative_ok: bool = first_cast_s >= 0.0 and contact_s >= (first_cast_s - cast_pre_signal_grace_s) and (contact_s - first_cast_s) <= cast_window_s
            if subj_contact_s < 0.0 or contact_s < subj_contact_s:
                subj_contact_s = contact_s
                subj_first_cast_s = first_cast_s
            if fast_contact_ok or cast_relative_ok:
                subj_success += 1
                subj_success_reason = ("fast_contact" if fast_contact_ok else "cast_relative_contact")
        var frac_subj: float = float(subj_success) / max(1.0, float(subj_considered))
        var pass_subj: bool = (frac_subj >= pass_frac_req)
        var sx: String = _any_side_for_subject(sims, subj_id)
        if pass_subj and sx == "a" and not a_pass:
            a_span_ok = null
            a_reason_str = "alternate_subject_backline_evidence_satisfied"
        elif pass_subj and sx == "b" and not b_pass:
            b_span_ok = null
            b_reason_str = "alternate_subject_backline_evidence_satisfied"
        RoleCommon.append_span(spans, "a_first_frac", a_frac, pass_frac_req, a_span_ok, {"time_bound_s": time_bound, "backline_access_supported": (total_considered > 0), "reason": a_reason_str})
        RoleCommon.append_span(spans, "b_first_frac", b_frac, pass_frac_req, b_span_ok, {"time_bound_s": time_bound, "backline_access_supported": (total_considered > 0), "reason": b_reason_str})
        var ex: Dictionary = RoleCommon.subject_extras(sx, subj_id, ("kernel_unsupported" if subj_considered <= 0 else ""))
        ex["time_bound_s"] = time_bound
        ex["cast_window_s"] = cast_window_s
        ex["cast_pre_signal_grace_s"] = cast_pre_signal_grace_s
        ex["subject_first_backline_contact_s"] = subj_contact_s
        ex["subject_first_cast_s"] = subj_first_cast_s
        ex["subject_considered"] = subj_considered
        ex["subject_success"] = subj_success
        ex["success_reason"] = subj_success_reason
        RoleCommon.append_span(spans, "subject_first_backline_frac", frac_subj, pass_frac_req, pass_subj, ex)
        return {
            "id": METRIC_ID,
            "version": VERSION,
            "pass": pass_subj,
            "spans": spans,
            "message": "; ".join(messages)
        }

    RoleCommon.append_span(spans, "a_first_frac", a_frac, pass_frac_req, a_span_ok, {"time_bound_s": time_bound, "backline_access_supported": (total_considered > 0), "reason": a_reason_str})
    RoleCommon.append_span(spans, "b_first_frac", b_frac, pass_frac_req, b_span_ok, {"time_bound_s": time_bound, "backline_access_supported": (total_considered > 0), "reason": b_reason_str})
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "pass": (a_pass or b_pass),
        "spans": spans,
        "message": "; ".join(messages)
    }

func _subject_side(entry: Dictionary, subject_id: String) -> String:
    var c: Dictionary = entry.get("context", {})
    var a: Array = c.get("team_a_ids", [])
    var b: Array = c.get("team_b_ids", [])
    var sid := String(subject_id)
    for x in a:
        if String(x) == sid:
            return "a"
    for y in b:
        if String(y) == sid:
            return "b"
    return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
    for k in sims.keys():
        var s := _subject_side(sims.get(k, {}), subject_id)
        if s != "":
            return s
    return "a"

func _subject_first_cast_s(entry: Dictionary, subject_id: String, side: String) -> float:
    var units: Dictionary = entry.get("units", {})
    if not (units is Dictionary):
        return -1.0
    var arr: Array = units.get(side, [])
    if not (arr is Array):
        return -1.0
    for v in arr:
        if not (v is Dictionary):
            continue
        var unit_entry: Dictionary = v
        if String(unit_entry.get("unit_id", "")) != subject_id:
            continue
        return float(unit_entry.get("first_cast_s", -1.0))
    return -1.0
