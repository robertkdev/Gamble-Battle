extends AbilityImplBase

# Volt — Arc Lock
# Deals 215/325/485 × SP magic damage to the current target and stuns it for 1s.

const STUN_DURATION := 1.0
const SP_MULT := [2.15, 3.25, 4.85]

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Arc Lock] BuffSystem not available; cast aborted")
        return false

    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false
    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx < 0:
        return false
    var tgt_team: String = ("enemy" if ctx.caster_team == "player" else "player")

    var li: int = _level_index(caster)
    var dmg: float = SP_MULT[li] * float(caster.spell_power)
    ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, max(0.0, dmg), "magic")
    bs.apply_stun(ctx.state, tgt_team, target_idx, STUN_DURATION)
    ctx.log("Arc Lock: dealt %d magic and stunned %.1fs" % [int(round(dmg)), STUN_DURATION])
    return true

