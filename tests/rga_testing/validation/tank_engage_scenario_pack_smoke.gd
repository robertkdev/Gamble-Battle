extends Node

const RoleMatrixSmokeScript := preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")
const RGARoleScenariosScript := preload("res://tests/rga_testing/config/role_scenarios.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var smoke: Node = RoleMatrixSmokeScript.new()
	var grint_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.initiate_fight",
		"approaches": ["engage", "debuff", "damage_reduction"]
	}
	var brute_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.frontline_absorb",
		"approaches": ["engage", "lockdown", "damage_reduction"]
	}
	var kythera_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.team_fortification",
		"approaches": ["damage_reduction", "debuff"]
	}
	var grint_labels: PackedStringArray = smoke.call("_labels_for_unit", grint_identity)
	var brute_labels: PackedStringArray = smoke.call("_labels_for_unit", brute_identity)
	var kythera_labels: PackedStringArray = smoke.call("_labels_for_unit", kythera_identity)
	smoke.free()

	var tank_packs: Array[Dictionary] = RGARoleScenariosScript.get_packs_for_role("tank")
	var engage_pack: Dictionary = _find_pack(tank_packs, "engage")
	var engage_map: Dictionary = engage_pack.get("map_params", {}) if engage_pack.has("map_params") else {}
	var map_id: String = String(engage_map.get("map_id", ""))
	var subject_lane: String = String(engage_pack.get("subject_lane", ""))

	print("TankEngageScenarioPackSmoke: grint_labels=", Array(grint_labels),
		" brute_labels=", Array(brute_labels),
		" kythera_labels=", Array(kythera_labels),
		" engage_map_id=", map_id)

	var failed: bool = false
	if grint_labels.size() != 4 or not _has_label(grint_labels, "engage") or not _has_label(grint_labels, "counterplay") or not _has_label(grint_labels, "burst"):
		printerr("TankEngageScenarioPackSmoke: FAIL Grint-style initiate identity should keep engage, counterplay, and burst labels")
		failed = true
	if brute_labels.size() != 4 or not _has_label(brute_labels, "engage") or not _has_label(brute_labels, "counterplay") or not _has_label(brute_labels, "peel"):
		printerr("TankEngageScenarioPackSmoke: FAIL engage frontline identity should keep engage, counterplay, and peel labels")
		failed = true
	if _has_label(kythera_labels, "engage"):
		printerr("TankEngageScenarioPackSmoke: FAIL non-engage fortification tank should not request engage context")
		failed = true
	if engage_pack.is_empty() or map_id != "engage_window" or subject_lane != "front":
		printerr("TankEngageScenarioPackSmoke: FAIL tank engage pack should select the front-lane engage_window map")
		failed = true
	if failed:
		_quit(1)
		return
	print("TankEngageScenarioPackSmoke: PASS")
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
