extends Object
class_name Health

# Health utilities: pure, small, and focused.

static func apply_damage(u: Unit, amount: int) -> Dictionary:
    var result := {"dealt": 0, "after_hp": 0}
    if u == null:
        return result
    var dmg: int = int(max(0, int(amount)))
    var before: int = int(u.hp)
    u.hp = max(0, before - dmg)
    result.dealt = dmg
    result.after_hp = int(u.hp)
    return result

static func heal(u: Unit, amount: int) -> Dictionary:
    var result := {"healed": 0, "after_hp": 0}
    if u == null:
        return result
    var before: int = int(u.hp)
    var inc: int = int(max(0, int(amount)))
    if inc <= 0:
        result.after_hp = before
        return result
    u.hp = min(int(u.max_hp), before + inc)
    result.healed = int(u.hp) - before
    result.after_hp = int(u.hp)
    return result

# Heals and reports overheal amount (without any external conversions/shields).
static func heal_and_overheal(u: Unit, amount: int) -> Dictionary:
    var result := {"healed": 0, "overheal": 0, "after_hp": 0}
    if u == null:
        return result
    var before: int = int(u.hp)
    var inc: int = int(max(0, int(amount)))
    if inc <= 0:
        result.after_hp = before
        return result
    var max_h: int = int(u.max_hp)
    var space: int = max(0, max_h - before)
    var healed: int = min(space, inc)
    var oh: int = max(0, inc - healed)
    if healed > 0:
        u.hp = min(max_h, before + healed)
    result.healed = healed
    result.overheal = oh
    result.after_hp = int(u.hp)
    return result

static func heal_full(u: Unit) -> void:
    if u != null:
        u.hp = int(u.max_hp)

static func regen_tick(u: Unit, seconds: float = 1.0) -> Dictionary:
    var result := {"healed": 0, "after_hp": 0}
    if u == null:
        return result
    var before: int = int(u.hp)
    var amt_f: float = max(0.0, float(u.hp_regen)) * max(0.0, seconds)
    var inc: int = int(round(amt_f))
    if inc > 0:
        u.hp = min(int(u.max_hp), before + inc)
    result.healed = int(u.hp) - before
    result.after_hp = int(u.hp)
    return result

static func is_alive(u: Unit) -> bool:
    return u != null and int(u.hp) > 0
