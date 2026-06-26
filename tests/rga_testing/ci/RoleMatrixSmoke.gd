extends Node

const RoleMatrixProbe := preload("res://tests/rga_testing/validation/RoleMatrixProbe.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")
const UnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const RGASettings := preload("res://tests/rga_testing/settings.gd")

const REPRESENTATIVE_UNITS: Array[String] = ["korath", "bonko", "nyxa", "hexeon", "paisley", "axiom"] # 1 per role (tank,brawler,marksman,assassin,mage,support)

@export var units: PackedStringArray = PackedStringArray()
@export var run_all_units: bool = true
@export var scenario_packs_to_run: PackedStringArray = PackedStringArray() # empty = role-aware fast defaults
@export var opponents_per_pack: int = 1
@export var repeats: int = 1
@export var include_swapped: bool = false
@export var max_sims: int = 12

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var all_ok: bool = true
	var units_to_run: PackedStringArray = _units_to_run()
	if units_to_run.is_empty():
		printerr("RoleMatrixSmoke: no units resolved")
		get_tree().quit(1)
		return
	print("RoleMatrixSmoke: running ", units_to_run.size(), " units")
	for u in units_to_run:
		var uid: String = String(u)
		if uid.strip_edges() == "":
			continue
		_finished_for.erase(uid)
		var ident: Dictionary = _identity_for(uid)
		var role_id: String = String(ident.get("primary_role", "")).strip_edges().to_lower()
		var labels: PackedStringArray = _labels_for_unit(ident)
		var profile_name: String = _profile_for_unit(ident)
		var output_root: String = "user://rga_smoke/%s" % uid
		print("RoleMatrixSmoke: unit=", uid, " role=", role_id, " profile=", profile_name, " labels=", labels, " out=", output_root)
		var probe: Node = RoleMatrixProbe.new()
		add_child(probe)
		# Configure probe for quick, subject-relevant coverage.
		probe.set("subject_unit_id", uid)
		probe.set("quick_balance_mode", true)
		probe.set("quick_balance_seed_count", max(1, int(repeats)))
		probe.set("quick_balance_labels", labels)
		probe.set("write_reports", true)
		probe.set("out_root", output_root)
		probe.set("resume_if_exists", false)
		probe.set("repeats", repeats)
		probe.set("include_swapped", include_swapped if profile_name != "full_probe_6v6" else false)
		probe.set("max_opponents", opponents_per_pack)
		probe.set("scenario_packs_to_run", labels)
		probe.set("opponents_per_pack", opponents_per_pack)
		probe.set("max_sims", max_sims)
		probe.set("profile", profile_name)
		if profile_name == "full_probe_6v6":
			probe.set("scenario_labels_6v6", labels)
			probe.set("max_seeds_per_label", max(1, int(repeats)))
		probe.set("do_quit_on_finish", false)
		var finished: bool = false
		var report_path: String = ""
		probe.connect("finished", Callable(self, "_on_probe_finished"), CONNECT_ONE_SHOT)
		# Wait for finish by polling; this avoids relying on private methods.
		var t0: int = Time.get_ticks_msec()
		while not finished and (Time.get_ticks_msec() - t0) < 600000: # 10 min safety
			await get_tree().process_frame
			if _finished_for.has(uid):
				finished = true
				report_path = String(_finished_for[uid])
		var expect: String = report_path if report_path.strip_edges() != "" else ("user://identity_reports/" + uid + ".json")
		var exists: bool = FileAccess.file_exists(expect)
		if not exists:
			printerr("RoleMatrixSmoke: report missing for ", uid, " at ", expect)
			all_ok = false
		elif not _report_passed(expect, uid):
			printerr("RoleMatrixSmoke: report did not pass for ", uid, " at ", expect)
			all_ok = false
		if probe.get_parent():
			remove_child(probe)
		probe.queue_free()
	if all_ok:
		print("RoleMatrixSmoke: PASS (", units_to_run.size(), " units)")
		get_tree().quit(0)
	else:
		printerr("RoleMatrixSmoke: FAIL")
		get_tree().quit(1)

func _units_to_run() -> PackedStringArray:
	var explicit_units: PackedStringArray = _clean_units(units)
	if explicit_units.size() > 0:
		return explicit_units
	if not bool(run_all_units):
		var representative: PackedStringArray = PackedStringArray()
		for uid in REPRESENTATIVE_UNITS:
			representative.append(String(uid))
		return representative
	var cat: RGAUnitCatalog = UnitCatalog.new()
	var cfg: RGASettings = RGASettings.new()
	cfg.role_filter = []
	cfg.goal_filter = []
	cfg.approach_filter = []
	cfg.cost_filter = PackedInt32Array([])
	var entries: Array = cat.list(cfg)
	var out: PackedStringArray = PackedStringArray()
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var uid: String = String((entry as Dictionary).get("id", "")).strip_edges()
		if uid != "":
			out.append(uid)
	return out

func _clean_units(input_units: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for raw_unit in input_units:
		var uid: String = String(raw_unit).strip_edges()
		if uid != "":
			out.append(uid)
	return out

var _finished_for: Dictionary = {}
func _on_probe_finished(uid: String, report_path: String) -> void:
	_finished_for[uid] = String(report_path)

func _identity_for(uid: String) -> Dictionary:
	return RoleCommon.get_identity(uid)

func _labels_for_unit(ident: Dictionary) -> PackedStringArray:
	if scenario_packs_to_run.size() > 0:
		return scenario_packs_to_run
	var role_id: String = String(ident.get("primary_role", "")).strip_edges().to_lower()
	var goal_id: String = String(ident.get("primary_goal", "")).strip_edges().to_lower()
	var approaches: Array = ident.get("approaches", [])
	var wants_aoe_context: bool = _has_approach(approaches, "aoe") or goal_id == "mage.wombo_combo_burst"
	var labels: PackedStringArray = PackedStringArray()
	_add_label(labels, "neutral")
	if wants_aoe_context:
		_add_label(labels, "clustered")
		_add_label(labels, "clustered_alt")
	if role_id == "support" or _has_approach(approaches, "peel") or _has_approach(approaches, "cc_immunity") or goal_id == "support.peel_carry":
		_add_label(labels, "peel")
	if goal_id == "support.peel_carry":
		_add_label(labels, "threat")
	if _has_approach(approaches, "debuff") or _has_approach(approaches, "lockdown") or goal_id.find("lockdown") >= 0:
		_add_label(labels, "counterplay")
	if goal_id == "tank.initiate_fight" or _has_approach(approaches, "engage"):
		_add_label(labels, "engage")
	if goal_id == "tank.team_fortification":
		_add_label(labels, "fortify")
	if role_id == "assassin" or _has_approach(approaches, "access_backline") or goal_id == "brawler.skirmish_dive":
		_add_label(labels, "counter")
	if role_id == "marksman" or _has_approach(approaches, "long_range"):
		_add_label(labels, "kite")
	if _has_approach(approaches, "burst") or _has_approach(approaches, "execute") or goal_id in ["mage.pick_burst", "mage.wombo_combo_burst"]:
		_add_label(labels, "burst")
	if _has_approach(approaches, "disrupt") or _has_approach(approaches, "lockdown") or _has_approach(approaches, "aoe") or goal_id in ["brawler.frontline_disruption", "tank.single_target_lockdown", "mage.pick_burst"]:
		_add_label(labels, "peel")
	if _has_approach(approaches, "sustain") or _has_approach(approaches, "damage_reduction"):
		_add_label(labels, "burst")
	var label_cap: int = 5 if wants_aoe_context else 3
	if goal_id == "tank.team_fortification":
		label_cap = 4
	elif goal_id == "tank.initiate_fight" or _has_approach(approaches, "engage"):
		label_cap = 4
	if labels.size() > label_cap:
		return _label_cap(labels, label_cap, goal_id == "mage.pick_burst")
	if labels.size() > 0:
		return labels
	match String(role_id):
		"assassin":
			return PackedStringArray(["counter"])
		"support":
			return PackedStringArray(["peel"])
		"marksman":
			return PackedStringArray(["neutral"])
		"mage":
			return PackedStringArray(["neutral"])
		_:
			return PackedStringArray(["neutral"])

func _profile_for_unit(ident: Dictionary) -> String:
	var role_id: String = String(ident.get("primary_role", "")).strip_edges().to_lower()
	var goal_id: String = String(ident.get("primary_goal", "")).strip_edges().to_lower()
	var approaches: Array = ident.get("approaches", [])
	if _needs_multi_unit_context(role_id, goal_id, approaches):
		return "full_probe_6v6"
	match String(role_id):
		"marksman", "assassin", "mage", "support":
			return "full_probe_6v6"
		_:
			return "quick_probe"

func _needs_multi_unit_context(role_id: String, goal_id: String, approaches: Array) -> bool:
	if String(role_id) in ["marksman", "assassin", "mage", "support"]:
		return true
	if String(goal_id) in ["brawler.frontline_disruption", "brawler.skirmish_dive", "tank.team_fortification"]:
		return true
	for raw_approach in approaches:
		var approach_id: String = String(raw_approach).strip_edges().to_lower()
		if approach_id in ["access_backline", "amp", "aoe", "cc_immunity", "peel", "zone"]:
			return true
	return false

func _has_approach(approaches: Array, approach_id: String) -> bool:
	var wanted: String = String(approach_id).strip_edges().to_lower()
	for raw_approach in approaches:
		if String(raw_approach).strip_edges().to_lower() == wanted:
			return true
	return false

func _add_label(labels: PackedStringArray, label: String) -> void:
	var normalized: String = String(label).strip_edges().to_lower()
	if normalized == "":
		return
	for existing in labels:
		if String(existing) == normalized:
			return
	labels.append(normalized)

func _label_cap(labels: PackedStringArray, cap: int, prioritize_burst: bool = false) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var preferred: Array[String] = ["neutral", "clustered", "clustered_alt", "counterplay", "engage", "fortify", "peel", "threat", "burst", "counter", "kite"]
	if prioritize_burst:
		preferred = ["neutral", "clustered", "clustered_alt", "counterplay", "burst", "engage", "fortify", "peel", "threat", "counter", "kite"]
	for label in preferred:
		if out.size() >= cap:
			break
		for existing in labels:
			if String(existing) == label:
				out.append(label)
				break
	if out.size() >= cap:
		return out
	for extra in labels:
		if out.size() >= cap:
			break
		_add_label(out, String(extra))
	return out

func _report_passed(path: String, uid: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		printerr("RoleMatrixSmoke: invalid report JSON for ", uid)
		return false
	var report: Dictionary = parsed
	var assigned: Dictionary = report.get("assigned_identity", {})
	var role_id: String = String(assigned.get("primary_role", "")).strip_edges().to_lower()
	if role_id == "":
		printerr("RoleMatrixSmoke: report missing primary_role for ", uid)
		return false
	var goal_id: String = String(assigned.get("primary_goal", "")).strip_edges().to_lower()
	if goal_id == "":
		printerr("RoleMatrixSmoke: report missing primary_goal for ", uid)
		return false
	var approaches: Array = assigned.get("approaches", [])
	if not (approaches is Array) or approaches.is_empty():
		printerr("RoleMatrixSmoke: report missing approaches for ", uid)
		return false
	var verdicts: Dictionary = report.get("verdicts", {})
	var roles: Dictionary = verdicts.get("roles", {}) if (verdicts is Dictionary) else {}
	if not _verdicts_pass(uid, "role", roles, PackedStringArray([role_id]), false):
		return false
	var goals: Dictionary = verdicts.get("goals", {}) if (verdicts is Dictionary) else {}
	if not _verdicts_pass(uid, "goal", goals, PackedStringArray([goal_id]), true):
		return false
	var required_approaches: PackedStringArray = PackedStringArray()
	for raw_approach in approaches:
		var approach_id: String = String(raw_approach).strip_edges().to_lower()
		if approach_id != "":
			required_approaches.append(approach_id)
	var approach_verdicts: Dictionary = verdicts.get("approaches", {}) if (verdicts is Dictionary) else {}
	if not _verdicts_pass(uid, "approach", approach_verdicts, required_approaches, false):
		return false
	return true

func _verdicts_pass(uid: String, block_name: String, block: Dictionary, required_ids: PackedStringArray, allow_proxy_pass: bool) -> bool:
	var all_ok: bool = true
	for required_id in required_ids:
		var key: String = String(required_id).strip_edges().to_lower()
		if key == "":
			continue
		if not (block is Dictionary) or not block.has(key):
			printerr("RoleMatrixSmoke: ", uid, " missing ", block_name, " verdict for ", key)
			all_ok = false
			continue
		var verdict: Dictionary = block.get(key, {})
		var status: String = String(verdict.get("status", "FAIL")).strip_edges().to_upper()
		var passed: bool = status == "PASS" or (allow_proxy_pass and status == "PROXY_PASS")
		if not passed:
			printerr("RoleMatrixSmoke: ", uid, " ", block_name, "=", key, " status=", status)
			all_ok = false
	return all_ok
