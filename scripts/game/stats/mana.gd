extends Object
class_name Mana

# Mana utilities: keep logic centralized and simple.

static func regen_tick(u: Unit, seconds: float = 1.0) -> Dictionary:
    var result := {"gained": 0, "mana": 0}
    if u == null:
        return result
    var before: int = int(u.mana)
    var amt_f: float = max(0.0, float(u.mana_regen)) * max(0.0, seconds)
    var inc: int = int(round(amt_f))
    if inc > 0 and int(u.mana_max) > 0:
        u.mana = min(int(u.mana_max), before + inc)
    result.gained = int(u.mana) - before
    result.mana = int(u.mana)
    return result

static func reset_for_preview(u: Unit) -> void:
    if u != null:
        u.mana = 0

static func gain_on_attack(state: BattleState, team: String, index: int, u: Unit, ability_system = null, buff_system = null) -> Dictionary:
    var result := {"gained": 0, "cast": false, "mana": (int(u.mana) if u != null else 0)}
    if u == null or int(u.mana_max) <= 0:
        return result
    var gain: int = int(max(0, int(u.mana_gain_per_attack)))
    if gain <= 0:
        return result
    var block: bool = false
    if buff_system != null and state != null:
        # Block any mana gain while a unit has an active tag that sets block_mana_gain=true
        if buff_system.has_method("is_mana_gain_blocked") and buff_system.is_mana_gain_blocked(state, team, index):
            block = true
    if block:
        return result
    var before: int = int(u.mana)
    u.mana = min(int(u.mana_max), before + gain)
    result.gained = int(u.mana) - before
    result.mana = int(u.mana)
    if ability_system != null and int(u.mana_max) > 0 and int(u.mana) >= int(u.mana_max):
        var cast_res: Dictionary = ability_system.try_cast(team, index)
        result.cast = bool(cast_res.get("cast", false))
    return result
