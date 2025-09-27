extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")

const TRAIT_ID := "Chronomancer"
const AS_ALLY_PER_UNIT := 0.10
const AS_ENEMY_PER_UNIT := -0.05
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func _apply_for_team(ctx, team: String) -> void:
    var members: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if members.is_empty():
        return
    var allies: Array[int] = []
    var enemies: Array[int] = []
    var arr_a: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    var arr_e: Array[Unit] = (ctx.state.enemy_team if team == "player" else ctx.state.player_team)
    for i in range(arr_a.size()):
        if arr_a[i] != null:
            allies.append(i)
    for j in range(arr_e.size()):
        if arr_e[j] != null:
            enemies.append(j)
    if allies.size() > 0:
        for _k in members:
            GroupApply.stats(ctx.buff_system, ctx.state, team, allies, {"attack_speed": AS_ALLY_PER_UNIT}, BATTLE_LONG)
    if enemies.size() > 0:
        var other: String = ("enemy" if team == "player" else "player")
        for _m in members:
            GroupApply.stats(ctx.buff_system, ctx.state, other, enemies, {"attack_speed": AS_ENEMY_PER_UNIT}, BATTLE_LONG)

