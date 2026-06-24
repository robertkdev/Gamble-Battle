extends AbilityImplBase

# Grint — Body Check
# Swipe the current target for 100/150/225 + 0.6×AD physical damage, then dash into the
# target and knock them back 1 tile.

const BASE_BY_LEVEL := [170, 240, 360]
const AD_MULT := 0.90
const KNOCKBACK_TILES := 1.0
const DASH_MAX_TILES := 1.2
const MOVE_DURATION := 0.20
const FOLLOW_UP_RATIO := 1.00
const TRUE_SHOCK_RATIO := 0.40
const ATTACK_BUFF_PCT := 0.20
const ATTACK_BUFF_DURATION := 3.0

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _other(team: String) -> String:
    return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx < 0:
        return false
    var tgt_team: String = _other(ctx.caster_team)
    var target: Unit = ctx.unit_at(tgt_team, target_idx)
    if target == null or not target.is_alive():
        return false

    # 1) Swipe damage (physical)
    var li: int = _level_index(caster)
    var dmg: float = max(0.0, float(BASE_BY_LEVEL[li]) + AD_MULT * float(caster.attack_damage))
    var res := ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, dmg, "physical")
    var dealt_primary: float = float(res.get("dealt", dmg))

    # If target died, skip movement
    target = ctx.unit_at(tgt_team, target_idx)
    if target == null or not target.is_alive():
        ctx.log("Body Check: target slain by swipe")
        return true

    # 2) Dash toward target (short forced movement) and knock back the target 1 tile
    var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var tpos: Vector2 = ctx.position_of(tgt_team, target_idx)
    var dir: Vector2 = (tpos - start)
    var ts: float = ctx.tile_size()
    var fwd: Vector2 = (dir.normalized() if dir.length() > 0.0 else Vector2.RIGHT)

    # Dash vector — close up to 1 tile or until just before overlap
    var dist: float = dir.length()
    var dash_tiles: float = clamp(dist / max(0.001, ts), 0.0, DASH_MAX_TILES)
    var dash_vec: Vector2 = fwd * dash_tiles * ts

    # Knockback vector — push target 1 tile away along same direction
    var kb_vec: Vector2 = fwd * KNOCKBACK_TILES * ts

    # Emit a quick impact line VFX (reuse beam overlay)
    if ctx.engine and ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
        ctx.engine._resolver_emit_vfx_beam_line(start, tpos, Color(1.0, 0.85, 0.4, 0.95), 3.5, 0.12)

    # Apply forced movement via movement service
    if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
        if dash_vec.length() > 0.0:
            ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, dash_vec, MOVE_DURATION)
        ctx.engine.arena_state.notify_forced_movement(tgt_team, target_idx, kb_vec, MOVE_DURATION)

    # 3) Driving shoulder check follow-through delivers a secondary hit
    var follow_up: float = dealt_primary * FOLLOW_UP_RATIO
    if follow_up > 0.0:
        ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, follow_up, "physical")
    var true_shock: float = dealt_primary * TRUE_SHOCK_RATIO
    if true_shock > 0.0:
        ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, true_shock, "true")

    # Self-sustain buff to keep pressure after connecting
    var bs = ctx.buff_system
    if bs != null:
        var delta_ad: float = float(caster.attack_damage) * ATTACK_BUFF_PCT
        if delta_ad > 0.0:
            bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"attack_damage": delta_ad}, ATTACK_BUFF_DURATION)
        bs.apply_stats_buff(ctx.state, tgt_team, target_idx, {"armor": -30.0}, ATTACK_BUFF_DURATION)

    ctx.log("Body Check: dealt %d + %d + %d true and knocked back 1 tile" % [
        int(round(dealt_primary)),
        int(round(follow_up)),
        int(round(true_shock))
    ])
    return true
