extends RefCounted
class_name LifestealService

const Health := preload("res://scripts/game/stats/health.gd")

func apply(src: Unit, dealt: int) -> int:
    if src == null or dealt <= 0:
        return 0
    var ls: float = float(src.lifesteal)
    if ls <= 0.0:
        return 0
    var heal_amt: int = int(floor(float(dealt) * ls))
    if heal_amt > 0:
        Health.heal(src, heal_amt)
    return heal_amt

