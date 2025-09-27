extends AbilityImplBase

# Vykos — Blood Feast
# Slams in a forward cone, dealing base+AD physical to enemies in a 2‑tile cone.
# Heals based on damage dealt per target and gains temporary Armor/MR per enemy hit.
# On kill by this ability, gains +10% lifesteal for 5s.

const KNOCK_RANGE_TILES := 2.0 # cone radius
const CONE_HALF_ANGLE_DEG := 30.0 # total 60° cone

const BASE_BY_LEVEL := [200, 350, 500]
const AD_SCALE := 1.20

const LEECH_PCT_BY_LEVEL := [0.20, 0.30, 0.40] # fraction of dealt per enemy
const BUFF_ARMOR_BY_LEVEL := [30, 40, 50]
const BUFF_DR_DURATION := 4.0
const LIFESTEAL_ON_EXECUTE := 0.10
const LIFESTEAL_DUR := 5.0

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _other(team: String) -> String:
    return "enemy" if team == "player" else "player"

func _cone_hits(ctx: AbilityContext, center: Vector2, dir_fwd: Vector2, radius_tiles: float, half_angle_deg: float) -> Array[int]:
    var out: Array[int] = []
    if dir_fwd == Vector2.ZERO:
        return out
    var ts: float = ctx.tile_size()
    var max_d: float = max(0.0, radius_tiles) * ts
    var cos_thresh: float = cos(deg_to_rad(max(0.0, half_angle_deg)))
    var tgt_team: String = _other(ctx.caster_team)
    var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
    for i in range(enemies.size()):
        var u: Unit = enemies[i]
        if u == null or not u.is_alive():
            continue
        var p: Vector2 = ctx.position_of(tgt_team, i)
        var v: Vector2 = p - center
        var d: float = v.length()
        if d <= 0.0 or d > max_d:
            continue
        var vd: Vector2 = v / d
        var dp: float = dir_fwd.dot(vd)
        if dp >= cos_thresh:
            out.append(i)
    return out

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Blood Feast] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    # Determine facing by target; fallback to lowest-HP enemy
    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx < 0:
        target_idx = ctx.lowest_hp_enemy(ctx.caster_team)
    if target_idx < 0:
        return false

    var origin: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var tgt_pos: Vector2 = ctx.position_of(_other(ctx.caster_team), target_idx)
    var dir: Vector2 = (tgt_pos - origin)
    var fwd: Vector2 = (dir.normalized() if dir.length() > 0.0 else Vector2.RIGHT)

    var li: int = _level_index(caster)
    var base_dmg: int = int(BASE_BY_LEVEL[li])
    var dmg_total: float = float(base_dmg) + AD_SCALE * float(caster.attack_damage)
    var per_hit_heal_pct: float = float(LEECH_PCT_BY_LEVEL[li])
    var per_enemy_buff_val: int = int(BUFF_ARMOR_BY_LEVEL[li])

    # Collect victims within cone and apply damage, tracking dealt and kills
    var victims: Array[int] = _cone_hits(ctx, origin, fwd, KNOCK_RANGE_TILES, CONE_HALF_ANGLE_DEG)
    if victims.is_empty():
        ctx.log("Blood Feast: no targets in cone")
        return true
    var tgt_team: String = _other(ctx.caster_team)
    var total_heal: int = 0
    var killed_any: bool = false
    for vi in victims:
        var res: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, int(vi), max(0.0, dmg_total), "physical")
        var dealt: int = int(res.get("dealt", 0))
        var after_hp: int = int(res.get("after_hp", 1))
        total_heal += int(round(float(dealt) * per_hit_heal_pct))
        if after_hp <= 0:
            killed_any = true

    # Heal self based on sum across all hits
    if total_heal > 0:
        ctx.heal_single(ctx.caster_team, ctx.caster_index, float(total_heal))

    # Temporary Armor/MR buff proportional to enemies hit
    var stack_val: int = max(0, per_enemy_buff_val * victims.size())
    if stack_val > 0:
        bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"armor": float(stack_val), "magic_resist": float(stack_val)}, BUFF_DR_DURATION)

    # On kill: temporary lifesteal buff
    if killed_any:
        bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"lifesteal": LIFESTEAL_ON_EXECUTE}, LIFESTEAL_DUR)

    ctx.log("Blood Feast: hit %d, dealt %d+%.0f%%AD, healed %d, +%d Armor/MR for %.1fs%s" % [
        victims.size(), base_dmg, AD_SCALE*100.0, total_heal, stack_val, BUFF_DR_DURATION, (", +10% lifesteal" if killed_any else "")
    ])
    return true
