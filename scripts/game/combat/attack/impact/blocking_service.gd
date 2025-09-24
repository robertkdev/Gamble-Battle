extends RefCounted
class_name BlockingService

func is_blocked(rng: RandomNumberGenerator, target: Unit, respect_block: bool) -> bool:
    if not respect_block or target == null:
        return false
    if rng == null:
        return false
    var chance: float = float(target.block_chance) if target.has_method("get") else float(target.block_chance)
    return rng.randf() < chance

