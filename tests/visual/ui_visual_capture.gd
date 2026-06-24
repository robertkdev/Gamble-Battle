extends Node

const CAPTURE_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")

func _ready() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var view: Control = CAPTURE_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	if not bool(ProjectSettings.get_setting("application/run/enable_mcp_pixel_capture", false)):
		print("UIVisualCapture: pixel capture skipped; enable application/run/enable_mcp_pixel_capture only when running with a real rendering backend.")
		get_tree().quit(0)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null:
		push_warning("UIVisualCapture: viewport texture unavailable; runner may be using dummy rendering.")
		get_tree().quit(0)
		return
	var texture_rid: RID = texture.get_rid()
	if not texture_rid.is_valid():
		push_warning("UIVisualCapture: viewport texture RID unavailable; runner may be using dummy rendering.")
		get_tree().quit(0)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("UIVisualCapture: viewport image unavailable; runner may be using dummy rendering.")
		get_tree().quit(0)
		return
	var path: String = "user://ui_visual_capture.png"
	var err: Error = image.save_png(path)
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if err != OK:
		push_error("UIVisualCapture: failed to save " + absolute_path + " error=" + str(int(err)))
		get_tree().quit(1)
		return
	print("UIVisualCapture: saved " + absolute_path)
	get_tree().quit(0)
