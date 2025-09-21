extends Node
class_name CombatManager

signal battle_started(stage: int, enemy)
signal log_line(text: String)
signal stats_updated(player, enemy)
signal team_stats_updated(player_team, enemy_team)
signal unit_stat_changed(team: String, index: int, fields: Dictionary)
signal victory(stage: int)
signal defeat(stage: int)
signal draw(stage: int)
signal powerup_choices(options)
signal powerup_applied(powerup_name: String)
signal prompt_continue()
signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)

var player: Unit
var enemy: Unit

var player_team: Array[Unit] = []
var enemy_team: Array[Unit] = []

var select_closest_target: Callable = Callable()
var stage: int = 1

var _state: BattleState
var _engine: CombatEngine

func set_arena(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	if _engine:
		_engine.set_arena(tile_size, player_pos, enemy_pos, bounds)

func get_player_positions() -> Array:
	if _engine:
		return _engine.get_player_positions_copy()
	return []

func get_enemy_positions() -> Array:
	if _engine:		return _engine.get_enemy_positions_copy()
	return []

func get_arena_bounds() -> Rect2:
	if _engine:		return _engine.get_arena_bounds_copy()
	return Rect2()


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
	if not _engine.is_connected("draw", Callable(self, "_on_draw")):
		_engine.draw.connect(_on_draw)
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

func new_player(player_name: String = "Hero") -> void:
	player = load("res://scripts/unit_factory.gd").spawn("sari")
	if player:
		player.name = player_name

func start_stage() -> void:
	_ensure_state()
	_state.reset()
	_state.stage = stage
	if player:
		_state.player_team.append(player)
	var ally: Unit = load("res://scripts/unit_factory.gd").spawn("paisley") as Unit
	if ally:
		_state.player_team.append(ally)
	var spawner: EnemySpawner = load("res://scripts/game/combat/enemy_spawner.gd").new()
	_state.enemy_team = spawner.build_for_stage(stage)

	player_team = _state.player_team
	enemy_team = _state.enemy_team
	enemy = BattleState.first_alive(_state.enemy_team)
	emit_signal("battle_started", stage, enemy)
	if enemy:
		var name2: String = (_state.enemy_team[1].name if _state.enemy_team.size() > 1 else "?")
		emit_signal("log_line", "=== Stage %d: %s and %s appear! ===" % [stage, _state.enemy_team[0].name, name2])
	emit_signal("stats_updated", player, enemy)

	_engine = load("res://scripts/game/combat/combat_engine.gd").new()
	_engine.configure(_state, player, stage, select_closest_target)
	_wire_engine_signals()
	_engine.start()

	# Compile traits for both teams and log summary (data-driven)
	var tc: Script = load("res://scripts/game/traits/trait_compiler.gd")
	var p_traits: Dictionary = tc.compile(_state.player_team)
	var e_traits: Dictionary = tc.compile(_state.enemy_team)
	_log_trait_summary("Your team", p_traits)
	_log_trait_summary("Enemy team", e_traits)

func setup_stage_preview() -> void:
	_ensure_state()
	_state.reset()
	_state.stage = stage
	if player:
		_state.player_team.append(player)
	var ally: Unit = load("res://scripts/unit_factory.gd").spawn("paisley") as Unit
	if ally:
		_state.player_team.append(ally)
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
	_reset_units_after_combat()
	emit_signal("stats_updated", player, enemy)
	emit_signal("victory", stage)
	_offer_powerups()

func _on_defeat(_stage: int = 0) -> void:
	emit_signal("log_line", "Defeat at Stage %d." % stage)
	_reset_units_after_combat()
	emit_signal("stats_updated", player, enemy)
	emit_signal("defeat", stage)

func _offer_powerups() -> void:
	var all: Array = load("res://scripts/powerup.gd").catalog()
	all.shuffle()
	var options: Array = all.slice(0, 3)
	emit_signal("powerup_choices", options)

func apply_powerup(p: Powerup) -> void:
	if not player:
		return
	p.apply_to(player)
	emit_signal("log_line", "Applied powerup: %s" % p.name)
	emit_signal("powerup_applied", p.name)
	emit_signal("stats_updated", player, enemy)
	emit_signal("prompt_continue")

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
func _on_draw(_stage: int = 0) -> void:
	emit_signal("log_line", "Stalemate! Both sides fell together.")
	_reset_units_after_combat()
	emit_signal("stats_updated", player, enemy)
	emit_signal("draw", stage)
