extends Node

const RoleMatrixProbe := preload("res://tests/rga_testing/validation/RoleMatrixProbe.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

@export var units: PackedStringArray = PackedStringArray(["korath","bonko","nyxa","hexeon","paisley","axiom"]) # 1 per role (tank,brawler,marksman,assassin,mage,support)
@export var scenario_packs_to_run: PackedStringArray = PackedStringArray() # empty = role-aware fast defaults
@export var opponents_per_pack: int = 1
@export var repeats: int = 1
@export var include_swapped: bool = false
@export var max_sims: int = 12

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var all_ok: bool = true
	for u in units:
		var uid: String = String(u)
		if uid.strip_edges() == "":
			continue
		_finished_for.erase(uid)
		var role_id: String = _role_for(uid)
		var labels: PackedStringArray = _labels_for_role(role_id)
		var profile_name: String = _profile_for_role(role_id)
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
		print("RoleMatrixSmoke: PASS (", units.size(), " units)")
		get_tree().quit(0)
	else:
		printerr("RoleMatrixSmoke: FAIL")
		get_tree().quit(1)

var _finished_for: Dictionary = {}
func _on_probe_finished(uid: String, report_path: String) -> void:
	_finished_for[uid] = String(report_path)

func _role_for(uid: String) -> String:
	var ident: Dictionary = RoleCommon.get_identity(uid)
	return String(ident.get("primary_role", "")).strip_edges().to_lower()

func _labels_for_role(role_id: String) -> PackedStringArray:
	if scenario_packs_to_run.size() > 0:
		return scenario_packs_to_run
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

func _profile_for_role(role_id: String) -> String:
	match String(role_id):
		"marksman", "assassin", "mage", "support":
			return "full_probe_6v6"
		_:
			return "quick_probe"

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
	var verdicts: Dictionary = report.get("verdicts", {})
	var roles: Dictionary = verdicts.get("roles", {}) if (verdicts is Dictionary) else {}
	var role_verdict: Dictionary = roles.get(role_id, {}) if (roles is Dictionary) else {}
	var status: String = String(role_verdict.get("status", "FAIL")).strip_edges().to_upper()
	if status != "PASS":
		printerr("RoleMatrixSmoke: ", uid, " role=", role_id, " status=", status)
		return false
	return true
