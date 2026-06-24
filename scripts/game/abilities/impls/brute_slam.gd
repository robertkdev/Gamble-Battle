extends AbilityImplBase

# Brute — Slam
# Leap into the fight, shattering shields, knocking up nearby enemies, and fortifying armor.

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

const HEAL_BASE := [170, 230, 310]
const HEAL_PER_STACK := 24
const DMG_BASE := [80, 120, 170]
const DMG_PER_STACK := 10
const KNOCKUP_DURATION := 0.75
const RADIUS_TILES := 1.25
const DASH_MAX_TILES := 1.5
const KEEP_DISTANCE_TILES := 0.4
const MOVE_DURATION := 0.25
const ARMOR_BUFF := 24.0
const DAMAGE_REDUCTION_BUFF := 0.15
const BUFF_DURATION := 5.0
const PULL_MAX_TILES := 0.9
const SHIELD_BASE := [200, 260, 340]
const SHIELD_PER_STACK := 10.0

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var bs = ctx.buff_system
	if bs == null:
		ctx.log("[Slam] BuffSystem not available; cast aborted")
		return false

	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false

	var lvl: int = clamp(int(caster.level), 1, 3)
	var heal_base: int = int(HEAL_BASE[lvl - 1])
	var dmg_base: int = int(DMG_BASE[lvl - 1])

	var stacks_at_cast: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.TITAN))
	var heal_amount: int = max(0, heal_base + HEAL_PER_STACK * stacks_at_cast)
	var damage_amount: int = max(0, dmg_base + DMG_PER_STACK * stacks_at_cast)
	var shield_amount: int = max(0, int(round(float(SHIELD_BASE[lvl - 1]) + SHIELD_PER_STACK * float(stacks_at_cast))))

	var impact_center: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_idx < 0:
		var nearest: Array[int] = ctx.two_nearest_enemies(ctx.caster_team)
		if nearest.size() > 0:
			target_idx = int(nearest[0])

	var dash_vec: Vector2 = Vector2.ZERO
	if target_idx >= 0:
		var enemy_team: String = _other(ctx.caster_team)
		var target_pos: Vector2 = ctx.position_of(enemy_team, target_idx)
		dash_vec = _compute_dash_vector(impact_center, target_pos, ctx.tile_size())
		if dash_vec.length() > 0.01:
			if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
				ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, dash_vec, MOVE_DURATION)
			impact_center += dash_vec

	var targets: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, impact_center, RADIUS_TILES)
	var enemy_team_name: String = _other(ctx.caster_team)

	for ti in targets:
		# Pull enemies slightly toward the slam impact to ensure engagement
		if ctx.engine != null and ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
			var enemy_pos: Vector2 = ctx.position_of(enemy_team_name, ti)
			var pull_vec: Vector2 = impact_center - enemy_pos
			var pull_len: float = pull_vec.length()
			if pull_len > 0.01:
				var ts2: float = ctx.tile_size()
				var max_pull: float = PULL_MAX_TILES * ts2
				if pull_len > max_pull:
					pull_vec = pull_vec.normalized() * max_pull
				ctx.engine.arena_state.notify_forced_movement(enemy_team_name, ti, pull_vec, MOVE_DURATION)
		AbilityEffects.stun(bs, ctx.engine, ctx.state, enemy_team_name, ti, KNOCKUP_DURATION, ctx.caster_team, ctx.caster_index)
		if ctx.engine and ctx.engine.has_method("_resolver_emit_vfx_knockup"):
			ctx.engine._resolver_emit_vfx_knockup(enemy_team_name, ti, KNOCKUP_DURATION)
		var removed: int = bs.break_shields_on(ctx.state, enemy_team_name, ti)
		if removed > 0:
			ctx.log("Slam shatters %d shield." % removed)
		ctx.damage_single(ctx.caster_team, ctx.caster_index, ti, float(damage_amount), "physical")

	if shield_amount > 0:
		bs.apply_shield(ctx.state, ctx.caster_team, ctx.caster_index, shield_amount, BUFF_DURATION)
	ctx.heal_single(ctx.caster_team, ctx.caster_index, float(heal_amount))
	if ARMOR_BUFF > 0.0 or DAMAGE_REDUCTION_BUFF > 0.0:
		var fields := {"armor": ARMOR_BUFF, "magic_resist": ARMOR_BUFF}
		if DAMAGE_REDUCTION_BUFF > 0.0:
			fields["damage_reduction"] = DAMAGE_REDUCTION_BUFF
		bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, fields, BUFF_DURATION)

	ctx.log("Slam: heal %d + shield %d, dmg %d (stacks=%d, hits=%d, DR=%.0f%%)" % [
		heal_amount,
		shield_amount,
		damage_amount,
		stacks_at_cast,
		targets.size(),
		DAMAGE_REDUCTION_BUFF * 100.0
	])
	return true

func _compute_dash_vector(start: Vector2, target: Vector2, tile_size: float) -> Vector2:
	var dir: Vector2 = target - start
	var dist: float = dir.length()
	if dist <= 0.01:
		return Vector2.ZERO
	var keep_gap: float = KEEP_DISTANCE_TILES * tile_size
	var desired: float = max(0.0, dist - keep_gap)
	var max_step: float = DASH_MAX_TILES * tile_size
	var step: float = min(desired, max_step)
	if step <= 0.01:
		return Vector2.ZERO
	return dir.normalized() * step

func _other(team: String) -> String:
	return "enemy" if team == "player" else "player"
