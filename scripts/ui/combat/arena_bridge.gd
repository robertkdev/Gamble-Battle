extends RefCounted
class_name ArenaBridge

const Trace := preload("res://scripts/util/trace.gd")
const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")
const ArenaControllerClass := preload("res://scripts/ui/combat/arena_controller.gd")

var arena: ArenaController = null
var arena_container: Control
var arena_units: Control
var planning_area: Control
var arena_background: Control
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var unit_actor_class
var tile_size: int = 72

var _planning_area_prev_mouse_filter: int = 0

func configure(_arena_container: Control, _arena_units: Control, _planning_area: Control, _arena_background: Control, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _unit_actor_class, _tile_size: int) -> void:
    arena_container = _arena_container
    arena_units = _arena_units
    planning_area = _planning_area
    arena_background = _arena_background
    player_grid_helper = _player_grid_helper
    enemy_grid_helper = _enemy_grid_helper
    unit_actor_class = _unit_actor_class
    tile_size = _tile_size
    if arena == null:
        arena = ArenaControllerClass.new()

func enter_arena(player_views, enemy_views) -> void:
    if arena == null:
        return
    Trace.step("ArenaBridge.enter_arena: begin")
    arena.configure(arena_container, arena_units, player_grid_helper, enemy_grid_helper, unit_actor_class, tile_size)
    arena.enter_arena(player_views, enemy_views)
    if arena_container:
        arena_container.visible = true
    if planning_area:
        _planning_area_prev_mouse_filter = planning_area.mouse_filter
        planning_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
        planning_area.modulate.a = 0.0
    Trace.step("ArenaBridge.enter_arena: done")

func sync(manager: CombatManager, player_views, enemy_views) -> void:
    if arena == null or arena_container == null or not arena_container.visible:
        return
    if manager:
        var ppos: Array = manager.get_player_positions()
        var epos: Array = manager.get_enemy_positions()
        if ppos.size() > 0 or epos.size() > 0:
            arena.sync_arena_with_positions(player_views, enemy_views, ppos, epos)
            return
    arena.sync_arena(player_views, enemy_views)

func exit_arena() -> void:
    if arena:
        arena.exit_arena()
    if arena_container:
        arena_container.visible = false
    if planning_area:
        planning_area.modulate.a = 1.0
        planning_area.mouse_filter = _planning_area_prev_mouse_filter

func get_player_actor(index: int) -> UnitActor:
    if arena:
        return arena.get_player_actor(index)
    return null

func get_enemy_actor(index: int) -> UnitActor:
    if arena:
        return arena.get_enemy_actor(index)
    return null

func get_actor(team: String, index: int) -> UnitActor:
    if arena:
        return arena.get_actor(team, index)
    return null

func configure_engine_arena(manager: CombatManager, _player_views: Array, _enemy_views: Array) -> void:
    if manager == null:
        return
    Trace.step("ArenaBridge.configure_engine_arena: begin")
    var ts := float(tile_size)
    # Initial positions from current tile centers
    var ppos: Array[Vector2] = []
    var epos: Array[Vector2] = []
    for i in range(_player_views.size()):
        var pv = _player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = player_grid_helper.get_center(idx) if player_grid_helper and idx >= 0 else Vector2.ZERO
        ppos.append(pos)
    for j in range(_enemy_views.size()):
        var ev = _enemy_views[j]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = enemy_grid_helper.get_center(idx2) if enemy_grid_helper and idx2 >= 0 else Vector2.ZERO
        epos.append(pos2)
    # Bounds from arena background; fallback if degenerate
    var bounds: Rect2 = Rect2()
    if arena_background and is_instance_valid(arena_background):
        var r: Rect2 = arena_background.get_global_rect()
        bounds = Rect2(r.position, r.size)
    if bounds.size.y <= 1.0 or bounds.size.x <= 1.0:
        var all_pts: Array[Vector2] = []
        for v in ppos:
            if typeof(v) == TYPE_VECTOR2:
                all_pts.append(v)
        for v2 in epos:
            if typeof(v2) == TYPE_VECTOR2:
                all_pts.append(v2)
        if all_pts.size() > 0:
            var min_x: float = all_pts[0].x
            var max_x: float = all_pts[0].x
            var min_y: float = all_pts[0].y
            var max_y: float = all_pts[0].y
            for p in all_pts:
                min_x = min(min_x, p.x)
                max_x = max(max_x, p.x)
                min_y = min(min_y, p.y)
                max_y = max(max_y, p.y)
            var margin: float = ts
            var pos := Vector2(min_x - margin, min_y - margin)
            var size := Vector2(max(1.0, (max_x - min_x) + margin * 2.0), max(1.0, (max_y - min_y) + margin * 2.0))
            bounds = Rect2(pos, size)
            if Debug.enabled:
                print("[ArenaFix] Fallback bounds from tiles -> ", bounds)
        else:
            var vp := (arena_container.get_viewport() if arena_container else null)
            var vs := (vp.get_visible_rect() if vp else Rect2(Vector2.ZERO, Vector2(1920, 1080)))
            bounds = Rect2(vs.position, vs.size)
            if Debug.enabled:
                print("[ArenaFix] Fallback bounds from viewport -> ", bounds)
    manager.set_arena(ts, ppos, epos, bounds)
    Trace.step("ArenaBridge.configure_engine_arena: done")
    if Debug.enabled:
        print("[Arena] tile=", ts, " bounds=", bounds)
    _log_start_positions_and_targets(manager)
    if manager and manager.has_method("enable_movement_debug"):
        manager.enable_movement_debug(60)

func _log_start_positions_and_targets(manager: CombatManager) -> void:
    if manager == null:
        return
    var ppos: Array = manager.get_player_positions()
    var epos: Array = manager.get_enemy_positions()
    for i in range(manager.player_team.size()):
        var u: Unit = manager.player_team[i]
        if not u or not u.is_alive():
            continue
        var my_pos: Vector2 = Vector2.ZERO
        if i >= 0 and i < ppos.size() and typeof(ppos[i]) == TYPE_VECTOR2:
            my_pos = ppos[i]
        var tgt_idx: int = manager.select_closest_target.call("player", i, "enemy") if manager and manager.select_closest_target.is_valid() else -1
        var tgt_pos: Vector2 = Vector2.ZERO
        if tgt_idx >= 0 and tgt_idx < epos.size() and typeof(epos[tgt_idx]) == TYPE_VECTOR2:
            tgt_pos = epos[tgt_idx]
        if Debug.enabled:
            print("[Start] player ", i, " pos=", my_pos, " -> target ", tgt_idx, " tpos=", tgt_pos)
    for j in range(manager.enemy_team.size()):
        var e: Unit = manager.enemy_team[j]
        if not e or not e.is_alive():
            continue
        var e_my_pos: Vector2 = Vector2.ZERO
        if j >= 0 and j < epos.size() and typeof(epos[j]) == TYPE_VECTOR2:
            e_my_pos = epos[j]
        var e_tgt_idx: int = manager.select_closest_target.call("enemy", j, "player") if manager and manager.select_closest_target.is_valid() else -1
        var e_tgt_pos: Vector2 = Vector2.ZERO
        if e_tgt_idx >= 0 and e_tgt_idx < ppos.size() and typeof(ppos[e_tgt_idx]) == TYPE_VECTOR2:
            e_tgt_pos = ppos[e_tgt_idx]
        if Debug.enabled:
            print("[Start] enemy  ", j, " pos=", e_my_pos, " -> target ", e_tgt_idx, " tpos=", e_tgt_pos)
