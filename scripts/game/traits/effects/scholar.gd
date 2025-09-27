extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")

const TRAIT_ID := "Scholar"
const MEMBER_MANA_REGEN := [2.0, 4.0, 6.0]
const ALLY_MANA_REGEN := [1.0, 2.0, 3.0]
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    _apply_start_bonuses(ctx, "player")
    _apply_start_bonuses(ctx, "enemy")

func _apply_start_bonuses(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var mem_bonus: float = StackUtils.value_by_tier(t, MEMBER_MANA_REGEN)
    var ally_bonus: float = StackUtils.value_by_tier(t, ALLY_MANA_REGEN)
    if mem_bonus <= 0.0 and ally_bonus <= 0.0:
        return
    var mem_indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    # Build non-member allies list
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
        GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"mana_regen": ally_bonus}, BATTLE_LONG)
    if mem_bonus > 0.0 and mem_indices.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, {"mana_regen": mem_bonus}, BATTLE_LONG)

