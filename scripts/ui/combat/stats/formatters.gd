extends Object
class_name StatsFormatters

# Simple, reusable number/percent/duration formatters for UI.

static func compact(n) -> String:
    var v: float = _to_float(n)
    if v >= 1000000.0:
        return String.num(v/1000000.0, 1) + "m"
    if v >= 1000.0:
        return String.num(v/1000.0, 1) + "k"
    if abs(v - round(v)) < 0.0001:
        return str(int(round(v)))
    return String.num(v, 2)

static func number(n, decimals: int = 0) -> String:
    var v: float = _to_float(n)
    if decimals <= 0 and abs(v - round(v)) < 0.0001:
        return str(int(round(v)))
    return String.num(v, max(0, decimals))

# Percent with input in 0..1
static func percent01(p, decimals: int = 0) -> String:
    var v: float = clamp(_to_float(p), 0.0, 1.0) * 100.0
    return String.num(v, max(0, decimals)) + "%"

# Percent with input already in 0..100
static func percent100(p, decimals: int = 0) -> String:
    var v: float = clamp(_to_float(p), 0.0, 100.0)
    return String.num(v, max(0, decimals)) + "%"

static func duration(seconds: float, show_ms: bool = false) -> String:
    var s: float = max(0.0, seconds)
    var m: int = int(floor(s / 60.0))
    var rem: float = s - float(m) * 60.0
    if m > 0:
        return "%d:%02d" % [m, int(round(rem))]
    return (String.num(rem, 2) if show_ms else str(int(round(rem))))

static func _to_float(v) -> float:
    match typeof(v):
        TYPE_NIL:
            return 0.0
        TYPE_INT:
            return float(v)
        TYPE_FLOAT:
            return float(v)
        _:
            var s := String(v)
            var f := s.to_float()
            return (f if f == f else 0.0)

