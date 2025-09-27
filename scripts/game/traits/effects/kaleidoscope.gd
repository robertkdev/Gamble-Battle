extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")

const TRAIT_ID := "Kaleidoscope"

const AD_PER_TRAIT := 15
const SP_PER_TRAIT := 15
const HP_PER_TRAIT := 30
const MAX_TRAITS := 12
const AS_BONUS_AT_10 := 0.60
const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    assert(ctx != null and ctx.state != null)
    assert(ctx.buff_system != null)
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func _apply_for_team(ctx, team: String) -> void:
    # Requires Kaleidoscope active on this team (threshold 2+)
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    var indices: Array[int] = []
    for i in range(arr.size()):
        if arr[i] != null:
            indices.append(i)
    if indices.is_empty():
        return
    var active_traits: int = _active_trait_count(ctx, team)
    var capped: int = min(MAX_TRAITS, active_traits)
    var hp_bonus: int = int(max(0, HP_PER_TRAIT * capped))
    var ad_bonus: int = int(max(0, AD_PER_TRAIT * capped))
    var sp_bonus: int = int(max(0, SP_PER_TRAIT * capped))
    var base_fields: Dictionary = {"attack_damage": ad_bonus, "spell_power": sp_bonus}
    if hp_bonus > 0:
        base_fields["max_hp"] = hp_bonus
    GroupApply.stats(ctx.buff_system, ctx.state, team, indices, base_fields, BATTLE_LONG)
    # If team has >= 10 distinct active traits, grant +60% Attack Speed
    if active_traits >= 10:
        GroupApply.stats(ctx.buff_system, ctx.state, team, indices, {"attack_speed": AS_BONUS_AT_10}, BATTLE_LONG)

func _active_trait_count(ctx, team: String) -> int:
    # Distinct active traits: those with tier >= 0
    var compiled: Dictionary = (ctx.compiled_player if team == "player" else ctx.compiled_enemy)
    var tiers: Dictionary = compiled.get("tiers", {})
    var n: int = 0
    for k in tiers.keys():
        if int(tiers[k]) >= 0:
            n += 1
    return n
