extends Object
class_name MentorLink

# Computes Mentor -> Pupil pairings for a single team.
# Rules:
# - A Mentor is any unit whose traits contain "Mentor" (string match).
# - The pupil is the nearest ally index (by Euclidean distance in arena coordinates)
#   that shares no trait with the Mentor. If none, maps to -1.
# - Returns an Array[int] of size units.size(), where non-mentors are -1 and
#   mentors map to their chosen pupil index.

static func compute_for_team(units: Array[Unit], positions: Array) -> Array[int]:
    var out: Array[int] = []
    var n: int = (units.size() if units != null else 0)
    for _i in range(n): out.append(-1)
    if n == 0:
        return out
    for i in range(n):
        var u: Unit = units[i]
        if u == null:
            continue
        if not _is_mentor(u):
            continue
        var my_pos: Vector2 = _pos_of(positions, i)
        var best_j: int = -1
        var best_d2: float = INF
        for j in range(n):
            if j == i:
                continue
            var v: Unit = units[j]
            if v == null:
                continue
            if _shares_any_trait(u, v):
                continue
            var p: Vector2 = _pos_of(positions, j)
            var d2: float = my_pos.distance_squared_to(p)
            if d2 < best_d2:
                best_d2 = d2
                best_j = j
        out[i] = best_j
    return out

static func _is_mentor(u: Unit) -> bool:
    if u == null:
        return false
    for t in u.traits:
        if String(t) == "Mentor":
            return true
    return false

static func _shares_any_trait(a: Unit, b: Unit) -> bool:
    if a == null or b == null:
        return false
    var set_a: Dictionary = {}
    for t in a.traits:
        set_a[String(t)] = true
    for t2 in b.traits:
        if set_a.has(String(t2)):
            return true
    return false

static func _pos_of(positions: Array, idx: int) -> Vector2:
    if positions != null and idx >= 0 and idx < positions.size() and typeof(positions[idx]) == TYPE_VECTOR2:
        return positions[idx]
    return Vector2.ZERO

