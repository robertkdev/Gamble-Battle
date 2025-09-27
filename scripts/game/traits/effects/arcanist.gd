extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const TRAIT_ID := "Arcanist"

const MEMBER_SP := [20, 60, 80, 160]
const ALLY_SP := [10, 30, 0, 0]
const STACKS_ON_KILL := [1, 2, 3, 4]
const ABILITY_AMP_T4 := 0.40
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    _apply_start(ctx, "player")
    _apply_start(ctx, "enemy")

func on_ability_cast(ctx, team: String, index: int, _ability_id: String):
    # At tier 8: first spell each combat double-casts for members
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 3:
        return
    var mem: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if mem.find(int(index)) < 0:
        return
    if ctx.buff_system == null or ctx.ability_system == null:
        return
    # If already used, do nothing
    if ctx.buff_system.has_tag(ctx.state, team, index, BuffTags.TAG_ARCANIST_DBL_USED):
        return
    # Mark as used
    ctx.buff_system.apply_tag(ctx.state, team, index, BuffTags.TAG_ARCANIST_DBL_USED, BATTLE_LONG, {})
    # Attempt immediate recast by refilling mana and trying to cast again
    var u: Unit = ctx.unit_at(team, index)
    if u != null and int(u.mana_max) > 0:
        u.mana = int(u.mana_max)
        ctx.ability_system.try_cast(team, index)

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
    var sp_mem: float = StackUtils.value_by_tier(t, MEMBER_SP)
    var sp_ally: float = StackUtils.value_by_tier(t, ALLY_SP)
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
    if sp_ally > 0.0 and nonmem.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"spell_power": sp_ally}, BATTLE_LONG)
    if sp_mem > 0.0 and mem_indices.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, {"spell_power": sp_mem}, BATTLE_LONG)
    # T4 special: +40% ability damage for members via a tag AbilityEffects reads
    if t >= 3 and mem_indices.size() > 0 and ctx.buff_system != null:
        for i in mem_indices:
            ctx.buff_system.apply_tag(ctx.state, team, int(i), BuffTags.TAG_ABILITY_AMP, BATTLE_LONG, {"ability_damage_amp": ABILITY_AMP_T4})
