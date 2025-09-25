extends AbilityImplBase

# Veyra — Harden
# For 4s: Veyra gains flat DR = 40 + (Aegis stacks).
# Snapshot at cast: Veyra and allies within 2 tiles gain CC-immunity for 4s (follows them as their own timed tag).
# On end: Veyra gains (Aegis stacks)% Max HP for the rest of combat.

const DURATION_S := 4.0
const RADIUS_TILES := 2.0
const KEY_AEGIS_STACKS := "aegis_stacks"               # future-provided by Aegis systems; 0 if absent
const KEY_HARDEN_MAXHP := "veyra_harden_hp"            # permanent stack key applying max_hp delta
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

func _read_aegis_stacks(ctx: AbilityContext) -> int:
    if ctx == null or ctx.buff_system == null:
        return 0
    # Prepared for trait wiring later: try a BuffSystem stack first; falls back to 0.
    return int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_AEGIS_STACKS))

func _snapshot_allies_in_radius(ctx: AbilityContext, radius_tiles: float) -> Array[int]:
    var out: Array[int] = []
    if ctx == null or ctx.engine == null:
        return out
    var center: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var ts: float = ctx.tile_size()
    var eps: float = ctx._range_epsilon()
    var allies: Array = ctx.ally_team_array(ctx.caster_team)
    for i in range(allies.size()):
        var u: Unit = allies[i]
        if u == null or not u.is_alive():
            continue
        var p: Vector2 = ctx.position_of(ctx.caster_team, i)
        if MovementMath.within_radius_tiles(center, p, radius_tiles, ts, eps):
            out.append(i)
    return out

func cast(ctx: AbilityContext) -> bool:
    if ctx == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Harden] BuffSystem not available; cast aborted")
        return false

    var stacks: int = max(0, _read_aegis_stacks(ctx))
    var flat_dr: float = 40.0 + float(stacks)

    # Apply timed flat DR buff to Veyra
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, { "damage_reduction_flat": flat_dr }, DURATION_S)

    # Snapshot allies in radius and grant CC-immunity tag for DURATION_S (tag follows them)
    var targets: Array[int] = _snapshot_allies_in_radius(ctx, RADIUS_TILES)
    var applied: int = 0
    for i in targets:
        var r := bs.apply_tag(ctx.state, ctx.caster_team, i, BuffTags.TAG_CC_IMMUNE, DURATION_S, {})
        if bool(r.get("processed", true)):
            applied += 1

    # Schedule end-of-buff effect: +(stacks)% Max HP for rest of combat (on Veyra)
    if ctx.engine != null and ctx.engine.ability_system != null:
        ctx.engine.ability_system.schedule_event("veyra_harden_end", ctx.caster_team, ctx.caster_index, DURATION_S, {})

    ctx.log("Harden: +%d flat DR for %.1fs; CC-immune %d ally(ies) (stacks=%d)" % [int(flat_dr), DURATION_S, applied, stacks])
    return true
