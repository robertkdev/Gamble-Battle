extends RefCounted
class_name CombatEngine

signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)
signal stats_updated(player, enemy)
signal team_stats_updated(player_team, enemy_team)
signal unit_stat_changed(team: String, index: int, fields: Dictionary)
signal log_line(text: String)
signal victory(stage: int)
signal defeat(stage: int)
signal draw(stage: int)

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
var simultaneous_pairs: bool = true
var deterministic_rolls: bool = true

var total_damage_player: int = 0
var total_damage_enemy: int = 0
var debug_pairs: int = 0
var debug_shots: int = 0
var debug_double_lethals: int = 0
var _frame_delta_last: float = 0.0

var arena_state: CombatArenaState = CombatArenaState.new()
var target_controller: TargetController = TargetController.new()
var cooldown_scheduler: CooldownScheduler = CooldownScheduler.new()
var attack_resolver: AttackResolver = AttackResolver.new()
var outcome_resolver: OutcomeResolver = OutcomeResolver.new()
var projectile_handler: ProjectileHandler = ProjectileHandler.new()
var regen_system: RegenSystem = RegenSystem.new()

var _resolver_emitters: Dictionary[String, Callable] = {}

func configure(_state: BattleState, _player: Unit, _stage: int, _selector: Callable = Callable()) -> void:
	state = _state
	player_ref = _player
	stage = _stage
	select_closest_target = _selector
	rng.randomize()
	_resolver_emitters = _build_resolver_emitters()
	target_controller.configure(state, select_closest_target)
	cooldown_scheduler.configure(state, target_controller)
	cooldown_scheduler.apply_rules(process_player_first, alternate_order, simultaneous_pairs)
	attack_resolver.configure(state, target_controller, rng, player_ref, _resolver_emitters)
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	outcome_resolver.configure(state, rng)
	projectile_handler.configure(attack_resolver)
	arena_state.ensure_capacity(state.player_team.size(), state.enemy_team.size())
	_update_totals_cache()
	_reset_debug_counters()

func set_arena(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	arena_state.configure(tile_size, player_pos, enemy_pos, bounds)

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

func start() -> void:
	if not state:
		return
	state.battle_active = true
	outcome_resolver.reset()
	attack_resolver.reset_totals()
	attack_resolver.begin_frame()
	state.regen_tick_accum = 0.0
	state.player_cds = BattleState.fill_cds_for(state.player_team)
	state.enemy_cds = BattleState.fill_cds_for(state.enemy_team)
	state.player_targets.clear()
	state.enemy_targets.clear()
	target_controller.configure(state, select_closest_target)
	cooldown_scheduler.configure(state, target_controller)
	cooldown_scheduler.apply_rules(process_player_first, alternate_order, simultaneous_pairs)
	cooldown_scheduler.reset_turn()
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	arena_state.ensure_capacity(state.player_team.size(), state.enemy_team.size())
	total_damage_player = 0
	total_damage_enemy = 0
	_reset_debug_counters()
	_emit_stats_snapshot()

func stop() -> void:
	if not state:
		return
	state.battle_active = false

func process(delta: float) -> void:
	if not state or outcome_resolver.outcome_sent:
		return
	if delta <= 0.0:
		return
	_frame_delta_last = delta
	cooldown_scheduler.apply_rules(process_player_first, alternate_order, simultaneous_pairs)
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	attack_resolver.begin_frame()
	if not state.battle_active:
		var idle_outcome: String = outcome_resolver.evaluate_idle(simultaneous_pairs, attack_resolver.totals())
		if idle_outcome != "":
			_update_totals_cache()
			_emit_outcome(idle_outcome)
		return
	arena_state.update_movement(state, delta, target_controller.resolver_for_arena())
	var board_pre: String = outcome_resolver.evaluate_board(simultaneous_pairs, attack_resolver.totals())
	if board_pre != "":
		_update_totals_cache()
		_emit_outcome(board_pre)
		return
	var frame_data: Dictionary = cooldown_scheduler.advance(delta)
	_apply_regen(int(frame_data.get("regen_ticks", 0)))
	var pairs: Array = frame_data.get("pairs", []) as Array
	if pairs.size() > 0:
		attack_resolver.resolve_pairs(pairs)
	var ordered: Array = frame_data.get("ordered", [])
	if ordered.size() > 0:
		attack_resolver.resolve_ordered(ordered)
	if _evaluate_outcome():
		return
	_update_totals_cache()
	_reset_debug_counters()

func on_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not state or not state.battle_active or outcome_resolver.outcome_sent:
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
	var frame_outcome: String = outcome_resolver.evaluate_frame(simultaneous_pairs, attack_resolver.frame_status())
	if frame_outcome != "":
		_update_totals_cache()
		_emit_outcome(frame_outcome)
		return true
	var board_outcome: String = outcome_resolver.evaluate_board(simultaneous_pairs, attack_resolver.totals())
	if board_outcome != "":
		_update_totals_cache()
		_emit_outcome(board_outcome)
		return true
	return false

func _emit_outcome(kind: String) -> void:
	if kind == "":
		return
	outcome_resolver.mark_emitted()
	state.battle_active = false
	match kind:
		"victory":
			emit_signal("victory", stage)
		"defeat":
			emit_signal("defeat", stage)
		_:
			emit_signal("draw", stage)
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

func _build_resolver_emitters() -> Dictionary[String, Callable]:
	return {
		"projectile_fired": Callable(self, "_resolver_emit_projectile"),
		"log_line": Callable(self, "_resolver_emit_log"),
		"unit_stat_changed": Callable(self, "_resolver_emit_unit_stat"),
		"stats_updated": Callable(self, "_resolver_emit_stats"),
		"team_stats_updated": Callable(self, "_resolver_emit_team_stats"),
		"hit_applied": Callable(self, "_resolver_emit_hit")
	}

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
