extends Node

const RoleMatrixSmokeScript := preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")
const RGARoleScenariosScript := preload("res://tests/rga_testing/config/role_scenarios.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var smoke: Node = RoleMatrixSmokeScript.new()
	var bo_identity: Dictionary[String, Variant] = {
		"primary_role": "brawler",
		"primary_goal": "brawler.skirmish_dive",
		"approaches": ["disrupt", "reposition"]
	}
	var attrition_identity: Dictionary[String, Variant] = {
		"primary_role": "brawler",
		"primary_goal": "brawler.attrition_dps",
		"approaches": ["reposition", "burst", "disrupt"]
	}
	var bo_labels: PackedStringArray = smoke.call("_labels_for_unit", bo_identity)
	var attrition_labels: PackedStringArray = smoke.call("_labels_for_unit", attrition_identity)
	smoke.free()

	var brawler_packs: Array[Dictionary] = RGARoleScenariosScript.get_packs_for_role("brawler")
	var counter_pack: Dictionary = _find_pack(brawler_packs, "counter")
	var counter_map: Dictionary = counter_pack.get("map_params", {}) if counter_pack.has("map_params") else {}
	var map_id: String = String(counter_map.get("map_id", ""))
	var subject_lane: String = String(counter_pack.get("subject_lane", ""))

	print("SkirmishDiveScenarioPackSmoke: bo_labels=", Array(bo_labels),
		" attrition_labels=", Array(attrition_labels),
		" counter_map_id=", map_id)

	var failed: bool = false
	if not _has_label(bo_labels, "counter"):
		printerr("SkirmishDiveScenarioPackSmoke: FAIL skirmish-dive identity should request counter/dive context")
		failed = true
	if _has_label(attrition_labels, "counter"):
		printerr("SkirmishDiveScenarioPackSmoke: FAIL non-skirmish brawler should not request counter/dive context")
		failed = true
	if counter_pack.is_empty() or map_id != "dive_window" or subject_lane != "front":
		printerr("SkirmishDiveScenarioPackSmoke: FAIL brawler counter pack should select the front-lane dive_window map")
		failed = true
	if failed:
		_quit(1)
		return
	print("SkirmishDiveScenarioPackSmoke: PASS")
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
