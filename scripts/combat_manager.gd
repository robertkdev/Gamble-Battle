extends Node
class_name CombatManager
const Trace := preload("res://scripts/util/trace.gd")

signal battle_started(stage: int, enemy)
signal log_line(text: String)
signal stats_updated(player, enemy)
signal team_stats_updated(player_team, enemy_team)
signal unit_stat_changed(team: String, index: int, fields: Dictionary)
signal victory(stage: int)
signal defeat(stage: int)
signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)

var enemy: Unit

var player_team: Array[Unit] = []
var enemy_team: Array[Unit] = []

var select_closest_target: Callable = Callable()
var stage: int = 1

var _state: BattleState
var _engine: CombatEngine
var _pending_movement_debug_frames: int = 0

func set_arena(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	if _engine:
		_engine.set_arena(tile_size, player_pos, enemy_pos, bounds)

func is_team_defeated(team: String) -> bool:
	var arr := player_team if team == "player" else enemy_team
	return BattleState.all_dead(arr)

func get_player_positions() -> Array:
	if _engine:
		return _engine.get_player_positions_copy()
	return []

func get_enemy_positions() -> Array:
	if _engine:
		return _engine.get_enemy_positions_copy()
	return []

func get_arena_bounds() -> Rect2:
	if _engine:
		return _engine.get_arena_bounds_copy()
	return Rect2()

func get_engine():
	return _engine


func _ready() -> void:
	set_process(true)

func is_turn_in_progress() -> bool:
	return false

func _process(delta: float) -> void:
	if _engine:
		_engine.process(delta)

func _wire_engine_signals() -> void:
	if not _engine:
		return
	if not _engine.is_connected("projectile_fired", Callable(self, "_re_emit_projectile")):
		_engine.projectile_fired.connect(_re_emit_projectile)
	if not _engine.is_connected("stats_updated", Callable(self, "_on_engine_stats")):
		_engine.stats_updated.connect(_on_engine_stats)
	if not _engine.is_connected("team_stats_updated", Callable(self, "_on_engine_team_stats")):
		_engine.team_stats_updated.connect(_on_engine_team_stats)
	if not _engine.is_connected("log_line", Callable(self, "_on_engine_log")):
		_engine.log_line.connect(_on_engine_log)
	if not _engine.is_connected("victory", Callable(self, "_on_victory")):
		_engine.victory.connect(_on_victory)
	if not _engine.is_connected("defeat", Callable(self, "_on_defeat")):
		_engine.defeat.connect(_on_defeat)
	if not _engine.is_connected("unit_stat_changed", Callable(self, "_on_engine_unit_stat")):
		_engine.unit_stat_changed.connect(_on_engine_unit_stat)

func _re_emit_projectile(team: String, sidx: int, tidx: int, dmg: int, crit: bool) -> void:
	emit_signal("projectile_fired", team, sidx, tidx, dmg, crit)

func _on_engine_stats(p, e) -> void:
	enemy = e
	emit_signal("stats_updated", p, e)

func _on_engine_log(t: String) -> void:
	emit_signal("log_line", t)

func _on_engine_team_stats(pteam, eteam) -> void:
	emit_signal("team_stats_updated", pteam, eteam)

func _on_engine_unit_stat(team: String, index: int, fields: Dictionary) -> void:
	emit_signal("unit_stat_changed", team, index, fields)

func _ensure_default_player_team_into(arr: Array) -> void:
	# Append default units into the provided array
	var uf = load("res://scripts/unit_factory.gd")
	var u1: Unit = uf.spawn("sari")
	var u2: Unit = uf.spawn("paisley")
	if u1:
		arr.append(u1)
	if u2:
		arr.append(u2)

func start_stage() -> void:
	Trace.step("CM.start_stage: begin stage=" + str(stage))
	_ensure_state()
	Trace.step("CM.start_stage: state ensured")
	# Snapshot current team before reset to avoid aliasing issues
	var saved_team: Array[Unit] = []
	for u in player_team:
		if u:
			saved_team.append(u)
	_state.reset()
	Trace.step("CM.start_stage: state reset")
	_state.stage = stage
	# Rebuild state player team from snapshot (or defaults)
	if saved_team.is_empty():
		Trace.step("CM.start_stage: no saved team -> defaults")
		_ensure_default_player_team_into(saved_team)
	_state.player_team.clear()
	for i in range(saved_team.size()):
		var u2: Unit = saved_team[i]
		_state.player_team.append(u2)
		if i < 8:
			Trace.step("CM.copy idx=" + str(i))
	Trace.step("CM.start_stage: copy done; state size=" + str(_state.player_team.size()))
	Trace.step("CM.start_stage: create spawner")
	var spawner: EnemySpawner = load("res://scripts/game/combat/enemy_spawner.gd").new()
	Trace.step("CM.start_stage: build enemy team")
	_state.enemy_team = spawner.build_for_stage(stage)
	Trace.step("CM.start_stage: teams built p=" + str(_state.player_team.size()) + " e=" + str(_state.enemy_team.size()))


	# Expose battle arrays to the view (alias to state for live updates)
	player_team = _state.player_team
	enemy_team = _state.enemy_team
	enemy = BattleState.first_alive(_state.enemy_team)
	Trace.step("CM.start_stage: emit battle_started")
	emit_signal("battle_started", stage, enemy)
	if enemy:
		var name2: String = (_state.enemy_team[1].name if _state.enemy_team.size() > 1 else "?")
		emit_signal("log_line", "=== Stage %d: %s and %s appear! ===" % [stage, _state.enemy_team[0].name, name2])
	var pref: Unit = BattleState.first_alive(_state.player_team)
	if pref == null and _state.player_team.size() > 0:
		pref = _state.player_team[0]
	Trace.step("CM.start_stage: emit stats_updated")
	emit_signal("stats_updated", pref, enemy)

	Trace.step("CM.start_stage: create engine")
	_engine = load("res://scripts/game/combat/combat_engine.gd").new()
	Trace.step("CM.start_stage: configure engine")
	_engine.configure(_state, pref, stage, select_closest_target)
	Trace.step("CM.start_stage: wire engine signals")
	_wire_engine_signals()
	Trace.step("CM.start_stage: start engine")
	_engine.start()
	Trace.step("CM.start_stage: engine started")
	# Apply any pending movement debug logging
	if _pending_movement_debug_frames > 0 and _engine and _engine.arena_state and _engine.arena_state.has_method("set_debug_log_frames"):
		_engine.arena_state.set_debug_log_frames(_pending_movement_debug_frames)
		_pending_movement_debug_frames = 0

	# Compile traits for both teams and log summary (data-driven)
	var tc: Script = load("res://scripts/game/traits/trait_compiler.gd")
	var p_traits: Dictionary = tc.compile(_state.player_team)
	var e_traits: Dictionary = tc.compile(_state.enemy_team)
	_log_trait_summary("Your team", p_traits)
	_log_trait_summary("Enemy team", e_traits)
	Trace.step("CM.start_stage: end")

func setup_stage_preview() -> void:
	_ensure_state()
	_state.reset()
	_state.stage = stage
	for u in player_team:
		if u:
			_state.player_team.append(u)
	var spawner: EnemySpawner = load("res://scripts/game/combat/enemy_spawner.gd").new()
	_state.enemy_team = spawner.build_for_stage(stage)

	for u in _state.player_team:
		if u:
			u.mana = 0
	for e in _state.enemy_team:
		if e:
			e.mana = 0

	player_team = _state.player_team
	enemy_team = _state.enemy_team
	enemy = BattleState.first_alive(_state.enemy_team)

	# Preview: compile and log trait counts (no activation yet)
	var tc: Script = load("res://scripts/game/traits/trait_compiler.gd")
	var p_traits: Dictionary = tc.compile(_state.player_team)
	var e_traits: Dictionary = tc.compile(_state.enemy_team)
	_log_trait_summary("Your team (preview)", p_traits)
	_log_trait_summary("Enemy team (preview)", e_traits)
	emit_signal("team_stats_updated", _state.player_team, _state.enemy_team)


func on_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if _engine:
		_engine.on_projectile_hit(source_team, source_index, target_index, damage, crit)

func _on_victory(_stage: int = 0) -> void:
	emit_signal("log_line", "Victory. You survived Stage %d." % stage)
	# Defer unit reset and post-combat UI to view until intermission completes
	emit_signal("stats_updated", BattleState.first_alive(player_team), enemy)
	emit_signal("victory", stage)

func _on_defeat(_stage: int = 0) -> void:
	emit_signal("log_line", "Defeat at Stage %d." % stage)
	# Defer unit reset and post-combat UI to view until intermission completes
	emit_signal("stats_updated", BattleState.first_alive(player_team), enemy)
	emit_signal("defeat", stage)

func _reset_units_after_combat() -> void:
	for u in player_team:
		if u:
			u.heal_to_full()
	for e in enemy_team:
		if e:
			e.heal_to_full()

func continue_to_next_stage() -> void:
	stage += 1
	start_stage()

func _ensure_state() -> void:
	if not _state:
		_state = load("res://scripts/game/combat/battle_state.gd").new()

func _log_trait_summary(label: String, compiled: Dictionary) -> void:
	var counts: Dictionary = compiled.get("counts", {})
	var tiers: Dictionary = compiled.get("tiers", {})
	if counts.is_empty():
		return
	var parts: Array[String] = []
	for k in counts.keys():
		var c: int = int(counts[k])
		var t: int = int(tiers.get(k, -1))
		var tstr: String = (" T" + str(t+1)) if t >= 0 else ""
		parts.append("%s %d%s" % [String(k), c, tstr])
	emit_signal("log_line", "%s traits: %s" % [label, ", ".join(parts)])

func finalize_post_combat() -> void:
	# Public entry to reset health/mana after view intermission completes
	_reset_units_after_combat()
	emit_signal("stats_updated", BattleState.first_alive(player_team), enemy)
	emit_signal("team_stats_updated", player_team, enemy_team)

func enable_movement_debug(frames: int) -> void:
	_pending_movement_debug_frames = max(_pending_movement_debug_frames, int(frames))
	if _engine and _engine.arena_state and _engine.arena_state.has_method("set_debug_log_frames"):
		_engine.arena_state.set_debug_log_frames(_pending_movement_debug_frames)
		_pending_movement_debug_frames = 0
