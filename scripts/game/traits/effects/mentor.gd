extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")

const TRAIT_ID := "Mentor"

const SHARE_PCT := [0.10, 0.12, 0.15, 0.20]
const BATTLE_LONG := 9999.0
const MANA_ON_CAST := 1

func on_battle_start(ctx):
    assert(ctx != null and ctx.state != null)
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func on_ability_cast(ctx, team: String, index: int, _ability_id: String):
    # At T4, when a mentor casts, grant +1 mana to their pupil
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 3:
        return
    var members: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if members.find(int(index)) < 0:
        return
    var pupil_idx: int = _pupil_for(ctx, team, int(index))
    if pupil_idx < 0:
        return
    var pupil: Unit = ctx.unit_at(team, pupil_idx)
    if pupil == null or not pupil.is_alive():
        return
    pupil.mana = min(int(pupil.mana_max), int(pupil.mana) + MANA_ON_CAST)

func _apply_for_team(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var pct: float = StackUtils.value_by_tier(t, SHARE_PCT)
    if pct <= 0.0:
        return
    var members: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    for i in members:
        var mentor_idx: int = int(i)
        var pupil_idx: int = _pupil_for(ctx, team, mentor_idx)
        if pupil_idx < 0:
            continue
        var mentor: Unit = ctx.unit_at(team, mentor_idx)
        var pupil: Unit = ctx.unit_at(team, pupil_idx)
        if mentor == null or pupil == null or not pupil.is_alive():
            continue
        var fields: Dictionary = {
            "attack_damage": float(mentor.attack_damage) * pct,
            "spell_power": float(mentor.spell_power) * pct,
            "armor": float(mentor.armor) * pct,
            "magic_resist": float(mentor.magic_resist) * pct,
            "max_hp": int(round(float(mentor.max_hp) * pct)),
        }
        if ctx.buff_system != null:
            ctx.buff_system.apply_stats_buff(ctx.state, team, pupil_idx, fields, BATTLE_LONG)

func _pupil_for(ctx, team: String, mentor_index: int) -> int:
    if ctx == null or ctx.state == null:
        return -1
    var map: Array[int] = (ctx.state.player_pupil_map if team == "player" else ctx.state.enemy_pupil_map)
    if mentor_index < 0 or mentor_index >= map.size():
        return -1
    return int(map[mentor_index])

