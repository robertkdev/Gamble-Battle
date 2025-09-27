extends AbilityImplBase

# Creep — Eavesdropping
# Dashes to the lowest-health enemy and spins in place, dealing AoE physical damage in rapid ticks.
# Exiled upgrade: longer duration, stronger ticks, first takedown during spin causes a chase to the next lowest-health enemy.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const TICK_INTERVAL := 0.2
const RADIUS_TILES := 2.3
const DR_DURING_SPIN := 0.30

# Per-tick AD multipliers (base) by level 1/2/3
const PER_TICK_AD_BASE := [0.45, 0.70, 1.05]

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
	var bs = ctx.buff_system
	if bs == null:
		ctx.log("[Eavesdropping] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false

	var target_idx: int = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_idx < 0:
		return false

	var exiled: bool = _exile_active(ctx)
	var li: int = _level_index(caster)
	var duration: float = (1.25 if exiled else 1.00)
	var ticks: int = max(1, int(floor((duration + 1e-4) / TICK_INTERVAL)))
	var per_tick_mult: float = float(PER_TICK_AD_BASE[li]) * (1.25 if exiled else 1.0)
	var per_tick_damage: int = int(max(0.0, round(per_tick_mult * float(caster.attack_damage))))

	# Center spin at the target's current world position
	var center: Vector2 = ctx.position_of(_other(ctx.caster_team), target_idx)

	# Apply CC-immune tag and temporary damage reduction while spinning
	bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, duration, {"block_mana_gain": true})
	bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"damage_reduction": DR_DURING_SPIN}, duration)

	# Schedule ticking damage via AbilitySystem events
	var data := {
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
