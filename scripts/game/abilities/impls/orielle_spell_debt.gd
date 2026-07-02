extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [210, 315, 475]
const TICK_DAMAGE: Array[int] = [34, 52, 78]
const RADIUS_TILES: float = 2.7
const ZONE_TICKS: int = 5
const ZONE_INTERVAL: float = 0.42
const STUN_DURATION: float = 0.55
const DEBT_DURATION: float = 6.0
const MANA_SLOW: float = -6.0

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
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var level_index: int = _level_index(caster)
	var debt_stacks: int = max(3, _mana_pressure(ctx))
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	if victims.is_empty():
		victims.append(target_index)
	var damage: float = float(DAMAGE_BASE[level_index]) + float(debt_stacks * 26) + 0.55 * float(caster.spell_power)
	for victim_index: int in victims:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, damage, "magic")
		ctx.emit_zone_exposure(target_team, victim_index, "orielle_spell_debt_zone", ZONE_INTERVAL * float(ZONE_TICKS), damage, RADIUS_TILES)
		if ctx.buff_system != null:
			ctx.buff_system.apply_stats_labeled(ctx.state, target_team, victim_index, "orielle_debt_timing_tax", {
				"mana_regen": MANA_SLOW
			}, DEBT_DURATION)
	ctx.stun(target_team, target_index, STUN_DURATION)
	ctx.emit_ramp_state("spell_debt", debt_stacks, float(debt_stacks * 26), 8, DEBT_DURATION, "stored_mana")
	if ctx.engine.ability_system != null:
		ctx.engine.ability_system.schedule_event("planned_area_tick", ctx.caster_team, ctx.caster_index, ZONE_INTERVAL, {
			"center": center,
			"radius": RADIUS_TILES,
			"damage": TICK_DAMAGE[level_index],
			"damage_type": "magic",
			"ticks_left": ZONE_TICKS,
			"interval": ZONE_INTERVAL,
			"dot_kind": "orielle_spell_debt_tick",
			"zone_kind": "orielle_spell_debt_zone"
		})
	ctx.log("Spell Debt: detonated %d debt stacks across %d enemies" % [debt_stacks, victims.size()])
	return true

func _mana_pressure(ctx: AbilityContext) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var pressure: int = 0
	for ally: Unit in allies:
		if ally == null or not ally.is_alive():
			continue
		if int(ally.mana_max) > 0:
			pressure += 1 + int(float(ally.mana) / max(1.0, float(ally.mana_max)) * 2.0)
	return clamp(pressure, 3, 8)
