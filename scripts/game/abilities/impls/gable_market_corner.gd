extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [250, 375, 565]
const AD_RATIO: float = 1.45
const LINE_LENGTH_TILES: float = 7.0
const LINE_WIDTH_TILES: float = 0.8
const SHOT_DURATION: float = 5.0
const SELF_AS: float = 0.22
const SELF_AD: float = 26.0
const SHRED: float = 22.0
const AMP_PCT: float = 0.12

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
	var target_index: int = _highest_hp_enemy(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_index, LINE_LENGTH_TILES, LINE_WIDTH_TILES)
	if not hits.has(target_index):
		hits.append(target_index)
	for extra_index: int in ctx.two_furthest_enemies(ctx.caster_team):
		if hits.size() >= 2:
			break
		if not hits.has(extra_index):
			hits.append(extra_index)
	if ctx.buff_system != null:
		ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, ctx.caster_index, "gable_market_corner_book", {
			"attack_speed": SELF_AS,
			"attack_damage": SELF_AD
		}, SHOT_DURATION)
	var board_value: int = _board_investment(ctx)
	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage) + float(board_value * 18)
	for order: int in range(hits.size()):
		var hit_index: int = hits[order]
		ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, damage, "physical")
		if ctx.buff_system != null:
			ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "on_hit")
			if order % 3 == 0:
				ctx.buff_system.apply_stats_labeled(ctx.state, target_team, hit_index, "gable_market_shred", {
					"armor": -SHRED,
					"magic_resist": -SHRED
				}, SHOT_DURATION)
			elif order % 3 == 1:
				ctx.buff_system.apply_tag(ctx.state, target_team, hit_index, "root", 0.35, {})
			else:
				ctx.buff_system.apply_tag(ctx.state, target_team, hit_index, "gable_market_amp_window", SHOT_DURATION, {
					"damage_amp_pct": AMP_PCT
				})
			ctx.buff_system.pop_source()
	ctx.emit_ramp_state("market_corner", max(2, board_value), float(board_value * 18), 8, SHOT_DURATION, "high_cost_board_context")
	ctx.log("Market Corner: rotated on-hit shots through %d targets" % hits.size())
	return true

func _highest_hp_enemy(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_hp: int = -1
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		if int(enemy.hp) > best_hp:
			best_hp = int(enemy.hp)
			best_index = index
	return best_index

func _board_investment(ctx: AbilityContext) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var value: int = 0
	for ally: Unit in allies:
		if ally == null or not ally.is_alive():
			continue
		value += max(1, int(ally.cost))
	return clamp(value / 2, 2, 8)
