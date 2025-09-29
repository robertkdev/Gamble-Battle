extends ItemEffectBase

# On cast: next 1 attack gains +%SP as magic on-hit.

const BuffTagsItems := preload("res://scripts/game/abilities/buff_tags_items.gd")
const HITS := 1
const PCT := 0.35

func on_event(u: Unit, ev: String, data: Dictionary) -> void:
    if buff_system == null or engine == null or u == null:
        return
    var st := _state()
    if st == null:
        return
    var ctx := _team_index_of(u)
    var team: String = String(ctx.team)
    var index: int = int(ctx.index)
    if team == "" or index < 0:
        return
    if ev == "ability_cast":
        buff_system.apply_tag(st, team, index, BuffTagsItems.TAG_ITEM_MINDSTONE, 9999.0, {"hits_left": HITS, "bonus_pct": PCT})
        return
    if ev == "hit_dealt":
        if not buff_system.has_tag(st, team, index, BuffTagsItems.TAG_ITEM_MINDSTONE):
            return
        var tag := buff_system.get_tag(st, team, index, BuffTagsItems.TAG_ITEM_MINDSTONE)
        var meta: Dictionary = tag.get("data", {})
        var left: int = int(meta.get("hits_left", 0))
        var pct: float = float(meta.get("bonus_pct", PCT))
        if left <= 0:
            tag["remaining"] = 0.0
            return
        var ti: int = int(data.get("target_index", -1))
        if ti < 0:
            return
        var bonus: int = int(max(0.0, round(float(u.spell_power) * pct)))
        if bonus > 0:
            var AbilityEffects = load("res://scripts/game/abilities/effects.gd")
            AbilityEffects.damage_single(engine, st, team, index, ti, bonus, "magic")
        left -= 1
        meta["hits_left"] = left
        tag["data"] = meta
        if left <= 0:
            tag["remaining"] = 0.0
