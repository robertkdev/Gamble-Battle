extends Object
class_name MentorLink

# Computes Mentor -> Pupil pairings for a single team.
# Rules:
# - A Mentor is any unit whose traits contain "Mentor" (string match).
# - The pupil is the nearest ally index (by Euclidean distance in arena coordinates)
#   that shares no trait with the Mentor.
# - Returns an Array[int] of size units.size(), where non-mentors are -1 and
#   mentors map to their chosen pupil index.

static func compute_for_team(units: Array[Unit], positions: Array) -> Array[int]:
	var out: Array[int] = []
	var n: int = units.size()
	if n <= 0:
		return out
	if positions.size() == n and n > 1 and _all_positions_equivalent(positions):
		for _i in range(n):
			out.append(-1)
		return out
	for _i in range(n):
		out.append(-1)
	for i: int in range(n):
		var u: Unit = units[i]
		if u == null:
			continue
		if not _is_mentor(u):
			continue
		var my_pos: Vector2 = _pos_of(positions, i)
		if my_pos == Vector2.ZERO and not _has_position(positions, i):
			continue
		var best_j: int = -1
		var best_d2: float = INF
		for j: int in range(n):
			if j == i:
				continue
			var v: Unit = units[j]
			if v == null:
				continue
			var p: Vector2 = _pos_of(positions, j)
			if p == Vector2.ZERO and not _has_position(positions, j):
				continue
			var d2: float = my_pos.distance_squared_to(p)
			if _shares_any_trait(u, v):
				continue
			if d2 < best_d2:
				best_d2 = d2
				best_j = j
		out[i] = best_j
	return out

static func _has_position(positions: Array, idx: int) -> bool:
	return positions != null and idx >= 0 and idx < positions.size() and typeof(positions[idx]) == TYPE_VECTOR2

static func _is_mentor(u: Unit) -> bool:
	if u == null:
		return false
	for t: String in u.traits:
		if String(t) == "Mentor":
			return true
	return false

static func _shares_any_trait(a: Unit, b: Unit) -> bool:
	if a == null or b == null:
		return false
	var set_a: Dictionary[String, bool] = {}
	for t: String in a.traits:
		set_a[String(t)] = true
	for t2: String in b.traits:
		if set_a.has(String(t2)):
			return true
	return false

static func _pos_of(positions: Array, idx: int) -> Vector2:
	if positions != null and idx >= 0 and idx < positions.size() and typeof(positions[idx]) == TYPE_VECTOR2:
		return positions[idx]
	return Vector2.ZERO

static func _all_positions_equivalent(positions: Array) -> bool:
	if positions.is_empty():
		return false
	if positions.size() == 1:
		return true
	for i: int in range(1, positions.size()):
		var base: Variant = positions[0]
		if typeof(base) != TYPE_VECTOR2 or typeof(positions[i]) != TYPE_VECTOR2:
			return false
		var p0: Vector2 = base
		var p: Vector2 = positions[i]
		if (p - p0).length_squared() > 0.000001:
			return false
	return true
