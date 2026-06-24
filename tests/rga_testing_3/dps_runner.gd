extends Node

const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const DPSDummyCollector := preload("res://tests/rga_testing_3/dps_dummy_collector.gd")

@export_enum("dps","ehp","both") var mode: String = "dps"
@export var filter_unit_id: String = ""
@export var filter_role: String = "" # e.g., tank|marksman
@export var filter_cost: int = 0	# 0 = any
@export var horizon_s: float = 15.0
@export var outfile: String = "user://rga_testing_3_out.jsonl"

var _role_targets: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if mode != "dps":
		print("Washer3: EHP not implemented yet; running DPS only.")
	# Load role DPS targets (reuse rga2 fixture for simplicity)
	_role_targets = _load_role_targets("res://tests/rga2/fixtures/role_targets.json")
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
	var cat: RGAUnitCatalog = UnitCatalog.new()
	var all_ids: Array[String] = cat.list_unit_ids()
	var role_f: String = String(filter_role).strip_edges().to_lower()
	var cost_f: int = int(filter_cost)
	var unit_f: String = String(filter_unit_id).strip_edges()
	for uid in all_ids:
		if unit_f != "" and uid != unit_f:
			continue
		var u: Variant = UnitFactory.spawn(uid)
		if u == null:
			continue
		if role_f != "":
			var pr: String = String(u.get_primary_role()).strip_edges().to_lower()
			if pr != role_f:
				continue
		if cost_f > 0 and int(u.cost) != cost_f:
			continue
		out.append(uid)
	return out

func _run_dps(unit_id: String) -> void:
	var seed: int = 525600
	var job_autos: DataModels.SimJob = _make_job(unit_id, false, seed)
	var job_full: DataModels.SimJob = _make_job(unit_id, true, seed)
	var collector1: DPSDummyCollector = DPSDummyCollector.new()
	var sim: LockstepSimulator = LockstepSimulator.new()
	var out1: Dictionary = sim.run(job_autos, false, collector1)
	var dmg_a1: float = float(((out1.get("aggregates", {}) as Dictionary).get("teams", {}) as Dictionary).get("a", {}).get("damage", 0))
	var dps_autos: float = dmg_a1 / max(0.001, horizon_s)
	var collector2: DPSDummyCollector = DPSDummyCollector.new()
	var out2: Dictionary = sim.run(job_full, false, collector2)
	var dmg_a2: float = float(((out2.get("aggregates", {}) as Dictionary).get("teams", {}) as Dictionary).get("a", {}).get("damage", 0))
	var dps_total: float = dmg_a2 / max(0.001, horizon_s)
	var dps_abilities_and_effects: float = max(0.0, dps_total - dps_autos)
	# Compare to role target
	var role: String = _role_for(unit_id)
	var want: float = _role_target_dps(role)
	var pass_flag: bool = (want <= 0.0) or (_within_tol(dps_total, want, 0.05))
	var msg: String = "%s (role=%s) DPS: total=%.2f autos=%.2f abilities+fx=%.2f want=%.2f tol=5%% -> %s" % [unit_id, role, dps_total, dps_autos, dps_abilities_and_effects, want, ("PASS" if pass_flag else "FAIL")]
	if pass_flag:
		print(msg)
	else:
		printerr(msg)

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
	j.bridge_projectile_to_hit = false
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
	var u: Variant = UnitFactory.spawn(unit_id)
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
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if (parsed is Dictionary) else {}

func _within_tol(v: float, want: float, tol_frac: float) -> bool:
	if want <= 0.0:
		return true
	var diff: float = abs(v - want)
	return diff <= (abs(want) * max(0.0, tol_frac))

func _quit(code: int) -> void:
	if get_tree():
		get_tree().quit(code)
