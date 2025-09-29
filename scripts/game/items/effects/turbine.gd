extends ItemEffectBase

# On hit: heal for a % of missing HP. 1.0s ICD.

const BuffTagsItems := preload("res://scripts/game/abilities/buff_tags_items.gd")
const ICD := 1.0
const MISSING_PCT := 0.06  # 6% of missing HP per proc (placeholder; balance later)

func on_event(u: Unit, ev: String, _data: Dictionary) -> void:
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
    if buff_system.has_tag(st, team, index, BuffTagsItems.TAG_ITEM_TURBINE_ICD):
        return
    var missing: int = max(0, int(u.max_hp) - int(u.hp))
    if missing <= 0:
        return
    var heal_amt: int = int(max(0.0, round(float(missing) * MISSING_PCT)))
    if heal_amt <= 0:
        return
    var AbilityEffects = load("res://scripts/game/abilities/effects.gd")
    AbilityEffects.heal_single(engine, st, team, index, heal_amt, team, index)
    buff_system.apply_tag(st, team, index, BuffTagsItems.TAG_ITEM_TURBINE_ICD, ICD, {})
