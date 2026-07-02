extends AbilityImplBase

const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")

const HEAL_BASE: Array[int] = [300, 450, 675]
const SHIELD_BASE: Array[int] = [240, 360, 540]
const TEAM_SHIELD: Array[int] = [80, 120, 180]
const DR: float = 0.24
const PEEL_DURATION: float = 4.5
const DAMAGE_BASE: Array[int] = [120, 180, 270]
const SLOW_DURATION: float = 2.0
const SLOW_AS: float = -0.18

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
	var ally_index: int = _most_threatened_ally(ctx)
	if ally_index < 0:
		return false
	var level_index: int = _level_index(caster)
	var heal_amount: float = float(HEAL_BASE[level_index]) + 0.65 * float(caster.spell_power)
	var heal_result: Dictionary = ctx.heal_single(ctx.caster_team, ally_index, heal_amount)
	if ctx.buff_system != null:
		ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, SHIELD_BASE[level_index], PEEL_DURATION)
		ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, ally_index, "saffron_golden_poultice", {
			"damage_reduction": DR
		}, PEEL_DURATION)
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, ally_index, BuffTags.TAG_CATALYST_META, PEEL_DURATION, {
			"charge": 1,
			"source": "golden_poultice"
		})
		ctx.buff_system.record_buff(ctx.state, ctx.caster_team, ally_index, "saffron_peel_window", {
			"healed": int(heal_result.get("healed", 0)),
			"shield": SHIELD_BASE[level_index]
		}, float(SHIELD_BASE[level_index]), PEEL_DURATION)
		_apply_team_overheal_shields(ctx, ally_index, level_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index >= 0:
		var target_team: String = _enemy_team(ctx.caster_team)
		ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, float(DAMAGE_BASE[level_index]), "magic")
		if ctx.buff_system != null:
			ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "saffron_amber_drag", {
				"attack_speed": SLOW_AS
			}, SLOW_DURATION)
	ctx.log("Golden Poultice: protected ally %d with heal and mitigation" % ally_index)
	return true

func _most_threatened_ally(ctx: AbilityContext) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = INF
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		var hp_pct: float = float(ally.hp) / max(1.0, float(ally.max_hp))
		var score: float = hp_pct
		if index == ctx.caster_index:
			score += 0.2
		if score < best_score:
			best_score = score
			best_index = index
	return best_index

func _apply_team_overheal_shields(ctx: AbilityContext, protected_index: int, level_index: int) -> void:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	for index: int in range(allies.size()):
		if index == protected_index:
			continue
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, index, TEAM_SHIELD[level_index], PEEL_DURATION)
