extends RefCounted
class_name ForcedMovement

# ForcedMovement
# Tracks per-unit forced movement impulses (e.g., knockbacks) that temporarily
# override normal movement. Each impulse is modeled as a total displacement
# to be applied evenly over its lifetime. When active, only forced movement is
# applied for that unit; normal approach steps are skipped.

class Impulse:
    var total: Vector2
    var remaining: float
    var duration: float
    func _init(_vec: Vector2, _dur: float) -> void:
        total = _vec
        duration = max(0.0001, _dur)
        remaining = duration
    func step(dt: float) -> Vector2:
        var d: float = clampf(dt, 0.0, remaining)
        var frac: float = d / duration
        var out: Vector2 = total * frac
        remaining -= d
        return out
    func is_done() -> bool:
        return remaining <= 0.0

var _map: Dictionary = {} # key -> Impulse

static func _key(team: String, idx: int) -> String:
    return team + ":" + str(idx)

func add(team: String, idx: int, vec: Vector2, duration: float) -> void:
    if duration <= 0.0 or vec == Vector2.ZERO:
        return
    _map[_key(team, idx)] = Impulse.new(vec, duration)

func has_active(team: String, idx: int) -> bool:
    var k := _key(team, idx)
    return _map.has(k) and not (_map[k] as Impulse).is_done()

func consume_step(team: String, idx: int, dt: float) -> Vector2:
    var k := _key(team, idx)
    if not _map.has(k):
        return Vector2.ZERO
    var imp: Impulse = _map[k]
    if imp.is_done():
        _map.erase(k)
        return Vector2.ZERO
    var step_vec: Vector2 = imp.step(dt)
    if imp.is_done():
        _map.erase(k)
    return step_vec

func clear() -> void:
    _map.clear()
