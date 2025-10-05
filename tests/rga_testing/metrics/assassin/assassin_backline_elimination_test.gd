extends RefCounted

const REQUIRED_CAPS := PackedStringArray(["base", "targets"])
const VERSION := "1.0.0"
const METRIC_ID := "assassin_backline_elimination"

func get_metadata() -> Dictionary:
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "required_capabilities": REQUIRED_CAPS,
        "description": "Checks that assassin carries eliminate opposing carries within acceptable TTK."\n}

func run_metric(payload: Dictionary = {}) -> Dictionary:
    var context: Dictionary = payload.get("context", {})
    var derived: Dictionary = context.get("derived", {})
    var team_a: Dictionary = derived.get("a", {})
    var team_b: Dictionary = derived.get("b", {})

    var spans: Array = []
    var pass := true
    var messages: Array = []

    var ttk_a := float(team_a.get("ttk_on_carry_s", -1.0))
    var ttk_b := float(team_b.get("ttk_on_carry_s", -1.0))

    if ttk_a < 0.0 or ttk_b < 0.0:
        pass = false
        messages.append("Missing TTK data in derived stats.")
    else:
        spans.append({
            "label": "team_a_ttk_on_carry_s",
            "value": ttk_a
        })
        spans.append({
            "label": "team_b_ttk_on_carry_s",
            "value": ttk_b
        })
        if ttk_a > 12.0:
            pass = false
            messages.append("Team A assassin TTK exceeds 12s threshold.")
        if ttk_b > 15.0:
            pass = false
            messages.append("Team B counter TTK exceeds 15s threshold.")
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "pass": pass,
        "spans": spans,
        "message": "; ".join(messages)
    }
