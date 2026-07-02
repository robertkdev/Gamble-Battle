extends AbilityImplBase

const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")

const DAMAGE_BASE: Array[int] = [1600, 2400, 3600]
const RADIUS_TILES: float = 3.25
const AMP_DURATION: float = 5.5
const DAMAGE_AMP: Array[float] = [0.16, 0.24, 0.36]
const STAT_AMP: Array[float] = [48.0, 72.0, 108.0]
const TRAIT_DAMAGE: float = 38.0
const STUN_DURATION: float = 0.45

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
	var level_index: int = _level_index(caster)
	var unique_traits: int = _wide_trait_count(ctx)
	_apply_treaty_amp(ctx, level_index, unique_traits)
	var target_team: String = _enemy_team(ctx.caster_team)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	if victims.is_empty():
		victims.append(target_index)
	var damage: float = float(DAMAGE_BASE[level_index]) + float(unique_traits) * TRAIT_DAMAGE + 0.75 * float(caster.spell_power)
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, damage, "magic")
		if bool(result.get("processed", false)):
			ctx.emit_zone_exposure(target_team, victim_index, "meridian_full_spectrum_treaty", 0.75, float(result.get("dealt", damage)), RADIUS_TILES)
			ctx.stun(target_team, victim_index, STUN_DURATION)
	ctx.log("Full Spectrum Treaty: linked %d unique traits and burst %d enemies" % [unique_traits, victims.size()])
	return true

func _wide_trait_count(ctx: AbilityContext) -> int:
	var seen: Dictionary[String, bool] = {}
	var meridian_traits: Dictionary[String, bool] = {
		"Kaleidoscope": true,
		"Liaison": true,
		"Catalyst": true,
	}
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	for index: int in range(allies.size()):
		if index == ctx.caster_index:
			continue
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		for raw_trait: String in ally.traits:
			var trait_id: String = String(raw_trait).strip_edges()
			if trait_id == "" or meridian_traits.has(trait_id):
				continue
			seen[trait_id] = true
	return max(1, seen.size())

func _apply_treaty_amp(ctx: AbilityContext, level_index: int, unique_traits: int) -> void:
	if ctx.buff_system == null:
		return
	var amp: float = float(DAMAGE_AMP[level_index]) + min(0.18, float(unique_traits) * 0.015)
	var stat_bonus: float = float(STAT_AMP[level_index]) + float(unique_traits) * 5.0
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "ability")
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_DAMAGE_AMP, AMP_DURATION, {
			"damage_amp_pct": amp,
			"kind": "meridian_full_spectrum_treaty"
		})
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_ABILITY_AMP, AMP_DURATION, {
			"ability_damage_amp": amp,
			"kind": "meridian_full_spectrum_treaty"
		})
		ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, index, "meridian_treaty_stats", {
			"attack_damage": stat_bonus,
			"spell_power": stat_bonus
		}, AMP_DURATION)
		if index != ctx.caster_index:
			ctx.buff_system.record_buff(ctx.state, ctx.caster_team, index, "meridian_treaty_link", {
				"unique_traits": unique_traits,
				"amp": amp
			}, stat_bonus, AMP_DURATION)
			ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_CATALYST_META, AMP_DURATION, {
				"charge": 1,
				"source": "full_spectrum_treaty"
			})
	ctx.buff_system.pop_source()
