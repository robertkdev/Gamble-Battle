extends Node

const RoleMatrixSmokeScript: Script = preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")
const RGARoleScenariosScript: Script = preload("res://tests/rga_testing/config/role_scenarios.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var mortem_approaches: Array[String] = ["reposition", "burst", "disrupt"]
	var skirmish_approaches: Array[String] = ["disrupt", "reposition"]
	var mortem_identity: Dictionary[String, Variant] = {
		"primary_role": "brawler",
		"primary_goal": "brawler.attrition_dps",
		"approaches": mortem_approaches
	}
	var skirmish_identity: Dictionary[String, Variant] = {
		"primary_role": "brawler",
		"primary_goal": "brawler.skirmish_dive",
		"approaches": skirmish_approaches
	}
	var smoke: Node = RoleMatrixSmokeScript.new()
	var mortem_labels: PackedStringArray = smoke.call("_labels_for_unit", mortem_identity)
	var skirmish_labels: PackedStringArray = smoke.call("_labels_for_unit", skirmish_identity)
	smoke.free()

	var brawler_packs: Array[Dictionary] = RGARoleScenariosScript.get_packs_for_role("brawler")
	var burst_pack: Dictionary = _find_pack(brawler_packs, "burst")
	var peel_pack: Dictionary = _find_pack(brawler_packs, "peel")
	var burst_map: Dictionary = burst_pack.get("map_params", {}) if burst_pack.has("map_params") else {}
	var peel_map: Dictionary = peel_pack.get("map_params", {}) if peel_pack.has("map_params") else {}
	var burst_map_id: String = String(burst_map.get("map_id", ""))
	var peel_map_id: String = String(peel_map.get("map_id", ""))
	var burst_lane: String = String(burst_pack.get("subject_lane", ""))
	var peel_lane: String = String(peel_pack.get("subject_lane", ""))

	print("BrawlerAttritionScenarioPackSmoke: mortem_labels=", Array(mortem_labels),
		" skirmish_labels=", Array(skirmish_labels),
		" burst_map_id=", burst_map_id,
		" peel_map_id=", peel_map_id)

	var failed: bool = false
	if mortem_labels.size() != 3 or not _has_label(mortem_labels, "neutral") or not _has_label(mortem_labels, "burst") or not _has_label(mortem_labels, "peel"):
		printerr("BrawlerAttritionScenarioPackSmoke: FAIL Mortem-style attrition identity should keep neutral, burst, and peel labels")
		failed = true
	if _has_label(mortem_labels, "counter"):
		printerr("BrawlerAttritionScenarioPackSmoke: FAIL Mortem-style attrition identity should not request skirmish counter context")
		failed = true
	if not _has_label(skirmish_labels, "counter"):
		printerr("BrawlerAttritionScenarioPackSmoke: FAIL skirmish-dive brawler control should still request counter context")
		failed = true
	if burst_pack.is_empty() or burst_map_id != "burst_lane" or burst_lane != "front":
		printerr("BrawlerAttritionScenarioPackSmoke: FAIL brawler burst pack should select the front-lane burst_lane map")
		failed = true
	if peel_pack.is_empty() or peel_map_id != "peel_context" or peel_lane != "front":
		printerr("BrawlerAttritionScenarioPackSmoke: FAIL brawler peel pack should select the front-lane peel_context map")
		failed = true
	if failed:
		_quit(1)
		return
	print("BrawlerAttritionScenarioPackSmoke: PASS")
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
