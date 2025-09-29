extends AbilityImplBase

# Sari — Strike
# Fires a precise shot at the current target for 160/220/300 + 0.9×AD physical
# and gains +20% attack speed for 2 seconds.

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

const DMG_BASE := [160, 220, 300]
const AS_BUFF_PCT := 0.20
const AS_BUFF_DUR := 2.0

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false
    var tgt_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if tgt_idx < 0:
        return false
    var li: int = _level_index(caster)
    var dmg: float = float(DMG_BASE[li]) + 0.9 * float(caster.attack_damage)
    ctx.damage_single(ctx.caster_team, ctx.caster_index, tgt_idx, max(0.0, dmg), "physical")
    # Temporary attack-speed buff
    var delta_as: float = float(caster.attack_speed) * AS_BUFF_PCT
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"attack_speed": delta_as}, AS_BUFF_DUR)
    ctx.log("Strike: dealt %d and +20%% AS for %.1fs" % [int(round(dmg)), AS_BUFF_DUR])
    return true

