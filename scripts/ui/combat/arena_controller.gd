extends RefCounted
class_name ArenaController
const Trace := preload("res://scripts/util/trace.gd")

const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")

var arena_container: Control
var arena_units: Control
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var unit_actor_class: Script
var tile_size: int = 72

var player_actors: Array[UnitActor] = []
var enemy_actors: Array[UnitActor] = []

const BAR_COLLISION_PADDING: float = 3.0
const BAR_OVERLAP_PENALTY: float = 10000.0
const BAR_OUTSIDE_PENALTY: float = 50000.0

func configure(_arena_container: Control, _arena_units: Control, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _unit_actor_class: Script, _tile_size: int) -> void:
    arena_container = _arena_container
    arena_units = _arena_units
    player_grid_helper = _player_grid_helper
    enemy_grid_helper = _enemy_grid_helper
    unit_actor_class = _unit_actor_class
    tile_size = _tile_size

func enter_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
    Trace.step("ArenaController.enter_arena: begin")
    _clear()
    var player_summary: Array[String] = []
    for i in range(player_views.size()):
        var pv: UnitSlotView = player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = Vector2.ZERO
        if player_grid_helper and idx >= 0:
            pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        var actor: UnitActor = unit_actor_class.new() as UnitActor
        actor.set_unit(pv.unit)
        actor.set_team_tint(Color(0.12, 0.30, 0.46, 0.72))
        arena_units.add_child(actor)
        actor.set_size_px(Vector2(tile_size, tile_size))
        actor.set_screen_position(pos)
        actor.visible = (pv.unit != null and pv.unit.is_alive())
        player_actors.append(actor)
    if not player_summary.is_empty():
        Debug.log("Arena", "Player positions %s" % [Strings.join(player_summary, ", ")])
    Trace.step("ArenaController.enter_arena: after players")

    var enemy_summary: Array[String] = []
    for i in range(enemy_views.size()):
        var ev: UnitSlotView = enemy_views[i]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = Vector2.ZERO
        if enemy_grid_helper and idx2 >= 0:
            pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        var actor2: UnitActor = unit_actor_class.new() as UnitActor
        actor2.set_unit(ev.unit)
        actor2.set_team_tint(Color(0.54, 0.06, 0.09, 0.76))
        arena_units.add_child(actor2)
        actor2.set_size_px(Vector2(tile_size, tile_size))
        actor2.set_screen_position(pos2)
        actor2.visible = (ev.unit != null and ev.unit.is_alive())
        enemy_actors.append(actor2)
    if not enemy_summary.is_empty():
        Debug.log("Arena", "Enemy positions %s" % [Strings.join(enemy_summary, ", ")])
    refresh_bar_layout()
    Trace.step("ArenaController.enter_arena: done")

func sync_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
    var player_summary: Array[String] = []
    for i in range(min(player_actors.size(), player_views.size())):
        var actor: UnitActor = player_actors[i]
        var pv: UnitSlotView = player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = Vector2.ZERO
        if player_grid_helper and idx >= 0:
            pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        if actor and is_instance_valid(actor):
            actor.set_screen_position(pos)
            # Keep actor bars in sync with the latest Unit state
            actor.update_bars(pv.unit)
            actor.sync_alive_visibility(pv.unit != null and pv.unit.is_alive())
    if not player_summary.is_empty():
        Debug.log("ArenaSync", "Player %s" % [Strings.join(player_summary, ", ")])

    var enemy_summary: Array[String] = []
    for i in range(min(enemy_actors.size(), enemy_views.size())):
        var actor2: UnitActor = enemy_actors[i]
        var ev: UnitSlotView = enemy_views[i]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = Vector2.ZERO
        if enemy_grid_helper and idx2 >= 0:
            pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        if actor2 and is_instance_valid(actor2):
            actor2.set_screen_position(pos2)
            # Keep actor bars in sync with the latest Unit state
            actor2.update_bars(ev.unit)
            actor2.sync_alive_visibility(ev.unit != null and ev.unit.is_alive())
    if not enemy_summary.is_empty():
        Debug.log("ArenaSync", "Enemy %s" % [Strings.join(enemy_summary, ", ")])
    refresh_bar_layout()

func sync_arena_with_positions(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView], player_positions: Array, enemy_positions: Array) -> void:
    # Prefer engine-provided positions when available; fall back to grid centers
    var player_summary: Array[String] = []
    for i in range(min(player_actors.size(), player_views.size())):
        var actor: UnitActor = player_actors[i]
        var pv: UnitSlotView = player_views[i]
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
            # Bars update through stat/team-stat signals; position sync only moves actors.
            actor.sync_alive_visibility(pv.unit != null and pv.unit.is_alive())
    if not player_summary.is_empty():
        Debug.log("ArenaSync", "Player %s" % [Strings.join(player_summary, ", ")])

    var enemy_summary: Array[String] = []
    for i in range(min(enemy_actors.size(), enemy_views.size())):
        var actor2: UnitActor = enemy_actors[i]
        var ev: UnitSlotView = enemy_views[i]
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
            # Bars update through stat/team-stat signals; position sync only moves actors.
            actor2.sync_alive_visibility(ev.unit != null and ev.unit.is_alive())
    if not enemy_summary.is_empty():
        Debug.log("ArenaSync", "Enemy %s" % [Strings.join(enemy_summary, ", ")])
    refresh_bar_layout()

func refresh_bar_layout() -> void:
    var actors: Array[UnitActor] = _visible_actors_for_bar_layout()
    if actors.is_empty():
        return
    actors.sort_custom(Callable(self, "_actor_bar_sort"))
    var placed_rects: Array[Rect2] = []
    var bounds: Rect2 = arena_units.get_global_rect() if arena_units != null and is_instance_valid(arena_units) else Rect2()
    var candidates: Array[Vector2] = _bar_offset_candidates()
    for actor: UnitActor in actors:
        actor.set_bar_layout_offset(Vector2.ZERO)
        var best_offset: Vector2 = Vector2.ZERO
        var best_rect: Rect2 = actor.bar_global_rect_for_offset(best_offset)
        var best_score: float = _bar_candidate_score(best_rect, best_offset, bounds, placed_rects)
        for candidate: Vector2 in candidates:
            var candidate_rect: Rect2 = actor.bar_global_rect_for_offset(candidate)
            var candidate_score: float = _bar_candidate_score(candidate_rect, candidate, bounds, placed_rects)
            if candidate_score + 0.001 < best_score:
                best_score = candidate_score
                best_offset = candidate
                best_rect = candidate_rect
        actor.set_bar_layout_offset(best_offset)
        placed_rects.append(best_rect.grow(BAR_COLLISION_PADDING))

func bar_layout_snapshot() -> Array[Dictionary]:
    var snapshot: Array[Dictionary] = []
    for actor: UnitActor in _visible_actors_for_bar_layout():
        snapshot.append(actor.bar_layout_snapshot())
    return snapshot

func _visible_actors_for_bar_layout() -> Array[UnitActor]:
    var actors: Array[UnitActor] = []
    for actor: UnitActor in player_actors:
        if actor != null and is_instance_valid(actor) and actor.visible:
            actors.append(actor)
    for actor: UnitActor in enemy_actors:
        if actor != null and is_instance_valid(actor) and actor.visible:
            actors.append(actor)
    return actors

func _actor_bar_sort(a: UnitActor, b: UnitActor) -> bool:
    if not is_equal_approx(a.global_position.y, b.global_position.y):
        return a.global_position.y < b.global_position.y
    if not is_equal_approx(a.global_position.x, b.global_position.x):
        return a.global_position.x < b.global_position.x
    return a.get_instance_id() < b.get_instance_id()

func _bar_offset_candidates() -> Array[Vector2]:
    return [
        Vector2.ZERO,
        Vector2(-72.0, 0.0), Vector2(72.0, 0.0),
        Vector2(0.0, -32.0),
        Vector2(-72.0, -32.0), Vector2(72.0, -32.0),
        Vector2(0.0, -64.0),
        Vector2(-72.0, -64.0), Vector2(72.0, -64.0),
        Vector2(0.0, -96.0),
        Vector2(-72.0, -96.0), Vector2(72.0, -96.0),
    ]

func _bar_candidate_score(rect: Rect2, offset: Vector2, bounds: Rect2, placed_rects: Array[Rect2]) -> float:
    var score: float = offset.length_squared() * 0.02
    for placed: Rect2 in placed_rects:
        if not rect.intersects(placed):
            continue
        score += BAR_OVERLAP_PENALTY + rect.intersection(placed).get_area() * 12.0
    if bounds.size.x > 1.0 and bounds.size.y > 1.0 and not bounds.encloses(rect):
        var overflow_x: float = maxf(0.0, bounds.position.x - rect.position.x) + maxf(0.0, rect.end.x - bounds.end.x)
        var overflow_y: float = maxf(0.0, bounds.position.y - rect.position.y) + maxf(0.0, rect.end.y - bounds.end.y)
        score += BAR_OUTSIDE_PENALTY + (overflow_x + overflow_y) * 1000.0
    return score

func exit_arena() -> void:
    _clear()

func teardown() -> void:
    _clear()
    arena_container = null
    arena_units = null
    player_grid_helper = null
    enemy_grid_helper = null
    unit_actor_class = null

func _clear() -> void:
    if arena_units:
        for child in arena_units.get_children():
            child.queue_free()
    player_actors.clear()
    enemy_actors.clear()

## join moved to Strings.join

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
