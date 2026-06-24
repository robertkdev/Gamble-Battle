extends AbilityImplBase

# Totem — Cleanse
# Cleanses the living ally with the most damage dealt this round; damages current target.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const BASE: Array[int] = [70, 110, 160]
const SP_MULT: float = 0.90
const SHIELD_BASE: Array[int] = [90, 140, 210]
const SHIELD_SP_MULT: float = 0.45
const SHIELD_DURATION: float = 3.0
const CC_IMMUNITY_DURATION: float = 2.0
const ALLY_DAMAGE_AMP: Array[float] = [0.08, 0.12, 0.18]
const AMP_DURATION: float = 6.0

func _li(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _ally_with_most_damage(state: BattleState, team: String, exclude_index: int = -1) -> int:
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
    var fallback_idx: int = -1
    for i in range(arr.size()):
        var u: Unit = arr[i]
        if u == null or not u.is_alive():
            continue
        if fallback_idx < 0:
            fallback_idx = i
        if i == exclude_index:
            continue
        var v: int = 0
        if team == "player":
            if i < totals.size(): v = int(totals[i])
        else:
            if i < totals.size(): v = int(totals[i])
        if v > best_val:
            best_val = v
            best_idx = i
    return best_idx if best_idx >= 0 else fallback_idx

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs: BuffSystem = ctx.buff_system
    if bs == null:
        ctx.log("[Cleanse] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    # Choose an allied carry first, falling back to Totem only if nobody else is alive.
    var ally_idx: int = _ally_with_most_damage(ctx.state, ctx.caster_team, ctx.caster_index)
    var li: int = _li(caster)
    var shield_val: int = int(max(0.0, round(float(SHIELD_BASE[li]) + SHIELD_SP_MULT * float(caster.spell_power))))
    var amp_pct: float = float(ALLY_DAMAGE_AMP[li])
    if ally_idx < 0:
        ally_idx = ctx.lowest_hp_ally(ctx.caster_team)
    if ally_idx >= 0:
        var pushed_source: bool = false
        if bs.has_method("push_source"):
            bs.push_source(ctx.caster_team, ctx.caster_index, "ability")
            pushed_source = true
        bs.cleanse(ctx.state, ctx.caster_team, ally_idx)
        bs.apply_shield(ctx.state, ctx.caster_team, ally_idx, shield_val, SHIELD_DURATION)
        bs.apply_tag(ctx.state, ctx.caster_team, ally_idx, BuffTags.TAG_CC_IMMUNE, CC_IMMUNITY_DURATION, {
            "kind": "totem_cleanse_immunity"
        })
        bs.apply_tag(ctx.state, ctx.caster_team, ally_idx, BuffTags.TAG_DAMAGE_AMP, AMP_DURATION, {
            "damage_amp_pct": amp_pct,
            "kind": "totem_carry_damage_amp"
        })
        bs.apply_tag(ctx.state, ctx.caster_team, ally_idx, BuffTags.TAG_ABILITY_AMP, AMP_DURATION, {
            "ability_damage_amp": amp_pct,
            "kind": "totem_carry_ability_amp"
        })
        if pushed_source and bs.has_method("pop_source"):
            bs.pop_source()

    # Damage current target
    var dmg: float = float(BASE[li]) + SP_MULT * float(caster.spell_power)
    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx >= 0:
        ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, max(0.0, dmg), "magic")

    ctx.log("Cleanse: ally %d protected for %d shield, %.0f%% amp; struck target for %d" % [ally_idx, shield_val, amp_pct * 100.0, int(round(dmg))])
    return true
