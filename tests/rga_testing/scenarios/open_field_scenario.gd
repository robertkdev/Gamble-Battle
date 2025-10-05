extends RefCounted
class_name OpenFieldScenario

const UnitFactory = preload("res://scripts/unit_factory.gd")
const BattleState = preload("res://scripts/game/combat/battle_state.gd")
const Unit = preload("res://scripts/unit.gd")

# Minimal open-field scenario with map parameter controls for arena layout.
# map_params fields (all optional):
#   openness (0..1)         -> scales overall arena footprint
#   choke_count (>=0)       -> emulates lateral compression from obstacles
#   obstacle_density (0..1) -> squeezes breadth and increases spawn buffer
#   artillery_range (float) -> desired initial separation between teams
#   tile_size (float)       -> grid scale passed to CombatEngine
#   center (Vector2)        -> arena center position
#   map_id (String)         -> identifier propagated to telemetry
func make(state: BattleState, teamA_ids: Array[String], teamB_ids: Array[String], map_params: Dictionary = {}) -> Dictionary:
    var out: Dictionary = {}
    if state == null:
        return out

    _populate_team(state.player_team, teamA_ids)
    _populate_team(state.enemy_team, teamB_ids)

    var tuned = _derive_params(map_params, state)
    var center_raw = tuned.get("center", Vector2.ZERO)
    var center: Vector2 = (center_raw as Vector2) if center_raw is Vector2 else Vector2.ZERO
    var half_width: float = float(tuned.get("half_width", 6.0))
    var half_height: float = float(tuned.get("half_height", 5.0))
    var spawn_x: float = float(tuned.get("spawn_x", 3.5))
    var row_spacing: float = float(tuned.get("row_spacing", 1.2))
    var tile_size: float = float(tuned.get("tile_size", 1.0))
    var map_id: String = String(tuned.get("map_id", "open_field_variable"))
    var artillery_range: float = float(tuned.get("artillery_range", 8.0))
    var choke_points: Array = tuned.get("choke_points", [])

    var bounds = Rect2(center - Vector2(half_width, half_height), Vector2(half_width * 2.0, half_height * 2.0))

    var count = max(state.player_team.size(), state.enemy_team.size())
    var player_positions = _formation_positions(count, -spawn_x, row_spacing)
    var enemy_positions = _formation_positions(count, spawn_x, row_spacing)

    out["state"] = state
    out["tile_size"] = tile_size
    out["player_positions"] = player_positions
    out["enemy_positions"] = enemy_positions
    out["bounds"] = bounds
    out["map_id"] = String(map_params.get("map_id", map_id))
    out["artillery_range"] = artillery_range
    out["choke_points"] = choke_points
    return out

func _populate_team(array: Array, ids: Array[String]) -> void:
    array.clear()
    for raw_id in ids:
        var inst: Unit = UnitFactory.spawn(String(raw_id))
        if inst:
            array.append(inst)

func _derive_params(map_params: Dictionary, state: BattleState) -> Dictionary:
    var openness: float = clamp(float(map_params.get("openness", 0.7)), 0.1, 1.0)
    var choke_count: int = max(0, int(map_params.get("choke_count", 0)))
    var obstacle_density: float = clamp(float(map_params.get("obstacle_density", 0.25)), 0.0, 1.0)
    var artillery_range: float = max(4.0, float(map_params.get("artillery_range", 8.0)))
    var tile_size: float = float(map_params.get("tile_size", 1.0))
    var center_raw = map_params.get("center", Vector2.ZERO)
    var center: Vector2 = (center_raw as Vector2) if center_raw is Vector2 else Vector2.ZERO

    var half_width_base: float = 6.0
    var half_height_base: float = 5.0
    var density_factor: float = 1.0 - obstacle_density * 0.6
    var choke_factor: float = 1.0 - min(choke_count * 0.08, 0.6)
    var half_width: float = max(3.0, half_width_base * openness * density_factor * choke_factor)
    var half_height: float = max(3.0, half_height_base * openness * density_factor)

    var largest_team: int = max(state.player_team.size(), state.enemy_team.size())
    if largest_team <= 0:
        largest_team = 1
    var row_spacing: float = max(1.2, (half_height * 2.0) / float(largest_team))

    var spawn_buffer: float = 1.0 + obstacle_density * 2.0 + float(choke_count) * 0.35
    var spawn_x: float = artillery_range * 0.5 + spawn_buffer
    spawn_x = clamp(spawn_x, 1.0, half_width - 0.5)

    var choke_points: Array[Vector2] = []
    if choke_count > 0:
        var spacing: float = (half_width * 2.0) / float(choke_count + 1)
        for i in range(choke_count):
            var cx: float = -half_width + spacing * float(i + 1)
            choke_points.append(Vector2(cx, 0))

    return {
        "tile_size": tile_size,
        "center": center,
        "half_width": half_width,
        "half_height": half_height,
        "row_spacing": row_spacing,
        "spawn_x": spawn_x,
        "map_id": String(map_params.get("map_id", "open_field_variable")),
        "artillery_range": artillery_range,
        "choke_points": choke_points,
    }

func _formation_positions(count: int, x: float, spacing: float) -> Array[Vector2]:
    var out: Array[Vector2] = []
    if count <= 0:
        return out
    if count == 1:
        out.append(Vector2(x, 0))
        return out
    var rows: int = max(1, int(ceil(sqrt(count))))
    var columns: int = int(ceil(float(count) / float(rows)))
    var start_y: float = -0.5 * float(rows - 1) * spacing
    var index: int = 0
    for r in range(rows):
        for c in range(columns):
            if index >= count:
                break
            var y: float = start_y + float(r) * spacing
            var lateral: float = (float(c) - 0.5 * float(columns - 1)) * spacing * 0.8
            out.append(Vector2(x + lateral, y))
            index += 1
    return out
