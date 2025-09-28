extends Object
class_name UnitScaler

# Centralized multiplicative scaling by cost and level for select Unit fields.
# Does not mutate unrelated fields; callers should handle final clamps and HP reset.

static func apply_cost_level_scaling(u: Unit, base_vals: Dictionary) -> void:
    if u == null:
        return
    # Keys eligible for multiplicative scaling
    var scale_keys := [
        "max_hp",
        "hp_regen",
        "attack_damage",
        "spell_power",
        "lifesteal",
        "armor",
        "magic_resist",
        "true_damage",
    ]
    for k in scale_keys:
        var base_zero := false
        if base_vals and base_vals.has(k):
            var bv = base_vals[k]
            base_zero = (int(bv) == 0 if k == "max_hp" else float(bv) == 0.0)
        if base_zero:
            continue
        var curv: float = float(u.get(k))
        # Cost scaling: stepwise 1.5x per step above 1
        if int(u.cost) > 1:
            for _ci in range(int(u.cost) - 1):
                curv *= 1.5
                if k == "max_hp":
                    curv = float(int(curv))
        # Level scaling: stepwise 1.5x per step above 1
        if int(u.level) > 1:
            for _li in range(int(u.level) - 1):
                curv *= 1.5
                if k == "max_hp":
                    curv = float(int(curv))
        match k:
            "max_hp":
                u.max_hp = max(1, int(curv))
            "hp_regen":
                u.hp_regen = max(0.0, curv)
            "attack_damage":
                u.attack_damage = max(0.0, curv)
            "spell_power":
                u.spell_power = max(0.0, curv)
            "lifesteal":
                u.lifesteal = clampf(curv, 0.0, 0.9)
            "armor":
                u.armor = max(0.0, curv)
            "magic_resist":
                u.magic_resist = max(0.0, curv)
            "true_damage":
                u.true_damage = max(0.0, curv)

