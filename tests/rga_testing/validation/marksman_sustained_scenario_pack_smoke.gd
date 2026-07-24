extends Node

const RoleMatrixSmokeScript := preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")
const RGARoleScenariosScript := preload("res://tests/rga_testing/config/role_scenarios.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var smoke: Node = RoleMatrixSmokeScript.new()
	var sari_identity: Dictionary[String, Variant] = {
		"primary_role": "marksman",
		"primary_goal": "marksman.sustained_dps",
		"approaches": ["long_range", "debuff", "ramp"]
	}
	var omenry_identity: Dictionary[String, Variant] = {
		"primary_role": "marksman",
		"primary_goal": "marksman.sustained_dps",
		"approaches": ["long_range", "burst", "aoe"]
	}
	var nyxa_identity: Dictionary[String, Variant] = {
		"primary_role": "marksman",
		"primary_goal": "marksman.backline_siege",
		"approaches": ["long_range", "ramp", "aoe"]
	}
	var sari_labels: PackedStringArray = smoke.call("_labels_for_unit", sari_identity)
	var omenry_labels: PackedStringArray = smoke.call("_labels_for_unit", omenry_identity)
	var nyxa_labels: PackedStringArray = smoke.call("_labels_for_unit", nyxa_identity)
	smoke.free()

	var marksman_packs: Array[Dictionary] = RGARoleScenariosScript.get_packs_for_role("marksman")
	var sustained_pack: Dictionary = _find_pack(marksman_packs, "sustained")
	var sustained_map: Dictionary = sustained_pack.get("map_params", {}) if sustained_pack.has("map_params") else {}
	var map_id: String = String(sustained_map.get("map_id", ""))
	var subject_lane: String = String(sustained_pack.get("subject_lane", ""))

	print("MarksmanSustainedScenarioPackSmoke: sari_labels=", Array(sari_labels),
		" omenry_labels=", Array(omenry_labels),
		" nyxa_labels=", Array(nyxa_labels),
		" sustained_map_id=", map_id)

	var failed: bool = false
	if sari_labels.size() != 4 or not _has_label(sari_labels, "sustained") or not _has_label(sari_labels, "kite") or not _has_label(sari_labels, "counterplay"):
		printerr("MarksmanSustainedScenarioPackSmoke: FAIL Sari-style sustained marksman should keep sustained, kite, and counterplay labels")
		failed = true
	if _has_label(sari_labels, "clustered"):
		printerr("MarksmanSustainedScenarioPackSmoke: FAIL non-AoE sustained marksman should not request clustered context")
		failed = true
	if omenry_labels.size() != 6 or not _has_label(omenry_labels, "sustained") or not _has_label(omenry_labels, "kite") or not _has_label(omenry_labels, "burst") or not _has_label(omenry_labels, "clustered") or not _has_label(omenry_labels, "clustered_alt"):
		printerr("MarksmanSustainedScenarioPackSmoke: FAIL Omenry-style sustained AoE marksman should keep sustained, kite, burst, and clustered contexts")
		failed = true
	if _has_label(omenry_labels, "peel"):
		printerr("MarksmanSustainedScenarioPackSmoke: FAIL sustained AoE marksman should prefer sustained/kite/burst over generic peel under cap")
		failed = true
	if _has_label(nyxa_labels, "sustained"):
		printerr("MarksmanSustainedScenarioPackSmoke: FAIL non-sustained marksman should not request sustained context")
		failed = true
	if sustained_pack.is_empty() or map_id != "marksman_sustained_pressure" or subject_lane != "back":
		printerr("MarksmanSustainedScenarioPackSmoke: FAIL marksman sustained pack should select the back-lane sustained-pressure map")
		failed = true
	if failed:
		_quit(1)
		return
	print("MarksmanSustainedScenarioPackSmoke: PASS")
	_quit(0)

func _find_pack(packs: Array[Dictionary], label: String) -> Dictionary:
	for pack in packs:
		if String(pack.get("label", "")) == String(label):
			return pack
	return {}

func _has_label(labels: PackedStringArray, wanted: String) -> bool:
	for label in labels:
		if String(label) == String(wanted):
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
