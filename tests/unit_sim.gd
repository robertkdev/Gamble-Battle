extends RefCounted
class_name UnitSim

# Fast 1v1 simulation utility for balancing.
# Usage (programmatic):
#   var sim := UnitSim.new()
#   var result := sim.run_1v1("Fighter", "Marksman", 100, 0.05, "sari", "nyxa")
#   prints(result)

const DEFAULT_A_ID := "sari"
const DEFAULT_B_ID := "nyxa"

var _rr := RandomNumberGenerator.new()

func _init() -> void:
	_rr.randomize()

# --- Placeholder-based simulation (no .tres) ---
func run_1v1_placeholders(
		a_cost: int,
		a_level: int,
		b_cost: int,
		b_level: int,
		runs: int = 2300,
		tick: float = 0.1,
		max_frames: int = 200,
		time_cap_sec: float = 6.0,
		fight_time_cap_sec: float = 2.0,
		a_roles: Array[String] = [],
		b_roles: Array[String] = []
	) -> Dictionary:
	var make_def := func(id_str: String, cost: int, level: int, roles: Array[String]) -> UnitDef:
		var def: UnitDef = load("res://scripts/game/units/unit_def.gd").new()
		def.id = id_str
		def.name = id_str.capitalize()
		def.traits = []
		def.roles = roles.duplicate()
		def.cost = cost
		def.level = level
		return def

	var a_def: UnitDef = make_def.call("placeholder_a", a_cost, a_level, a_roles)
	var b_def: UnitDef = make_def.call("placeholder_b", b_cost, b_level, b_roles)

	return _run_defs_1v1(a_def, b_def, runs, tick, max_frames, time_cap_sec, fight_time_cap_sec)

func _run_defs_1v1(
		a_def: UnitDef,
		b_def: UnitDef,
		runs: int,
		tick: float,
		max_frames: int,
		time_cap_sec: float,
		fight_time_cap_sec: float
	) -> Dictionary:
	var wins_a: int = 0
	var wins_b: int = 0
	var draws: int = 0
	var started_ms: int = Time.get_ticks_msec()
	var completed: int = 0
	for i in runs:
		var player_first := (int(i) % 2 == 0)
		var outcome := _simulate_single_from_defs(a_def, b_def, tick, max_frames, fight_time_cap_sec, player_first)
		if outcome == "A": wins_a += 1
		elif outcome == "B": wins_b += 1
		elif outcome == "D": draws += 1
		completed += 1
		if time_cap_sec > 0.0 and float(Time.get_ticks_msec() - started_ms) / 1000.0 >= time_cap_sec:
			break
	var total: int = max(1, completed)
	var a_pct: float = (float(wins_a) * 100.0) / float(total)
	var b_pct: float = (float(wins_b) * 100.0) / float(total)
	var d_pct: float = (float(draws) * 100.0) / float(total)
	return {"A_pct": a_pct, "B_pct": b_pct, "D_pct": d_pct, "A": wins_a, "B": wins_b, "D": draws, "runs": completed}

func run_1v1(
		role_a: String,
		role_b: String,
		runs: int = 2300,
		tick: float = 0.05,
		a_id: String = DEFAULT_A_ID,
		b_id: String = DEFAULT_B_ID,
		a_cost: int = 1,
		a_level: int = 1,
		b_cost: int = 1,
		b_level: int = 1,
		max_frames: int = 200,
		time_cap_sec: float = 6.0,
		fight_time_cap_sec: float = 2.0
	) -> Dictionary:
	var wins_a: int = 0
	var wins_b: int = 0
	var draws: int = 0
	var started_ms: int = Time.get_ticks_msec()
	var completed: int = 0
	for i in runs:
		var player_first := (int(i) % 2 == 0)
		var outcome := _simulate_single(a_id, role_a, a_cost, a_level, b_id, role_b, b_cost, b_level, tick, max_frames, fight_time_cap_sec, player_first)
		if outcome == "A":
			wins_a += 1
		elif outcome == "B":
			wins_b += 1
		elif outcome == "D":
			draws += 1
		completed += 1
		if time_cap_sec > 0.0 and float(Time.get_ticks_msec() - started_ms) / 1000.0 >= time_cap_sec:
			break
	var total: int = max(1, completed)
	var a_pct: float = (float(wins_a) * 100.0) / float(total)
	var b_pct: float = (float(wins_b) * 100.0) / float(total)
	var d_pct: float = (float(draws) * 100.0) / float(total)
	return {"A_pct": a_pct, "B_pct": b_pct, "D_pct": d_pct, "A": wins_a, "B": wins_b, "D": draws, "runs": completed}

func _simulate_single(
		a_id: String,
		a_role: String,
		a_cost: int,
		a_level: int,
		b_id: String,
		b_role: String,
		b_cost: int,
		b_level: int,
		tick: float,
		max_frames: int,
		fight_time_cap_sec: float,
		player_first: bool
	) -> String:
	# Prepare state and units
	var state: BattleState = load("res://scripts/game/combat/battle_state.gd").new()
	state.reset()
	state.stage = 1

	var a_unit: Unit = _spawn_with_role(a_id, a_role, a_cost, a_level)
	var b_unit: Unit = _spawn_with_role(b_id, b_role, b_cost, b_level)
	if not a_unit or not b_unit:
		return ""

	a_unit.heal_to_full()
	b_unit.heal_to_full()
	a_unit.mana = a_unit.mana_start
	b_unit.mana = b_unit.mana_start

	state.player_team = [a_unit]
	state.enemy_team = [b_unit]

	var engine: CombatEngine = load("res://scripts/game/combat/combat_engine.gd").new()
	var outcome: String = ""
	# Fairness: randomize first-mover per battle, alternate order to avoid bias
	engine.process_player_first = player_first
	engine.alternate_order = false
	engine.simultaneous_pairs = true
	engine.deterministic_rolls = true
	engine.victory.connect(func(_stage): if outcome == "": outcome = "A")
	engine.defeat.connect(func(_stage): if outcome == "": outcome = "B")
	engine.draw.connect(func(_stage): if outcome == "": outcome = "D")
	engine.configure(state, a_unit, 1)
	# Track actual damage dealt from engine-applied hits
	var dmg_a_total: int = 0
	var dmg_b_total: int = 0
	engine.hit_applied.connect(func(src_team: String, _si: int, _ti: int, _rolled: int, dealt: int, _crit: bool, _bhp: int, _ahp: int, _pcd: float, _ecd: float):
		if src_team == "player":
			dmg_a_total += dealt
		else:
			dmg_b_total += dealt
	)
	engine.start()

	var sim_time: float = 0.0
	var max_time: float = 120.0 # hard stop just in case
	var frames: int = 0
	var frame_cap: int = (max_frames if max_frames > 0 else int(ceil(max_time / max(0.001, tick))))
	frame_cap = clamp(frame_cap, 1, 100000) # absolute safety bounds
	var fight_start_ms: int = Time.get_ticks_msec()
	while outcome == "" and sim_time < max_time and frames < frame_cap:
		engine.process(tick)
		sim_time += tick
		frames += 1
		if fight_time_cap_sec > 0.0 and float(Time.get_ticks_msec() - fight_start_ms) / 1000.0 >= fight_time_cap_sec:
			break

	if outcome == "":
		# Fallback by remaining HP if time cap hit
		var a_alive: bool = a_unit.is_alive()
		var b_alive: bool = b_unit.is_alive()
		if a_alive and not b_alive:
			outcome = "A"
		elif b_alive and not a_alive:
			outcome = "B"
		elif not a_alive and not b_alive:
			outcome = "D"
		else:
			var a_hp := int(a_unit.hp)
			var b_hp := int(b_unit.hp)
			if a_hp > b_hp:
				outcome = "A"
			elif b_hp > a_hp:
				outcome = "B"
			else:
				if dmg_a_total > dmg_b_total:
					outcome = "A"
				elif dmg_b_total > dmg_a_total:
					outcome = "B"
				else:
					var p_cd := (state.player_cds[0] if state.player_cds.size() > 0 else 9999.0)
					var e_cd := (state.enemy_cds[0] if state.enemy_cds.size() > 0 else 9999.0)
					if abs(p_cd - e_cd) <= 0.0001:
						outcome = "D"
					elif p_cd < e_cd:
						outcome = "A"
					else:
						outcome = "B"
	# If single fight mode, annotate with end-state
	if max_frames <= 0 and fight_time_cap_sec <= 0.0:
		# nothing
		pass
	# Attach metadata to outcome via globals (optional) - not needed
	return outcome


func _simulate_single_from_defs(
		a_def: UnitDef,
		b_def: UnitDef,
		tick: float,
		max_frames: int,
		fight_time_cap_sec: float,
		player_first: bool
	) -> String:
	var state: BattleState = load("res://scripts/game/combat/battle_state.gd").new()
	state.reset()
	state.stage = 1
	var a_unit: Unit = load("res://scripts/unit_factory.gd")._from_def(a_def)
	var b_unit: Unit = load("res://scripts/unit_factory.gd")._from_def(b_def)
	if not a_unit or not b_unit:
		return ""
	a_unit.heal_to_full()
	b_unit.heal_to_full()
	a_unit.mana = a_unit.mana_start
	b_unit.mana = b_unit.mana_start
	state.player_team = [a_unit]
	state.enemy_team = [b_unit]
	var engine: CombatEngine = load("res://scripts/game/combat/combat_engine.gd").new()
	var outcome := ""
	engine.process_player_first = player_first
	engine.alternate_order = true
	engine.victory.connect(func(_s): if outcome == "": outcome = "A")
	engine.defeat.connect(func(_s): if outcome == "": outcome = "B")
	engine.draw.connect(func(_s): if outcome == "": outcome = "D")
	engine.configure(state, a_unit, 1)
	var dmg_a_total2: int = 0
	var dmg_b_total2: int = 0
	engine.hit_applied.connect(func(src_team: String, _si: int, _ti: int, _rolled: int, dealt: int, _crit: bool, _bhp: int, _ahp: int, _pcd: float, _ecd: float):
		if src_team == "player":
			dmg_a_total2 += dealt
		else:
			dmg_b_total2 += dealt
	)
	engine.start()
	var sim_time := 0.0
	var frames := 0
	var max_time := 120.0
	var frame_cap := (max_frames if max_frames > 0 else int(ceil(max_time / max(0.001, tick))))
	frame_cap = clamp(frame_cap, 1, 100000)
	var t0 := Time.get_ticks_msec()
	while outcome == "" and sim_time < max_time and frames < frame_cap:
		engine.process(tick)
		sim_time += tick
		frames += 1
		if fight_time_cap_sec > 0.0 and float(Time.get_ticks_msec() - t0) / 1000.0 >= fight_time_cap_sec:
			break
	if outcome == "":
		var a_alive := a_unit.is_alive()
		var b_alive := b_unit.is_alive()
		if a_alive and not b_alive:
			outcome = "A"
		elif b_alive and not a_alive:
			outcome = "B"
		elif not a_alive and not b_alive:
			outcome = "D"
		else:
			var a_hp := int(a_unit.hp)
			var b_hp := int(b_unit.hp)
			if a_hp > b_hp:
				outcome = "A"
			elif b_hp > a_hp:
				outcome = "B"
			else:
				if dmg_a_total2 > dmg_b_total2:
					outcome = "A"
				elif dmg_b_total2 > dmg_a_total2:
					outcome = "B"
				else:
					var p_cd2 := (state.player_cds[0] if state.player_cds.size() > 0 else 9999.0)
					var e_cd2 := (state.enemy_cds[0] if state.enemy_cds.size() > 0 else 9999.0)
					if abs(p_cd2 - e_cd2) <= 0.0001:
						outcome = "D"
					elif p_cd2 < e_cd2:
						outcome = "A"
					else:
						outcome = "B"
	return outcome


func _spawn_with_role(unit_id: String, role: String, cost: int, level: int) -> Unit:
	# Load a UnitDef via UnitFactory (supports UnitProfile-backed .tres), then override role/cost/level
	var factory = load("res://scripts/unit_factory.gd")
	var def: UnitDef = null
	if factory and factory.has_method("_load_def"):
		def = factory._load_def(unit_id)
	if def == null:
		# Build a minimal default def if missing
		def = load("res://scripts/game/units/unit_def.gd").new()
		def.id = unit_id
		def.name = unit_id.capitalize()

	# Empty/"none" disables roles, using base stats only
	var r := String(role)
	if r == "" or r.to_lower() == "none":
		def.roles = []
	else:
		def.roles = [r]
	def.cost = cost
	def.level = level
	# Use factory pipeline so role + scaling apply.
	return factory._from_def(def)
