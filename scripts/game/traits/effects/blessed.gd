extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const TRAIT_ID := "Blessed"

# Healing and shield strength amplification by tier (2/4/6)
const HEALING_REC_PCT := [0.20, 0.30, 0.60]
const SHIELD_STR_PCT := [0.20, 0.30, 0.60]
# Overheal-to-shield conversion by tier (none at T2, 10% at T4, 40% at T6)
const OVERHEAL_TO_SHIELD_PCT := [0.0, 0.10, 0.40]

const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
    assert(ctx != null and ctx.state != null)
    assert(ctx.buff_system != null)
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func _apply_for_team(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var heal_pct: float = StackUtils.value_by_tier(t, HEALING_REC_PCT)
    var shield_pct: float = StackUtils.value_by_tier(t, SHIELD_STR_PCT)
    var overheal_pct: float = StackUtils.value_by_tier(t, OVERHEAL_TO_SHIELD_PCT)
    if heal_pct <= 0.0 and shield_pct <= 0.0 and overheal_pct <= 0.0:
        return
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    for i in range(arr.size()):
        if arr[i] == null:
            continue
        var data := {
            "healing_received_pct": heal_pct,
            "shield_strength_pct": shield_pct,
            "overheal_to_shield_pct": overheal_pct,
        }
        ctx.buff_system.apply_tag(ctx.state, team, i, BuffTags.TAG_HEALING_MODS, BATTLE_LONG, data)

