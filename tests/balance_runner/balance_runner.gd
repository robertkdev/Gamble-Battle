extends Node

# Headless round-robin 1v1 simulator for balance.
# Scene-friendly and -s friendly.
# CLI example:
# godot --headless -s tests/balance_runner/balance_runner.gd -- --repeats=10 --timeout=120 --cost=1,2,3 --role=marksman,mage --out=user://balance_matrix.csv

const UnitFactory = preload("res://scripts/unit_factory.gd")
const BattleState = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngine = preload("res://scripts/game/combat/combat_engine.gd")
const Unit = preload("res://scripts/unit.gd")
const UnitProfile = preload("res://scripts/game/units/unit_profile.gd")
const UnitDef = preload("res://scripts/game/units/unit_def.gd")
const CSV_SCHEMA_VERSION := "identity_v2"
## Legacy adapter removed; BalanceRunner now writes only one CSV.

var _signal_outcome: String = ""

# Editor-friendly overrides (set via Inspector when running as a scene)
@export var use_editor_params: bool = true
@export var ids_prop: String = ""              # format: "attacker:defender,att:def"
@export var repeats_prop: int = 10
@export var timeout_prop: float = 120.0
@export var abilities_prop: bool = false
@export var ability_metrics_prop: bool = false
@export var role_filter_prop: String = ""       # CSV of primary roles (tank,brawler,assassin,marksman,mage,support)
@export var goal_filter_prop: String = ""       # CSV of primary goals (e.g., brawler.frontline_disruption)
@export var cost_filter_prop: String = ""       # CSV of ints
@export var out_path_prop: String = "user://balance_matrix.csv"

func _ready() -> void:
	# Prefer Inspector parameters when no CLI args are provided.
	call_deferred("_run")

func _run_from_properties() -> void:
	# Use fixed delta (0.05) per request; ignore delta-related fields.
	UnitFactory.role_invariant_fail_fast = true
	var id_pairs: Array = _parse_id_pairs(String(ids_prop))
	var role_filter: PackedStringArray = _split_csv(String(role_filter_prop))
	var goal_filter: PackedStringArray = _split_csv(String(goal_filter_prop))
	var cost_filter: PackedInt32Array = _csv_to_ints(String(cost_filter_prop))
	var out_path: String = String(out_path_prop)
	var repeats := int(repeats_prop)
	var timeout_s := float(timeout_prop)
	var abilities_enabled := bool(abilities_prop)
	var ability_metrics := bool(ability_metrics_prop)

	var units: Array[Dictionary] = _collect_units(role_filter, goal_filter, cost_filter)
	if units.size() < 2:
		var cost_strs: PackedStringArray = []
		for v in cost_filter:
			cost_strs.append(str(v))
		var goal_strs: PackedStringArray = []
		for g in goal_filter:
			goal_strs.append(String(g))
		var msg := "BalanceRunner: not enough units after filtering. role=%s goal=%s cost=%s" % [
			_join_strings(role_filter, ","), _join_strings(goal_strs, ","), _join_strings(cost_strs, ",")
		]
		push_warning(msg)
		printerr(msg)
		if get_tree():
			get_tree().quit()
		return
	var pairs: Array[Dictionary] = _enumerate_pairs(units, id_pairs)
	var total_pairs: int = pairs.size()
	var results: Array = []
	for idx in range(total_pairs):
		var p: Dictionary = pairs[idx]
		print("running test %d/%d" % [idx + 1, total_pairs])
		var ai: int = int(p.ai)
		var bi: int = int(p.bi)
		var a: Dictionary = units[ai]
		var b: Dictionary = units[bi]
		var mr := MatchResult.new()
		mr.a_id = String(a.id)
		mr.b_id = String(b.id)
		# Attach unit metadata for analytics/aggregation
		mr.a_roles = a.roles.duplicate()
		mr.b_roles = b.roles.duplicate()
		mr.a_primary_role = String(a.primary_role)
		mr.b_primary_role = String(b.primary_role)
		mr.a_primary_goal = String(a.primary_goal)
		mr.b_primary_goal = String(b.primary_goal)
		mr.a_approaches = _duplicate_string_array(a.approaches)
		mr.b_approaches = _duplicate_string_array(b.approaches)
		mr.a_cost = int(a.cost)
		mr.b_cost = int(b.cost)
		mr.a_level = int(a.level)
		mr.b_level = int(b.level)
		for _r in range(repeats):
			_simulate_pair(mr, a.id, b.id, 0.05, timeout_s, abilities_enabled, ability_metrics)
			_simulate_pair(mr, b.id, a.id, 0.05, timeout_s, abilities_enabled, ability_metrics)
		results.append(mr)
	_write_csv(out_path, results, ability_metrics)
	_print_human_summary(results)
	print("BalanceRunner: wrote identity_v2 matrix to %s (see docs/balance_runner_schema.md)" % out_path)

class MatchResult:
	var a_id: String
	var b_id: String
	var a_roles: Array[String] = []
	var b_roles: Array[String] = []
	var a_primary_role: String = ""
	var b_primary_role: String = ""
	var a_primary_goal: String = ""
	var b_primary_goal: String = ""
	var a_approaches: Array[String] = []
	var b_approaches: Array[String] = []
	var a_cost: int = 0
	var b_cost: int = 0
	var a_level: int = 1
	var b_level: int = 1
	var a_wins: int = 0
	var b_wins: int = 0
	var draws: int = 0
	var shots: int = 0
	var a_shots: int = 0
	var b_shots: int = 0
	var casts_sum: int = 0
	var first_cast_time_sum: float = 0.0
	var first_cast_samples: int = 0
	var a_casts_sum: int = 0
	var b_casts_sum: int = 0
	var a_first_cast_time_sum: float = 0.0
	var b_first_cast_time_sum: float = 0.0
	var a_first_cast_samples: int = 0
	var b_first_cast_samples: int = 0
	var a_time_sum: float = 0.0
	var b_time_sum: float = 0.0
	var a_hp_sum: int = 0
	var b_hp_sum: int = 0
	# Per-side totals for analytics
	var a_damage_sum: int = 0
	var b_damage_sum: int = 0
	var a_heal_total: int = 0
	var b_heal_total: int = 0
	var a_absorb_total: int = 0
	var b_absorb_total: int = 0
	var a_mitigated_total: int = 0
	var b_mitigated_total: int = 0
	var a_overkill_total: int = 0
	var b_overkill_total: int = 0
	var a_phys_total: int = 0
	var b_phys_total: int = 0
	var a_mag_total: int = 0
	var b_mag_total: int = 0
	var a_true_total: int = 0
	var b_true_total: int = 0
	# First-hit timing per side
	var a_first_hit_time_sum: float = 0.0
	var b_first_hit_time_sum: float = 0.0
	var a_first_hit_samples: int = 0
	var b_first_hit_samples: int = 0
	var total: int = 0

	static func _join_identity_list(values: Array[String]) -> String:
		var tokens := PackedStringArray()
		for v in values:
			var token := String(v).strip_edges()
			if token != "":
				tokens.append(token)
		var joined := ""
		for i in range(tokens.size()):
			if i > 0:
				joined += "|"
			joined += tokens[i]
		return joined

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
		var a_roles_s := ""
		for i in range(a_roles.size()):
			if i > 0:
				a_roles_s += "|"
			a_roles_s += String(a_roles[i])
		var b_roles_s := ""
		for j in range(b_roles.size()):
			if j > 0:
				b_roles_s += "|"
			b_roles_s += String(b_roles[j])
		var a_approach_s: String = MatchResult._join_identity_list(a_approaches)
		var b_approach_s: String = MatchResult._join_identity_list(b_approaches)
		return {
			"a": a_id,
			"b": b_id,
			"a_roles": a_roles_s,
			"b_roles": b_roles_s,
			"a_primary_role": a_primary_role,
			"b_primary_role": b_primary_role,
			"a_primary_goal": a_primary_goal,
			"b_primary_goal": b_primary_goal,
			"a_approaches": a_approach_s,
			"b_approaches": b_approach_s,
			"a_cost": a_cost,
			"b_cost": b_cost,
			"a_level": a_level,
			"b_level": b_level,
			"a_win_pct": (float(a_wins) / max(1, total)),
			"b_win_pct": (float(b_wins) / max(1, total)),
			"draw_pct": (float(draws) / max(1, total)),
			"a_avg_time": (a_time_sum / max(1, a_wins)),
			"b_avg_time": (b_time_sum / max(1, b_wins)),
			"a_avg_hp": int(round(float(a_hp_sum) / max(1, a_wins))),
			"b_avg_hp": int(round(float(b_hp_sum) / max(1, b_wins))),
			"matches_total": total,
			"shots": shots,
			"a_shots": a_shots,
			"b_shots": b_shots,
			"a_avg_damage": float(a_damage_sum) / max(1, total),
			"b_avg_damage": float(b_damage_sum) / max(1, total),
			"a_heal_total": a_heal_total,
			"b_heal_total": b_heal_total,
			"a_absorbed": a_absorb_total,
			"b_absorbed": b_absorb_total,
			"a_mitigated": a_mitigated_total,
			"b_mitigated": b_mitigated_total,
			"a_overkill": a_overkill_total,
			"b_overkill": b_overkill_total,
			"a_phys": a_phys_total,
			"b_phys": b_phys_total,
			"a_mag": a_mag_total,
			"b_mag": b_mag_total,
			"a_true": a_true_total,
			"b_true": b_true_total,
			"a_first_hit_s": a_first_hit_time_sum / max(1, a_first_hit_samples),
			"b_first_hit_s": b_first_hit_time_sum / max(1, b_first_hit_samples),
			"a_avg_casts": float(a_casts_sum) / max(1, total),
			"b_avg_casts": float(b_casts_sum) / max(1, total),
			"a_first_cast_s": a_first_cast_time_sum / max(1, a_first_cast_samples),
			"b_first_cast_s": b_first_cast_time_sum / max(1, b_first_cast_samples),
		}

func _run() -> void:
	print("BalanceRunner: starting. argv=", OS.get_cmdline_args())
	var args := _parse_args(OS.get_cmdline_args())
	UnitFactory.role_invariant_fail_fast = true
	# If no CLI args, use editor properties for convenience when running the scene from Godot.
	if args.size() == 0 and bool(use_editor_params):
		_run_from_properties()
		return
	var repeats: int = int(args.get("repeats", 10))
	var timeout_s: float = float(args.get("timeout", 120.0))
	var abilities_flag_str: String = String(args.get("abilities", "false"))
	var abilities_enabled: bool = _parse_bool(abilities_flag_str)
	var metrics_flag_str: String = String(args.get("ability_metrics", "false"))
	var ability_metrics: bool = _parse_bool(metrics_flag_str)
	# Optional filters
	var ids_filter_str: String = String(args.get("ids", ""))
	var id_pairs: Array = _parse_id_pairs(ids_filter_str)
	# Default to the repo folder; we'll resolve to an OS path so it works headless.
	var out_path: String = String(args.get("out", "user://balance_matrix.csv"))
	var role_filter: PackedStringArray = _split_csv(String(args.get("role", "")))
	var goal_filter: PackedStringArray = _split_csv(String(args.get("goal", "")))
	var cost_filter: PackedInt32Array = _csv_to_ints(String(args.get("cost", "")))

	var units: Array[Dictionary] = _collect_units(role_filter, goal_filter, cost_filter)
	if units.size() < 2:
		var cost_strs: PackedStringArray = []
		for v in cost_filter:
			cost_strs.append(str(v))
		var goal_strs: PackedStringArray = []
		for g in goal_filter:
			goal_strs.append(String(g))
		var msg := "BalanceRunner: not enough units after filtering. role=%s goal=%s cost=%s" % [
			_join_strings(role_filter, ","), _join_strings(goal_strs, ","), _join_strings(cost_strs, ",")
		]
		push_warning(msg)
	var results: Array = []
	var pairs_cli: Array[Dictionary] = _enumerate_pairs(units, id_pairs)
	var total_pairs_cli: int = pairs_cli.size()
	for idx2 in range(total_pairs_cli):
		var p2: Dictionary = pairs_cli[idx2]
		print("running test %d/%d" % [idx2 + 1, total_pairs_cli])
		var ai2: int = int(p2.ai)
		var bi2: int = int(p2.bi)
		var a2: Dictionary = units[ai2]
		var b2: Dictionary = units[bi2]
		var mr2 := MatchResult.new()
		mr2.a_id = String(a2.id)
		mr2.b_id = String(b2.id)
		# Attach unit metadata for analytics/aggregation
		mr2.a_roles = a2.roles.duplicate()
		mr2.b_roles = b2.roles.duplicate()
		mr2.a_primary_role = String(a2.primary_role)
		mr2.b_primary_role = String(b2.primary_role)
		mr2.a_primary_goal = String(a2.primary_goal)
		mr2.b_primary_goal = String(b2.primary_goal)
		mr2.a_approaches = _duplicate_string_array(a2.approaches)
		mr2.b_approaches = _duplicate_string_array(b2.approaches)
		mr2.a_cost = int(a2.cost)
		mr2.b_cost = int(b2.cost)
		mr2.a_level = int(a2.level)
		mr2.b_level = int(b2.level)
		for _r2 in range(repeats):
			_simulate_pair(mr2, a2.id, b2.id, 0.05, timeout_s, abilities_enabled, ability_metrics)
			_simulate_pair(mr2, b2.id, a2.id, 0.05, timeout_s, abilities_enabled, ability_metrics)
		results.append(mr2)
	_write_csv(out_path, results, ability_metrics)
	_print_human_summary(results)
	print("BalanceRunner: wrote identity_v2 matrix to %s (see docs/balance_runner_schema.md)" % out_path)
	if get_tree():
		get_tree().quit()

func _simulate_pair(mr: MatchResult, player_id: String, enemy_id: String, delta: float, timeout_s: float, abilities_enabled: bool, ability_metrics: bool) -> void:
	var uA: Unit = UnitFactory.spawn(player_id)
	var uB: Unit = UnitFactory.spawn(enemy_id)
	if uA == null or uB == null:
		return
	# Optional: role invariant checks (fail-fast during BalanceRunner runs)
	var vA: Array = UnitFactory.validate_role_invariants(uA)
	var vB: Array = UnitFactory.validate_role_invariants(uB)
	if vA.size() > 0 or vB.size() > 0:
		for msg in vA:
			printerr("Invariant violation for ", player_id, ": ", String(msg))
		for msg2 in vB:
			printerr("Invariant violation for ", enemy_id, ": ", String(msg2))
		if bool(UnitFactory.role_invariant_fail_fast):
			return
	var state: BattleState = BattleState.new()
	state.stage = 1
	state.player_team.append(uA)
	state.enemy_team.append(uB)

	var engine: CombatEngine = CombatEngine.new()
	engine.abilities_enabled = abilities_enabled
	engine.deterministic_rolls = false
	engine.configure(state, uA, 1, Callable())
	# Place units with a small separation so first-hit timings reflect approach/kiting
	# Bounds centered on origin: 4x4 area spanning (-2,-2) to (2,2)
	engine.set_arena(1.0, [Vector2(-1, 0)], [Vector2(1, 0)], Rect2(Vector2(-2, -2), Vector2(4, 4)))
	var debug_hit_prints := 0
	# Time accumulator declared early so signal closures can reference it safely
	var t: float = 0.0
	# Map engine team labels to logical A/B for this simulation
	var player_is_a := (player_id == mr.a_id)
	# Use a small ref dict for per-sim one-time flags (mutable in lambdas)
	var rec := {"a_first_hit": false, "b_first_hit": false}

	# Inline connects; engine is new per sim so no duplicate risk
	engine.projectile_fired.connect(func(team: String, sidx: int, tidx: int, dmg: int, crit: bool):
		engine.on_projectile_hit(team, sidx, tidx, dmg, crit)
	)
	engine.hit_applied.connect(func(team: String, sidx: int, tidx: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, p_cd: float, e_cd: float):
			mr.shots += 1
			var is_a_source := ((team == "player") and player_is_a) or ((team == "enemy") and (not player_is_a))
			var eff_dealt := int(dealt)
			if eff_dealt <= 0:
				var d_from_hp := int(max(0, int(before_hp) - int(after_hp)))
				eff_dealt = d_from_hp
			if is_a_source:
				mr.a_shots += 1
				mr.a_damage_sum += eff_dealt
				if not rec["a_first_hit"]:
					mr.a_first_hit_time_sum += t
					mr.a_first_hit_samples += 1
					rec["a_first_hit"] = true
			else:
				mr.b_shots += 1
				mr.b_damage_sum += eff_dealt
				if not rec["b_first_hit"]:
					mr.b_first_hit_time_sum += t
					mr.b_first_hit_samples += 1
					rec["b_first_hit"] = true
			if debug_hit_prints < 20:
				debug_hit_prints += 1
	)
	# Additional analytics signals
	if engine.has_signal("heal_applied"):
		engine.heal_applied.connect(func(source_team: String, _source_index: int, _target_team: String, _target_index: int, healed: int, _overheal: int, _before_hp: int, _after_hp: int):
			var is_a_source := ((source_team == "player") and player_is_a) or ((source_team == "enemy") and (not player_is_a))
			if is_a_source:
				mr.a_heal_total += int(healed)
			else:
				mr.b_heal_total += int(healed)
		)
	if engine.has_signal("shield_absorbed"):
		engine.shield_absorbed.connect(func(target_team: String, _target_index: int, absorbed: int):
			var is_a_target := ((target_team == "player") and player_is_a) or ((target_team == "enemy") and (not player_is_a))
			if is_a_target:
				mr.a_absorb_total += int(absorbed)
			else:
				mr.b_absorb_total += int(absorbed)
		)
	if engine.has_signal("hit_mitigated"):
		engine.hit_mitigated.connect(func(_source_team: String, _source_index: int, target_team: String, _target_index: int, pre_mit: int, _post_pre_shield: int):
			var is_a_target := ((target_team == "player") and player_is_a) or ((target_team == "enemy") and (not player_is_a))
			if is_a_target:
				mr.a_mitigated_total += int(pre_mit)
			else:
				mr.b_mitigated_total += int(pre_mit)
		)
	if engine.has_signal("hit_overkill"):
		engine.hit_overkill.connect(func(source_team: String, _source_index: int, _target_team: String, _target_index: int, overkill: int):
			var is_a_source := ((source_team == "player") and player_is_a) or ((source_team == "enemy") and (not player_is_a))
			if is_a_source:
				mr.a_overkill_total += int(overkill)
			else:
				mr.b_overkill_total += int(overkill)
		)
	if engine.has_signal("hit_components"):
		engine.hit_components.connect(func(source_team: String, _source_index: int, _target_team: String, _target_index: int, phys: int, mag: int, tru: int):
			var is_a_source := ((source_team == "player") and player_is_a) or ((source_team == "enemy") and (not player_is_a))
			if is_a_source:
				mr.a_phys_total += int(phys)
				mr.a_mag_total += int(mag)
				mr.a_true_total += int(tru)
			else:
				mr.b_phys_total += int(phys)
				mr.b_mag_total += int(mag)
				mr.b_true_total += int(tru)
		)

	var outcome: String = ""
	_signal_outcome = ""
	if not engine.is_connected("victory", Callable(self, "_on_engine_outcome_v")):
		engine.victory.connect(Callable(self, "_on_engine_outcome_v"))
	if not engine.is_connected("defeat", Callable(self, "_on_engine_outcome_d")):
		engine.defeat.connect(Callable(self, "_on_engine_outcome_d"))

	# Ability analytics (optional)
	var casts_player := 0
	var casts_enemy := 0
	var first_cast_time_player := -1.0
	var first_cast_time_enemy := -1.0
	# Per-frame sampling to detect casts via mana reset (robust regardless of signals)
	var last_mana_player := int(uA.mana)
	var last_mana_enemy := int(uB.mana)
	engine.start()
	while outcome == "" and t < timeout_s:
		engine.process(delta)
		# Detect mana resets to 0 as casts (covers attack-based gain and regen autocast)
		if abilities_enabled and ability_metrics:
			if last_mana_player > 0 and int(uA.mana) == 0:
				casts_player += 1
				if first_cast_time_player < 0.0:
					first_cast_time_player = t
			if last_mana_enemy > 0 and int(uB.mana) == 0:
				casts_enemy += 1
				if first_cast_time_enemy < 0.0:
					first_cast_time_enemy = t
			last_mana_player = int(uA.mana)
			last_mana_enemy = int(uB.mana)
		t += delta
		if _signal_outcome != "":
			outcome = _signal_outcome

	var winner_id := "draw"
	# Map final HPs to logical a/b (mr.a_id/mr.b_id), not player/enemy order.
	# When we simulate with sides swapped, uA/uB are player/enemy, so
	# compute a_hp/b_hp by comparing the current player_id to mr.a_id/mr.b_id.
	var a_hp: int
	var b_hp: int
	if player_id == mr.a_id:
		a_hp = int(uA.hp)
		b_hp = int(uB.hp)
	else:
		a_hp = int(uB.hp)
		b_hp = int(uA.hp)
	if outcome == "victory":
		winner_id = player_id
	elif outcome == "defeat":
		winner_id = enemy_id

	mr.add_win(winner_id, t, a_hp, b_hp)
	# Per-side ability metrics aggregation
	if abilities_enabled and ability_metrics:
		if player_is_a:
			mr.a_casts_sum += casts_player
			mr.b_casts_sum += casts_enemy
			if first_cast_time_player >= 0.0:
				mr.a_first_cast_time_sum += first_cast_time_player
				mr.a_first_cast_samples += 1
			if first_cast_time_enemy >= 0.0:
				mr.b_first_cast_time_sum += first_cast_time_enemy
				mr.b_first_cast_samples += 1
		else:
			mr.a_casts_sum += casts_enemy
			mr.b_casts_sum += casts_player
			if first_cast_time_enemy >= 0.0:
				mr.a_first_cast_time_sum += first_cast_time_enemy
				mr.a_first_cast_samples += 1
			if first_cast_time_player >= 0.0:
				mr.b_first_cast_time_sum += first_cast_time_player
				mr.b_first_cast_samples += 1

func _write_csv(path: String, results: Array, ability_metrics: bool) -> void:
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa == null:
		var emsg := "BalanceRunner: cannot write %s" % path
		push_warning(emsg)
		printerr(emsg)
		return
	var header := "schema_version,attacker_id,defender_id,attacker_primary_role,defender_primary_role,attacker_primary_goal,defender_primary_goal,attacker_approaches,defender_approaches,attacker_cost,defender_cost,attacker_level,defender_level,attacker_win_pct,defender_win_pct,draw_pct,attacker_avg_time_to_win_s,defender_avg_time_to_win_s,attacker_avg_remaining_hp,defender_avg_remaining_hp,matches_total,hit_events_total,attacker_hit_events,defender_hit_events,attacker_avg_damage_dealt_per_match,defender_avg_damage_dealt_per_match,attacker_healing_total,defender_healing_total,attacker_shield_absorbed_total,defender_shield_absorbed_total,attacker_damage_mitigated_total,defender_damage_mitigated_total,attacker_overkill_total,defender_overkill_total,attacker_damage_physical_total,defender_damage_physical_total,attacker_damage_magic_total,defender_damage_magic_total,attacker_damage_true_total,defender_damage_true_total,attacker_time_to_first_hit_s,defender_time_to_first_hit_s"
	if ability_metrics:
		header += ",attacker_avg_casts_per_match,defender_avg_casts_per_match,attacker_first_cast_time_s,defender_first_cast_time_s"
	fa.store_line(header)
	for mr: MatchResult in results:
		var s := mr.summary()
		var cols: Array[String] = []
		cols.append(CSV_SCHEMA_VERSION)
		cols.append(String(s.a))
		cols.append(String(s.b))
		cols.append(String(s.a_primary_role))
		cols.append(String(s.b_primary_role))
		cols.append(String(s.a_primary_goal))
		cols.append(String(s.b_primary_goal))
		cols.append(String(s.a_approaches))
		cols.append(String(s.b_approaches))
		cols.append(str(int(s.a_cost)))
		cols.append(str(int(s.b_cost)))
		cols.append(str(int(s.a_level)))
		cols.append(str(int(s.b_level)))
		cols.append("%.3f" % float(s.a_win_pct))
		cols.append("%.3f" % float(s.b_win_pct))
		cols.append("%.3f" % float(s.draw_pct))
		cols.append("%.2f" % float(s.a_avg_time))
		cols.append("%.2f" % float(s.b_avg_time))
		cols.append(str(int(s.a_avg_hp)))
		cols.append(str(int(s.b_avg_hp)))
		cols.append(str(int(s.matches_total)))
		cols.append(str(int(s.shots)))
		cols.append(str(int(s.a_shots)))
		cols.append(str(int(s.b_shots)))
		cols.append("%.2f" % float(s.a_avg_damage))
		cols.append("%.2f" % float(s.b_avg_damage))
		cols.append(str(int(s.a_heal_total)))
		cols.append(str(int(s.b_heal_total)))
		cols.append(str(int(s.a_absorbed)))
		cols.append(str(int(s.b_absorbed)))
		cols.append(str(int(s.a_mitigated)))
		cols.append(str(int(s.b_mitigated)))
		cols.append(str(int(s.a_overkill)))
		cols.append(str(int(s.b_overkill)))
		cols.append(str(int(s.a_phys)))
		cols.append(str(int(s.b_phys)))
		cols.append(str(int(s.a_mag)))
		cols.append(str(int(s.b_mag)))
		cols.append(str(int(s.a_true)))
		cols.append(str(int(s.b_true)))
		cols.append("%.2f" % float(s.a_first_hit_s))
		cols.append("%.2f" % float(s.b_first_hit_s))
		if ability_metrics:
			cols.append("%.2f" % float(s.a_avg_casts))
			cols.append("%.2f" % float(s.b_avg_casts))
			cols.append("%.2f" % float(s.a_first_cast_s))
			cols.append("%.2f" % float(s.b_first_cast_s))
		var psa := PackedStringArray()
		for c in cols:
			psa.append(String(c))
		fa.store_line(_join_strings(psa, ","))
	fa.close()
func _collect_units(role_filter: PackedStringArray, goal_filter: PackedStringArray, cost_filter: PackedInt32Array) -> Array:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open("res://data/units")
	if dir == null:
		return out
	var filtered_roles := PackedStringArray()
	for r in role_filter:
		filtered_roles.append(_normalize_role_id(r))
	var filtered_goals := PackedStringArray()
	for g in goal_filter:
		filtered_goals.append(_normalize_goal_id(g))
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
		var level := 1
		var primary_role := ""
		var primary_goal := ""
		var approaches_accum: Array[String] = []
		if res is UnitProfile:
			id = String(res.id)
			roles = res.roles.duplicate()
			cost = int(res.cost)
			level = int(res.level)
			primary_role = String(res.primary_role)
			primary_goal = String(res.primary_goal)
			approaches_accum = _duplicate_string_array(res.approaches)
			if res.identity != null:
				if primary_role == "":
					primary_role = String(res.identity.primary_role)
				if primary_goal == "":
					primary_goal = String(res.identity.primary_goal)
				approaches_accum = _merge_normalized_lists(approaches_accum, res.identity.approaches)
		elif res is UnitDef:
			id = String(res.id)
			roles = res.roles.duplicate()
			cost = int(res.cost)
			level = int(res.level)
			primary_role = String(res.primary_role)
			primary_goal = String(res.primary_goal)
			approaches_accum = _duplicate_string_array(res.approaches)
			if res.identity != null:
				if primary_role == "":
					primary_role = String(res.identity.primary_role)
				if primary_goal == "":
					primary_goal = String(res.identity.primary_goal)
				approaches_accum = _merge_normalized_lists(approaches_accum, res.identity.approaches)
		if id == "":
			continue
		var primary_role_norm := _normalize_role_id(primary_role)
		if primary_role_norm == "" and roles.size() > 0:
			primary_role_norm = _normalize_role_id(roles[0])
		if filtered_roles.size() > 0:
			var role_ok := filtered_roles.has(primary_role_norm)
			if not role_ok:
				for r_name in roles:
					if filtered_roles.has(_normalize_role_id(r_name)):
						role_ok = true
						break
			if not role_ok:
				continue
		var primary_goal_norm := _normalize_goal_id(primary_goal)
		if filtered_goals.size() > 0 and not filtered_goals.has(primary_goal_norm):
			continue
		if cost_filter.size() > 0 and not cost_filter.has(cost):
			continue
		var approaches_norm := _normalized_identity_list(approaches_accum)
		out.append({
			"id": id,
			"roles": roles,
			"cost": cost,
			"level": level,
			"primary_role": primary_role_norm,
			"primary_goal": primary_goal_norm,
			"approaches": approaches_norm
		})
	dir.list_dir_end()
	out.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return out
## Aggregated summary output removed; only the main matrix CSV is written.

## Sweep helpers removed (fixed delta only)

func _print_human_summary(results: Array) -> void:
	var fastest: Array = []
	for mr: MatchResult in results:
		var s := mr.summary()
		if mr.a_wins > 0:
			fastest.append({"pair": "%s vs %s" % [mr.a_id, mr.b_id], "winner": mr.a_id, "t": s.a_avg_time})
		if mr.b_wins > 0:
			fastest.append({"pair": "%s vs %s" % [mr.a_id, mr.b_id], "winner": mr.b_id, "t": s.b_avg_time})
	fastest.sort_custom(func(x, y): return float(x.t) < float(y.t))


	for i in range(min(15, fastest.size())):
		var r = fastest[i]


	var margins: Array = []
	for mr2: MatchResult in results:
		var s2 := mr2.summary()
		if mr2.a_wins > 0:
			margins.append({"pair": "%s vs %s" % [mr2.a_id, mr2.b_id], "winner": mr2.a_id, "hp": s2.a_avg_hp})
		if mr2.b_wins > 0:
			margins.append({"pair": "%s vs %s" % [mr2.a_id, mr2.b_id], "winner": mr2.b_id, "hp": s2.b_avg_hp})
	margins.sort_custom(func(x, y): return int(y.hp) - int(x.hp))


	for i2 in range(min(15, margins.size())):
		var r2 = margins[i2]

	results.sort_custom(func(m1: MatchResult, m2: MatchResult): return m1.a_id + m1.b_id < m2.a_id + m2.b_id)
	for k in range(min(20, results.size())):
		var mr3: MatchResult = results[k]
		var s3 := mr3.summary()

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


func _duplicate_string_array(source) -> Array[String]:
	var out: Array[String] = []
	if source == null:
		return out
	if source is PackedStringArray:
		for value in source:
			out.append(String(value))
	elif source is Array:
		for value in source:
			out.append(String(value))
	elif typeof(source) == TYPE_STRING:
		var single := String(source).strip_edges()
		if single != "":
			out.append(single)
	return out


func _normalize_role_id(value) -> String:
	var s := String(value).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

func _normalize_goal_id(value) -> String:
	return String(value).strip_edges().to_lower()

func _normalized_identity_list(values) -> Array[String]:
	return _merge_normalized_lists([], values)

func _merge_normalized_lists(base: Array[String], extra) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for entry in base:
		var norm := String(entry).strip_edges().to_lower()
		if norm == "" or seen.has(norm):
			continue
		seen[norm] = true
		out.append(norm)
	if extra == null:
		return out
	if extra is Array:
		for raw in extra:
			var norm2 := String(raw).strip_edges().to_lower()
			if norm2 == "" or seen.has(norm2):
				continue
			seen[norm2] = true
			out.append(norm2)
	elif extra is PackedStringArray:
		for raw in extra:
			var norm3 := String(raw).strip_edges().to_lower()
			if norm3 == "" or seen.has(norm3):
				continue
			seen[norm3] = true
			out.append(norm3)
	elif typeof(extra) == TYPE_STRING:
		var single := String(extra).strip_edges().to_lower()
		if single != "" and not seen.has(single):
			seen[single] = true
			out.append(single)
	return out

func _join_identity_list(values: Array[String]) -> String:
	var out := PackedStringArray()
	for v in values:
		var token := String(v).strip_edges()
		if token != "":
			out.append(token)
	return _join_strings(out, "|")

func _cluster_from_identity(primary_role: String, legacy_roles: Array[String]) -> String:
	var collected: Array[String] = []
	var norm := _normalize_role_id(primary_role)
	if norm != "":
		collected.append(norm)
	elif legacy_roles != null:
		for r in legacy_roles:
			collected.append(String(r))
	return UnitFactory.cluster_for_roles(collected)

func _join_strings(arr: PackedStringArray, sep: String) -> String:
	var s := ""
	for i in range(arr.size()):
		if i > 0:
			s += sep
		s += arr[i]
	return s

func _enumerate_pairs(units: Array[Dictionary], id_pairs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(units.size()):
		for j in range(i + 1, units.size()):
			var a: Dictionary = units[i]
			var b: Dictionary = units[j]
			if not _pair_allowed(String(a.id), String(b.id), id_pairs):
				continue
			out.append({"ai": i, "bi": j, "a": String(a.id), "b": String(b.id)})
	return out

func _parse_bool(s: String) -> bool:
	var v := s.strip_edges().to_lower()
	return v in ["1", "true", "yes", "y", "on"]

func _parse_id_pairs(s: String) -> Array:
	# Format: "a:b,c:d"
	var out: Array = []
	var src := String(s).strip_edges()
	if src == "":
		return out
	for tok in src.split(","):
		var t := String(tok).strip_edges()
		if t == "":
			continue
		var parts := t.split(":", false, 2)
		if parts.size() != 2:
			continue
		var a := String(parts[0]).strip_edges().to_lower()
		var b := String(parts[1]).strip_edges().to_lower()
		if a == "" or b == "":
			continue
		out.append({"a": a, "b": b})
	return out

func _pair_allowed(attacker_id: String, defender_id: String, pairs: Array) -> bool:
	if pairs == null or pairs.is_empty():
		return true
	var a := attacker_id.to_lower()
	var b := defender_id.to_lower()
	for p in pairs:
		if String(p.get("a", "")) == a and String(p.get("b", "")) == b:
			return true
	return false

# Delta sweep helpers removed per request; fixed delta 0.05 is used for all sims


func _on_engine_outcome_v(_stage: int) -> void:
	_signal_outcome = "victory"


func _on_engine_outcome_d(_stage: int) -> void:
	_signal_outcome = "defeat"
