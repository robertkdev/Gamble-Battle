extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const TRAIT_ID := "Exile"
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    assert(ctx != null and ctx.state != null)
    assert(ctx.buff_system != null)
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func _apply_for_team(ctx, team: String) -> void:
    var count: int = ctx.count(team, TRAIT_ID)
    var tier: int = _upgrade_tier_for_count(count)
    var members: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if members.is_empty():
        return
    if tier <= 0:
        # No upgrade active; ensure tag is not applied (buff system resets per battle)
        return
    for i in members:
        ctx.buff_system.apply_tag(ctx.state, team, int(i), BuffTags.TAG_EXILE_UPGRADE, BATTLE_LONG, {"level": tier})

func _upgrade_tier_for_count(c: int) -> int:
    match int(c):
        1:
            return 1
        3:
            return 2
        5:
            return 3
        _:
            return 0

