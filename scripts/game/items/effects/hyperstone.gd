extends ItemEffectBase

const BuffTagsItems := preload("res://scripts/game/abilities/buff_tags_items.gd")

# Representative behavior:
# - Build up attack speed over time (gated by a 1s ICD so it ramps roughly once/second during activity)
# - When at cap, basic attacks cause additional magic bleed damage on the target.
# Numbers are placeholders; balance later.

const TAG_META := BuffTagsItems.TAG_ITEM_HYPERSTONE_META      # holds { stacks:int, at_cap:bool }
const TAG_STACK_ICD := BuffTagsItems.TAG_ITEM_HYPERSTONE_STACK_ICD
const AS_PER_STACK := 0.04                     # +4% AS per stack (additive via stats buff)
const MAX_STACKS := 5                          # cap stacks
const STACK_DURATION := 6.0                    # each AS stack lasts 6s, refreshed as new stacks are added
const STACK_ICD := 1.0                         # at most one new stack per second

const BLEED_PCT_AD := 0.15                     # while at cap, on-hit bonus magic equal to 15% AD

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

    if ev == "combat_started":
        # Reset meta tag
        buff_system.apply_tag(st, team, index, TAG_META, 3600.0, {"stacks": 0, "at_cap": false})
        return

    if ev == "hit_dealt":
        # Try to build a new AS stack if not on ICD
        if not buff_system.has_tag(st, team, index, TAG_STACK_ICD):
            var meta: Dictionary = buff_system.get_tag_data(st, team, index, TAG_META)
            var stacks: int = int(meta.get("stacks", 0))
            if stacks < MAX_STACKS:
                stacks += 1
                meta["stacks"] = stacks
                meta["at_cap"] = stacks >= MAX_STACKS
                buff_system.apply_tag(st, team, index, TAG_META, 3600.0, meta)
                # Apply/refresh a labeled AS buff for visibility and deterministic stacking
                var label := BuffTagsItems.LABEL_PREFIX_HYPERSTONE_AS + str(stacks)
                buff_system.apply_stats_labeled(st, team, index, label, {"attack_speed": AS_PER_STACK}, STACK_DURATION)
            # Gate next stack attempt
            buff_system.apply_tag(st, team, index, TAG_STACK_ICD, STACK_ICD, {})

        # While at cap, apply an on-hit magic bleed proxy as immediate magic damage
        var meta2: Dictionary = buff_system.get_tag_data(st, team, index, TAG_META)
        if bool(meta2.get("at_cap", false)):
            var ti: int = int(data.get("target_index", -1))
            if ti >= 0:
                var bonus: int = int(max(0.0, round(float(u.attack_damage) * BLEED_PCT_AD)))
                if bonus > 0:
                    var AbilityEffects = load("res://scripts/game/abilities/effects.gd")
                    AbilityEffects.damage_single(engine, st, team, index, ti, bonus, "magic")
