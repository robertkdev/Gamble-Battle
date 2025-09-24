extends RefCounted
class_name ProjectileBridge

const ProjectileManagerScript := preload("res://scripts/projectile_manager.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const G := preload("res://scripts/constants/gameplay_constants.gd")

var parent: Node
var projectile_manager: ProjectileManager
var arena_bridge
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var manager: CombatManager
var rng: RandomNumberGenerator

func configure(_parent: Node, _arena_bridge, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _manager: CombatManager, _rng: RandomNumberGenerator) -> void:
    parent = _parent
    arena_bridge = _arena_bridge
    player_grid_helper = _player_grid_helper
    enemy_grid_helper = _enemy_grid_helper
    manager = _manager
    rng = _rng
    _ensure_projectile_manager()

func _ensure_projectile_manager() -> void:
    if not projectile_manager:
        projectile_manager = ProjectileManagerScript.new()
    if parent and projectile_manager.get_parent() != parent:
        parent.add_child(projectile_manager)
    projectile_manager.configure()

func set_projectile_manager(pm: ProjectileManager) -> void:
    projectile_manager = pm
    if parent and projectile_manager.get_parent() != parent:
        parent.add_child(projectile_manager)
    projectile_manager.configure()

func has_active() -> bool:
    return projectile_manager != null and projectile_manager.has_active()

func clear() -> void:
    if projectile_manager:
        projectile_manager.clear()

func on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
    if not projectile_manager:
        return
    var start_pos: Vector2
    var end_pos: Vector2
    var tgt_control: Control = null
    var src_control: Control = null
    var color: Color
    if source_team == "player":
        var actor_src: UnitActor = (arena_bridge.get_player_actor(source_index) if arena_bridge else null)
        if actor_src:
            start_pos = actor_src.get_global_rect().get_center()
        else:
            var psrc := _get_player_sprite_by_index(source_index)
            start_pos = psrc.get_global_rect().get_center() if psrc else player_grid_helper.get_center(source_index)
        src_control = actor_src if actor_src else _get_player_sprite_by_index(source_index)
        var actor_tgt: UnitActor = (arena_bridge.get_enemy_actor(target_index) if arena_bridge else null)
        if actor_tgt:
            tgt_control = actor_tgt
            end_pos = actor_tgt.get_global_rect().get_center()
        else:
            var spr: Control = _get_enemy_sprite_by_index(target_index)
            if spr:
                tgt_control = spr
                end_pos = spr.get_global_rect().get_center()
            else:
                end_pos = enemy_grid_helper.get_center(target_index)
        color = Color(0.2, 0.8, 1.0)
    else:
        var actor_esrc: UnitActor = (arena_bridge.get_enemy_actor(source_index) if arena_bridge else null)
        if actor_esrc:
            start_pos = actor_esrc.get_global_rect().get_center()
        else:
            var esrc := _get_enemy_sprite_by_index(source_index)
            start_pos = esrc.get_global_rect().get_center() if esrc else enemy_grid_helper.get_center(source_index)
        src_control = actor_esrc if actor_esrc else _get_enemy_sprite_by_index(source_index)
        var actor_ptgt: UnitActor = (arena_bridge.get_player_actor(target_index) if arena_bridge else null)
        if actor_ptgt:
            tgt_control = actor_ptgt
            end_pos = actor_ptgt.get_global_rect().get_center()
        else:
            tgt_control = _get_player_sprite_by_index(target_index)
            end_pos = (tgt_control as Control).get_global_rect().get_center() if tgt_control else player_grid_helper.get_center(target_index)
        color = Color(1.0, 0.4, 0.2)

    var speed := G.PROJECTILE_SPEED
    var radius := G.PROJECTILE_RADIUS
    var arc_curve: float = 0.0
    var arc_freq: float = 6.0
    if manager and manager.get_engine():
        var eng = manager.get_engine()
        if eng and eng.buff_system and eng.state and eng.buff_system.has_tag(eng.state, source_team, source_index, BuffTags.TAG_NYXA):
            arc_curve = 0.35 + (rng.randf() if rng else 0.0) * 0.25
            arc_freq = 5.0 + (rng.randf() if rng else 0.0) * 4.0
    projectile_manager.fire_basic(
        source_team,
        source_index,
        start_pos,
        end_pos,
        damage,
        crit,
        speed,
        radius,
        color,
        tgt_control,
        target_index,
        src_control,
        arc_curve,
        arc_freq
    )
    if not projectile_manager.is_connected("projectile_hit", Callable(manager, "on_projectile_hit")):
        projectile_manager.projectile_hit.connect(manager.on_projectile_hit)

# These lookups expect the parent (CombatView) to hold current views arrays
func _get_enemy_sprite_by_index(i: int) -> Control:
    if parent and parent.has_method("_get_enemy_sprite_by_index"):
        return parent.call("_get_enemy_sprite_by_index", i)
    return null

func _get_player_sprite_by_index(i: int) -> Control:
    if parent and parent.has_method("_get_player_sprite_by_index"):
        return parent.call("_get_player_sprite_by_index", i)
    return null
