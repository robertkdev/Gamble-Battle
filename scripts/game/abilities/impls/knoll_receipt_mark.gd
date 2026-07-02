extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [150, 230, 340]
const SP_RATIO: float = 0.70
const STUN_DURATION: float = 1.05
const MARK_DURATION: float = 4.0
const ARMOR_SHRED: float = 18.0
const MR_SHRED: float = 18.0
const ATTACK_SPEED_TAX: float = -0.18

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var buff_system: BuffSystem = ctx.buff_system
	if buff_system == null:
		ctx.log("[Receipt Mark] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + SP_RATIO * float(caster.spell_power)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, max(0.0, damage), "magic")
	ctx.stun(target_team, target_index, STUN_DURATION)
	buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "knoll_receipt_mark", {
		"armor": -ARMOR_SHRED,
		"magic_resist": -MR_SHRED,
		"attack_speed": ATTACK_SPEED_TAX
	}, MARK_DURATION)
	buff_system.record_debuff(ctx.state, target_team, target_index, "receipt_mark", {
		"marked": true
	}, ARMOR_SHRED + MR_SHRED + absf(ATTACK_SPEED_TAX), MARK_DURATION)
	ctx.log("Receipt Mark: target %d taxed for %.1fs" % [target_index, MARK_DURATION])
	return true
