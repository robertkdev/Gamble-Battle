extends RefCounted
class_name CombatEngine
const Trace := preload("res://scripts/util/trace.gd")
const AbilitySystemLib := preload("res://scripts/game/abilities/ability_system.gd")
const BuffSystemLib := preload("res://scripts/game/abilities/buff_system.gd")
const MovementServiceLib := preload("res://scripts/game/combat/movement/movement_service.gd")

signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)
signal stats_updated(player, enemy)
signal team_stats_updated(player_team, enemy_team)
signal unit_stat_changed(team: String, index: int, fields: Dictionary)
signal log_line(text: String)
signal victory(stage: int)
signal defeat(stage: int)
signal vfx_knockup(team: String, index: int, duration: float)
signal vfx_beam_line(start: Vector2, end: Vector2, color: Color, width: float, duration: float)

# Emitted after damage is applied (single or paired)
# Provides detailed data for deterministic logging/analytics.
signal hit_applied(source_team: String, source_index: int, target_index: int, rolled_damage: int, dealt_damage: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float)

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

var arena_state = MovementServiceLib.new()
var target_controller: TargetController = TargetController.new()
var cooldown_scheduler: CooldownScheduler = CooldownScheduler.new()
var attack_resolver: AttackResolver = AttackResolver.new()
var outcome_resolver: OutcomeResolver = OutcomeResolver.new()
var projectile_handler: ProjectileHandler = ProjectileHandler.new()
var regen_system: RegenSystem = RegenSystem.new()
var ability_system: AbilitySystem = null
var buff_system: BuffSystem = null

# Feature toggles
var abilities_enabled: bool = true

var _resolver_emitters: Dictionary[String, Callable] = {}

func configure(_state: BattleState, _player: Unit, _stage: int, _selector: Callable = Callable()) -> void:
	Trace.step("CombatEngine.configure: begin")
	state = _state
	player_ref = _player
	stage = _stage
	# Prefer engine-provided closest-target selector if none supplied
	select_closest_target = (_selector if _selector.is_valid() else Callable(self, "_engine_select_closest_target"))
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
	var ordered: Array[AttackEvent] = frame_data.get("ordered", []) as Array[AttackEvent]
	if ordered.size() > 0:
		var gated: Array[AttackEvent] = _filter_events_in_range(ordered)
		if gated.size() > 0:
			attack_resolver.resolve_ordered(gated)
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
		"hit_applied": Callable(self, "_resolver_emit_hit")
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
		var prof := arena_state.get_profile(team, idx) if arena_state and arena_state.has_method("get_profile") else null
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

func _resolver_emit_vfx_knockup(team: String, index: int, duration: float) -> void:
	emit_signal("vfx_knockup", team, index, duration)

func _resolver_emit_vfx_beam_line(start: Vector2, end: Vector2, color: Color, width: float, duration: float) -> void:
	# Visual-only signal to draw a transient beam line in the arena UI.
	emit_signal("vfx_beam_line", start, end, color, width, duration)
