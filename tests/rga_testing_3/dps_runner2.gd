extends Node

const UnitFactory := preload("res://scripts/unit_factory.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const CombatStatsCollector := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")

# Collector that also converts the enemy side into inert high-HP dummies.
class DPSDummyApplier:
	extends RefCounted

	var make_dummies: bool = true
	var dummy_hp: int = 1000000

	var _engine
	var _state
	var _base: CombatStatsCollector = null

	func attach(engine, state, _player_is_team_a: bool = true) -> void:
		_engine = engine
		_state = state
		# Wrap base aggregates so we actually track damage/heal/shield totals
		_base = CombatStatsCollector.new()
		if _base != null and _base.has_method("attach"):
			_base.attach(engine, state, _player_is_team_a)
		if make_dummies:
			_setup_dummies()

	func detach() -> void:
		if _base != null and _base.has_method("detach"):
			_base.detach()
		_engine = null
		_state = null

	func tick(_delta_s: float) -> void:
		if _base != null and _base.has_method("tick"):
			_base.tick(_delta_s)

	func finalize(_total_time_s: float) -> void:
		if _base != null and _base.has_method("finalize"):
			_base.finalize(_total_time_s)

	func result() -> Dictionary:
		if _base != null and _base.has_method("result"):
			return _base.result()
		return {}

	func _setup_dummies() -> void:
		if _engine == null or _state == null:
			return
		var bs = null
		if _engine != null:
			bs = _engine.buff_system
		if bs == null:
			return
		# Configure every enemy as an inert sponge with no mitigation.
		for idx in range(_state.enemy_team.size()):
			var u = _state.enemy_team[idx]
			if u == null:
				continue
			var fields: Dictionary = {}
			fields["attack_damage"] = -float(u.attack_damage)
			fields["armor"] = -float(u.armor)
			fields["magic_resist"] = -float(u.magic_resist)
			fields["damage_reduction"] = -float(u.damage_reduction)
			fields["damage_reduction_flat"] = -float(u.damage_reduction_flat)
			fields["max_hp"] = float(max(0, int(dummy_hp) - int(u.max_hp)))
			bs.apply_stats_buff(_state, "enemy", idx, fields, 1000.0)
			u.max_hp = max(int(u.max_hp), int(dummy_hp))
			u.hp = u.max_hp

@export_enum("dps","ehp","both") var mode: String = "dps"
@export var filter_unit_id: String = ""
@export var filter_role: String = ""
@export var filter_cost: int = 0
@export var horizon_s: float = 15.0
@export var outfile: String = "user://rga_testing_3_out.jsonl"

var _role_targets: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if mode != "dps":
		print("Washer3: EHP not implemented yet; running DPS only.")
	_role_targets = _load_role_targets("res://tests/rga2/fixtures/role_targets.json")
	# Truncate output file at start of run
	_reset_outfile()
	var ids: Array[String] = _resolve_units()
	if ids.is_empty():
		printerr("Washer3: no units matched filters")
		_quit(1)
		return
	for uid in ids:
		_run_dps(uid)
	_quit(0)

func _resolve_units() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/units")
	if dir == null:
		return out
	dir.list_dir_begin()
	var role_f: String = String(filter_role).strip_edges().to_lower()
	var cost_f: int = int(filter_cost)
	var unit_f: String = String(filter_unit_id).strip_edges()
	while true:
		var f: String = dir.get_next()
		if f == "":
			break
		if dir.current_is_dir() or not f.ends_with(".tres"):
			continue
		var path := "res://data/units/%s" % f
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			continue
		# Expect UnitProfile resource
		var uid: String = ""
		if res is Resource:
			uid = String(res.get("id"))
		if uid == "":
			continue
		if unit_f != "" and uid != unit_f:
			continue
		var u = UnitFactory.spawn(uid)
		if u == null:
			continue
		if role_f != "":
			var pr: String = String(u.get_primary_role()).strip_edges().to_lower()
			if pr != role_f:
				continue
		if cost_f > 0 and int(u.cost) != cost_f:
			continue
		out.append(uid)
	dir.list_dir_end()
	out.sort()
	return out

func _run_dps(unit_id: String) -> void:
	var seed: int = 525600
	var job_autos: DataModels.SimJob = _make_job(unit_id, false, seed)
	var job_full: DataModels.SimJob = _make_job(unit_id, true, seed)
	var sim: LockstepSimulator = LockstepSimulator.new()
	# Autos-only run (abilities disabled) with dummy collector for sponge enemies
	var col_autos: DPSDummyApplier = DPSDummyApplier.new()
	var out_autos: Dictionary = sim.run(job_autos, false, col_autos)
	var teams_a: Dictionary = ((out_autos.get("aggregates", {}) as Dictionary).get("teams", {}) as Dictionary)
	var dmg_autos: float = float(teams_a.get("a", {}).get("damage", 0))
	var dps_autos: float = dmg_autos / max(0.001, horizon_s)
	# Full run (abilities enabled) with dummy collector
	var col_full: DPSDummyApplier = DPSDummyApplier.new()
	var out_full: Dictionary = sim.run(job_full, false, col_full)
	var teams_full: Dictionary = ((out_full.get("aggregates", {}) as Dictionary).get("teams", {}) as Dictionary)
	var dmg_total: float = float(teams_full.get("a", {}).get("damage", 0))
	var dps_total: float = dmg_total / max(0.001, horizon_s)
	var dps_abilities_and_effects: float = max(0.0, dps_total - dps_autos)
	var role: String = _role_for(unit_id)
	var want: float = _role_target_dps(role)
	var pass_flag: bool = (want <= 0.0) or (_within_tol(dps_total, want, 0.05))
	var delta_dps: float = dps_total - want
	var pct_of_target: float = (100.0 if want <= 0.0 else (dps_total / max(0.0001, want) * 100.0))
	var msg: String = "%s [%s] %.2f dps vs %.2f (%.2f, %.1f%%) | autos %.2f | abil %.2f | dmg %.0f/%.0fs -> %s" % [
		unit_id, role, _r2(dps_total), _r2(want), _r2(delta_dps), _r2(pct_of_target), _r2(dps_autos), _r2(dps_abilities_and_effects), dmg_total, horizon_s, ("PASS" if pass_flag else "FAIL")
	]
	if pass_flag:
		print(msg)
	else:
		printerr(msg)
	# Emit NDJSON row with grouped fields and context
	var row: Dictionary = {
		"schema": "dps_v1",
		"context": {
			"run_id": "washer3_dps",
			"seed": seed,
			"horizon_s": float(horizon_s),
			"abilities": true
		},
		"subject": {
			"id": unit_id,
			"role": role
		},
		"results": {
			"damage": {
				"total": int(dmg_total),
				"autos": int(dmg_autos),
				"abilities_fx": int(max(0.0, dmg_total - dmg_autos))
			},
			"dps": {
				"total": _r2(dps_total),
				"autos": _r2(dps_autos),
				"abilities_fx": _r2(dps_abilities_and_effects)
			},
			"target": {
				"dps": _r2(want),
				"tolerance_pct": 5,
				"delta_dps": _r2(delta_dps),
				"pct_of_target": _r2(pct_of_target),
				"pass": pass_flag
			}
		},
		"timestamp": Time.get_datetime_string_from_system()
	}
	_write_jsonl(row)

func _make_job(unit_id: String, abilities_on: bool, seed: int) -> DataModels.SimJob:
	var j: DataModels.SimJob = DataModels.SimJob.new()
	j.run_id = "washer3_dps"
	j.sim_index = 0
	j.seed = seed
	j.team_a_ids = [unit_id]
	j.team_b_ids = ["dummy_inf","dummy_inf","dummy_inf","dummy_inf","dummy_inf","dummy_inf"]
	j.team_size = 1
	j.scenario_id = "open_field"
	j.map_params = {}
	j.deterministic = true
	j.delta_s = 0.05
	j.timeout_s = horizon_s
	j.abilities = abilities_on
	j.alternate_order = false
	# Bridge projectile->hit in headless runs so autos resolve without UI
	j.bridge_projectile_to_hit = true
	j.capabilities = PackedStringArray(["base"]) # aggregates only
	# Perf: accelerate when far apart
	j.metadata = {
		"perf_adaptive": true,
		"perf_fast_dt": 0.5,
		"perf_margin_tiles": 0.75,
		"perf_pos_emit_interval": 0.0,
		"perf_collision_iterations": 1,
		"perf_friendly_soft": false,
		"perf_avoidance_weight": 0.0
	}
	return j

func _role_for(unit_id: String) -> String:
	var u = UnitFactory.spawn(unit_id)
	if u == null:
		return ""
	return String(u.get_primary_role()).strip_edges().to_lower()

func _role_target_dps(role_id: String) -> float:
	var roles: Dictionary = _role_targets.get("roles", {})
	var cfg: Dictionary = roles.get(role_id, {})
	return float(cfg.get("sustained_dps_target", 0.0))

func _load_role_targets(path: String) -> Dictionary:
	var fa: FileAccess = FileAccess.open(path, FileAccess.READ)
	if fa == null:
		return {}
	var txt: String = fa.get_as_text()
	fa.close()
	var parsed = JSON.parse_string(txt)
	return parsed if (parsed is Dictionary) else {}

func _within_tol(v: float, want: float, tol_frac: float) -> bool:
	if want <= 0.0:
		return true
	var diff: float = abs(v - want)
	return diff <= (abs(want) * max(0.0, tol_frac))

func _write_jsonl(row: Dictionary) -> void:
	var line: String = JSON.stringify(row)
	var fa: FileAccess = FileAccess.open(outfile, FileAccess.READ_WRITE)
	if fa == null:
		# Try create if missing
		fa = FileAccess.open(outfile, FileAccess.WRITE)
	if fa != null:
		# Append to end (READ_WRITE path)
		fa.seek_end()
		fa.store_string(line + "\n")
		fa.flush()
		fa.close()

func _reset_outfile() -> void:
	# Truncate the output file for a clean run
	var fa: FileAccess = FileAccess.open(outfile, FileAccess.WRITE)
	if fa != null:
		fa.store_string("")
		fa.flush()
		fa.close()

func _r2(x: float) -> float:
	return float(round(x * 100.0)) / 100.0

func _quit(code: int) -> void:
	if get_tree():
		get_tree().quit(code)
