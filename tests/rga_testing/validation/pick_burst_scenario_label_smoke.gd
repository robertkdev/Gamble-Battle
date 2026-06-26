extends Node

const RoleMatrixSmokeScript := preload("res://tests/rga_testing/ci/RoleMatrixSmoke.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var smoke: Node = RoleMatrixSmokeScript.new()
	var volt_identity: Dictionary[String, Variant] = {
		"primary_role": "mage",
		"primary_goal": "mage.pick_burst",
		"approaches": ["burst", "lockdown"]
	}
	var brute_identity: Dictionary[String, Variant] = {
		"primary_role": "tank",
		"primary_goal": "tank.frontline_absorb",
		"approaches": ["engage", "damage_reduction", "lockdown"]
	}
	var volt_labels: PackedStringArray = smoke.call("_labels_for_unit", volt_identity)
	var brute_labels: PackedStringArray = smoke.call("_labels_for_unit", brute_identity)
	var volt_has_burst: bool = _has_label(volt_labels, "burst")
	var volt_has_counterplay: bool = _has_label(volt_labels, "counterplay")
	var volt_drops_generic_peel: bool = not _has_label(volt_labels, "peel")
	var brute_keeps_peel: bool = _has_label(brute_labels, "peel")
	var brute_drops_burst: bool = not _has_label(brute_labels, "burst")
	smoke.free()

	print("PickBurstScenarioLabelSmoke: volt_labels=", Array(volt_labels),
		" brute_labels=", Array(brute_labels))

	var failed: bool = false
	if volt_labels.size() != 3 or not volt_has_burst or not volt_has_counterplay or not volt_drops_generic_peel:
		printerr("PickBurstScenarioLabelSmoke: FAIL pick-burst labels should preserve neutral/counterplay/burst under the cap")
		failed = true
	if brute_labels.size() != 3 or not brute_keeps_peel or not brute_drops_burst:
		printerr("PickBurstScenarioLabelSmoke: FAIL non-pick-burst capped labels should preserve existing generic peel preference")
		failed = true
	if failed:
		_quit(1)
		return
	print("PickBurstScenarioLabelSmoke: PASS")
	_quit(0)

func _has_label(labels: PackedStringArray, wanted: String) -> bool:
	for label in labels:
		if String(label) == String(wanted):
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
