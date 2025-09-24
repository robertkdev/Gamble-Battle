extends RefCounted
class_name AttackRoller

# Rolls base damage and crit for a unit. Keeps deterministic path centralized.

var deterministic: bool = true

func roll(u: Unit, rng: RandomNumberGenerator) -> Dictionary:
    if u == null:
        return {"damage": 0, "crit": false}
    if deterministic:
        var dmg_f: float = float(u.attack_damage) + float(u.true_damage)
        return {"damage": int(round(dmg_f)), "crit": false}
    if u.has_method("attack_roll"):
        return u.attack_roll(rng)
    return {"damage": int(max(0.0, float(u.attack_damage) + float(u.true_damage))), "crit": false}

