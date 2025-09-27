extends AbilityImplBase

# Hexeon — Prismatic Guillotine (simplified core)
# Blinks to the lowest‑HP enemy (retargets) and strikes for
# 260/390/900 + 0.9×SP + 12×Kaleidoscope stacks magic damage.
# If target HP% is at/under Executioner threshold (12% + 2% × stacks, up to 40%), execute it.
# On execute, retarget lowest‑HP enemy and recast at 70% power.

const BASE := [260, 390, 900]
const SP_MULT := 0.90
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const KALEI_KEY := "kaleidoscope_stacks" # Legacy fallback; TODO remove after validation
const EXEC_KEY := "executioner_stacks"    # Legacy fallback; TODO remove after validation
const RECAST_SCALE := 0.70

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _stack(bs, state: BattleState, team: String, index: int, key: String) -> int:
    if bs == null:
        return 0
    var trait_key: String = key
    if key == EXEC_KEY:
        trait_key = TraitKeys.EXECUTIONER
    elif key == KALEI_KEY:
        trait_key = TraitKeys.KALEIDOSCOPE
    var v: int = int(bs.get_stack(state, team, index, trait_key))
    if v > 0:
        return v
    return int(bs.get_stack(state, team, index, key))

func _exec_threshold(exec_stacks: int) -> float:
    var base_t: float = 0.12
    var inc: float = 0.02 * float(max(0, exec_stacks))
    return clamp(base_t + inc, 0.0, 0.40)

func _strike(ctx: AbilityContext, target_idx: int, power_scale: float) -> Dictionary:
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null:
        return {}
    var bs = ctx.buff_system
    var li: int = _level_index(caster)
    var kalei: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, KALEI_KEY)
    var execs: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, EXEC_KEY)
    var dmg_f: float = float(BASE[li]) + SP_MULT * float(caster.spell_power) + 12.0 * float(max(0, kalei))
    dmg_f = max(0.0, dmg_f * max(0.0, power_scale))
    var res: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, dmg_f, "magic")
    # Execute check (post-hit HP%)
    var tgt := ctx.unit_at(ctx._other_team(ctx.caster_team), target_idx)
    if tgt != null and tgt.is_alive():
        var hp_pct: float = float(tgt.hp) / max(1.0, float(tgt.max_hp))
        if hp_pct <= _exec_threshold(execs):
            var to_kill: float = float(tgt.hp)
            if to_kill > 0.0:
                ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, to_kill, "true")
            res["executed"] = true
    else:
        res["killed"] = true
    return res

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false
    # First strike at lowest‑HP enemy
    var t0: int = ctx.lowest_hp_enemy(ctx.caster_team)
    if t0 < 0:
        return false
    var r0 := _strike(ctx, t0, 1.0)
    var executed0: bool = bool(r0.get("executed", false))
    if executed0:
        # Recast at 70% power on new lowest‑HP enemy
        var t1: int = ctx.lowest_hp_enemy(ctx.caster_team)
        if t1 >= 0 and ctx.is_alive(ctx._other_team(ctx.caster_team), t1):
            _strike(ctx, t1, RECAST_SCALE)
            ctx.log("Prismatic Guillotine: executed and recast at 70% power")
    else:
        ctx.log("Prismatic Guillotine: struck lowest‑HP enemy")
    return true
