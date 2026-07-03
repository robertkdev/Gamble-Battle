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
var _team_counts: Dictionary[String, int] = {}

static func _key(team: String, idx: int) -> String:
    return team + ":" + str(idx)

func add(team: String, idx: int, vec: Vector2, duration: float) -> void:
    if duration <= 0.0 or vec == Vector2.ZERO:
        return
    var key: String = _key(team, idx)
    if not _map.has(key):
        _team_counts[team] = int(_team_counts.get(team, 0)) + 1
    _map[key] = Impulse.new(vec, duration)

func has_any() -> bool:
    return not _map.is_empty()

func has_any_for_team(team: String) -> bool:
    return int(_team_counts.get(team, 0)) > 0

func has_active(team: String, idx: int) -> bool:
    var k: String = _key(team, idx)
    return _map.has(k) and not (_map[k] as Impulse).is_done()

func consume_step(team: String, idx: int, dt: float) -> Vector2:
    var k: String = _key(team, idx)
    if not _map.has(k):
        return Vector2.ZERO
    var imp: Impulse = _map[k]
    if imp.is_done():
        _erase_impulse(team, k)
        return Vector2.ZERO
    var step_vec: Vector2 = imp.step(dt)
    if imp.is_done():
        _erase_impulse(team, k)
    return step_vec

func _erase_impulse(team: String, key: String) -> void:
    if not _map.has(key):
        return
    _map.erase(key)
    var current: int = int(_team_counts.get(team, 0))
    if current <= 1:
        _team_counts.erase(team)
    else:
        _team_counts[team] = current - 1

func clear() -> void:
    _map.clear()
    _team_counts.clear()
