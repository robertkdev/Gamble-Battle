extends AbilityImplBase

# Morrak — Reaping Line (simplified v1)
# On cast: gains Armor & MR for 3s (25/35/45 by level).
# Cleaves in a line through the current target for physical damage:
#   D = BaseByLevel + 0.9 * AD + 12 * StrikerStacks + 10 * ExecutionerStacks
# Execute enemies under threshold T = min(0.40, 0.12 + 0.02 * ExecutionerStacks).
# On execute: heal Morrak for 30% Max HP.

const BUFF_DURATION := 3.0
const LINE_LENGTH_TILES := 4.0
const LINE_WIDTH_TILES := 0.6

const BASE_BY_LEVEL := [110, 165, 250]
const BUFF_BY_LEVEL := [25, 35, 45] # Armor/MR

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const STRIKER_KEY := "striker_stacks"           # Legacy fallback; TODO remove after validation
const EXECUTIONER_KEY := "executioner_stacks"    # Legacy fallback; TODO remove after validation

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _stack(bs, state: BattleState, team: String, index: int, key: String) -> int:
    if bs == null:
        return 0
    var trait_key: String = key
    if key == STRIKER_KEY:
        trait_key = TraitKeys.STRIKER
    elif key == EXECUTIONER_KEY:
        trait_key = TraitKeys.EXECUTIONER
    var v: int = int(bs.get_stack(state, team, index, trait_key))
    if v > 0:
        return v
    return int(bs.get_stack(state, team, index, key))

func _execute_threshold(exec_stacks: int) -> float:
    var base_t: float = 0.12
    var inc: float = 0.02 * float(max(0, exec_stacks))
    return clamp(base_t + inc, 0.0, 0.40)

func _heal_on_execute(ctx: AbilityContext, amount: int) -> void:
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null:
        return
    ctx.heal_single(ctx.caster_team, ctx.caster_index, max(0, amount))

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Reaping Line] BuffSystem not available; cast aborted")
        return false

    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx < 0:
        return false

    # On-cast defensive buff
    var li: int = _level_index(caster)
    var buff_val: int = BUFF_BY_LEVEL[li]
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"armor": buff_val, "magic_resist": buff_val}, BUFF_DURATION)

    # Stacks (trait-ready; default 0 until traits wire them in)
    var striker: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, STRIKER_KEY)
    var execs: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, EXECUTIONER_KEY)

    # Damage formula
    var base_dmg: int = BASE_BY_LEVEL[li]
    var scale_ad: float = 0.9 * float(caster.attack_damage)
    var scale_striker: int = 12 * max(0, striker)
    var scale_exec: int = 10 * max(0, execs)
    var total_dmg: int = int(max(0.0, round(float(base_dmg) + scale_ad + float(scale_striker + scale_exec))))

    # Select line targets
    var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_idx, LINE_LENGTH_TILES, LINE_WIDTH_TILES)
    var exec_thresh: float = _execute_threshold(execs)
    var executes: int = 0
    for idx in hits:
        var before := ctx.unit_at(ctx._other_team(ctx.caster_team), idx)
        if before == null or not before.is_alive():
            continue
        ctx.damage_single(ctx.caster_team, ctx.caster_index, idx, float(total_dmg), "physical")
        var tgt := ctx.unit_at(ctx._other_team(ctx.caster_team), idx)
        if tgt != null and tgt.is_alive():
            var hp_pct: float = (float(tgt.hp) / max(1.0, float(tgt.max_hp)))
            if hp_pct <= exec_thresh:
                # Execute: deal true damage equal to current HP
                var to_kill: float = float(tgt.hp)
                if to_kill > 0.0:
                    ctx.damage_single(ctx.caster_team, ctx.caster_index, idx, to_kill, "true")
                    executes += 1
    if executes > 0:
        var heal_amt: int = int(round(0.30 * float(caster.max_hp)))
        _heal_on_execute(ctx, heal_amt)
        ctx.log("Reaping Line: executed %d and healed %d" % [executes, heal_amt])
    else:
        ctx.log("Reaping Line: hit %d for %d (AD scale=%.0f, S=%d, E=%d)" % [hits.size(), total_dmg, caster.attack_damage, striker, execs])
    return true
