extends AbilityImplBase

# Bo — Writ of Severance
# Tosses weapon through current target (line 3.0 tiles, width 0.6), damaging all hit.
# Then dashes to the weapon's landing point, Unstoppable with 30% DR; enemies passed through are knocked up and damaged.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const LINE_LEN_TILES := 3.0
const LINE_WIDTH_TILES := 0.6
const DR_DURING_DASH := 0.30
const KNOCKUP_DURATION := 0.75
const DASH_SPEED_TPS := 6.0 # tiles per second (3 tiles => ~0.5s)

const TOSS_AD_MULT := [1.50, 2.25, 3.50]
const DASH_AD_MULT := [0.60, 0.90, 1.40]

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _other(team: String) -> String:
    return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Writ of Severance] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx < 0:
        return false

    var li: int = _level_index(caster)
    var toss_dmg: int = int(max(0.0, round(TOSS_AD_MULT[li] * float(caster.attack_damage))))
    var dash_dmg: int = int(max(0.0, round(DASH_AD_MULT[li] * float(caster.attack_damage))))

    # 1) Weapon toss: line damage through target
    var victims: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_idx, LINE_LEN_TILES, LINE_WIDTH_TILES)
    for vi in victims:
        ctx.damage_single(ctx.caster_team, ctx.caster_index, int(vi), float(toss_dmg), "physical")

    # Compute dash vector toward landing point (3 tiles along the same direction)
    var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var tgt_pos: Vector2 = ctx.position_of(_other(ctx.caster_team), target_idx)
    var dir: Vector2 = (tgt_pos - start)
    var ts: float = ctx.tile_size()
    var fwd: Vector2 = (dir.normalized() if dir.length() > 0.0 else Vector2.RIGHT)
    var vec_world: Vector2 = fwd * LINE_LEN_TILES * ts
    var dash_len_tiles: float = LINE_LEN_TILES
    var dash_dur: float = dash_len_tiles / max(0.1, float(DASH_SPEED_TPS))

    # 2) Dash phase control: block normal movement, add CC immunity and DR during the dash
    bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, "root", dash_dur, {})
    bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, dash_dur, {"block_mana_gain": true})
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"damage_reduction": DR_DURING_DASH}, dash_dur)

    # 2b) Schedule dash ticks to apply knockups/damage along the actual path
    if ctx.engine != null and ctx.engine.ability_system != null:
        var end_pos: Vector2 = start + vec_world
        var meta := {
            "start_pos": start,
            "end_pos": end_pos,
            "dur": dash_dur,
            "remain": dash_dur,
            "tick": 0.06,
            "width_tiles": LINE_WIDTH_TILES,
            "damage": dash_dmg,
            "knock": KNOCKUP_DURATION,
            "hit": {},
            "last_pos": start
        }
        ctx.engine.ability_system.schedule_event("bo_wos_dash_tick", ctx.caster_team, ctx.caster_index, 0.0, meta)

    # 3) Retarget nearest after landing (schedule for after dash duration)
    if ctx.engine != null and ctx.engine.ability_system != null:
        var end_pos2: Vector2 = start + vec_world
        ctx.engine.ability_system.schedule_event("bo_wos_land", ctx.caster_team, ctx.caster_index, dash_dur, {"end_pos": end_pos2})

    ctx.log("Writ of Severance: toss %d to %d, dash %.2fs" % [toss_dmg, dash_dmg, dash_dur])
    return true
