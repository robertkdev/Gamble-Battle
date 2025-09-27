extends AbilityImplBase

# Luna — Moon Beam
# Fires a thin ray of refracted moonlight through the current target, piercing all enemies
# in a line for 170/255/380 + 0.75×SP magic damage.

const LINE_LEN_TILES := 6.0
const LINE_WIDTH_TILES := 0.5
const BASE_BY_LEVEL := [170, 255, 380]
const SP_MULT := 0.75

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _other_team(team: String) -> String:
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

    var li: int = _level_index(caster)
    var dmg: int = int(max(0.0, round(float(BASE_BY_LEVEL[li]) + SP_MULT * float(caster.spell_power))))

    # Apply line damage to all enemies along the ray
    var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_idx, LINE_LEN_TILES, LINE_WIDTH_TILES)
    for i in hits:
        ctx.damage_single(ctx.caster_team, ctx.caster_index, int(i), float(dmg), "magic")

    # Visual: emit a brief beam effect from caster through target direction
    var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var tpos: Vector2 = ctx.position_of(_other_team(ctx.caster_team), target_idx)
    var fwd: Vector2 = (tpos - start)
    if fwd.length() <= 0.001:
        fwd = Vector2.RIGHT
    var end_pos: Vector2 = start + fwd.normalized() * float(LINE_LEN_TILES) * ctx.tile_size()
    var color := Color(0.85, 0.95, 1.0, 0.95) # pale moonlight
    var width: float = 4.0
    var duration: float = 0.20
    if ctx.engine and ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
        ctx.engine._resolver_emit_vfx_beam_line(start, end_pos, color, width, duration)

    ctx.log("Moon Beam: hit %d for %d magic" % [hits.size(), dmg])
    return true

