extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")

const TRAIT_ID := "Aegis"

const MEMBER_ARMOR_MR := [20, 40, 60, 160]
const ALLY_ARMOR_MR := [10, 20, 30, 80]
const STACKS_ON_CAST := [1, 2, 3, 4]
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    _apply_start_bonuses(ctx, "player")
    _apply_start_bonuses(ctx, "enemy")

func on_ability_cast(ctx, team: String, index: int, _ability_id: String):
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var mem: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if mem.find(int(index)) < 0:
        return
    var add_n: int = int(StackUtils.value_by_tier(t, STACKS_ON_CAST))
    if add_n <= 0:
        return
    # Primary unified key
    StackUtils.add_stacks(ctx, team, index, TRAIT_ID, add_n)

func _apply_start_bonuses(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var mem_bonus: float = StackUtils.value_by_tier(t, MEMBER_ARMOR_MR)
    var ally_bonus: float = StackUtils.value_by_tier(t, ALLY_ARMOR_MR)
    if mem_bonus <= 0.0 and ally_bonus <= 0.0:
        return
    var mem_indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    # Build non-member list
    var nonmem: Array[int] = []
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    var mem_set: Dictionary = {}
    for i in mem_indices:
        mem_set[int(i)] = true
    for i in range(arr.size()):
        if arr[i] == null:
            continue
        if not mem_set.has(i):
            nonmem.append(i)
    if ally_bonus > 0.0 and nonmem.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"armor": ally_bonus, "magic_resist": ally_bonus}, BATTLE_LONG)
    if mem_bonus > 0.0 and mem_indices.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, {"armor": mem_bonus, "magic_resist": mem_bonus}, BATTLE_LONG)
