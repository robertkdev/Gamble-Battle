extends Object
class_name ShopOdds

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")

# Read-only provider of cost weights by player level.
# All logic for resolving/normalizing odds is centralized here.

static func clamp_level(level: int) -> int:
    return min(max(int(level), int(ShopConfig.MIN_LEVEL)), int(ShopConfig.MAX_LEVEL))

static func resolve_level(level: int) -> int:
    var cl: int = clamp_level(level)
    if ShopConfig.ODDS_BY_LEVEL.has(cl):
        return cl
    # Fallback: closest lower defined level, else closest upper, else default
    var lower: int = -1
    var upper: int = -1
    for k in ShopConfig.ODDS_BY_LEVEL.keys():
        var ki: int = int(k)
        if ki <= cl and (lower == -1 or ki > lower):
            lower = ki
        if ki >= cl and (upper == -1 or ki < upper):
            upper = ki
    if lower != -1:
        return lower
    if upper != -1:
        return upper
    return int(ShopConfig.DEFAULT_ROLL_LEVEL)

static func get_cost_weights(level: int) -> Dictionary:
    var lv: int = resolve_level(level)
    var raw = ShopConfig.ODDS_BY_LEVEL.get(lv, {})
    var out: Dictionary = {}
    for c in raw.keys():
        var cost_i: int = int(c)
        if ShopConfig.VALID_COSTS.has(cost_i):
            var w: float = max(0.0, float(raw[c]))
            if w > 0.0:
                out[cost_i] = w
    return out

static func get_cost_probabilities(level: int) -> Dictionary:
    var w: Dictionary = get_cost_weights(level)
    var total: float = 0.0
    for k in w.keys():
        total += float(w[k])
    if total <= 0.0:
        return {}
    var out: Dictionary = {}
    for k in w.keys():
        out[int(k)] = float(w[k]) / total
    return out

static func valid_costs() -> Array[int]:
    var arr: Array[int] = []
    for c in ShopConfig.VALID_COSTS:
        arr.append(int(c))
    return arr

