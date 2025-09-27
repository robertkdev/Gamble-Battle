extends RefCounted
class_name CostAdapter

# Tiny effective-cost adapter for AbilitySystem.
# Holds per-unit flat reductions and computes: max(0, base_cost - reduction).

var _flat_reduction: Dictionary = {} # Map[Unit -> int]

func clear() -> void:
    _flat_reduction.clear()

func set_flat_reduction(u: Unit, amount: int) -> void:
    if u == null:
        return
    _flat_reduction[u] = max(0, int(amount))

func add_flat_reduction(u: Unit, amount: int) -> void:
    if u == null or int(amount) == 0:
        return
    var cur: int = int(_flat_reduction.get(u, 0))
    _flat_reduction[u] = max(0, cur + int(amount))

func effective_cost(u: Unit, base_cost: int) -> int:
    if u == null:
        return max(0, int(base_cost))
    var red: int = int(_flat_reduction.get(u, 0))
    return max(0, int(base_cost) - max(0, red))

