extends Node

const RoleMatrixSmokeScript: Script = preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")
const RGARoleScenariosScript: Script = preload("res://tests/rga_testing/config/role_scenarios.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hexeon_approaches: Array[String] = ["access_backline", "burst", "execute"]
	var pick_burst_approaches: Array[String] = ["burst"]
	var hexeon_identity: Dictionary[String, Variant] = {
		"primary_role": "assassin",
		"primary_goal": "assassin.backline_elimination",
		"approaches": hexeon_approaches
	}
	var pick_burst_identity: Dictionary[String, Variant] = {
		"primary_role": "mage",
		"primary_goal": "mage.pick_burst",
		"approaches": pick_burst_approaches
	}
	var smoke: Node = RoleMatrixSmokeScript.new()
	var hexeon_labels: PackedStringArray = smoke.call("_labels_for_unit", hexeon_identity)
	var pick_burst_labels: PackedStringArray = smoke.call("_labels_for_unit", pick_burst_identity)
	smoke.free()

	var assassin_packs: Array[Dictionary] = RGARoleScenariosScript.get_packs_for_role("assassin")
	var counter_pack: Dictionary = _find_pack(assassin_packs, "counter")
	var counter_map: Dictionary = counter_pack.get("map_params", {}) if counter_pack.has("map_params") else {}
	var map_id: String = String(counter_map.get("map_id", ""))
	var subject_lane: String = String(counter_pack.get("subject_lane", ""))

	print("AssassinOpeningScenarioPackSmoke: hexeon_labels=", Array(hexeon_labels),
		" pick_burst_labels=", Array(pick_burst_labels),
		" counter_map_id=", map_id)

	var failed: bool = false
	if hexeon_labels.size() != 3 or not _has_label(hexeon_labels, "neutral") or not _has_label(hexeon_labels, "counter") or not _has_label(hexeon_labels, "burst"):
		printerr("AssassinOpeningScenarioPackSmoke: FAIL Hexeon-style assassin identity should keep neutral, counter, and burst labels")
		failed = true
	if _has_label(pick_burst_labels, "counter"):
		printerr("AssassinOpeningScenarioPackSmoke: FAIL non-assassin pick-burst identity should not request assassin counter context")
		failed = true
	if counter_pack.is_empty() or map_id != "dive_window" or subject_lane != "front":
		printerr("AssassinOpeningScenarioPackSmoke: FAIL assassin counter pack should select the front-lane dive_window map")
		failed = true
	if failed:
		_quit(1)
		return
	print("AssassinOpeningScenarioPackSmoke: PASS")
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
