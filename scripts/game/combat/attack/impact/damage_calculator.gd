extends RefCounted
class_name DamageCalculator

const DamageMath := preload("res://scripts/game/combat/damage_math.gd")

func from_components(phys_base: float, magic_base: float, true_base: float, src: Unit, tgt: Unit) -> float:
    var phys: float = 0.0
    var mag: float = 0.0
    if phys_base > 0.0:
        phys = DamageMath.physical_after_armor(max(0.0, phys_base), src, tgt)
    if magic_base > 0.0:
        mag = DamageMath.magic_after_resist(max(0.0, magic_base), src, tgt)
    var total: float = max(0.0, phys + mag + max(0.0, true_base))
    return DamageMath.apply_reduction(total, tgt)

