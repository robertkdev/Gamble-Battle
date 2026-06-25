extends AbilityImplBase

# Volt — Arc Lock
# Deals base magic damage plus SP scaling to the current target and stuns it for 1s.

const AbilityEffects := preload("res://scripts/game/abilities/effects.gd")

const STUN_DURATION := 1.0
const BASE_BY_LEVEL := [215, 325, 485]
const SP_MULT := 0.75

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs: BuffSystem = ctx.buff_system
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
    var dmg: float = float(BASE_BY_LEVEL[li]) + SP_MULT * float(caster.spell_power)
    ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, max(0.0, dmg), "magic")
    AbilityEffects.stun(bs, ctx.engine, ctx.state, tgt_team, target_idx, STUN_DURATION, ctx.caster_team, ctx.caster_index)
    ctx.log("Arc Lock: dealt %d magic and stunned %.1fs" % [int(round(dmg)), STUN_DURATION])
    return true
