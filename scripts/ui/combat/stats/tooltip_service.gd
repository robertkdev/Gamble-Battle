extends Object
class_name StatsTooltipService

const F := preload("res://scripts/ui/combat/stats/formatters.gd")

# Returns a multiline tooltip for a scoreboard row.
# params:
#  - metric: String (e.g., "damage", "taken", "dps", "casts")
#  - window: String ("ALL" | "3S")
#  - value: float (row absolute value for selected metric)
#  - share: float (0..1 for normalized bar)
#  - unit_name: String
#  - team_total: float (sum over team for this metric+window)
#  - breakdown: Dictionary (optional), e.g., { physical, magic, true }
static func row_tooltip(metric: String, window: String, value: float, share: float, unit_name: String = "", team_total: float = 0.0, breakdown: Dictionary = {}) -> String:
    var lines: Array[String] = []
    var title := (unit_name if unit_name != "" else "Unit") + " — " + _metric_label(metric)
    lines.append(title)

    var wl := _window_label(window)
    var val_str := F.compact(value)
    var pct := F.percent01(clamp(share, 0.0, 1.0), 0)
    var base := "%s (%s)" % [val_str, wl]
    if team_total > 0.0 and metric != "dps":
        base += "  •  %s of team" % pct
    lines.append(base)

    if metric == "dps" and window == "ALL":
        # For ALL DPS, clarify that it is avg over time_alive
        lines.append("Avg over time alive")
    if metric == "focus":
        lines.append("Top target share")

    if breakdown != null and not breakdown.is_empty():
        var bparts: Array[String] = []
        if breakdown.has("physical"):
            bparts.append("Phys " + F.compact(breakdown.get("physical", 0)))
        if breakdown.has("magic"):
            bparts.append("Mag " + F.compact(breakdown.get("magic", 0)))
        if breakdown.has("true"):
            bparts.append("True " + F.compact(breakdown.get("true", 0)))
        if not bparts.is_empty():
            lines.append("Breakdown: " + ", ".join(bparts))

    return "\n".join(lines)

static func _window_label(w: String) -> String:
    match String(w):
        "3S":
            return "last 3s"
        _:
            return "all"

static func _metric_label(m: String) -> String:
    match String(m):
        "damage":
            return "Damage"
        "taken":
            return "Damage Taken"
        "dps":
            return "DPS"
        "casts":
            return "Casts"
        "healing":
            return "Healing"
        "overheal":
            return "Overheal"
        "absorbed":
            return "Shield Absorbed"
        "mitigated":
            return "Mitigated"
        "hps":
            return "HPS"
        "cc_inflicted":
            return "CC Inflicted"
        "cc_received":
            return "CC Received"
        "kills":
            return "Kills"
        "deaths":
            return "Deaths"
        "time":
            return "Time Alive"
        "focus":
            return "Focus%"
        _:
            return m.capitalize()
