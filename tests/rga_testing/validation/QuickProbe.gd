extends Node

const RoleMatrixProbe := preload("res://tests/rga_testing/validation/RoleMatrixProbe.gd")

@export var unit_id: String = "bonko"
@export var scenario_packs_to_run: PackedStringArray = PackedStringArray(["neutral"])
@export var opponents_per_pack: int = 1
@export var repeats: int = 1
@export var include_swapped: bool = false
@export var max_sims: int = 12

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe: Node = RoleMatrixProbe.new()
	add_child(probe)
	probe.set("subject_unit_id", unit_id)
	probe.set("repeats", repeats)
	probe.set("include_swapped", include_swapped)
	probe.set("max_opponents", opponents_per_pack)
	probe.set("scenario_packs_to_run", scenario_packs_to_run)
	probe.set("opponents_per_pack", opponents_per_pack)
	probe.set("max_sims", max_sims)
	probe.set("do_quit_on_finish", false)
	probe.set("dump_json", true)
	probe.set("write_reports", true)
	probe.connect("finished", Callable(self, "_on_done"), CONNECT_ONE_SHOT)

func _on_done(_uid: String, report_path: String) -> void:
	var expect := (report_path if String(report_path).strip_edges() != "" else ("user://identity_reports/" + String(unit_id) + ".json"))
	if FileAccess.file_exists(expect):
		print("QuickProbe: PASS -> ", expect)
		get_tree().quit(0)
	else:
		printerr("QuickProbe: FAIL; missing ", expect)
		get_tree().quit(1)
