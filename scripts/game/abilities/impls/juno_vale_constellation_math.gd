extends AbilityImplBase

const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const SHIELD_BASE: Array[int] = [115, 175, 265]
const MANA_GRANT: Array[int] = [10, 16, 24]
const DISRUPT_DAMAGE: Array[int] = [80, 120, 180]
const RADIUS_TILES: float = 2.4
const SHIELD_DURATION: float = 4.5
const STUN_DURATION: float = 0.85
const FORMATION_PUSH_TILES: float = 1.15
const MOVE_DURATION: float = 0.18

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
	var linked_allies: Array[int] = _linked_allies(ctx, caster)
	for ally_index: int in linked_allies:
		_grant_mana(ctx, ally_index, MANA_GRANT[level_index])
		if ctx.buff_system != null:
			ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, SHIELD_BASE[level_index], SHIELD_DURATION)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return not linked_allies.is_empty()
	var target_team: String = _enemy_team(ctx.caster_team)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	for order: int in range(victims.size()):
		var victim_index: int = victims[order]
		ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, float(DISRUPT_DAMAGE[level_index]), "magic")
		ctx.stun(target_team, victim_index, STUN_DURATION)
		_scatter_enemy(ctx, target_team, victim_index, center, order)
		ctx.emit_zone_exposure(target_team, victim_index, "juno_constellation_field", STUN_DURATION, float(DISRUPT_DAMAGE[level_index]), RADIUS_TILES)
		ctx.emit_redirect_semantic(target_team, victim_index, "constellation_misdirection", STUN_DURATION, 1.0, 0.6)
	ctx.log("Constellation Math: linked %d allies and disrupted %d enemies" % [linked_allies.size(), victims.size()])
	return true

func _linked_allies(ctx: AbilityContext, caster: Unit) -> Array[int]:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var output: Array[int] = []
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive() or index == ctx.caster_index:
			continue
		if not _shares_trait(caster, ally):
			output.append(index)
		if output.size() >= 2:
			break
	if output.is_empty():
		var fallback: int = ctx.lowest_hp_ally(ctx.caster_team)
		if fallback >= 0:
			output.append(fallback)
	return output

func _shares_trait(first: Unit, second: Unit) -> bool:
	for first_trait: String in first.traits:
		for second_trait: String in second.traits:
			if String(first_trait) == String(second_trait):
				return true
	return false

func _grant_mana(ctx: AbilityContext, target_index: int, amount: int) -> void:
	var target: Unit = ctx.unit_at(ctx.caster_team, target_index)
	if target == null or not target.is_alive() or int(target.mana_max) <= 0:
		return
	var before: int = int(target.mana)
	target.mana = min(int(target.mana_max), before + max(0, amount))
	var gained: int = int(target.mana) - before
	if gained <= 0:
		return
	ctx.engine._resolver_emit_unit_stat(ctx.caster_team, target_index, {"mana": target.mana})
	if ctx.buff_system != null:
		ctx.buff_system.record_buff(ctx.state, ctx.caster_team, target_index, "juno_mana_link", {"mana": gained}, float(gained), 0.0)

func _scatter_enemy(ctx: AbilityContext, target_team: String, target_index: int, center: Vector2, order: int) -> void:
	var current: Vector2 = ctx.position_of(target_team, target_index)
	var direction: Vector2 = current - center
	if direction.length_squared() <= 0.001:
		var angle: float = float(order) * TAU / 6.0
		direction = Vector2(cos(angle), sin(angle))
	var destination: Vector2 = current + direction.normalized() * FORMATION_PUSH_TILES * ctx.tile_size()
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(target_team, target_index, destination - current, MOVE_DURATION)
	_set_enemy_position(ctx, target_team, target_index, destination)

func _set_enemy_position(ctx: AbilityContext, target_team: String, target_index: int, destination: Vector2) -> void:
	if ctx.engine == null:
		return
	if ctx.engine.arena_state == null:
		_emit_enemy_position(ctx, target_team, target_index, destination)
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	if movement_data == null:
		_emit_enemy_position(ctx, target_team, target_index, destination)
		return
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if target_team == "player":
		if target_index >= 0 and target_index < movement_data.player_positions.size():
			movement_data.player_positions[target_index] = clamped
	else:
		if target_index >= 0 and target_index < movement_data.enemy_positions.size():
			movement_data.enemy_positions[target_index] = clamped
	_emit_enemy_position(ctx, target_team, target_index, clamped)

func _emit_enemy_position(ctx: AbilityContext, target_team: String, target_index: int, position: Vector2) -> void:
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", target_team, target_index, position.x, position.y)
