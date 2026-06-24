extends RefCounted

const REQUIRED_CAPS = ["base", "targets"]
const VERSION := "1.0.0"
const METRIC_ID := "assassin_backline_elimination"

func get_metadata() -> Dictionary:
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "required_capabilities": REQUIRED_CAPS,
        "description": "Checks that assassin carries eliminate opposing carries within acceptable TTK."
    }

func run_metric(payload: Dictionary = {}) -> Dictionary:
    var context: Dictionary = payload.get("context", {})
    var derived: Dictionary = context.get("derived", {})
    var team_a: Dictionary = derived.get("a", {})
    var team_b: Dictionary = derived.get("b", {})

    var spans: Array = []
    var ok := true
    var messages: Array = []

    var val_a = team_a.get("ttk_on_carry_s", null)
    var val_b = team_b.get("ttk_on_carry_s", null)
    var has_a := (typeof(val_a) == TYPE_FLOAT or typeof(val_a) == TYPE_INT)
    var has_b := (typeof(val_b) == TYPE_FLOAT or typeof(val_b) == TYPE_INT)

    if not (has_a and has_b):
        ok = false
        messages.append("Missing TTK data in derived stats.")
    else:
        var ttk_a: float = float(val_a)
        var ttk_b: float = float(val_b)
        spans.append({
            "label": "team_a_ttk_on_carry_s",
            "value": ttk_a
        })
        spans.append({
            "label": "team_b_ttk_on_carry_s",
            "value": ttk_b
        })
        if ttk_a > 12.0:
            ok = false
            messages.append("Team A assassin TTK exceeds 12s threshold.")
        if ttk_b > 15.0:
            ok = false
            messages.append("Team B counter TTK exceeds 15s threshold.")
    return {
        "id": METRIC_ID,
        "version": VERSION,
        "pass": ok,
        "spans": spans,
        "message": "; ".join(messages)
    }
