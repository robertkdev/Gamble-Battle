extends RefCounted
class_name MovementState

# MovementState
# Holds world-space movement data with no Node/UI coupling.
# - Positions for player/enemy units (Vector2 world coords)
# - Arena bounds (Rect2 world coords)
# - Tile size (pixels per tile)
# - Minimal per-unit memory arrays reserved for future strategies

var tile_size_px: float = 72.0
var arena_bounds: Rect2 = Rect2()
var player_positions: Array[Vector2] = []
var enemy_positions: Array[Vector2] = []

# Optional per-unit memory (example: last target id); not used in approach-only
var player_last_target: Array[int] = []
var enemy_last_target: Array[int] = []

var debug_log_frames: int = 0

func configure(tile_size: float, player_pos: Array[Vector2], enemy_pos: Array[Vector2], bounds: Rect2) -> void:
    tile_size_px = tile_size
    arena_bounds = Rect2(bounds.position, bounds.size)
    player_positions = player_pos.duplicate()
    enemy_positions = enemy_pos.duplicate()
    player_last_target = _resize_int_array(player_last_target, player_positions.size())
    enemy_last_target = _resize_int_array(enemy_last_target, enemy_positions.size())

func ensure_capacity(player_count: int, enemy_count: int) -> void:
    var fill: Vector2 = _default_position()
    _resize_vector_array(player_positions, player_count, fill)
    _resize_vector_array(enemy_positions, enemy_count, fill)
    player_last_target = _resize_int_array(player_last_target, player_count)
    enemy_last_target = _resize_int_array(enemy_last_target, enemy_count)

func set_debug_log_frames(n: int) -> void:
    debug_log_frames = max(0, int(n))

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

func _resize_vector_array(arr: Array[Vector2], length: int, fill: Vector2) -> void:
    if length < 0:
        length = 0
    var current: int = arr.size()
    if current < length:
        for _i in range(length - current):
            arr.append(fill)
    elif current > length:
        arr.resize(length)

func _resize_int_array(existing: Array, desired: int) -> Array[int]:
    var out: Array[int] = []
    if desired < 0:
        desired = 0
    var count: int = min(existing.size(), desired)
    for i in range(count):
        out.append(int(existing[i]))
    while out.size() < desired:
        out.append(-1)
    return out

func _default_position() -> Vector2:
    return arena_bounds.position + arena_bounds.size * 0.5
