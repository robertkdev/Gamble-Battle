extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")

const TRAIT_ID := "Harmony"
const BATTLE_LONG := 9999.0

const DMG_PCT_LOW := 0.20   # +20% damage (modeled as +20% AD and +20% SP)
const DR_PCT_LOW := 0.20    # -20% damage taken
const AS_PCT_MID := 0.12    # +12% attack speed
const DR_PCT_MID := 0.06    # -6% damage taken

func on_battle_start(ctx):
    assert(ctx != null and ctx.state != null)
    assert(ctx.buff_system != null)
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func _apply_for_team(ctx, team: String) -> void:
    # Activate only if Harmony is active for this team (threshold 2+)
    var t_active: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t_active < 0:
        return
    var largest: int = _largest_trait_size(ctx, team)
    if largest <= 0:
        return
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    var indices: Array[int] = []
    for i in range(arr.size()):
        if arr[i] != null:
            indices.append(i)
    if indices.is_empty():
        return

    if largest == 2:
        # Team +20% damage (AD/SP) and -20% damage taken
        GroupApply.stats(ctx.buff_system, ctx.state, team, indices, {"damage_reduction": DR_PCT_LOW}, BATTLE_LONG)
        # AD/SP as +20% of current per unit
        for i in indices:
            var u: Unit = arr[i]
            if u == null or not u.is_alive():
                continue
            var fields: Dictionary = {}
            var ad_delta: float = float(u.attack_damage) * DMG_PCT_LOW
            var sp_delta: float = float(u.spell_power) * DMG_PCT_LOW
            if ad_delta != 0.0:
                fields["attack_damage"] = ad_delta
            if sp_delta != 0.0:
                fields["spell_power"] = sp_delta
            if not fields.is_empty():
                ctx.buff_system.apply_stats_buff(ctx.state, team, i, fields, BATTLE_LONG)
    elif largest == 3:
        # Team +12% AS and -6% damage taken
        GroupApply.stats(ctx.buff_system, ctx.state, team, indices, {"attack_speed": AS_PCT_MID, "damage_reduction": DR_PCT_MID}, BATTLE_LONG)
    else:
        # 4 or more: no bonus
        pass

func _largest_trait_size(ctx, team: String) -> int:
    var compiled: Dictionary = (ctx.compiled_player if team == "player" else ctx.compiled_enemy)
    var counts: Dictionary = compiled.get("counts", {})
    var mx: int = 0
    for k in counts.keys():
        mx = max(mx, int(counts[k]))
    return mx
