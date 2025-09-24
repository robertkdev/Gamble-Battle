extends AbilityImplBase

# TRAIT HOOKS: Implement baseline; expose TUNE_* constants + STACK/TAG keys only.
# Gate trait behavior via ctx.trait_tier(ctx.caster_team, "Titan") >= 0; skip when inactive—do not implement trait effects yet.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const TAG_ACTIVE := BuffTags.TAG_KORATH
const STACK_KEY := "korath_titan_stacks"

const PCT_BY_LVL := [0.25, 0.30, 0.35] # absorb percent for 3s
const RELEASE_DELAY_S := 3.0
const RELEASE_BASE_HP_FACTOR := 0.20
const RELEASE_STACK_BONUS := 4

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Absorb & Release] BuffSystem not available; cast aborted")
        return false

    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var lvl: int = max(1, int(caster.level))
    var pct: float = PCT_BY_LVL[min(2, lvl - 1)]

    # Titan gating: only gain a Titan stack if the Titan trait is active on the team
    var titan_active: bool = (ctx.trait_tier(ctx.caster_team, "Titan") >= 0)
    if titan_active:
        bs.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, STACK_KEY, 1)
    var stacks_at_cast: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, STACK_KEY))

    # Apply timed absorbing tag; also block mana gain while active
    var meta := {
        "pct": pct,
        "pool": 0,
        "stacks_at_cast": stacks_at_cast,
        "block_mana_gain": true
    }
    bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, TAG_ACTIVE, RELEASE_DELAY_S, meta)

    # Schedule release event via AbilitySystem; store meta reference so absorbed pool accumulates
    if ctx.engine.ability_system != null and ctx.engine.ability_system.has_method("schedule_event"):
        ctx.engine.ability_system.schedule_event("korath_release", ctx.caster_team, ctx.caster_index, RELEASE_DELAY_S, {"meta": meta})

    ctx.log("Absorb & Release: absorbing %.0f%% of damage for %.1fs" % [pct * 100.0, RELEASE_DELAY_S])
    return true
