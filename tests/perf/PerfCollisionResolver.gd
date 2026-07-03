extends Node

const CollisionResolverScript: Script = preload("res://scripts/game/combat/movement/collision_resolver.gd")

@export var samples_per_case: int = 3

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"label": "dense_6v6", "player_count": 6, "enemy_count": 6, "player_alive": 6, "enemy_alive": 6, "iterations": 420},
		{"label": "dense_12v12", "player_count": 12, "enemy_count": 12, "player_alive": 12, "enemy_alive": 12, "iterations": 180},
		{"label": "late_12v12", "player_count": 12, "enemy_count": 12, "player_alive": 12, "enemy_alive": 3, "iterations": 300}
	]
	var aggregate_signature: int = 23
	var total_ms: int = 0
	var sample_count: int = max(1, int(samples_per_case))
	for case_data in cases:
		var result: Dictionary = _run_case(case_data, sample_count)
		total_ms += int(result.get("median_ms", 0))
		aggregate_signature = _mix(aggregate_signature, int(result.get("signature", 0)))
		print("PerfCollisionResolver case=", String(case_data.get("label", "unknown")),
			" iterations=", int(case_data.get("iterations", 0)),
			" samples=", sample_count,
			" median_ms=", int(result.get("median_ms", 0)),
			" p95_ms=", int(result.get("p95_ms", 0)),
			" min_ms=", int(result.get("min_ms", 0)),
			" max_ms=", int(result.get("max_ms", 0)),
			" signature=", int(result.get("signature", 0)))
	print("PerfCollisionResolver: median_total_ms=", total_ms, " aggregate_sig=", aggregate_signature)
	get_tree().quit(0)

func _run_case(case_data: Dictionary, sample_count: int) -> Dictionary:
	var ms_values: Array[int] = []
	var first_signature: int = 0
	for sample_index in range(max(1, sample_count)):
		var sample: Dictionary = _run_case_once(case_data)
		ms_values.append(int(sample.get("time_ms", 0)))
		var signature: int = int(sample.get("signature", 0))
		if sample_index == 0:
			first_signature = signature
		elif signature != first_signature:
			push_error("PerfCollisionResolver: inconsistent signature for " + String(case_data.get("label", "unknown")) + " sample " + str(sample_index))
	return {
		"median_ms": _percentile_int(ms_values, 0.50),
		"p95_ms": _percentile_int(ms_values, 0.95),
		"min_ms": _min_int(ms_values),
		"max_ms": _max_int(ms_values),
		"signature": first_signature
	}

func _run_case_once(case_data: Dictionary) -> Dictionary:
	var player_count: int = int(case_data.get("player_count", 0))
	var enemy_count: int = int(case_data.get("enemy_count", 0))
	var player_alive_count: int = int(case_data.get("player_alive", player_count))
	var enemy_alive_count: int = int(case_data.get("enemy_alive", enemy_count))
	var iterations: int = max(0, int(case_data.get("iterations", 0)))
	var base_player_positions: Array[Vector2] = _positions_for(player_count, Vector2(420.0, 360.0), -1.0)
	var base_enemy_positions: Array[Vector2] = _positions_for(enemy_count, Vector2(468.0, 372.0), 1.0)
	var player_positions: Array[Vector2] = []
	var enemy_positions: Array[Vector2] = []
	var player_alive: Array[bool] = []
	var enemy_alive: Array[bool] = []
	var player_caps: Array[float] = []
	var enemy_caps: Array[float] = []
	_resize_positions(player_positions, base_player_positions)
	_resize_positions(enemy_positions, base_enemy_positions)
	for i in range(player_count):
		player_alive.append(i < player_alive_count)
		player_caps.append(18.0 + float((i * 5) % 9))
	for j in range(enemy_count):
		enemy_alive.append(j < enemy_alive_count)
		enemy_caps.append(17.0 + float((j * 7) % 11))
	var resolver: CollisionResolver = CollisionResolverScript.new()
	var bounds: Rect2 = Rect2(Vector2(240.0, 160.0), Vector2(560.0, 440.0))
	var radius: float = 27.0
	var guard_sum: int = 0
	var start_usec: int = Time.get_ticks_usec()
	for iteration in range(iterations):
		_resize_positions(player_positions, base_player_positions)
		_resize_positions(enemy_positions, base_enemy_positions)
		var offset: Vector2 = Vector2(float(iteration % 5) * 0.25, float((iteration * 3) % 7) * 0.20)
		for p_index in range(player_positions.size()):
			player_positions[p_index] += offset
		for e_index in range(enemy_positions.size()):
			enemy_positions[e_index] -= offset
		resolver.resolve(
			player_positions,
			enemy_positions,
			player_alive,
			enemy_alive,
			player_caps,
			enemy_caps,
			radius,
			bounds,
			2,
			true,
			false)
		guard_sum = _mix(guard_sum, player_positions.size() + enemy_positions.size() + iteration)
	var elapsed_ms: int = int((Time.get_ticks_usec() - start_usec) / 1000)
	return {
		"time_ms": elapsed_ms,
		"signature": _signature_for(player_positions, enemy_positions, player_alive, enemy_alive, guard_sum)
	}

func _positions_for(count: int, center: Vector2, side: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(max(0, count)):
		var row: int = index / 4
		var column: int = index % 4
		var x_offset: float = side * float(row) * 20.0 + float((index * 11) % 5)
		var y_offset: float = (float(column) - 1.5) * 20.0 + float((index * 7) % 6)
		out.append(center + Vector2(x_offset, y_offset))
	return out

func _resize_positions(out: Array[Vector2], source: Array[Vector2]) -> void:
	out.resize(source.size())
	for index in range(source.size()):
		out[index] = source[index]

func _signature_for(player_positions: Array[Vector2], enemy_positions: Array[Vector2], player_alive: Array[bool], enemy_alive: Array[bool], guard_sum: int) -> int:
	var signature: int = _mix(37, guard_sum)
	for i in range(player_positions.size()):
		signature = _mix(signature, int(round(player_positions[i].x * 100.0)))
		signature = _mix(signature, int(round(player_positions[i].y * 100.0)))
		signature = _mix(signature, 1 if i < player_alive.size() and player_alive[i] else 0)
	for j in range(enemy_positions.size()):
		signature = _mix(signature, int(round(enemy_positions[j].x * 100.0)))
		signature = _mix(signature, int(round(enemy_positions[j].y * 100.0)))
		signature = _mix(signature, 1 if j < enemy_alive.size() and enemy_alive[j] else 0)
	return signature

func _percentile_int(values: Array[int], pct: float) -> int:
	if values.is_empty():
		return 0
	var sorted_values: Array[int] = []
	for value in values:
		sorted_values.append(int(value))
	sorted_values.sort()
	var index: int = int(ceil(float(sorted_values.size()) * clampf(float(pct), 0.0, 1.0))) - 1
	index = clampi(index, 0, sorted_values.size() - 1)
	return int(sorted_values[index])

func _min_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var best: int = int(values[0])
	for value in values:
		best = min(best, int(value))
	return best

func _max_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var best: int = int(values[0])
	for value in values:
		best = max(best, int(value))
	return best

func _mix(current: int, value: int) -> int:
	return int((current * 1315423911 + value * 2654435761 + 97) & 0x7fffffffffffffff)
