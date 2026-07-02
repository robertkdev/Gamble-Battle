extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const SHIELD_BASE: Array[int] = [120, 190, 290]
const SP_RATIO: float = 0.45
const MANA_GRANT: Array[int] = [8, 14, 22]
const DAMAGE_AMP: Array[float] = [0.10, 0.15, 0.22]
const BUFF_DURATION: float = 5.0
const ENGAGE_TILES: float = 1.1
const CASTER_ENGAGE_TILES: float = 1.35
const MOVE_DURATION: float = 0.22
const OPENING_STUN_DURATION: float = 1.05

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
		ctx.log("[Lesson Plan] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var student_index: int = _student_for(ctx, caster)
	if student_index < 0:
		return false
	var student: Unit = ctx.unit_at(ctx.caster_team, student_index)
	if student == null or not student.is_alive():
		return false
	var level_index: int = _level_index(caster)
	var shield_amount: int = int(max(0.0, round(float(SHIELD_BASE[level_index]) + SP_RATIO * float(caster.spell_power))))
	buff_system.apply_shield(ctx.state, ctx.caster_team, student_index, shield_amount, BUFF_DURATION)
	_grant_mana(ctx, student_index, int(MANA_GRANT[level_index]))
	_apply_amp(ctx, buff_system, student_index, float(DAMAGE_AMP[level_index]))
	_send_student_forward(ctx, student_index)
	_send_caster_forward(ctx)
	_stun_opening_target(ctx)
	ctx.log("Lesson Plan: student %d shielded for %d and sent forward" % [student_index, shield_amount])
	return true

func _student_for(ctx: AbilityContext, caster: Unit) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var fallback: int = -1
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive() or index == ctx.caster_index:
			continue
		if fallback < 0:
			fallback = index
		if not _shares_trait(caster, ally):
			return index
	if fallback >= 0:
		return fallback
	return ctx.caster_index

func _shares_trait(first: Unit, second: Unit) -> bool:
	if first == null or second == null:
		return false
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
		ctx.buff_system.record_buff(ctx.state, ctx.caster_team, target_index, "lesson_mana", {"mana": gained}, float(gained), 0.0)

func _apply_amp(ctx: AbilityContext, buff_system: BuffSystem, target_index: int, amp: float) -> void:
	var pushed: bool = false
	if buff_system.has_method("push_source"):
		buff_system.push_source(ctx.caster_team, ctx.caster_index, "ability")
		pushed = true
	buff_system.apply_tag(ctx.state, ctx.caster_team, target_index, BuffTags.TAG_DAMAGE_AMP, BUFF_DURATION, {
		"damage_amp_pct": amp,
		"kind": "miri_lesson_plan"
	})
	buff_system.apply_tag(ctx.state, ctx.caster_team, target_index, BuffTags.TAG_ABILITY_AMP, BUFF_DURATION, {
		"ability_damage_amp": amp,
		"kind": "miri_lesson_plan"
	})
	if pushed and buff_system.has_method("pop_source"):
		buff_system.pop_source()

func _send_student_forward(ctx: AbilityContext, student_index: int) -> void:
	if ctx.engine.arena_state == null or not ctx.engine.arena_state.has_method("notify_forced_movement"):
		return
	var enemy_index: int = ctx.lowest_hp_enemy(ctx.caster_team)
	if enemy_index < 0:
		return
	var start: Vector2 = ctx.position_of(ctx.caster_team, student_index)
	var target_pos: Vector2 = ctx.position_of(_enemy_team(ctx.caster_team), enemy_index)
	var delta: Vector2 = target_pos - start
	if delta.length() <= 0.001:
		return
	ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, student_index, delta.normalized() * ENGAGE_TILES * ctx.tile_size(), MOVE_DURATION)

func _send_caster_forward(ctx: AbilityContext) -> void:
	if ctx.engine.arena_state == null or not ctx.engine.arena_state.has_method("notify_forced_movement"):
		return
	var enemy_index: int = ctx.lowest_hp_enemy(ctx.caster_team)
	if enemy_index < 0:
		return
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_pos: Vector2 = ctx.position_of(_enemy_team(ctx.caster_team), enemy_index)
	var delta: Vector2 = target_pos - start
	if delta.length() <= 0.001:
		return
	ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, delta.normalized() * CASTER_ENGAGE_TILES * ctx.tile_size(), MOVE_DURATION)

func _stun_opening_target(ctx: AbilityContext) -> void:
	var target_index: int = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return
	ctx.stun(_enemy_team(ctx.caster_team), target_index, OPENING_STUN_DURATION)
