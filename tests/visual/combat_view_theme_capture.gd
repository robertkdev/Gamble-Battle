extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_PATH := "res://outputs/gamblebattle-gothic-ui-battle-pass6.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var view: Control = COMBAT_VIEW_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	if view.has_method("set_player_team_ids"):
		view.call("set_player_team_ids", ["bonko", "paisley"])
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture()
	print("CombatViewThemeCapture: ready")

func _save_capture() -> void:
	var output_dir: String = ProjectSettings.globalize_path("res://outputs")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png(OUTPUT_PATH)
	if result != OK:
		push_error("CombatViewThemeCapture: save failed %s" % str(result))
		return
	print("CombatViewThemeCapture: saved %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
