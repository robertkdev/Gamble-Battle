extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")

const TRAIT_ID := "Fortified"
const MEMBER_DR := [0.10, 0.20, 0.30, 0.40]
const ALLY_DR_BY_TIER := [0.0, 0.0, 0.10, 0.15] # tiers 0..3
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    _apply_start(ctx, "player")
    _apply_start(ctx, "enemy")

func _apply_start(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var mem_dr: float = StackUtils.value_by_tier(t, MEMBER_DR)
    var ally_dr: float = StackUtils.value_by_tier(t, ALLY_DR_BY_TIER)
    if mem_dr <= 0.0 and ally_dr <= 0.0:
        return
    var mem_indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    var nonmem: Array[int] = []
    var mem_set: Dictionary = {}
    for i in mem_indices:
        mem_set[int(i)] = true
    for i in range(arr.size()):
        if arr[i] == null:
            continue
        if not mem_set.has(i):
            nonmem.append(i)
    if mem_dr > 0.0 and mem_indices.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, {"damage_reduction": mem_dr}, BATTLE_LONG)
    if ally_dr > 0.0 and nonmem.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"damage_reduction": ally_dr}, BATTLE_LONG)

