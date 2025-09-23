extends Node

# Headless round-robin 1v1 simulator for balance.
# Scene-friendly and -s friendly.
# CLI example:
# godot --headless -s tests/balance_runner/balance_runner.gd -- --repeats=10 --delta=0.05 --timeout=120 --cost=1,2,3 --role=marksman,mage --out=user://balance_runner/balance_matrix.csv

const UnitFactory = preload("res://scripts/unit_factory.gd")
const BattleState = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngine = preload("res://scripts/game/combat/combat_engine.gd")
const Unit = preload("res://scripts/unit.gd")
const UnitProfile = preload("res://scripts/game/units/unit_profile.gd")
const UnitDef = preload("res://scripts/game/units/unit_def.gd")

var _signal_outcome: String = ""

func _ready() -> void:
	# Run automatically when used as a scene.
	call_deferred("_run")

class MatchResult:
	var a_id: String
	var b_id: String
	var a_wins: int = 0
	var b_wins: int = 0
	var draws: int = 0
	var shots: int = 0
	var casts_sum: int = 0
	var first_cast_time_sum: float = 0.0
	var first_cast_samples: int = 0
	var a_time_sum: float = 0.0
	var b_time_sum: float = 0.0
	var a_hp_sum: int = 0
	var b_hp_sum: int = 0
	var total: int = 0

	func add_win(winner: String, time_s: float, a_hp: int, b_hp: int) -> void:
		total += 1
		if winner == a_id:
			a_wins += 1
			a_time_sum += time_s
			a_hp_sum += a_hp
		elif winner == b_id:
			b_wins += 1
			b_time_sum += time_s
			b_hp_sum += b_hp
		else:
			draws += 1

	func summary() -> Dictionary:
		return {
			"a": a_id,
			"b": b_id,
			"a_win_pct": (float(a_wins) / max(1, total)),
			"b_win_pct": (float(b_wins) / max(1, total)),
			"draw_pct": (float(draws) / max(1, total)),
			"a_avg_time": (a_time_sum / max(1, a_wins)),
			"b_avg_time": (b_time_sum / max(1, b_wins)),
			"a_avg_hp": int(round(float(a_hp_sum) / max(1, a_wins))),
			"b_avg_hp": int(round(float(b_hp_sum) / max(1, b_wins))),
			"shots": shots,
		}

func _run() -> void:
	print("BalanceRunner: starting. argv=", OS.get_cmdline_args())
	var args := _parse_args(OS.get_cmdline_args())
	var repeats: int = int(args.get("repeats", 10))
	var delta: float = float(args.get("delta", 0.05))
	var timeout_s: float = float(args.get("timeout", 120.0))
	var abilities_flag_str: String = String(args.get("abilities", "false"))
	var abilities_enabled: bool = _parse_bool(abilities_flag_str)
	var metrics_flag_str: String = String(args.get("ability_metrics", "false"))
	var ability_metrics: bool = _parse_bool(metrics_flag_str)
	# Default to the repo folder; we'll resolve to an OS path so it works headless.
	var out_path: String = String(args.get("out", "res://tests/balance_runner/results/balance_matrix.csv"))
	var role_filter: PackedStringArray = _split_csv(String(args.get("role", "")))
	var cost_filter: PackedInt32Array = _csv_to_ints(String(args.get("cost", "")))

	var units: Array[Dictionary] = _collect_units(role_filter, cost_filter)
	print("BalanceRunner: collected ", units.size(), " units")
	if units.size() < 2:
		var cost_strs: PackedStringArray = []
		for v in cost_filter:
			cost_strs.append(str(v))
		var msg := "BalanceRunner: not enough units after filtering. role=%s cost=%s" % [
			_join_strings(role_filter, ","), _join_strings(cost_strs, ",")
		]
		push_warning(msg)
		printerr(msg)
		if get_tree():
			get_tree().quit()
		return

	var results: Array = []
	for i in range(units.size()):
		for j in range(i + 1, units.size()):
			var a: Dictionary = units[i]
			var b: Dictionary = units[j]
			var mr := MatchResult.new()
			mr.a_id = String(a.id)
			mr.b_id = String(b.id)
			for _r in range(repeats):
			_simulate_pair(mr, a.id, b.id, delta, timeout_s, abilities_enabled, ability_metrics)
			_simulate_pair(mr, b.id, a.id, delta, timeout_s, abilities_enabled, ability_metrics)
			results.append(mr)

	print("BalanceRunner: pairs=%d repeats=%d delta=%.3f timeout=%.2fs out=%s" % [
		(units.size() * (units.size() - 1)) / 2, repeats, delta, timeout_s, out_path
	])
	_write_csv(out_path, results)
	_print_human_summary(results)
	if get_tree():
		get_tree().quit()

func _simulate_pair(mr: MatchResult, player_id: String, enemy_id: String, delta: float, timeout_s: float, abilities_enabled: bool, ability_metrics: bool) -> void:
	var uA: Unit = UnitFactory.spawn(player_id)
	var uB: Unit = UnitFactory.spawn(enemy_id)
	if uA == null or uB == null:
		return
	var state: BattleState = BattleState.new()
	state.stage = 1
	state.player_team.append(uA)
	state.enemy_team.append(uB)

	var engine: CombatEngine = CombatEngine.new()
	engine.abilities_enabled = abilities_enabled
	engine.deterministic_rolls = false
	engine.configure(state, uA, 1, Callable())
	engine.set_arena(1.0, [Vector2.ZERO], [Vector2.ZERO], Rect2(Vector2.ZERO, Vector2(4, 4)))
	var debug_hit_prints := 0
	if not engine.is_connected("projectile_fired", Callable(self, "_bridge_projectile")):
		engine.projectile_fired.connect(func(team: String, sidx: int, tidx: int, dmg: int, crit: bool):
			print("BalanceRunner: projectile ", team, " ", sidx, "->", tidx, " dmg=", dmg, " crit=", crit)
			engine.on_projectile_hit(team, sidx, tidx, dmg, crit)
		)
	if not engine.is_connected("hit_applied", Callable(self, "_debug_hit")):
		engine.hit_applied.connect(func(team: String, sidx: int, tidx: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, p_cd: float, e_cd: float):
			mr.shots += 1
			if debug_hit_prints < 20:
				debug_hit_prints += 1
				print("BalanceRunner: hit ", team, " ", sidx, "->", tidx, " rolled=", rolled, " dealt=", dealt, " hp ", before_hp, "->", after_hp)
		)

	var outcome: String = ""
	_signal_outcome = ""
	if not engine.is_connected("victory", Callable(self, "_on_engine_outcome_v")):
		engine.victory.connect(Callable(self, "_on_engine_outcome_v"))
	if not engine.is_connected("defeat", Callable(self, "_on_engine_outcome_d")):
		engine.defeat.connect(Callable(self, "_on_engine_outcome_d"))

	# Ability analytics (optional)
	var casts_local := 0
	var first_cast_time := -1.0
	if abilities_enabled and ability_metrics and engine.ability_system != null:
		engine.ability_system.ability_cast.connect(func(_team: String, _idx: int, _ability_id: String):
			casts_local += 1
			if first_cast_time < 0.0:
				first_cast_time = t
		)
	engine.start()

	var t := 0.0
	while outcome == "" and t < timeout_s:
		engine.process(delta)
		t += delta
		if _signal_outcome != "":
			outcome = _signal_outcome

	var winner_id := "draw"
	var a_hp := int(uA.hp)
	var b_hp := int(uB.hp)
	if outcome == "victory":
		winner_id = player_id
	elif outcome == "defeat":
		winner_id = enemy_id

	mr.add_win(winner_id, t, a_hp, b_hp)
	# shots already accumulated into mr via hit_applied
	if abilities_enabled and ability_metrics:
		mr.casts_sum += casts_local
		if first_cast_time >= 0.0:
			mr.first_cast_time_sum += first_cast_time
			mr.first_cast_samples += 1

func _collect_units(role_filter: PackedStringArray, cost_filter: PackedInt32Array) -> Array:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open("res://data/units")
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if f.begins_with(".") or dir.current_is_dir() or not f.ends_with(".tres"):
			continue
		var path := "res://data/units/%s" % f
		var res = load(path)
		var id := ""
		var roles: Array[String] = []
		var cost := 0
		if res is UnitProfile:
			id = String(res.id)
			roles = res.roles.duplicate()
			cost = int(res.cost)
		elif res is UnitDef:
			id = String(res.id)
			roles = res.roles.duplicate()
			cost = int(res.cost)
		if id == "":
			continue
		if role_filter.size() > 0:
			var ok := false
			for r in roles:
				if role_filter.has(String(r).to_lower()):
					ok = true
					break
			if not ok:
				continue
		if cost_filter.size() > 0 and not cost_filter.has(cost):
			continue
		out.append({"id": id, "roles": roles, "cost": cost})
	dir.list_dir_end()
	out.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return out

func _write_csv(path: String, results: Array) -> void:
	var resolved_path := _resolve_writable_path(path)
	var dir_path := resolved_path.get_base_dir()
	if dir_path != "":
		var mk := DirAccess.make_dir_recursive_absolute(dir_path)
		if mk != OK:
			var dmsg := "BalanceRunner: failed to ensure directory %s (err=%d)" % [dir_path, mk]
			push_warning(dmsg)
			printerr(dmsg)
	var fa := FileAccess.open(resolved_path, FileAccess.WRITE)
	if fa == null:
		var emsg := "BalanceRunner: cannot write %s" % resolved_path
		push_warning(emsg)
		printerr(emsg)
		return
	var header := "attacker,defender,a_win_pct,b_win_pct,draw_pct,a_avg_time,b_avg_time,a_avg_hp,b_avg_hp,total,shots"
	if ability_metrics:
		header += ",avg_casts,avg_first_cast_s"
	fa.store_line(header)
	for mr: MatchResult in results:
		var s := mr.summary()
		var line := "%s,%s,%.3f,%.3f,%.3f,%.2f,%.2f,%d,%d,%d,%d" % [
			s.a, s.b, s.a_win_pct, s.b_win_pct, s.draw_pct,
			s.a_avg_time, s.b_avg_time, s.a_avg_hp, s.b_avg_hp, mr.total, mr.shots
		]
		if ability_metrics:
			var avg_casts := (float(mr.casts_sum) / max(1, mr.total))
			var avg_first_cast := (mr.first_cast_time_sum / max(1, mr.first_cast_samples))
			line += ",%.2f,%.2f" % [avg_casts, avg_first_cast]
		fa.store_line(line)
	fa.close()
	print("BalanceRunner: wrote results to %s" % resolved_path)

func _resolve_writable_path(p: String) -> String:
	# If path is res://, convert to absolute OS path so writing works when running headless.
	if p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return p

func _print_human_summary(results: Array) -> void:
	var fastest: Array = []
	for mr: MatchResult in results:
		var s := mr.summary()
		if mr.a_wins > 0:
			fastest.append({"pair": "%s vs %s" % [mr.a_id, mr.b_id], "winner": mr.a_id, "t": s.a_avg_time})
		if mr.b_wins > 0:
			fastest.append({"pair": "%s vs %s" % [mr.a_id, mr.b_id], "winner": mr.b_id, "t": s.b_avg_time})
	fastest.sort_custom(func(x, y): return float(x.t) < float(y.t))

	print("\n=== Fastest Average Kills ===")
	for i in range(min(15, fastest.size())):
		var r = fastest[i]
		print("%2d. %-18s winner=%-10s avg_t=%.2fs" % [i + 1, r.pair, r.winner, r.t])

	var margins: Array = []
	for mr2: MatchResult in results:
		var s2 := mr2.summary()
		if mr2.a_wins > 0:
			margins.append({"pair": "%s vs %s" % [mr2.a_id, mr2.b_id], "winner": mr2.a_id, "hp": s2.a_avg_hp})
		if mr2.b_wins > 0:
			margins.append({"pair": "%s vs %s" % [mr2.a_id, mr2.b_id], "winner": mr2.b_id, "hp": s2.b_avg_hp})
	margins.sort_custom(func(x, y): return int(y.hp) - int(x.hp))

	print("\n=== Largest Average HP Margin ===")
	for i2 in range(min(15, margins.size())):
		var r2 = margins[i2]
		print("%2d. %-18s winner=%-10s avg_hp=%d" % [i2 + 1, r2.pair, r2.winner, r2.hp])

	print("\n=== Matrix (excerpt) ===")
	results.sort_custom(func(m1: MatchResult, m2: MatchResult): return m1.a_id + m1.b_id < m2.a_id + m2.b_id)
	for k in range(min(20, results.size())):
		var mr3: MatchResult = results[k]
		var s3 := mr3.summary()
		print("%s vs %s  a%%=%.2f  b%%=%.2f  draws=%.2f  a_t=%.2f  b_t=%.2f" % [s3.a, s3.b, s3.a_win_pct, s3.b_win_pct, s3.draw_pct, s3.a_avg_time, s3.b_avg_time])

func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var seen_sep := false
	for a in argv:
		if a == "--":
			seen_sep = true
			continue
		var s := String(a)
		if (not seen_sep) and (not s.contains("=")):
			continue
		var parts := s.split("=", false, 2)
		if parts.size() == 2:
			out[parts[0].lstrip("-")] = parts[1]
	return out

func _split_csv(s: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if s.strip_edges() == "":
		return out
	for p in s.split(","):
		var v := String(p).strip_edges().to_lower()
		if v != "":
			out.append(v)
	return out

func _csv_to_ints(s: String) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if s.strip_edges() == "":
	return out
	for p in s.split(","):
		var v := String(p).strip_edges()
		if v.is_valid_int():
			out.append(int(v))
	return out

func _join_strings(arr: PackedStringArray, sep: String) -> String:
	var s := ""
	for i in arr.size():
		if i > 0:
			s += sep
		s += arr[i]
	return s

func _parse_bool(s: String) -> bool:
	var v := s.strip_edges().to_lower()
	return v in ["1", "true", "yes", "y", "on"]


func _on_engine_outcome_v(_stage: int) -> void:
	_signal_outcome = "victory"
	print("BalanceRunner: outcome victory")

func _on_engine_outcome_d(_stage: int) -> void:
	_signal_outcome = "defeat"
	print("BalanceRunner: outcome defeat")
