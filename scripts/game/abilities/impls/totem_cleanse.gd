extends AbilityImplBase

# Totem — Cleanse
# Cleanses the living ally with the most damage dealt this round; damages current target.

const BASE := [70, 110, 160]
const SP_MULT := 0.90

func _li(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _ally_with_most_damage(state: BattleState, team: String) -> int:
    if state == null:
        return -1
    var arr: Array[Unit] = (state.player_team if team == "player" else state.enemy_team)
    var totals: Array[int] = []
    if team == "player":
        totals = state.player_damage_this_round
    else:
        totals = state.enemy_damage_this_round
    # If arrays not present on state, use zeros
    var best_idx: int = -1
    var best_val: int = -1
    for i in range(arr.size()):
        var u: Unit = arr[i]
        if u == null or not u.is_alive():
            continue
        var v: int = 0
        if team == "player":
            if i < totals.size(): v = int(totals[i])
        else:
            if i < totals.size(): v = int(totals[i])
        if v > best_val:
            best_val = v
            best_idx = i
    return best_idx

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Cleanse] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    # Choose ally to cleanse: most damage-dealt this round; fallback to lowest HP ally
    var ally_idx: int = _ally_with_most_damage(ctx.state, ctx.caster_team)
    if ally_idx < 0:
        ally_idx = ctx.lowest_hp_ally(ctx.caster_team)
    if ally_idx >= 0:
        bs.cleanse(ctx.state, ctx.caster_team, ally_idx)

    # Damage current target
    var li: int = _li(caster)
    var dmg: float = float(BASE[li]) + SP_MULT * float(caster.spell_power)
    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx >= 0:
        ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, max(0.0, dmg), "magic")

    ctx.log("Cleanse: ally %d cleansed; struck target for %d" % [ally_idx, int(round(dmg))])
    return true
