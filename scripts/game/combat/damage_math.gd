extends Object
class_name DamageMath

# Shared damage mitigation helpers used by basic attacks and abilities.

static func physical_after_armor(base: float, src, tgt) -> float:
    if base <= 0.0 or tgt == null:
        return 0.0
    var armor_eff: float = 0.0
    if tgt != null and tgt.has_method("get"):
        armor_eff = float(tgt.get("armor"))
    # Apply penetration if source exposes it
    var pen_pct: float = 0.0
    var pen_flat: float = 0.0
    if src != null and src.has_method("get"):
        pen_pct = clamp(float(src.get("armor_pen_pct")), 0.0, 1.0)
        pen_flat = max(0.0, float(src.get("armor_pen_flat")))
    armor_eff = armor_eff * (1.0 - pen_pct) - pen_flat
    var factor: float = 1.0
    if armor_eff >= 0.0:
        factor = 100.0 / (100.0 + armor_eff)
    else:
        factor = 2.0 - 100.0 / (100.0 - armor_eff)
    return max(0.0, base * factor)

static func magic_after_resist(base: float, src, tgt) -> float:
    if base <= 0.0 or tgt == null:
        return 0.0
    var mr_eff: float = 0.0
    if tgt != null and tgt.has_method("get"):
        mr_eff = float(tgt.get("magic_resist"))
    var pen_pct: float = 0.0
    var pen_flat: float = 0.0
    if src != null and src.has_method("get"):
        pen_pct = clamp(float(src.get("mr_pen_pct")), 0.0, 1.0)
        pen_flat = max(0.0, float(src.get("mr_pen_flat")))
    mr_eff = mr_eff * (1.0 - pen_pct) - pen_flat
    var factor: float = 1.0
    if mr_eff >= 0.0:
        factor = 100.0 / (100.0 + mr_eff)
    else:
        factor = 2.0 - 100.0 / (100.0 - mr_eff)
    return max(0.0, base * factor)

static func apply_reduction(total: float, tgt) -> float:
    if total <= 0.0 or tgt == null:
        return 0.0
    var dr: float = 0.0
    if tgt != null and tgt.has_method("get"):
        dr = clamp(float(tgt.get("damage_reduction")), 0.0, 0.9)
    return max(0.0, total * (1.0 - dr))

