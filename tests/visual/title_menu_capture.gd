extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const OUTPUT_PATH: String = "user://title_menu_capture.png"

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var main: Control = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout

	if not bool(ProjectSettings.get_setting("application/run/enable_mcp_pixel_capture", false)):
		print("TitleMenuCapture: pixel capture skipped; enable application/run/enable_mcp_pixel_capture only with a real rendering backend.")
		get_tree().quit(0)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null:
		print("TitleMenuCapture: viewport texture unavailable; runner may be using dummy rendering.")
		get_tree().quit(0)
		return
	var texture_rid: RID = texture.get_rid()
	if not texture_rid.is_valid():
		print("TitleMenuCapture: viewport texture RID unavailable; runner may be using dummy rendering.")
		get_tree().quit(0)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("TitleMenuCapture: viewport image unavailable; runner may be using dummy rendering.")
		get_tree().quit(0)
		return
	var error: Error = image.save_png(OUTPUT_PATH)
	var absolute_path: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	if error != OK:
		push_error("TitleMenuCapture: failed to save " + absolute_path + " error=" + str(int(error)))
		get_tree().quit(1)
		return
	print("TitleMenuCapture: saved " + absolute_path)
	get_tree().quit(0)
