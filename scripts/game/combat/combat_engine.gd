extends RefCounted
class_name CombatEngine
const Trace := preload("res://scripts/util/trace.gd")
const AbilitySystemLib := preload("res://scripts/game/abilities/ability_system.gd")
const BuffSystemLib := preload("res://scripts/game/abilities/buff_system.gd")
# Use a minimal service to allow loading while iterating on movement.
const MovementServiceLib := preload("res://scripts/game/combat/movement/movement_service2.gd")

signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)
signal stats_updated(player, enemy)
signal team_stats_updated(player_team, enemy_team)
signal unit_stat_changed(team: String, index: int, fields: Dictionary)
signal log_line(text: String)
signal victory(stage: int)
signal defeat(stage: int)
signal vfx_knockup(team: String, index: int, duration: float)
signal vfx_beam_line(start: Vector2, end: Vector2, color: Color, width: float, duration: float)
signal position_updated(team: String, index: int, x: float, y: float)
signal target_start(source_team: String, source_index: int, target_team: String, target_index: int)
signal target_end(source_team: String, source_index: int, target_team: String, target_index: int)
signal ability_cast(source_team: String, source_index: int, target_team: String, target_index: int, position: Vector2)

const POSITION_EMIT_INTERVAL: float = 0.1

# Emitted after damage is applied (single or paired)
# Provides detailed data for deterministic logging/analytics.
signal hit_applied(source_team: String, source_index: int, target_index: int, rolled_damage: int, dealt_damage: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float)

# New analytics signals
signal heal_applied(source_team: String, source_index: int, target_team: String, target_index: int, healed: int, overheal: int, before_hp: int, after_hp: int)
signal shield_absorbed(target_team: String, target_index: int, absorbed: int)
signal hit_mitigated(source_team: String, source_index: int, target_team: String, target_index: int, pre_mit: int, post_pre_shield: int)
signal hit_overkill(source_team: String, source_index: int, target_team: String, target_index: int, overkill: int)
signal hit_components(source_team: String, source_index: int, target_team: String, target_index: int, phys: int, mag: int, tru: int)
signal cc_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration: float)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var state: BattleState
var player_ref: Unit
var stage: int = 1
var select_closest_target: Callable = Callable()

var process_player_first: bool = true
var alternate_order: bool = false
var deterministic_rolls: bool = true

var total_damage_player: int = 0
var total_damage_enemy: int = 0
var debug_pairs: int = 0
var debug_shots: int = 0
var debug_double_lethals: int = 0
var _frame_delta_last: float = 0.0
var _seed_locked: bool = false
var _seed_value: int = 0
var _position_emit_accum: float = 0.0
var _last_player_positions: Array = []
var _last_enemy_positions: Array = []
var _last_targets_player: Array = []
var _last_targets_enemy: Array = []

var arena_state = MovementServiceLib.new()
var target_controller: TargetController = TargetController.new()
var cooldown_scheduler: CooldownScheduler = CooldownScheduler.new()
var attack_resolver: AttackResolver = AttackResolver.new()
var outcome_resolver: OutcomeResolver = OutcomeResolver.new()
var projectile_handler: ProjectileHandler = ProjectileHandler.new()
var regen_system: RegenSystem = RegenSystem.new()
var ability_system: AbilitySystem = null
var buff_system: BuffSystem = null
var _connected_ability_system: AbilitySystem = null

# Feature toggles
var abilities_enabled: bool = true

var _resolver_emitters: Dictionary[String, Callable] = {}

func set_seed(seed: int) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var coerced: int = int(seed)
	if coerced < 0:
		coerced = int(abs(seed))
	_seed_value = coerced
	_seed_locked = true
	rng.seed = coerced

func configure(_state: BattleState, _player: Unit, _stage: int, _selector: Callable = Callable()) -> void:
	Trace.step("CombatEngine.configure: begin")
	_disconnect_signal_bindings()
	state = _state
	player_ref = _player
	stage = _stage
	# Prefer engine-provided closest-target selector if none supplied
	select_closest_target = (_selector if _selector.is_valid() else Callable(self, "_engine_select_closest_target"))
	if _seed_locked:
		rng.seed = _seed_value
	else:
		rng.randomize()
	_resolver_emitters = _build_resolver_emitters()
	if outcome_resolver == null:
		outcome_resolver = OutcomeResolver.new()
	target_controller.configure(state, select_closest_target)
	cooldown_scheduler.configure(state, target_controller, buff_system)
	cooldown_scheduler.rng = rng
	cooldown_scheduler.apply_rules(process_player_first, alternate_order)
	# Ensure buff and ability systems
	if buff_system == null:
		buff_system = BuffSystemLib.new()
	# Ability system is optional based on toggle
	if abilities_enabled:
		if ability_system == null:
			ability_system = AbilitySystemLib.new()
		ability_system.configure(self, state, rng, buff_system)
	else:
		ability_system = null
	attack_resolver.configure(state, target_controller, rng, player_ref, _resolver_emitters, ability_system, buff_system)
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	outcome_resolver.configure(state, rng)
	projectile_handler.configure(attack_resolver)
	# Ensure regen system enforces mana blocking via BuffSystem
	regen_system.buff_system = buff_system
	regen_system.ability_system = ability_system
	# Ensure movement service (already constructed at declaration)
	# Provide BuffSystem to movement via adapter if supported
	if arena_state and arena_state.has_method("set_buff_system"):
		arena_state.set_buff_system(buff_system)
	arena_state.ensure_capacity(state.player_team.size(), state.enemy_team.size())
	_reset_position_tracking()
	_reset_target_tracking()
	_position_emit_accum = 0.0
	_refresh_signal_bindings()
	_update_totals_cache()
	_reset_debug_counters()
	Trace.step("CombatEngine.configure: done")

func set_arena(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	# Cast/convert to typed arrays of Vector2 for movement.configure signature
	var p: Array[Vector2] = []
	for v in player_pos:
		if typeof(v) == TYPE_VECTOR2:
			p.append(v)
	var e: Array[Vector2] = []
	for v2 in enemy_pos:
		if typeof(v2) == TYPE_VECTOR2:
			e.append(v2)
	# Movement service already exists; keep configuration idempotent
	arena_state.configure(tile_size, p, e, bounds)
	# Now that arena positions are available, reprime targets so initial
	# selections can use real distances (closest enemy at round start).
	if target_controller != null:
		target_controller.prime_targets()

func _engine_select_closest_target(my_team: String, my_index: int, enemy_team: String) -> int:
	# Default target selection: nearest alive enemy by engine arena positions.
	if state == null:
		return -1
	var enemy_arr: Array[Unit] = state.enemy_team if enemy_team == "enemy" else state.player_team
	var alive_indices: Array[int] = []
	for i in range(enemy_arr.size()):
		var u: Unit = enemy_arr[i]
		if u and u.is_alive():
			alive_indices.append(i)
	if alive_indices.is_empty():
		return -1
	var src_pos: Vector2 = Vector2.ZERO
	if my_team == "player":
		src_pos = arena_state.get_player_position(my_index)
	else:
		src_pos = arena_state.get_enemy_position(my_index)
	var best_idx := alive_indices[0]
	var best_d2: float = INF
	for idx in alive_indices:
		var tgt_pos: Vector2 = (arena_state.get_enemy_position(idx) if enemy_team == "enemy" else arena_state.get_player_position(idx))
		var d2 := tgt_pos.distance_squared_to(src_pos)
		if d2 < best_d2:
			best_d2 = d2
			best_idx = idx
	return best_idx

func get_arena_bounds_copy() -> Rect2:
	return arena_state.bounds_copy()

func get_player_position(idx: int) -> Vector2:
	return arena_state.get_player_position(idx)

func get_enemy_position(idx: int) -> Vector2:
	return arena_state.get_enemy_position(idx)

func get_player_positions_copy() -> Array:
	return arena_state.player_positions_copy()

func get_enemy_positions_copy() -> Array:
	return arena_state.enemy_positions_copy()

func notify_forced_movement(team: String, idx: int, vec: Vector2, dur: float) -> void:
	if arena_state and arena_state.has_method("notify_forced_movement"):
		arena_state.notify_forced_movement(team, idx, vec, dur)

func start() -> void:
	Trace.step("CombatEngine.start: begin")
	if not state:
		return
	state.battle_active = true
	if outcome_resolver != null:
		outcome_resolver.reset()
	attack_resolver.reset_totals()
	attack_resolver.begin_frame()
	state.regen_tick_accum = 0.0
	state.player_cds = BattleState.fill_cds_for(state.player_team)
	state.enemy_cds = BattleState.fill_cds_for(state.enemy_team)
	state.player_targets.clear()
	state.enemy_targets.clear()
	target_controller.configure(state, select_closest_target)
	cooldown_scheduler.configure(state, target_controller, buff_system)
	cooldown_scheduler.apply_rules(process_player_first, alternate_order)
	cooldown_scheduler.reset_turn()
	# Randomize starting side once per battle when not explicitly set by rules
	if rng:
		cooldown_scheduler._next_player_first = (rng.randf() < 0.5) if alternate_order else cooldown_scheduler._next_player_first
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	arena_state.ensure_capacity(state.player_team.size(), state.enemy_team.size())
	_position_emit_accum = 0.0
	_reset_position_tracking()
	_reset_target_tracking()
	_emit_position_updates(true)
	_emit_target_events(true)
	total_damage_player = 0
	total_damage_enemy = 0
	_reset_debug_counters()
	_emit_stats_snapshot()
	Trace.step("CombatEngine.start: done")

func stop() -> void:
	if not state:
		return
	state.battle_active = false

func process(delta: float) -> void:
	if not state or (outcome_resolver != null and outcome_resolver.outcome_sent):
		return
	if delta <= 0.0:
		return
	_frame_delta_last = delta
	cooldown_scheduler.apply_rules(process_player_first, alternate_order)
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	attack_resolver.begin_frame()
	if not state.battle_active:
		var idle_outcome: String = ""
		if outcome_resolver != null:
			idle_outcome = outcome_resolver.evaluate_idle(attack_resolver.totals())
		if idle_outcome != "":
			_update_totals_cache()
			_emit_outcome(idle_outcome)
		return
	arena_state.update_movement(state, delta, target_controller.resolver_for_arena())
	_position_emit_accum += delta
	while _position_emit_accum >= POSITION_EMIT_INTERVAL:
		_emit_position_updates()
		_position_emit_accum -= POSITION_EMIT_INTERVAL
	var board_pre: String = ""
	if outcome_resolver != null:
		board_pre = outcome_resolver.evaluate_board(attack_resolver.totals())
	if board_pre != "":
		_update_totals_cache()
		_emit_outcome(board_pre)
		return
	var frame_data: Dictionary = cooldown_scheduler.advance(delta)
	_apply_regen(int(frame_data.get("regen_ticks", 0)))
	if buff_system != null:
		buff_system.tick(state, delta)
	if ability_system != null:
		ability_system.tick(delta)
	_emit_target_events()
	var ordered: Array[AttackEvent] = frame_data.get("ordered", []) as Array[AttackEvent]
	if ordered.size() > 0:
		var gated: Array[AttackEvent] = _filter_events_in_range(ordered)
		if gated.size() > 0:
			attack_resolver.resolve_ordered(gated)
	_emit_target_events()
	if _evaluate_outcome():
		return
	_update_totals_cache()
	_reset_debug_counters()

func on_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not state or not state.battle_active or (outcome_resolver != null and outcome_resolver.outcome_sent):
		return
	var result: Dictionary = projectile_handler.handle_hit(source_team, source_index, target_index, damage, crit)
	if not result.get("processed", false):
		return
	_update_totals_cache()
	_reset_debug_counters()
	_evaluate_outcome()

func _apply_regen(ticks: int) -> void:
	regen_system.apply_ticks(state, ticks, player_ref, _resolver_emitters)

func _evaluate_outcome() -> bool:
	var frame_outcome: String = ""
	if outcome_resolver != null:
		frame_outcome = outcome_resolver.evaluate_frame(attack_resolver.frame_status())
	if frame_outcome != "":
		_update_totals_cache()
		_emit_outcome(frame_outcome)
		return true
	var board_outcome: String = ""
	if outcome_resolver != null:
		board_outcome = outcome_resolver.evaluate_board(attack_resolver.totals())
	if board_outcome != "":
		_update_totals_cache()
		_emit_outcome(board_outcome)
		return true
	return false

func _emit_outcome(kind: String) -> void:
	if kind == "":
		return
	if outcome_resolver != null:
		outcome_resolver.mark_emitted()
	state.battle_active = false
	match kind:
		"victory":
			emit_signal("victory", stage)
		"defeat":
			emit_signal("defeat", stage)
		_:
			# Fallback: default to defeat if unknown outcome
			emit_signal("defeat", stage)
	stop()

func _emit_stats_snapshot() -> void:
	emit_signal("stats_updated", player_ref, BattleState.first_alive(state.enemy_team))
	emit_signal("team_stats_updated", state.player_team, state.enemy_team)

func _update_totals_cache() -> void:
	var totals: Dictionary = attack_resolver.totals()
	total_damage_player = int(totals.get("player", total_damage_player))
	total_damage_enemy = int(totals.get("enemy", total_damage_enemy))

func _reset_debug_counters() -> void:
	debug_pairs = attack_resolver.debug_pairs
	debug_shots = attack_resolver.debug_shots
	debug_double_lethals = attack_resolver.debug_double_lethals

func _refresh_signal_bindings() -> void:
	if ability_system != null and ability_system.has_signal("ability_cast"):
		if not ability_system.is_connected("ability_cast", Callable(self, "_on_ability_system_cast")):
			ability_system.ability_cast.connect(_on_ability_system_cast)
		_connected_ability_system = ability_system
	else:
		_connected_ability_system = null

func _disconnect_signal_bindings() -> void:
	if _connected_ability_system != null and _connected_ability_system.has_signal("ability_cast"):
		if _connected_ability_system.is_connected("ability_cast", Callable(self, "_on_ability_system_cast")):
			_connected_ability_system.ability_cast.disconnect(_on_ability_system_cast)
	_connected_ability_system = null

func _reset_position_tracking() -> void:
	_last_player_positions = []
	_last_enemy_positions = []

func _reset_target_tracking() -> void:
	_last_targets_player = []
	_last_targets_enemy = []

func _emit_position_updates(force: bool = false) -> void:
	if state == null or arena_state == null:
		return
	var player_count: int = state.player_team.size()
	if player_count > 0:
		_last_player_positions.resize(player_count)
		for i in range(player_count):
			var unit: Unit = state.player_team[i]
			if unit == null:
				_last_player_positions[i] = null
				continue
			var pos: Vector2 = arena_state.get_player_position(i)
			var last = _last_player_positions[i] if i < _last_player_positions.size() else null
			var emit_now: bool = force
			if not emit_now:
				emit_now = not (last is Vector2 and pos.is_equal_approx(last))
			if emit_now:
				emit_signal("position_updated", "player", i, pos.x, pos.y)
			_last_player_positions[i] = pos
	else:
		_last_player_positions.clear()
	var enemy_count: int = state.enemy_team.size()
	if enemy_count > 0:
		_last_enemy_positions.resize(enemy_count)
		for j in range(enemy_count):
			var enemy: Unit = state.enemy_team[j]
			if enemy == null:
				_last_enemy_positions[j] = null
				continue
			var epos: Vector2 = arena_state.get_enemy_position(j)
			var elast = _last_enemy_positions[j] if j < _last_enemy_positions.size() else null
			var emit_enemy: bool = force
			if not emit_enemy:
				emit_enemy = not (elast is Vector2 and epos.is_equal_approx(elast))
			if emit_enemy:
				emit_signal("position_updated", "enemy", j, epos.x, epos.y)
			_last_enemy_positions[j] = epos
	else:
		_last_enemy_positions.clear()

func _emit_target_events(force: bool = false) -> void:
	if target_controller == null or state == null:
		return
	var player_targets: Array = target_controller.target_array("player")
	var enemy_targets: Array = target_controller.target_array("enemy")
	_last_targets_player = _emit_target_events_for_team("player", "enemy", player_targets, _last_targets_player, force)
	_last_targets_enemy = _emit_target_events_for_team("enemy", "player", enemy_targets, _last_targets_enemy, force)

func _emit_target_events_for_team(team: String, target_team: String, current: Array, previous: Array, force: bool) -> Array:
	var result: Array = []
	var curr_count: int = current.size()
	var prev_count: int = previous.size()
	for i in range(curr_count):
		var new_target: int = int(current[i])
		var prev_target: int = (int(previous[i]) if i < prev_count else -1)
		if force:
			if new_target >= 0:
				emit_signal("target_start", team, i, target_team, new_target)
		else:
			if prev_target != new_target:
				if prev_target >= 0:
					emit_signal("target_end", team, i, target_team, prev_target)
				if new_target >= 0:
					emit_signal("target_start", team, i, target_team, new_target)
		result.append(new_target)
	if not force and prev_count > curr_count:
		for j in range(curr_count, prev_count):
			var prev_val: int = int(previous[j])
			if prev_val >= 0:
				emit_signal("target_end", team, j, target_team, prev_val)
	return result

# Public helper to avoid external scripts depending on internal fields
func set_movement_debug_frames(frames: int) -> void:
	if arena_state != null and arena_state.has_method("set_debug_log_frames"):
		arena_state.set_debug_log_frames(int(max(0, frames)))

func _build_resolver_emitters() -> Dictionary[String, Callable]:
	return {
		"projectile_fired": Callable(self, "_resolver_emit_projectile"),
		"log_line": Callable(self, "_resolver_emit_log"),
		"unit_stat_changed": Callable(self, "_resolver_emit_unit_stat"),
		"stats_updated": Callable(self, "_resolver_emit_stats"),
		"team_stats_updated": Callable(self, "_resolver_emit_team_stats"),
		"hit_applied": Callable(self, "_resolver_emit_hit"),
		"heal_applied": Callable(self, "_resolver_emit_heal_applied"),
		"shield_absorbed": Callable(self, "_resolver_emit_shield_absorbed"),
		"hit_mitigated": Callable(self, "_resolver_emit_hit_mitigated"),
		"hit_overkill": Callable(self, "_resolver_emit_hit_overkill")
		,"hit_components": Callable(self, "_resolver_emit_hit_components")
	}

func _filter_events_in_range(events: Array[AttackEvent]) -> Array[AttackEvent]:
	var out: Array[AttackEvent] = []
	if not state:
		return out
	const MovementMath := preload("res://scripts/game/combat/movement/math.gd")
	var ts: float = arena_state.tile_size()
	var epsilon: float = 0.5
	# Use MovementService tuning epsilon to keep parity
	if arena_state != null:
		epsilon = float(arena_state.tuning.range_epsilon)
	for evt in events:
		if evt == null:
			continue
		var team: String = evt.team
		var idx: int = evt.shooter_index
		var tgt_idx: int = evt.target_index
		var shooter: Unit = null
		if team == "player":
			if idx >= 0 and idx < state.player_team.size():
				shooter = state.player_team[idx]
		else:
			if idx >= 0 and idx < state.enemy_team.size():
				shooter = state.enemy_team[idx]
		if not shooter or not shooter.is_alive():
			continue
		var spos: Vector2 = arena_state.get_player_position(idx) if team == "player" else arena_state.get_enemy_position(idx)
		var tpos: Vector2 = arena_state.get_enemy_position(tgt_idx) if team == "player" else arena_state.get_player_position(tgt_idx)
		var prof: Variant = arena_state.get_profile(team, idx) if arena_state and arena_state.has_method("get_profile") else null
		var band_mult: float = (prof.band_max if prof != null else 1.0)
		if MovementMath.within_range(shooter, spos, tpos, ts, epsilon, band_mult):
			out.append(evt)
		else:
			# Not in range: keep shooter ready without accumulating extra cooldown debt.
			# Setting CD to max(negative small, 0) ensures at most one retry next frame.
			var cds: Array[float] = state.player_cds if team == "player" else state.enemy_cds
			if idx >= 0 and idx < cds.size():
				cds[idx] = min(float(cds[idx]), 0.0)
				if team == "player":
					state.player_cds = cds
				else:
					state.enemy_cds = cds
	return out

func _resolver_emit_projectile(team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	emit_signal("projectile_fired", team, source_index, target_index, damage, crit)

func _resolver_emit_log(text: String) -> void:
	emit_signal("log_line", text)

func _resolver_emit_unit_stat(team: String, index: int, fields: Dictionary) -> void:
	emit_signal("unit_stat_changed", team, index, fields)

func _resolver_emit_stats(player, enemy) -> void:
	emit_signal("stats_updated", player, enemy)

func _resolver_emit_team_stats(player_team, enemy_team) -> void:
	emit_signal("team_stats_updated", player_team, enemy_team)

func _resolver_emit_hit(team: String, source_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	emit_signal("hit_applied", team, source_index, target_index, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd)

func _resolver_emit_heal_applied(source_team: String, source_index: int, target_team: String, target_index: int, healed: int, overheal: int, before_hp: int, after_hp: int) -> void:
	emit_signal("heal_applied", source_team, source_index, target_team, target_index, healed, overheal, before_hp, after_hp)

func _resolver_emit_shield_absorbed(target_team: String, target_index: int, absorbed: int) -> void:
	emit_signal("shield_absorbed", target_team, target_index, absorbed)

func _resolver_emit_hit_mitigated(source_team: String, source_index: int, target_team: String, target_index: int, pre_mit: int, post_pre_shield: int) -> void:
	emit_signal("hit_mitigated", source_team, source_index, target_team, target_index, pre_mit, post_pre_shield)

func _resolver_emit_hit_overkill(source_team: String, source_index: int, target_team: String, target_index: int, overkill: int) -> void:
	emit_signal("hit_overkill", source_team, source_index, target_team, target_index, overkill)

func _resolver_emit_hit_components(source_team: String, source_index: int, target_team: String, target_index: int, phys: int, mag: int, tru: int) -> void:
	emit_signal("hit_components", source_team, source_index, target_team, target_index, phys, mag, tru)

func _resolver_emit_vfx_knockup(team: String, index: int, duration: float) -> void:
	emit_signal("vfx_knockup", team, index, duration)

func _resolver_emit_vfx_beam_line(start: Vector2, end: Vector2, color: Color, width: float, duration: float) -> void:
	# Visual-only signal to draw a transient beam line in the arena UI.
	emit_signal("vfx_beam_line", start, end, color, width, duration)

func _on_ability_system_cast(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	var tgt_team := String(target_team)
	if tgt_team == "":
		tgt_team = ("enemy" if team == "player" else "player")
	var tgt_index: int = int(target_index)
	if tgt_index < 0 and target_controller != null:
		tgt_index = target_controller.current_target(team, index)
	if tgt_index < 0:
		tgt_team = String(team)
		tgt_index = index
	var pos: Vector2 = target_point
	if arena_state != null and state != null:
		if pos == Vector2.ZERO:
			if tgt_team == "player" and tgt_index >= 0 and tgt_index < state.player_team.size():
				pos = arena_state.get_player_position(tgt_index)
			elif tgt_team == "enemy" and tgt_index >= 0 and tgt_index < state.enemy_team.size():
				pos = arena_state.get_enemy_position(tgt_index)
		if pos == Vector2.ZERO:
			if team == "player" and index >= 0 and index < state.player_team.size():
				pos = arena_state.get_player_position(index)
			elif team == "enemy" and index >= 0 and index < state.enemy_team.size():
				pos = arena_state.get_enemy_position(index)
	emit_signal("ability_cast", team, index, tgt_team, tgt_index, pos)
