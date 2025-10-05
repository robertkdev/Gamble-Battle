extends RefCounted
class_name RGAInvariants

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")

# Validates per-simulation invariants given telemetry aggregates and optional event stream.
# Returns an Array of issues (each issue is a Dictionary with {message, details}).
# An empty array means the row passed all invariants.
static func validate(row: DataModels.TelemetryRow) -> Array:
    var issues: Array = []
    if row == null:
        issues.append({"message": "row_null"})
        return issues
    var aggregates: Dictionary = row.aggregates if row.aggregates != null else {}
    issues.append_array(_check_damage_conservation(aggregates))
    issues.append_array(_check_non_negative_ehp(aggregates))
    issues.append_array(_check_monotonic_events(row.events))
    return issues

static func fail_fast(row: DataModels.TelemetryRow) -> void:
    var issues := validate(row)
    if issues.size() > 0:
        var msg_parts: Array[String] = []
        for issue in issues:
            msg_parts.append(str(issue))
        push_error("RGA invariants failed: %s" % ";".join(msg_parts))
        assert(false)

static func _check_damage_conservation(aggregates: Dictionary) -> Array:
    var issues: Array = []
    if aggregates == null:
        return issues
    var teams: Dictionary = aggregates.get("teams", {})
    if teams == null or teams.is_empty():
        return issues
    # Basic conservation: total damage dealt by A should equal damage taken by B (kills + shields ignored for now)
    var team_a: Dictionary = teams.get("a", {})
    var team_b: Dictionary = teams.get("b", {})
    if not (team_a is Dictionary and team_b is Dictionary):
        return issues
    var dmg_a := _safe_int(team_a.get("damage", 0))
    var dmg_b := _safe_int(team_b.get("damage", 0))
    var deaths_a := _safe_int(team_a.get("deaths", 0))
    var deaths_b := _safe_int(team_b.get("deaths", 0))
    var mitigated_a := _safe_int(team_a.get("mitigated", 0))
    var mitigated_b := _safe_int(team_b.get("mitigated", 0))
    var shield_a := _safe_int(team_a.get("shield", 0))
    var shield_b := _safe_int(team_b.get("shield", 0))

    var lhs := dmg_a + mitigated_b + shield_b
    var rhs := dmg_b + mitigated_a + shield_a
    var delta := abs(lhs - rhs)
    # Allow minor discrepancy for rounding/int conversions. Use 1 as epsilon for integer values.
    if delta > 1:
        issues.append({
            "message": "damage_conservation",
            "details": {"team_a_damage": lhs, "team_b_damage": rhs, "delta": delta, "team_a_mitigated": mitigated_a, "team_b_mitigated": mitigated_b, "team_a_shield": shield_a, "team_b_shield": shield_b, "team_a_overkill": _safe_int(team_a.get("overkill", 0)), "team_b_overkill": _safe_int(team_b.get("overkill", 0)), "team_a_deaths": deaths_a, "team_b_deaths": deaths_b},
        })
    return issues

static func _check_non_negative_ehp(aggregates: Dictionary) -> Array:
    var issues: Array = []
    if aggregates == null:
        return issues
    var teams: Dictionary = aggregates.get("teams", {})
    if teams == null:
        return issues
    for key in ["a", "b"]:
        var team: Dictionary = teams.get(key, {})
        if not (team is Dictionary):
            continue
        if _safe_int(team.get("damage", 0)) < 0:
            issues.append({"message": "negative_damage", "details": {"team": key, "value": team.get("damage")}})
        if _safe_int(team.get("healing", 0)) < 0:
            issues.append({"message": "negative_healing", "details": {"team": key, "value": team.get("healing")}})
        if _safe_int(team.get("shield", 0)) < 0:
            issues.append({"message": "negative_shield", "details": {"team": key, "value": team.get("shield")}})
        if _safe_int(team.get("mitigated", 0)) < 0:
            issues.append({"message": "negative_mitigated", "details": {"team": key, "value": team.get("mitigated")}})
        if _safe_int(team.get("overkill", 0)) < 0:
            issues.append({"message": "negative_overkill", "details": {"team": key, "value": team.get("overkill")}})
    return issues

static func _check_monotonic_events(events: Array) -> Array:
    var issues: Array = []
    if events == null or events.size() == 0:
        return issues
    var last_t := -INF
    for evt in events:
        if not (evt is Dictionary):
            continue
        var t := float(evt.get("t_s", last_t))
        if t < last_t:
            issues.append({
                "message": "events_not_monotonic",
                "details": {"previous": last_t, "current": t, "event": evt}
            })
            break
        last_t = t
    return issues

static func _safe_int(v) -> int:
    if v is int:
        return v
    if v is float:
        return int(round(v))
    var s := str(v)
    if s.is_valid_int():
        return int(s)
    if s.is_valid_float():
        return int(round(float(s)))
    return 0
