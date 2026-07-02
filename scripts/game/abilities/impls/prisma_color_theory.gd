extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [145, 220, 330]
const RADIUS_TILES: float = 2.35
const AMP_DURATION: float = 4.5
const DAMAGE_AMP: Array[float] = [0.10, 0.15, 0.22]

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var level_index: int = _level_index(caster)
	_apply_team_amp(ctx, float(DAMAGE_AMP[level_index]))
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return true
	var target_team: String = _enemy_team(ctx.caster_team)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, float(DAMAGE_BASE[level_index]), "magic")
		if bool(result.get("processed", false)):
			ctx.emit_zone_exposure(target_team, victim_index, "prisma_color_field", 1.0, float(result.get("dealt", DAMAGE_BASE[level_index])), RADIUS_TILES)
	ctx.log("Color Theory: amplified team and burst %d enemies" % victims.size())
	return true

func _apply_team_amp(ctx: AbilityContext, amp: float) -> void:
	if ctx.buff_system == null:
		return
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "ability")
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_DAMAGE_AMP, AMP_DURATION, {
			"damage_amp_pct": amp,
			"kind": "prisma_color_theory"
		})
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_ABILITY_AMP, AMP_DURATION, {
			"ability_damage_amp": amp,
			"kind": "prisma_color_theory"
		})
	ctx.buff_system.pop_source()
