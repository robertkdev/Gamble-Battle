extends RefCounted
class_name ArenaController
const Trace := preload("res://scripts/util/trace.gd")

const Debug := preload("res://scripts/util/debug.gd")

var arena_container: Control
var arena_units: Control
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var unit_actor_class
var tile_size: int = 72

var player_actors: Array[UnitActor] = []
var enemy_actors: Array[UnitActor] = []

func configure(_arena_container: Control, _arena_units: Control, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _unit_actor_class, _tile_size: int) -> void:
    arena_container = _arena_container
    arena_units = _arena_units
    player_grid_helper = _player_grid_helper
    enemy_grid_helper = _enemy_grid_helper
    unit_actor_class = _unit_actor_class
    tile_size = _tile_size

func enter_arena(player_views, enemy_views) -> void:
    Trace.step("ArenaController.enter_arena: begin")
    _clear()
    var player_summary: Array[String] = []
    for i in range(player_views.size()):
        var pv = player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = Vector2.ZERO
        if player_grid_helper and idx >= 0:
            pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        var actor: UnitActor = unit_actor_class.new() as UnitActor
        actor.set_unit(pv.unit)
        arena_units.add_child(actor)
        actor.set_size_px(Vector2(tile_size, tile_size))
        actor.set_screen_position(pos)
        actor.visible = (pv.unit != null and pv.unit.is_alive())
        player_actors.append(actor)
    if not player_summary.is_empty():
        Debug.log("Arena", "Player positions %s" % [_join_strings(player_summary, ", ")])
    Trace.step("ArenaController.enter_arena: after players")

    var enemy_summary: Array[String] = []
    for i in range(enemy_views.size()):
        var ev = enemy_views[i]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = Vector2.ZERO
        if enemy_grid_helper and idx2 >= 0:
            pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        var actor2: UnitActor = unit_actor_class.new() as UnitActor
        actor2.set_unit(ev.unit)
        arena_units.add_child(actor2)
        actor2.set_size_px(Vector2(tile_size, tile_size))
        actor2.set_screen_position(pos2)
        actor2.visible = (ev.unit != null and ev.unit.is_alive())
        enemy_actors.append(actor2)
    if not enemy_summary.is_empty():
        Debug.log("Arena", "Enemy positions %s" % [_join_strings(enemy_summary, ", ")])
    Trace.step("ArenaController.enter_arena: done")

func sync_arena(player_views, enemy_views) -> void:
    var player_summary: Array[String] = []
    for i in range(min(player_actors.size(), player_views.size())):
        var actor: UnitActor = player_actors[i]
        var pv = player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = Vector2.ZERO
        if player_grid_helper and idx >= 0:
            pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        if actor and is_instance_valid(actor):
            actor.set_screen_position(pos)
            # Keep actor bars in sync with the latest Unit state
            actor.update_bars(pv.unit)
            actor.visible = (pv.unit != null and pv.unit.is_alive())
    if not player_summary.is_empty():
        Debug.log("ArenaSync", "Player %s" % [_join_strings(player_summary, ", ")])

    var enemy_summary: Array[String] = []
    for i in range(min(enemy_actors.size(), enemy_views.size())):
        var actor2: UnitActor = enemy_actors[i]
        var ev = enemy_views[i]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = Vector2.ZERO
        if enemy_grid_helper and idx2 >= 0:
            pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        if actor2 and is_instance_valid(actor2):
            actor2.set_screen_position(pos2)
            # Keep actor bars in sync with the latest Unit state
            actor2.update_bars(ev.unit)
            actor2.visible = (ev.unit != null and ev.unit.is_alive())
    if not enemy_summary.is_empty():
        Debug.log("ArenaSync", "Enemy %s" % [_join_strings(enemy_summary, ", ")])

func sync_arena_with_positions(player_views, enemy_views, player_positions: Array, enemy_positions: Array) -> void:
    # Prefer engine-provided positions when available; fall back to grid centers
    var player_summary: Array[String] = []
    for i in range(min(player_actors.size(), player_views.size())):
        var actor: UnitActor = player_actors[i]
        var pv = player_views[i]
        var pos: Vector2 = Vector2.ZERO
        if i < player_positions.size():
            pos = player_positions[i]
        else:
            var idx: int = pv.tile_idx
            if player_grid_helper and idx >= 0:
                pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        if actor and is_instance_valid(actor):
            actor.set_screen_position(pos)
            actor.update_bars(pv.unit)
            actor.visible = (pv.unit != null and pv.unit.is_alive())
    if not player_summary.is_empty():
        Debug.log("ArenaSync", "Player %s" % [_join_strings(player_summary, ", ")])

    var enemy_summary: Array[String] = []
    for i in range(min(enemy_actors.size(), enemy_views.size())):
        var actor2: UnitActor = enemy_actors[i]
        var ev = enemy_views[i]
        var pos2: Vector2 = Vector2.ZERO
        if i < enemy_positions.size():
            pos2 = enemy_positions[i]
        else:
            var idx2: int = ev.tile_idx
            if enemy_grid_helper and idx2 >= 0:
                pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        if actor2 and is_instance_valid(actor2):
            actor2.set_screen_position(pos2)
            actor2.update_bars(ev.unit)
            actor2.visible = (ev.unit != null and ev.unit.is_alive())
    if not enemy_summary.is_empty():
        Debug.log("ArenaSync", "Enemy %s" % [_join_strings(enemy_summary, ", ")])

func exit_arena() -> void:
    _clear()

func _clear() -> void:
    if arena_units:
        for child in arena_units.get_children():
            child.queue_free()
    player_actors.clear()
    enemy_actors.clear()

func _join_strings(arr: Array, sep: String) -> String:
    var out := ""
    for i in range(arr.size()):
        if i > 0:
            out += sep
        out += str(arr[i])
    return out

func get_player_actor(index: int) -> UnitActor:
    if index < 0 or index >= player_actors.size():
        return null
    return player_actors[index]

func get_enemy_actor(index: int) -> UnitActor:
    if index < 0 or index >= enemy_actors.size():
        return null
    return enemy_actors[index]

func get_actor(team: String, index: int) -> UnitActor:
    return get_player_actor(index) if team == "player" else get_enemy_actor(index)
