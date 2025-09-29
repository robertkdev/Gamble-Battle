extends ItemEffectBase

# On hit: +5 mana; on crit: +5 more. ICD 0.25s.

const BuffTagsItems := preload("res://scripts/game/abilities/buff_tags_items.gd")
const ICD := 0.25
const BASE_GAIN := 5
const CRIT_BONUS := 5

func on_event(u: Unit, ev: String, data: Dictionary) -> void:
    if buff_system == null or engine == null or u == null:
        return
    if ev != "hit_dealt":
        return
    var st := _state()
    if st == null:
        return
    var ctx := _team_index_of(u)
    var team: String = String(ctx.team)
    var index: int = int(ctx.index)
    if team == "" or index < 0:
        return
    if buff_system.is_mana_gain_blocked(st, team, index):
        return
    if buff_system.has_tag(st, team, index, BuffTagsItems.TAG_ITEM_MIND_SIPHON_ICD):
        return
    var gain: int = BASE_GAIN
    if bool(data.get("crit", false)):
        gain += CRIT_BONUS
    if gain <= 0:
        return
    u.mana = min(int(u.mana_max), int(u.mana) + max(0, gain))
    # Notify UI/analytics
    engine._resolver_emit_unit_stat(team, index, {"mana": u.mana})
    # Start ICD
    buff_system.apply_tag(st, team, index, BuffTagsItems.TAG_ITEM_MIND_SIPHON_ICD, ICD, {})
