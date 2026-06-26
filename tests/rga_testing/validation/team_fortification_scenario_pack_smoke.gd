extends Node

const RoleMatrixSmokeScript := preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")
const RGARoleScenariosScript := preload("res://tests/rga_testing/config/role_scenarios.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var smoke: Node = RoleMatrixSmokeScript.new()
	var kythera_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.team_fortification",
		"approaches": ["damage_reduction", "debuff"]
	}
	var veyra_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.team_fortification",
		"approaches": ["damage_reduction", "cc_immunity", "ramp"]
	}
	var grint_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.initiate_fight",
		"approaches": ["engage", "debuff", "damage_reduction"]
	}
	var kythera_labels: PackedStringArray = smoke.call("_labels_for_unit", kythera_identity)
	var veyra_labels: PackedStringArray = smoke.call("_labels_for_unit", veyra_identity)
	var grint_labels: PackedStringArray = smoke.call("_labels_for_unit", grint_identity)
	smoke.free()

	var tank_packs: Array[Dictionary] = RGARoleScenariosScript.get_packs_for_role("tank")
	var fortify_pack: Dictionary = _find_pack(tank_packs, "fortify")
	var fortify_map: Dictionary = fortify_pack.get("map_params", {}) if fortify_pack.has("map_params") else {}
	var map_id: String = String(fortify_map.get("map_id", ""))
	var subject_lane: String = String(fortify_pack.get("subject_lane", ""))

	print("TeamFortificationScenarioPackSmoke: kythera_labels=", Array(kythera_labels),
		" veyra_labels=", Array(veyra_labels),
		" grint_labels=", Array(grint_labels),
		" fortify_map_id=", map_id)

	var failed: bool = false
	if not _has_label(kythera_labels, "fortify") or not _has_label(kythera_labels, "counterplay"):
		printerr("TeamFortificationScenarioPackSmoke: FAIL Kythera-style fortification identity should keep fortify and counterplay labels")
		failed = true
	if not _has_label(veyra_labels, "fortify") or not _has_label(veyra_labels, "peel"):
		printerr("TeamFortificationScenarioPackSmoke: FAIL Veyra-style fortification identity should keep fortify and defensive peel labels")
		failed = true
	if _has_label(grint_labels, "fortify"):
		printerr("TeamFortificationScenarioPackSmoke: FAIL non-fortification tank should not request fortify context")
		failed = true
	if fortify_pack.is_empty() or map_id != "fortification_window" or subject_lane != "front":
		printerr("TeamFortificationScenarioPackSmoke: FAIL tank fortify pack should select the front-lane fortification_window map")
		failed = true
	if failed:
		_quit(1)
		return
	print("TeamFortificationScenarioPackSmoke: PASS")
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
