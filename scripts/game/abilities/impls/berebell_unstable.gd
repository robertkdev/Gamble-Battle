extends AbilityImplBase

# Berebell — Unstable
# Frenzy for 5s: +AS and basic attacks gain bonus physical equal to % missing HP of target.
# While frenzied, heals for a % of damage dealt (via lifesteal stat buff).

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const DURATION := 5.0
const AS_PCT := [0.50, 0.75, 1.00]
const MISSING_PCT := [0.08, 0.12, 0.16]
const HEAL_PCT := [0.25, 0.40, 0.50]

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Unstable] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var li: int = _level_index(caster)
    # Attack speed buff (additive): +X% of current AS
    var delta_as: float = float(caster.attack_speed) * float(AS_PCT[li])
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"attack_speed": delta_as}, DURATION)

    # Lifesteal during frenzy equals heal percent
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"lifesteal": float(HEAL_PCT[li])}, DURATION)

    # Tag for on-attack missing HP bonus; also block mana gain during frenzy
    bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_BEREBELL, DURATION, {
        "missing_pct": float(MISSING_PCT[li]),
        "block_mana_gain": true
    })

    ctx.log("Unstable: +%d%% AS, +%d%% lifesteal, %d%% missing-HP bonus for %.1fs" % [
        int(AS_PCT[li]*100.0), int(HEAL_PCT[li]*100.0), int(MISSING_PCT[li]*100.0), DURATION
    ])
    return true
