extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")

const TRAIT_ID := "Striker"

const MEMBER_AD := [20, 40, 75, 140]
const ALLY_AD := [10, 20, 0, 0]
const STACKS_ON_KILL := [1, 2, 3, 4]
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    _apply_start(ctx, "player")
    _apply_start(ctx, "enemy")

func on_unit_killed(ctx, source_team: String, source_index: int, _target_team: String, _target_index: int):
    var t: int = StackUtils.tier(ctx, source_team, TRAIT_ID)
    if t < 0:
        return
    var mem: Array[int] = StackUtils.members(ctx, source_team, TRAIT_ID)
    if mem.find(int(source_index)) < 0:
        return
    var add_n: int = int(StackUtils.value_by_tier(t, STACKS_ON_KILL))
    if add_n <= 0:
        return
    StackUtils.add_stacks(ctx, source_team, source_index, TRAIT_ID, add_n)

func _apply_start(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var ad_mem: float = StackUtils.value_by_tier(t, MEMBER_AD)
    var ad_ally: float = StackUtils.value_by_tier(t, ALLY_AD)
    if ad_mem <= 0.0 and ad_ally <= 0.0:
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
    if ad_ally > 0.0 and nonmem.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"attack_damage": ad_ally}, BATTLE_LONG)
    if ad_mem > 0.0 and mem_indices.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, {"attack_damage": ad_mem}, BATTLE_LONG)
