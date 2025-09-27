extends AbilityImplBase

# TRAIT HOOKS: Implement baseline; expose TUNE_* constants + STACK/TAG keys only.
# Gate trait behavior via ctx.trait_tier(ctx.caster_team, "Titan") >= 0; skip when inactive.

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

const HEAL_BASE := [120, 170, 240]
const HEAL_PER_STACK := 20
const DMG_BASE := [110, 165, 250]
const DMG_PER_STACK := 15
const KNOCKUP_DURATION := 0.75
const RADIUS_TILES := 1.0

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Slam] BuffSystem not available; cast aborted")
        return false

    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var lvl: int = clamp(int(caster.level), 1, 3)
    var heal_base: int = int(HEAL_BASE[lvl - 1])
    var dmg_base: int = int(DMG_BASE[lvl - 1])

    # Read unified Titan stack key (managed by trait system). Do not add stacks here.
    var stacks_at_cast: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.TITAN))

    var heal_amount: int = max(0, heal_base + HEAL_PER_STACK * stacks_at_cast)
    var damage_amount: int = max(0, dmg_base + DMG_PER_STACK * stacks_at_cast)

    # Targets: enemies in radius around caster
    var targets: Array[int] = ctx.enemies_in_radius(ctx.caster_team, ctx.caster_index, RADIUS_TILES)

    # Instant: knock up, break shields, and deal damage
    var enemy_team: String = ("enemy" if ctx.caster_team == "player" else "player")
    for ti in targets:
        # Knock up (stun + VFX)
        AbilityEffects.stun(bs, ctx.engine, ctx.state, enemy_team, ti, KNOCKUP_DURATION)
        if ctx.engine and ctx.engine.has_method("_resolver_emit_vfx_knockup"):
            ctx.engine._resolver_emit_vfx_knockup(enemy_team, ti, KNOCKUP_DURATION)
        # Break shields before damage
        var removed: int = bs.break_shields_on(ctx.state, enemy_team, ti)
        if removed > 0:
            ctx.log("Slam shatters %d shield." % removed)
        # Damage
        ctx.damage_single(ctx.caster_team, ctx.caster_index, ti, float(damage_amount), "physical")

    # Heal self (instant)
    ctx.heal_single(ctx.caster_team, ctx.caster_index, float(heal_amount))

    ctx.log("Slam: heal %d, dmg %d (stacks=%d)" % [heal_amount, damage_amount, stacks_at_cast])
    return true
