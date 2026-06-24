extends RefCounted
class_name RolesThresholdsChecker

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

static func check(thresholds: Dictionary) -> Dictionary:
    var warnings: Array[String] = []
    var critical_missing: Array[Dictionary] = []
    if thresholds == null or not (thresholds is Dictionary):
        warnings.append("thresholds: missing or not a dictionary")
        return {"ok": false, "warnings": warnings, "missing": [{"where": "root", "what": "roles"}]}
    var roles: Dictionary = thresholds.get("roles", {})
    if not (roles is Dictionary):
        warnings.append("thresholds.roles: missing or not a dictionary")
        return {"ok": false, "warnings": warnings, "missing": [{"where": "root", "what": "roles"}]}
    # Required role ids
    var req_roles: Array[String] = ["tank","brawler","marksman","assassin","mage","support"]
    for r in req_roles:
        var cfg = roles.get(r, null)
        if not (cfg is Dictionary):
            warnings.append("roles." + r + ": missing")
            critical_missing.append({"role": r, "what": "role_cfg"})
            continue
        var metrics = (cfg as Dictionary).get("metrics", null)
        if not (metrics is Dictionary):
            warnings.append("roles." + r + ".metrics: missing")
            critical_missing.append({"role": r, "what": "metrics"})
            continue
        match r:
            "tank":
                if not metrics.has("focus_survival_s"):
                    warnings.append("roles.tank.metrics.focus_survival_s: missing (will fallback to time_alive)")
                var fallback = (cfg as Dictionary).get("fallback", {})
                if not (fallback is Dictionary) or not (fallback as Dictionary).has("time_alive_s"):
                    warnings.append("roles.tank.fallback.time_alive_s: missing")
            "brawler":
                if not metrics.has("sustained_damage_rate"):
                    warnings.append("roles.brawler.metrics.sustained_damage_rate: missing")
                    critical_missing.append({"role": r, "what": "sustained_damage_rate"})
                if not metrics.has("can_take_damage"):
                    warnings.append("roles.brawler.metrics.can_take_damage: missing")
            "marksman":
                var ok1: bool = metrics.has("sustained_damage_rate")
                var ok2: bool = metrics.has("backline_zone_share")
                if not ok1 or not ok2:
                    warnings.append("roles.marksman.metrics: need sustained_damage_rate and backline_zone_share")
                    if not ok1:
                        critical_missing.append({"role": r, "what": "sustained_damage_rate"})
                    if not ok2:
                        critical_missing.append({"role": r, "what": "backline_zone_share"})
            "assassin":
                if not metrics.has("first_backline_contact"):
                    warnings.append("roles.assassin.metrics.first_backline_contact: missing")
                    critical_missing.append({"role": r, "what": "first_backline_contact"})
            "mage":
                if not metrics.has("periodicity"):
                    warnings.append("roles.mage.metrics.periodicity: missing")
                    critical_missing.append({"role": r, "what": "periodicity"})
                if not metrics.has("frontline_first"):
                    warnings.append("roles.mage.metrics.frontline_first: missing")
            "support":
                if not metrics.has("buff_presence") and not metrics.has("proxies"):
                    warnings.append("roles.support.metrics: expected buff_presence or proxies")
            _:
                pass
    var ok: bool = (critical_missing.size() == 0)
    return {"ok": ok, "warnings": warnings, "missing": critical_missing}

static func check_and_warn() -> void:
    var th: Dictionary = RoleCommon.load_thresholds()
    var res: Dictionary = check(th)
    var warns: Array = res.get("warnings", [])
    for w in warns:
        push_warning("ThresholdsChecker: " + String(w))
    if not bool(res.get("ok", false)) and warns.size() == 0:
        push_warning("ThresholdsChecker: thresholds present but critical items missing")
