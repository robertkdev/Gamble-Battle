extends AbilityImplBase

# Sari — Strike
# Fires a precise shot at the current target, shredding armor and ramping attack speed.

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

const DMG_BASE := [210, 280, 360]
const AD_RATIO := 1.10
const AS_BUFF_PCT := 0.35
const AS_BUFF_DUR := 3.5
const ARMOR_SHRED := 20.0
const SHRED_DURATION := 4.0
const FOLLOWUP_RATIO := 0.60
const AD_BUFF_PCT := 0.20

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs: BuffSystem = ctx.buff_system
    if bs == null:
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false
    var tgt_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if tgt_idx < 0:
        return false
    var li: int = _level_index(caster)
    var dmg: float = float(DMG_BASE[li]) + AD_RATIO * float(caster.attack_damage)
    var dealt: float = ctx.damage_single(ctx.caster_team, ctx.caster_index, tgt_idx, max(0.0, dmg), "physical").get("dealt", dmg)
    var bonus_dmg: float = max(0.0, dealt * FOLLOWUP_RATIO)
    if bonus_dmg > 0.0:
        ctx.damage_single(ctx.caster_team, ctx.caster_index, tgt_idx, bonus_dmg, "physical")
    # Temporary attack-speed buff
    var delta_as: float = float(caster.attack_speed) * AS_BUFF_PCT
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"attack_speed": delta_as}, AS_BUFF_DUR)
    # Add a small attack-damage steroid so follow-up arrows bite harder
    var delta_ad: float = float(caster.attack_damage) * AD_BUFF_PCT
    if delta_ad > 0.0:
        bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"attack_damage": delta_ad}, AS_BUFF_DUR)
    ctx.emit_ramp_state("timed_window", 1, delta_as + delta_ad, 1, AS_BUFF_DUR, "sari_strike_attack_speed_window")
    # Armor shred on target to amplify follow-up pressure
    bs.apply_stats_buff(ctx.state, _enemy_team(ctx.caster_team), tgt_idx, {"armor": -ARMOR_SHRED}, SHRED_DURATION)
    ctx.log("Strike: dealt %d + %d, -%d armor for %.1fs, +35%% AS for %.1fs" % [
        int(round(dealt)), int(round(bonus_dmg)), int(ARMOR_SHRED), SHRED_DURATION, AS_BUFF_DUR
    ])
    return true

func _enemy_team(team: String) -> String:
    return "enemy" if team == "player" else "player"
