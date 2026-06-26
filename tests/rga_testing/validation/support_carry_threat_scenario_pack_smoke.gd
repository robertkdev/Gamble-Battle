extends Node

const RoleMatrixSmokeScript := preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")
const RGARoleScenariosScript := preload("res://tests/rga_testing/config/role_scenarios.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var smoke: Node = RoleMatrixSmokeScript.new()
	var totem_identity: Dictionary[String, Variant] = {
		"primary_role": "support",
		"primary_goal": "support.peel_carry",
		"approaches": ["peel", "cc_immunity", "amp"]
	}
	var axiom_identity: Dictionary[String, Variant] = {
		"primary_role": "support",
		"primary_goal": "support.team_amplification",
		"approaches": ["amp", "peel", "sustain"]
	}
	var veyra_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.team_fortification",
		"approaches": ["damage_reduction", "cc_immunity", "ramp"]
	}
	var totem_labels: PackedStringArray = smoke.call("_labels_for_unit", totem_identity)
	var axiom_labels: PackedStringArray = smoke.call("_labels_for_unit", axiom_identity)
	var veyra_labels: PackedStringArray = smoke.call("_labels_for_unit", veyra_identity)
	smoke.free()

	var support_packs: Array[Dictionary] = RGARoleScenariosScript.get_packs_for_role("support")
	var threat_pack: Dictionary = _find_pack(support_packs, "threat")
	var threat_map: Dictionary = threat_pack.get("map_params", {}) if threat_pack.has("map_params") else {}
	var map_id: String = String(threat_map.get("map_id", ""))
	var subject_lane: String = String(threat_pack.get("subject_lane", ""))

	print("SupportCarryThreatScenarioPackSmoke: totem_labels=", Array(totem_labels),
		" axiom_labels=", Array(axiom_labels),
		" veyra_labels=", Array(veyra_labels),
		" threat_map_id=", map_id)

	var failed: bool = false
	if not _has_label(totem_labels, "threat") or not _has_label(totem_labels, "peel"):
		printerr("SupportCarryThreatScenarioPackSmoke: FAIL Totem-style peel-carry identity should keep threat and peel labels")
		failed = true
	if _has_label(axiom_labels, "threat"):
		printerr("SupportCarryThreatScenarioPackSmoke: FAIL non-peel-carry support should not request threat context")
		failed = true
	if _has_label(veyra_labels, "threat"):
		printerr("SupportCarryThreatScenarioPackSmoke: FAIL non-support CC-immunity identity should not request support threat context")
		failed = true
	if threat_pack.is_empty() or map_id != "carry_threat_window" or subject_lane != "back":
		printerr("SupportCarryThreatScenarioPackSmoke: FAIL support threat pack should select the back-lane carry_threat_window map")
		failed = true
	if failed:
		_quit(1)
		return
	print("SupportCarryThreatScenarioPackSmoke: PASS")
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
