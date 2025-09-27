extends AbilityImplBase

# Mortem — Blood Feast (3-step combo)
# Cycles across casts: Backstep Rend -> Bonebreaker -> Crimson Cleave

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const KEY_COMBO := "mortem_blood_feast_combo"

# Backstep Rend
const REND_BASE := [80, 120, 180]
const REND_SP := 0.40
const REND_DASH_TILES := 1.0
const REND_DASH_DUR := 0.20

# Bonebreaker
const BREAK_BASE := [100, 150, 225]
const BREAK_SP := 0.45
const BREAK_KNOCK := 0.50

# Crimson Cleave
const CLEAVE_BASE := [120, 180, 270]
const CLEAVE_SP := 0.50
const CLEAVE_RADIUS_TILES := 2.0
const CLEAVE_HALF_ANGLE_DEG := 30.0 # 60° cone

func _li(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _other(team: String) -> String:
    return "enemy" if team == "player" else "player"

func _cone_hits(ctx: AbilityContext, center: Vector2, dir_fwd: Vector2, radius_tiles: float, half_angle_deg: float) -> Array[int]:
    var out: Array[int] = []
    if dir_fwd == Vector2.ZERO:
        return out
    var ts: float = ctx.tile_size()
    var max_d: float = max(0.0, radius_tiles) * ts
    var cos_thresh: float = cos(deg_to_rad(max(0.0, half_angle_deg)))
    var tgt_team: String = _other(ctx.caster_team)
    var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
    for i in range(enemies.size()):
        var u: Unit = enemies[i]
        if u == null or not u.is_alive():
            continue
        var p: Vector2 = ctx.position_of(tgt_team, i)
        var v: Vector2 = p - center
        var d: float = v.length()
        if d <= 0.0 or d > max_d:
            continue
        var vd: Vector2 = v / d
        var dp: float = dir_fwd.dot(vd)
        if dp >= cos_thresh:
            out.append(i)
    return out

func _stage(bs, state: BattleState, team: String, index: int) -> int:
    var c: int = 0
    if bs != null:
        c = int(bs.get_stack(state, team, index, KEY_COMBO))
    return int(c % 3)

func _advance(bs, state: BattleState, team: String, index: int) -> void:
    if bs != null:
        bs.add_stack(state, team, index, KEY_COMBO, 1)

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Blood Feast] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var s: int = _stage(bs, ctx.state, ctx.caster_team, ctx.caster_index)
    var li: int = _li(caster)
    var t_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if t_idx < 0:
        t_idx = ctx.lowest_hp_enemy(ctx.caster_team)
    if t_idx < 0:
        return false

    match s:
        0:
            # Backstep Rend: short dash through and behind target, then damage
            var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
            var tpos: Vector2 = ctx.position_of(_other(ctx.caster_team), t_idx)
            var dir: Vector2 = (tpos - start)
            var fwd: Vector2 = (dir.normalized() if dir.length() > 0.0 else Vector2.RIGHT)
            var vec_world: Vector2 = fwd * REND_DASH_TILES * ctx.tile_size()
            # Root + CC-immune during dash to prevent approach and ensure no mana gain
            bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, "mortem_combo_active", REND_DASH_DUR, {"block_mana_gain": true})
            bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, REND_DASH_DUR, {"block_mana_gain": true})
            bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, "root", REND_DASH_DUR, {})
            if ctx.engine and ctx.engine.has_method("notify_forced_movement"):
                ctx.engine.notify_forced_movement(ctx.caster_team, ctx.caster_index, fwd * (REND_DASH_TILES * ctx.tile_size()), REND_DASH_DUR)
            var dmg: float = float(REND_BASE[li]) + REND_SP * float(caster.spell_power)
            ctx.damage_single(ctx.caster_team, ctx.caster_index, t_idx, max(0.0, dmg), "magic")
            ctx.log("Backstep Rend: dealt %d" % int(round(dmg)))
        1:
            # Bonebreaker: damage + brief knockup
            var dmg2: float = float(BREAK_BASE[li]) + BREAK_SP * float(caster.spell_power)
            ctx.damage_single(ctx.caster_team, ctx.caster_index, t_idx, max(0.0, dmg2), "magic")
            var enemy_team: String = _other(ctx.caster_team)
            AbilityEffects.stun(bs, ctx.engine, ctx.state, enemy_team, t_idx, BREAK_KNOCK)
            if ctx.engine and ctx.engine.has_method("_resolver_emit_vfx_knockup"):
                ctx.engine._resolver_emit_vfx_knockup(enemy_team, t_idx, BREAK_KNOCK)
            # Brief active window to suppress mana gain
            bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, "mortem_combo_active", 0.25, {"block_mana_gain": true})
            ctx.log("Bonebreaker: dealt %d and knocked up" % int(round(dmg2)))
        _:
            # Crimson Cleave: cone magic damage
            var origin: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
            var tpos3: Vector2 = ctx.position_of(_other(ctx.caster_team), t_idx)
            var dir3: Vector2 = (tpos3 - origin)
            var fwd3: Vector2 = (dir3.normalized() if dir3.length() > 0.0 else Vector2.RIGHT)
            var hits: Array[int] = _cone_hits(ctx, origin, fwd3, CLEAVE_RADIUS_TILES, CLEAVE_HALF_ANGLE_DEG)
            var dmg3: float = float(CLEAVE_BASE[li]) + CLEAVE_SP * float(caster.spell_power)
            for vi in hits:
                ctx.damage_single(ctx.caster_team, ctx.caster_index, int(vi), max(0.0, dmg3), "magic")
            # Brief active window to suppress mana gain
            bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, "mortem_combo_active", 0.25, {"block_mana_gain": true})
            ctx.log("Crimson Cleave: hit %d for %d" % [hits.size(), int(round(dmg3))])

    _advance(bs, ctx.state, ctx.caster_team, ctx.caster_index)
    return true

