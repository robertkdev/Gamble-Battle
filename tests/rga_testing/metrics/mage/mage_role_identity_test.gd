extends RefCounted

# Mage Role Identity Test
# Pass condition: 1-of-2 (magic-only)
#  - magic burst periodicity: top_2s_magic_damage_share
#  - magic burst periodicity: magic_peak_over_mean

const VERSION := "1.0.0"
const METRIC_ID := "role_mage_identity"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS = ["base"] # periodicity from hits; magic uses hit_components which are part of base analytics

func get_metadata() -> Dictionary:
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "required_capabilities": REQUIRED_CAPS,
        "description": "Mage identity via magic-only burst periodicity."
    }

func run_metric(payload: Dictionary = {}) -> Dictionary:
    var ctx: Dictionary = payload.get("context", {})
    var sims: Dictionary = ctx.get("sims", {}) if ctx is Dictionary else {}
    if sims.is_empty():
        return RoleCommon.fail_result([], ["no_sims_in_context"])

    var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)

    var thresholds_all: Dictionary = RoleCommon.load_thresholds()
    var cfg: Dictionary = RoleCommon.role_threshold(thresholds_all, "mage")
    var kcfg: Dictionary = cfg.get("k_of_n", {"k": 1, "n": 2})
    var metrics_cfg: Dictionary = cfg.get("metrics", {})
    var per_cfg: Dictionary = metrics_cfg.get("periodicity", {})

    var scenario_label: String = String(ctx.get("scenario", "neutral"))
    var assumed_cost_band: int = 3

    # periodicity any thresholds
    var per_any: Array = per_cfg.get("any", []) if per_cfg is Dictionary else []
    var per_top_req: float = _resolve_any(per_any, "top_2s_magic_damage_share", assumed_cost_band, scenario_label, 0.35)
    var per_peak_req: float = _resolve_any(per_any, "magic_peak_over_mean", assumed_cost_band, scenario_label, 1.7)
    var per_med: Dictionary = {"a": {"share": 0.0, "peak": 0.0}, "b": {"share": 0.0, "peak": 0.0}}
    var per_samples: Dictionary = {"a": [], "b": []}
    var peak_samples: Dictionary = {"a": [], "b": []}

    var subj_id: String = (String(subject_set.keys()[0]) if (subject_set is Dictionary and not subject_set.is_empty()) else "")
    var subj_front_proxy_samples: Array = []
    for key in sims.keys():
        var entry: Dictionary = sims.get(key, {})
        var kernels: Dictionary = entry.get("kernels", {})
        var per: Dictionary = kernels.get("periodicity", {})
        if per is Dictionary:
            for s in ["a","b"]:
                var obj: Dictionary = per.get(s, {})
                if obj is Dictionary:
                    if obj.has("top_2s_magic_damage_share"):
                        (per_samples[s] as Array).append(float(obj.get("top_2s_magic_damage_share", 0.0)))
                    if obj.has("magic_peak_over_mean"):
                        (peak_samples[s] as Array).append(float(obj.get("magic_peak_over_mean", 0.0)))

    per_med["a"]["share"] = RoleCommon.median(per_samples["a"])
    per_med["b"]["share"] = RoleCommon.median(per_samples["b"])
    per_med["a"]["peak"] = RoleCommon.median(peak_samples["a"])
    per_med["b"]["peak"] = RoleCommon.median(peak_samples["b"])

    var share_pass_a: bool = float(per_med["a"]["share"]) >= per_top_req
    var share_pass_b: bool = float(per_med["b"]["share"]) >= per_top_req
    var peak_pass_a: bool = float(per_med["a"]["peak"]) >= per_peak_req
    var peak_pass_b: bool = float(per_med["b"]["peak"]) >= per_peak_req
    var per_pass: Dictionary = {
        "a": (per_med["a"]["share"] >= per_top_req or per_med["a"]["peak"] >= per_peak_req),
        "b": (per_med["b"]["share"] >= per_top_req or per_med["b"]["peak"] >= per_peak_req)
    }

    var passes: Array = [bool(per_pass["a"]), bool(per_pass["b"]) ]
    var eval: Dictionary = RoleCommon.k_of_n(passes, int(kcfg.get("k", 1)), int(kcfg.get("n", 2)))

    var spans: Array = []
    var share_extra_a: Dictionary = {"periodicity_pass": bool(per_pass["a"])}
    var share_extra_b: Dictionary = {"periodicity_pass": bool(per_pass["b"])}
    var share_ok_a: Variant = share_pass_a
    var share_ok_b: Variant = share_pass_b
    if not share_pass_a and peak_pass_a:
        share_ok_a = null
        share_extra_a["reason"] = "alternate_magic_periodicity_evidence_satisfied"
    if not share_pass_b and peak_pass_b:
        share_ok_b = null
        share_extra_b["reason"] = "alternate_magic_periodicity_evidence_satisfied"
    RoleCommon.append_span(spans, "magic_share_med_a", per_med["a"]["share"], per_top_req, share_ok_a, share_extra_a)
    RoleCommon.append_span(spans, "magic_peak_over_mean_med_a", per_med["a"]["peak"], per_peak_req, peak_pass_a, {"periodicity_pass": bool(per_pass["a"])})
    RoleCommon.append_span(spans, "magic_share_med_b", per_med["b"]["share"], per_top_req, share_ok_b, share_extra_b)
    RoleCommon.append_span(spans, "magic_peak_over_mean_med_b", per_med["b"]["peak"], per_peak_req, peak_pass_b, {"periodicity_pass": bool(per_pass["b"])})

    var messages: Array = []
    messages.append("scenario=%s" % scenario_label)

    if subject_set is Dictionary and not subject_set.is_empty():
        var sidex: String = _any_side_for_subject(sims, subj_id)
        var per_side_pass: bool = bool(per_pass.get(sidex, false))
        var pass_subj: bool = per_side_pass
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
