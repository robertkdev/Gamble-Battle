extends AbilityImplBase

# Axiom — Mentor's Reserve
# Instantly grants the Pupil 5/10/20 mana and shields Axiom for 240/320/460 + 0.6×SP for 3s.
# If no Pupil is alive, only the shield applies.

const SHIELD_BASE := [240, 320, 460]
const SHIELD_SP_MULT := 0.60
const SHIELD_DURATION := 3.0
const MANA_GRANT := [5, 10, 20]

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Mentor's Reserve] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var li: int = _level_index(caster)
    # Shield self
    var shield_f: float = float(SHIELD_BASE[li]) + SHIELD_SP_MULT * float(caster.spell_power)
    var shield_val: int = int(max(0.0, round(shield_f)))
    bs.apply_shield(ctx.state, ctx.caster_team, ctx.caster_index, shield_val, SHIELD_DURATION)

    # Resolve Pupil and grant mana
    var pupil_idx: int = ctx.pupil_for(ctx.caster_team, ctx.caster_index)
    var granted: int = 0
    if pupil_idx >= 0:
        var pupil: Unit = ctx.unit_at(ctx.caster_team, pupil_idx)
        if pupil != null and pupil.is_alive() and int(pupil.mana_max) > 0:
            var amt: int = int(MANA_GRANT[li])
            var before: int = int(pupil.mana)
            pupil.mana = min(int(pupil.mana_max), before + amt)
            granted = int(pupil.mana) - before
            ctx.engine._resolver_emit_unit_stat(ctx.caster_team, pupil_idx, {"mana": pupil.mana})

    if granted > 0:
        ctx.log("Mentor's Reserve: +%d mana to Pupil; shield %d" % [granted, shield_val])
    else:
        ctx.log("Mentor's Reserve: shield %d" % shield_val)
    return true

