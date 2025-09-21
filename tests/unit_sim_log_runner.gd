extends Node

# Runs a single 1v1 battle and dumps full logs for debugging fairness/order.

var _dmg_a_total: int = 0
var _dmg_b_total: int = 0
var _shot_rolled_a: int = 0
var _shot_rolled_b: int = 0
var _shots_seen: int = 0
var _hits_seen_count: int = 0
var _saw_hit: bool = false
var _last_pair_simultaneous: bool = false
var _outcome: String = ""
var _engine: CombatEngine = null

var _last_player_hit: Dictionary = {"src": -1, "tgt": -1, "rolled": 0, "dealt": 0, "before": 0, "after": 0, "pcd": 0.0, "ecd": 0.0}
var _last_enemy_hit: Dictionary = {"src": -1, "tgt": -1, "rolled": 0, "dealt": 0, "before": 0, "after": 0, "pcd": 0.0, "ecd": 0.0}
var _last_player_shot: Dictionary = {"src": -1, "tgt": -1, "rolled": 0, "crit": false}
var _last_enemy_shot: Dictionary = {"src": -1, "tgt": -1, "rolled": 0, "crit": false}

class BattleOptions:
	var role_a: String = "none"
	var role_b: String = "none"
	var unit_a: String = "sari"
	var unit_b: String = "nyxa"
	var tick: float = 0.1
	var max_frames: int = 2000
	var fight_cap: float = 10.0
	var player_first: bool = true

func _ready() -> void:
	var opts: BattleOptions = _parse_args()
	_reset_logging_state()
	_outcome = ""

	var state: BattleState = load("res://scripts/game/combat/battle_state.gd").new()
	state.reset()
	state.stage = 1

	var a_unit: Unit = _spawn_with_role(opts.unit_a, opts.role_a, 1, 1)
	var b_unit: Unit = _spawn_with_role(opts.unit_b, opts.role_b, 1, 1)
	if not a_unit or not b_unit:
		printerr("Failed to spawn units")
		get_tree().quit(1)
		return

	a_unit.heal_to_full()
	b_unit.heal_to_full()
	a_unit.mana = a_unit.mana_start
	b_unit.mana = b_unit.mana_start
	state.player_team = [a_unit]
	state.enemy_team = [b_unit]

	var engine: CombatEngine = load("res://scripts/game/combat/combat_engine.gd").new()
	_engine = engine
	engine.process_player_first = opts.player_first
	engine.alternate_order = false
	engine.simultaneous_pairs = true
	engine.deterministic_rolls = true
	engine.configure(state, a_unit, 1)

	engine.hit_applied.connect(_on_hit_applied)
	engine.projectile_fired.connect(_on_projectile_fired)
	engine.victory.connect(_on_victory)
	engine.defeat.connect(_on_defeat)
	engine.draw.connect(_on_draw)

	var init_a_hp := int(a_unit.hp)
	var init_b_hp := int(b_unit.hp)
	engine.start()
	var sim_time := 0.0
	var frames := 0
	var frame_cap: int = max(1, opts.max_frames)
	var cap_ms := int(max(0.0, opts.fight_cap) * 1000.0)
	var start_ms := Time.get_ticks_msec()
	while _outcome == "" and frames < frame_cap:
		engine.process(opts.tick)
		sim_time += opts.tick
		frames += 1
		if cap_ms > 0 and (Time.get_ticks_msec() - start_ms) >= cap_ms:
			break

	if _outcome == "":
		_outcome = _determine_fallback_outcome(a_unit, b_unit, state)

	var header := "OneBattle %s[%s] vs %s[%s] tick=%s frames=%d outcome=%s" % [
		opts.unit_a,
		opts.role_a,
		opts.unit_b,
		opts.role_b,
		str(opts.tick),
		frames,
		_outcome
	]
	var out_path := "res://tests/unit_battle_log.txt"
	var fa := FileAccess.open(out_path, FileAccess.WRITE)
	if fa:
		fa.store_line(header)
		fa.store_line("InitHP A=%d B=%d" % [init_a_hp, init_b_hp])
		fa.store_line("FinalHP A=%d B=%d" % [int(a_unit.hp), int(b_unit.hp)])
		var hits_seen_str := ("true" if _saw_hit else "false")
		var pair_mode_str := ("true" if engine.simultaneous_pairs else "false")
		fa.store_line("HitsSeen=%s count=%d shots=%d pairMode=%s" % [hits_seen_str, _hits_seen_count, _shots_seen, pair_mode_str])
		fa.store_line("EnginePairs=%d EngineShots=%d DoubleLethals=%d" % [int(engine.debug_pairs), int(engine.debug_shots), int(engine.debug_double_lethals)])
		if _saw_hit:
			fa.store_line("Totals dmgA=%d dmgB=%d" % [_dmg_a_total, _dmg_b_total])
			fa.store_line("LastHit A: src=%d->tgt=%d rolled=%d dealt=%d tgt_hp:%d->%d" % [
				int(_last_player_hit["src"]),
				int(_last_player_hit["tgt"]),
				int(_last_player_hit["rolled"]),
				int(_last_player_hit["dealt"]),
				int(_last_player_hit["before"]),
				int(_last_player_hit["after"])
			])
			fa.store_line("LastHit B: src=%d->tgt=%d rolled=%d dealt=%d tgt_hp:%d->%d" % [
				int(_last_enemy_hit["src"]),
				int(_last_enemy_hit["tgt"]),
				int(_last_enemy_hit["rolled"]),
				int(_last_enemy_hit["dealt"]),
				int(_last_enemy_hit["before"]),
				int(_last_enemy_hit["after"])
			])
		else:
			fa.store_line("TotalsRolled A=%d B=%d" % [_shot_rolled_a, _shot_rolled_b])
			fa.store_line("LastShot A: src=%d->tgt=%d rolled=%d" % [
				int(_last_player_shot["src"]),
				int(_last_player_shot["tgt"]),
				int(_last_player_shot["rolled"])
			])
			fa.store_line("LastShot B: src=%d->tgt=%d rolled=%d" % [
				int(_last_enemy_shot["src"]),
				int(_last_enemy_shot["tgt"]),
				int(_last_enemy_shot["rolled"])
			])
		fa.store_line("SimultaneousLastPair=%s" % ("true" if _last_pair_simultaneous else "false"))
		if _outcome != "D":
			fa.store_line("OutcomeDelta=%d" % int(abs(int(a_unit.hp) - int(b_unit.hp))))
		fa.close()
	else:
		printerr("Failed to open log output: %s" % out_path)

	prints(header)
	prints("Wrote: %s" % ProjectSettings.globalize_path(out_path))

	get_tree().quit(0)

func _parse_args() -> BattleOptions:
	var opts: BattleOptions = BattleOptions.new()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--roleA="):
			opts.role_a = arg.substr(8)
		elif arg.begins_with("--roleB="):
			opts.role_b = arg.substr(8)
		elif arg.begins_with("--unitA="):
			opts.unit_a = arg.substr(8)
		elif arg.begins_with("--unitB="):
			opts.unit_b = arg.substr(8)
		elif arg.begins_with("--tick="):
			opts.tick = max(0.005, float(arg.substr(7)))
		elif arg.begins_with("--maxframes="):
			opts.max_frames = max(1, int(arg.substr(12)))
		elif arg.begins_with("--fightcap="):
			opts.fight_cap = max(0.0, float(arg.substr(11)))
		elif arg == "--enemy-first":
			opts.player_first = false
	return opts

func _determine_fallback_outcome(a_unit: Unit, b_unit: Unit, state: BattleState) -> String:
	var a_alive := a_unit.is_alive()
	var b_alive := b_unit.is_alive()
	if a_alive and not b_alive:
		return "A"
	elif b_alive and not a_alive:
		return "B"
	elif not a_alive and not b_alive:
		return "D"

	if int(a_unit.hp) > int(b_unit.hp):
		return "A"
	elif int(b_unit.hp) > int(a_unit.hp):
		return "B"

	if _dmg_a_total > _dmg_b_total:
		return "A"
	elif _dmg_b_total > _dmg_a_total:
		return "B"

	var p_cd: float = (state.player_cds[0] if state.player_cds.size() > 0 else 9999.0)
	var e_cd: float = (state.enemy_cds[0] if state.enemy_cds.size() > 0 else 9999.0)
	var cd_diff: float = abs(p_cd - e_cd)
	if cd_diff <= 0.0001:
		return "D"
	return "A" if p_cd < e_cd else "B"

func _reset_logging_state() -> void:
	_dmg_a_total = 0
	_dmg_b_total = 0
	_shot_rolled_a = 0
	_shot_rolled_b = 0
	_shots_seen = 0
	_hits_seen_count = 0
	_saw_hit = false
	_last_pair_simultaneous = false
	_last_player_hit = {"src": -1, "tgt": -1, "rolled": 0, "dealt": 0, "before": 0, "after": 0, "pcd": 0.0, "ecd": 0.0}
	_last_enemy_hit = {"src": -1, "tgt": -1, "rolled": 0, "dealt": 0, "before": 0, "after": 0, "pcd": 0.0, "ecd": 0.0}
	_last_player_shot = {"src": -1, "tgt": -1, "rolled": 0, "crit": false}
	_last_enemy_shot = {"src": -1, "tgt": -1, "rolled": 0, "crit": false}

func _spawn_with_role(unit_id: String, role: String, cost: int, level: int) -> Unit:
	var factory = load("res://scripts/unit_factory.gd")
	var def: UnitDef = null
	if factory and factory.has_method("_load_def"):
		def = factory._load_def(unit_id)
	if def == null:
		var fallback: UnitDef = load("res://scripts/game/units/unit_def.gd").new()
		fallback.id = unit_id
		fallback.name = unit_id.capitalize()
		def = fallback
	var r := String(role)
	if r == "" or r.to_lower() == "none":
		def.roles = []
	else:
		def.roles = [r]
	def.cost = cost
	def.level = level
	return factory._from_def(def)

func _on_hit_applied(src_team: String, src_idx: int, tgt_idx: int, rolled: int, dealt: int, _crit: bool, before_hp: int, after_hp: int, pcd: float, ecd: float) -> void:
	if src_team == "player":
		_dmg_a_total += int(dealt)
		_last_player_hit = {"src": src_idx, "tgt": tgt_idx, "rolled": rolled, "dealt": dealt, "before": before_hp, "after": after_hp, "pcd": pcd, "ecd": ecd}
	else:
		_dmg_b_total += int(dealt)
		_last_enemy_hit = {"src": src_idx, "tgt": tgt_idx, "rolled": rolled, "dealt": dealt, "before": before_hp, "after": after_hp, "pcd": pcd, "ecd": ecd}
	_saw_hit = true
	_hits_seen_count += 1
	if before_hp > 0 and after_hp == 0:
		_last_pair_simultaneous = true

func _on_projectile_fired(src_team: String, src_idx: int, tgt_idx: int, dmg: int, crit: bool) -> void:
	if src_team == "player":
		_last_player_shot = {"src": src_idx, "tgt": tgt_idx, "rolled": dmg, "crit": crit}
		_shot_rolled_a += int(dmg)
	else:
		_last_enemy_shot = {"src": src_idx, "tgt": tgt_idx, "rolled": dmg, "crit": crit}
		_shot_rolled_b += int(dmg)
	_shots_seen += 1

func _on_victory(_stage: int) -> void:
	if _outcome == "":
		_outcome = "A"

func _on_defeat(_stage: int) -> void:
	if _outcome == "":
		_outcome = "B"

func _on_draw(_stage: int) -> void:
	if _outcome == "":
		_outcome = "D"
