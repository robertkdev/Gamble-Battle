extends Object
class_name Targeting

# Pure fallback selection helpers. Engine can also accept a view-provided Callable.

static func pick_first_alive(enemy_team: Array[Unit]) -> int:
	for i in range(enemy_team.size()):
		var u: Unit = enemy_team[i]
		if u and u.is_alive():
			return i
	return -1
