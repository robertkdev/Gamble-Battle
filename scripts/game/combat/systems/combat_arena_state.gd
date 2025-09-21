extends RefCounted
class_name CombatArenaState

var tile_size_px: float = 72.0
var arena_bounds: Rect2 = Rect2()
var player_positions: Array[Vector2] = []
var enemy_positions: Array[Vector2] = []

func configure(tile_size: float, player_pos: Array[Vector2], enemy_pos: Array[Vector2], bounds: Rect2) -> void:
	tile_size_px = tile_size
	arena_bounds = Rect2(bounds.position, bounds.size)
	player_positions = player_pos.duplicate()
	enemy_positions = enemy_pos.duplicate()

func ensure_capacity(player_count: int, enemy_count: int) -> void:
	var fill: Vector2 = _default_position()
	_resize_vector_array(player_positions, player_count, fill)
	_resize_vector_array(enemy_positions, enemy_count, fill)

func update_movement(state: BattleState, delta: float, target_resolver: Callable) -> void:
	if delta <= 0.0:
		return
	if arena_bounds == Rect2():
		return
	ensure_capacity(state.player_team.size(), state.enemy_team.size())
	_update_team_movement("player", state.player_team, player_positions, enemy_positions, delta, target_resolver)
	_update_team_movement("enemy", state.enemy_team, enemy_positions, player_positions, delta, target_resolver)

func player_positions_copy() -> Array[Vector2]:
	return player_positions.duplicate()

func enemy_positions_copy() -> Array[Vector2]:
	return enemy_positions.duplicate()

func get_player_position(idx: int) -> Vector2:
	if idx < 0 or idx >= player_positions.size():
		return _default_position()
	return player_positions[idx]

func get_enemy_position(idx: int) -> Vector2:
	if idx < 0 or idx >= enemy_positions.size():
		return _default_position()
	return enemy_positions[idx]

func bounds_copy() -> Rect2:
	return Rect2(arena_bounds.position, arena_bounds.size)

func tile_size() -> float:
	return tile_size_px

func _update_team_movement(team: String, units: Array[Unit], positions: Array[Vector2], enemy_positions_arr: Array[Vector2], delta: float, resolver: Callable) -> void:
	for i in range(units.size()):
		var u: Unit = units[i]
		if not u or not u.is_alive():
			continue
		if i >= positions.size():
			continue
		var target_idx_variant = resolver.call(team, i)
		if typeof(target_idx_variant) != TYPE_INT:
			continue
		var target_idx: int = target_idx_variant
		if target_idx < 0 or target_idx >= enemy_positions_arr.size():
			continue
		var current_pos: Vector2 = positions[i]
		var target_pos: Vector2 = enemy_positions_arr[target_idx]
		var desired_range: float = max(0.0, float(u.attack_range)) * tile_size_px
		var dist: float = current_pos.distance_to(target_pos)
		if dist <= desired_range:
			continue
		var dir: Vector2 = target_pos - current_pos
		if dir.length() == 0.0:
			continue
		var move_dist: float = u.move_speed * delta
		if move_dist <= 0.0:
			continue
		var step: float = min(move_dist, max(0.0, dist - desired_range))
		if step <= 0.0:
			continue
		var new_pos: Vector2 = current_pos + dir.normalized() * step
		if arena_bounds.size != Vector2.ZERO:
			new_pos.x = clamp(new_pos.x, arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x)
			new_pos.y = clamp(new_pos.y, arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y)
		positions[i] = new_pos

func _resize_vector_array(arr: Array[Vector2], length: int, fill: Vector2) -> void:
	if length < 0:
		length = 0
	var current: int = arr.size()
	if current < length:
		for _i in range(length - current):
			arr.append(fill)
	elif current > length:
		arr.resize(length)

func _default_position() -> Vector2:
	return arena_bounds.position + arena_bounds.size * 0.5
