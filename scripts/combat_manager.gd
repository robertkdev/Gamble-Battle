extends Node
class_name CombatManager

signal battle_started(stage: int, enemy)
signal log_line(text: String)
signal stats_updated(player, enemy)
signal victory(stage: int)
signal defeat(stage: int)
signal powerup_choices(options)
signal powerup_applied(powerup_name: String)
signal prompt_continue()
# New team-based projectile signal: includes team and indices
signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)

var rng := RandomNumberGenerator.new()
var player: Unit
# Maintain legacy single enemy for HUD compatibility (first alive enemy)
var enemy: Unit

# Teams (locked to 2v2 for now)
var player_team: Array[Unit] = []
var enemy_team: Array[Unit] = []

# Per-unit cooldowns and targets (parallel to teams)
var _player_cds: Array[float] = []
var _enemy_cds: Array[float] = []
var _player_targets: Array[int] = []
var _enemy_targets: Array[int] = []

# Distance/selection helper provided by the view
var select_closest_target: Callable = Callable()

var stage: int = 1

# Realtime combat state
var _battle_active: bool = false
var _regen_tick_accum: float = 0.0

func _ready() -> void:
	rng.randomize()
	set_process(true)

func is_turn_in_progress() -> bool:
	return false

func _process(delta: float) -> void:
	if not _battle_active:
		return
	# Victory/defeat guardrails
	if _all_dead(player_team):
		_on_defeat()
		return
	if _all_dead(enemy_team):
		_on_victory()
		return

	# Advance regen/mana tick (once per second)
	_regen_tick_accum += delta
	if _regen_tick_accum >= 1.0:
		_regen_tick_accum -= 1.0
		_tick_regen()

	# Tick and possibly attack for each alive unit on both teams
	for i in range(player_team.size()):
		if i >= _player_cds.size():
			_player_cds.append(0.0)
		_player_cds[i] -= delta
		var u: Unit = player_team[i]
		if not u or not u.is_alive():
			continue
		# Ensure/refresh target
		if not _is_valid_target(_player_targets, i, enemy_team):
			_player_targets = _ensure_size(_player_targets, player_team.size(), -1)
			_player_targets[i] = _select_target_for("player", i, "enemy")
		# Attack if ready and target valid
		if _player_cds[i] <= 0.0 and _is_target_alive(enemy_team, _player_targets[i]):
			var roll := u.attack_roll(rng)
			emit_signal("projectile_fired", "player", i, _player_targets[i], int(roll["damage"]), bool(roll["crit"]))
			_after_attack_mana_gain(u)
			_player_cds[i] = _compute_cooldown(u)

	for j in range(enemy_team.size()):
		if j >= _enemy_cds.size():
			_enemy_cds.append(0.0)
		_enemy_cds[j] -= delta
		var e: Unit = enemy_team[j]
		if not e or not e.is_alive():
			continue
		if not _is_valid_target(_enemy_targets, j, player_team):
			_enemy_targets = _ensure_size(_enemy_targets, enemy_team.size(), -1)
			_enemy_targets[j] = _select_target_for("enemy", j, "player")
		if _enemy_cds[j] <= 0.0 and _is_target_alive(player_team, _enemy_targets[j]):
			var r2 := e.attack_roll(rng)
			emit_signal("projectile_fired", "enemy", j, _enemy_targets[j], int(r2["damage"]), bool(r2["crit"]))
			_after_attack_mana_gain(e)
			_enemy_cds[j] = _compute_cooldown(e)

func _compute_cooldown(u: Unit) -> float:
	if not u:
		return 1.0
	var atk_speed: float = max(0.01, u.attack_speed)
	return 1.0 / atk_speed

func _after_attack_mana_gain(src: Unit) -> void:
	if not src:
		return
	var gain: int = int(max(0, int(src.mana_gain_per_attack)))
	if gain > 0 and src.mana_max > 0:
		src.mana = min(src.mana_max, src.mana + gain)
		if src.mana >= src.mana_max:
			emit_signal("log_line", "%s used its ability!" % (src.name if src.name != "" else "Unit"))
			src.mana = 0
		emit_signal("stats_updated", player, enemy)

func new_player(player_name: String = "Hero") -> void:
	player = load("res://scripts/unit_factory.gd").spawn("sari")
	if player:
		player.name = player_name

func start_stage() -> void:
	# Build 2v2 teams
	player_team.clear()
	enemy_team.clear()
	# Player team: starter + ally
	if player:
		player_team.append(player)
	var ally: Unit = load("res://scripts/unit_factory.gd").spawn("paisley") as Unit
	if ally:
		player_team.append(ally)
	# Enemy team: Nyxa + Volt
	var nyxa: Unit = load("res://scripts/unit_factory.gd").spawn("nyxa") as Unit
	var volt: Unit = load("res://scripts/unit_factory.gd").spawn("volt") as Unit
	if nyxa: enemy_team.append(nyxa)
	if volt: enemy_team.append(volt)

	# Legacy fields for HUD compatibility
	enemy = _first_alive(enemy_team)
	emit_signal("battle_started", stage, enemy)
	if enemy:
		emit_signal("log_line", "=== Stage %d: %s and %s appear! ===" % [stage, enemy_team[0].name, enemy_team[1].name if enemy_team.size() > 1 else "?"])
	emit_signal("stats_updated", player, enemy)

	# Initialize realtime battle state
	_battle_active = true
	_regen_tick_accum = 0.0
	_player_cds = _fill_cds_for(player_team)
	_enemy_cds = _fill_cds_for(enemy_team)
	_player_targets = _ensure_size([], player_team.size(), -1)
	_enemy_targets = _ensure_size([], enemy_team.size(), -1)
	# Initial target selection for each unit
	for i in range(player_team.size()):
		_player_targets[i] = _select_target_for("player", i, "enemy")
	for j in range(enemy_team.size()):
		_enemy_targets[j] = _select_target_for("enemy", j, "player")

func setup_stage_preview() -> void:
	# Prepare teams (2v2) without starting combat so the view can build sprites and allow placement.
	player_team.clear()
	enemy_team.clear()
	if player:
		player_team.append(player)
	var ally: Unit = load("res://scripts/unit_factory.gd").spawn("paisley") as Unit
	if ally:
		player_team.append(ally)
	# Spawn enemies for preview; do not start battle yet.
	var nyxa: Unit = load("res://scripts/unit_factory.gd").spawn("nyxa") as Unit
	var volt: Unit = load("res://scripts/unit_factory.gd").spawn("volt") as Unit
	if nyxa: enemy_team.append(nyxa)
	if volt: enemy_team.append(volt)
	# Legacy HUD ref
	enemy = _first_alive(enemy_team)
	_battle_active = false
	_regen_tick_accum = 0.0
	_player_cds = _fill_cds_for(player_team)
	_enemy_cds = _fill_cds_for(enemy_team)
	_player_targets = _ensure_size([], player_team.size(), -1)
	_enemy_targets = _ensure_size([], enemy_team.size(), -1)

func on_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	# Ignore any hits after combat stops to avoid post-fight damage
	if not _battle_active:
		return
	var src: Unit = null
	var tgt: Unit = null
	var tgt_array: Array[Unit]
	if source_team == "player":
		src = _unit_at(player_team, source_index)
		tgt = _unit_at(enemy_team, target_index)
		tgt_array = enemy_team
	else:
		src = _unit_at(enemy_team, source_index)
		tgt = _unit_at(player_team, target_index)
		tgt_array = player_team
	if not src or not tgt:
		return
	# Apply block chance if defender has it
	if rng.randf() < tgt.block_chance:
		if source_team == "enemy":
			emit_signal("log_line", "You blocked the enemy attack.")
		else:
			emit_signal("log_line", "%s blocked your attack." % (tgt.name))
	else:
		var dealt := tgt.take_damage(damage)
		var heal := int(float(dealt) * src.lifesteal)
		if heal > 0:
			src.hp = min(src.max_hp, src.hp + heal)
		if source_team == "player":
			emit_signal("log_line", "You hit %s for %d%s. Lifesteal +%d." % [tgt.name, dealt, " (CRIT)" if crit else "", heal])
		else:
			emit_signal("log_line", "%s hits you for %d%s." % [src.name, dealt, " (CRIT)" if crit else ""])

	# Refresh legacy enemy ref for HUD
	enemy = _first_alive(enemy_team)
	emit_signal("stats_updated", player, enemy)

	# Victory/defeat checks
	if _all_dead(tgt_array):
		if source_team == "player":
			_on_victory()
		else:
			_on_defeat()

func _tick_regen() -> void:
	for u in player_team:
		if u:
			u.end_of_turn()
	for e in enemy_team:
		if e:
			e.end_of_turn()
	# Refresh legacy refs
	enemy = _first_alive(enemy_team)
	emit_signal("stats_updated", player, enemy)

func _on_victory() -> void:
	emit_signal("log_line", "Victory. You survived Stage %d." % stage)
	_reset_units_after_combat()
	emit_signal("stats_updated", player, enemy)
	emit_signal("victory", stage)
	_offer_powerups()
	_battle_active = false

func _on_defeat() -> void:
	emit_signal("log_line", "Defeat at Stage %d." % stage)
	_reset_units_after_combat()
	emit_signal("stats_updated", player, enemy)
	emit_signal("defeat", stage)
	_battle_active = false

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

# Initialization hook to reset per-combat state (e.g., stacks in future)
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

# --- Targeting helpers ---
func _ensure_size(arr: Array[int], size: int, fill: int) -> Array[int]:
	var out: Array[int] = []
	for v in arr:
		out.append(int(v))
	while out.size() < size:
		out.append(fill)
	return out

func _fill_cds_for(team: Array[Unit]) -> Array[float]:
	var cds: Array[float] = []
	for u in team:
		cds.append(0.0 if u else 1.0)
	return cds

func _all_dead(team: Array[Unit]) -> bool:
	for u in team:
		if u and u.is_alive():
			return false
	return true

func _first_alive(team: Array[Unit]) -> Unit:
	for u in team:
		if u and u.is_alive():
			return u
	return null

func _unit_at(team: Array[Unit], idx: int) -> Unit:
	if idx < 0 or idx >= team.size():
		return null
	return team[idx]

func _is_target_alive(team: Array[Unit], idx: int) -> bool:
	var u := _unit_at(team, idx)
	return u != null and u.is_alive()

func _is_valid_target(targets: Array[int], src_index: int, enemy_team_local: Array[Unit]) -> bool:
	if src_index < 0 or src_index >= targets.size():
		return false
	var t := targets[src_index]
	return _is_target_alive(enemy_team_local, t)

func _select_target_for(my_team: String, my_index: int, enemy_team_name: String) -> int:
	# Defer to view-provided helper if available
	if select_closest_target.is_valid():
		var result = select_closest_target.call(my_team, my_index, enemy_team_name)
		if typeof(result) == TYPE_INT:
			return int(result)
	# Fallback: pick first alive
	var enemy_arr := enemy_team if enemy_team_name == "enemy" else player_team
	for i in range(enemy_arr.size()):
		if _is_target_alive(enemy_arr, i):
			return i
	return -1
