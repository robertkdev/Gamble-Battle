extends RefCounted
class_name AbsorbRedirector

var hooks

func configure(_hooks) -> void:
    hooks = _hooks

func divert(state: BattleState, target_team: String, target_index: int, incoming: int) -> Dictionary:
    var result := {"diverted": 0, "leftover": max(0, incoming)}
    if hooks == null or state == null or incoming <= 0:
        return result
    var pct: float = 0.0
    if hooks.has_method("korath_absorb_pct"):
        pct = float(hooks.korath_absorb_pct(state, target_team, target_index))
    if pct <= 0.0:
        return result
    var divert_amt: int = int(floor(float(incoming) * pct))
    if divert_amt <= 0:
        return result
    if hooks.has_method("korath_accumulate_pool"):
        hooks.korath_accumulate_pool(state, target_team, target_index, divert_amt)
    result.diverted = divert_amt
    result.leftover = max(0, incoming - divert_amt)
    return result

