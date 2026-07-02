extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const DAMAGE_BASE: Array[int] = [145, 225, 340]
const AD_RATIO: float = 1.05
const LINE_LENGTH_TILES: float = 6.0
const LINE_WIDTH_TILES: float = 0.75
const BRACE_DURATION: float = 3.5
const SHRED_DURATION: float = 4.0
const ARMOR_SHRED: float = 28.0
const ATTACK_SPEED_SLOW: float = -0.20

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
		ctx.log("[Brace Shot] BuffSystem not available; cast aborted")
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
	buff_system.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {
		"damage_reduction": 0.28
	}, BRACE_DURATION)
	buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, 1.4, {
		"kind": "rooket_brace"
	})
	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_index, LINE_LENGTH_TILES, LINE_WIDTH_TILES)
	if not hits.has(target_index):
		hits.append(target_index)
	for hit_index: int in hits:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, max(0.0, damage), "physical")
		buff_system.apply_stats_labeled(ctx.state, target_team, hit_index, "rooket_brace_shot_shred", {
			"armor": -ARMOR_SHRED,
			"attack_speed": ATTACK_SPEED_SLOW
		}, SHRED_DURATION)
	ctx.log("Brace Shot: pierced %d targets with shred" % hits.size())
	return true
