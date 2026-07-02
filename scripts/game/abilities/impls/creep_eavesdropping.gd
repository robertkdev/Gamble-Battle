extends AbilityImplBase

# Creep — Eavesdropping
# Dives into the enemy backline and spins in place, dealing AoE physical damage in rapid ticks.
# Exiled upgrade: longer duration, stronger ticks, first takedown during spin causes a chase to the next lowest-health enemy.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const TICK_INTERVAL: float = 0.2
const RADIUS_TILES: float = 2.3
const DR_DURING_SPIN: float = 0.30
const DASH_OVERSHOOT_TILES: float = 0.75
const MOVE_DURATION: float = 0.22

# Per-tick AD multipliers (base) by level 1/2/3
const PER_TICK_AD_BASE: Array[float] = [0.45, 0.70, 1.05]

func _level_index(u: Unit) -> int:
	var lvl: int = (int(u.level) if u != null else 1)
	return clamp(lvl - 1, 0, 2)

func _exile_active(ctx: AbilityContext) -> bool:
	if ctx == null:
		return false
	var c: int = 0
	if ctx.has_method("trait_count"):
		c = ctx.trait_count(ctx.caster_team, "Exile")
	return c > 0

func _other(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var bs: BuffSystem = ctx.buff_system
	if bs == null:
		ctx.log("[Eavesdropping] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false

	var target_idx: int = _priority_backline_enemy(ctx)
	if target_idx < 0:
		return false

	var exiled: bool = _exile_active(ctx)
	var li: int = _level_index(caster)
	var duration: float = (1.25 if exiled else 1.00)
	var ticks: int = max(1, int(floor((duration + 1e-4) / TICK_INTERVAL)))
	var per_tick_mult: float = float(PER_TICK_AD_BASE[li]) * (1.25 if exiled else 1.0)
	var per_tick_damage: int = int(max(0.0, round(per_tick_mult * float(caster.attack_damage))))

	var target_team: String = _other(ctx.caster_team)
	var center: Vector2 = _dash_to_enemy_backline(ctx, target_team, target_idx)

	# Apply CC-immune tag and temporary damage reduction while spinning
	bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, duration, {"block_mana_gain": true})
	bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"damage_reduction": DR_DURING_SPIN}, duration)

	# Schedule ticking damage via AbilitySystem events
	var data: Dictionary = {
		"center": center,
		"damage": per_tick_damage,
		"radius": float(RADIUS_TILES),
		"ticks_left": ticks,
		"interval": float(TICK_INTERVAL),
		"exiled": exiled,
		"allow_chase": exiled,
		"chase_used": false,
		"shred_pct": 0.10,
		"shred_dur": 3.0
	}
	if ctx.engine != null and ctx.engine.ability_system != null:
		ctx.engine.ability_system.schedule_event("creep_eaves_tick", ctx.caster_team, ctx.caster_index, 0.0, data)
	ctx.log("Eavesdropping: spin %.2fs, %d ticks, %d per tick" % [duration, ticks, per_tick_damage])
	return true

func _priority_backline_enemy(ctx: AbilityContext) -> int:
	var far_targets: Array[int] = ctx.two_furthest_enemies(ctx.caster_team)
	if not far_targets.is_empty():
		return int(far_targets[0])
	return ctx.lowest_hp_enemy(ctx.caster_team)

func _dash_to_enemy_backline(ctx: AbilityContext, target_team: String, target_index: int) -> Vector2:
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_pos: Vector2 = ctx.position_of(target_team, target_index)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var enemy_depth_x: float = abs(target_pos.x) * sign_x
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_pos: Vector2 = ctx.position_of(target_team, enemy_index)
		var projected_enemy_x: float = abs(enemy_pos.x) * sign_x
		if sign_x > 0.0:
			enemy_depth_x = max(enemy_depth_x, projected_enemy_x)
		else:
			enemy_depth_x = min(enemy_depth_x, projected_enemy_x)
	var tile: float = ctx.tile_size()
	var destination: Vector2 = Vector2(enemy_depth_x + sign_x * DASH_OVERSHOOT_TILES * tile, 0.0)
	var delta: Vector2 = destination - start
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement") and delta.length() > 0.001:
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, delta, MOVE_DURATION)
	return _set_position(ctx, destination)

func _set_position(ctx: AbilityContext, destination: Vector2) -> Vector2:
	if ctx.engine == null:
		return destination
	if ctx.engine.arena_state == null:
		_emit_position(ctx, destination)
		return destination
	var movement_data: Variant = ctx.engine.arena_state.data
	if movement_data == null:
		_emit_position(ctx, destination)
		return destination
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if ctx.caster_team == "player":
		if ctx.caster_index >= 0 and ctx.caster_index < movement_data.player_positions.size():
			movement_data.player_positions[ctx.caster_index] = clamped
	else:
		if ctx.caster_index >= 0 and ctx.caster_index < movement_data.enemy_positions.size():
			movement_data.enemy_positions[ctx.caster_index] = clamped
	_emit_position(ctx, clamped)
	return clamped

func _emit_position(ctx: AbilityContext, position: Vector2) -> void:
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", ctx.caster_team, ctx.caster_index, position.x, position.y)
