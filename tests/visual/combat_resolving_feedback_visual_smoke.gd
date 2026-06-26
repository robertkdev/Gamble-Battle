extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const SMOKE_NAME: String = "CombatResolvingFeedbackVisualSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/combat_resolving_feedback_pass"

var _failures: Array[String] = []
var _view: Control = null
var _controller: Variant = null
var _button: Button = null
var _saved_captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)

	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_fail("CombatView scene did not instantiate")
		_finish()
		return
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.offset_left = 0.0
	_view.offset_top = 0.0
	_view.offset_right = 0.0
	_view.offset_bottom = 0.0
	get_tree().root.add_child(_view)
	await _settle_frames(4)

	_controller = _view.get("controller")
	_button = _view.find_child("ContinueButton", true, false) as Button
	if _controller == null:
		_fail("CombatView controller missing")
	if _button == null:
		_fail("ContinueButton missing")
	if _controller == null or _button == null:
		_finish()
		return

	_controller.call("_begin_combat_resolving_feedback")
	await _assert_and_capture("Combat Resolving...", "01_immediate_resolving.png", "initial resolving text should stay immediate")

	_controller.call("_update_combat_resolving_feedback", 2.0)
	await _settle_frames(2)
	_expect(String(_button.text) == "Combat Resolving...", "resolving text should not count before delay")

	_controller.call("_update_combat_resolving_feedback", 1.2)
	await _assert_and_capture("Resolving 3s...", "02_elapsed_resolving.png", "resolving text should show elapsed seconds after delay")

	_controller.call("_update_combat_resolving_feedback", 7.0)
	await _assert_and_capture("Still resolving 10s...", "03_still_resolving.png", "long resolving text should warn after 10 seconds")

	_controller.call("_on_log_line", "Combat no-progress timeout: forcing result from current board state.")
	await _assert_and_capture("Resolving fallback...", "04_watchdog_fallback.png", "watchdog log should switch button to fallback text")

	_controller.call("_update_combat_resolving_feedback", 3.0)
	await _settle_frames(2)
	_expect(String(_button.text) == "Resolving fallback...", "fallback text should not be overwritten by timer updates")

	_finish()

func _assert_and_capture(expected_text: String, filename: String, message: String) -> void:
	await _settle_frames(2)
	_expect(String(_button.text) == expected_text, message)
	_save_capture(filename)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		print("%s: skipped %s because framebuffer capture is unavailable" % [SMOKE_NAME, filename])
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: skipped %s; viewport texture unavailable" % [SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: skipped %s; viewport image unavailable" % [SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s: failed to save %s error=%s" % [SMOKE_NAME, ProjectSettings.globalize_path(path), str(int(error))])
		return
	_saved_captures += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	if _view != null and is_instance_valid(_view):
		if _view.has_method("_teardown"):
			_view.call("_teardown")
		var view_parent: Node = _view.get_parent()
		if view_parent != null:
			view_parent.remove_child(_view)
		_view.free()
		_view = null
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	get_tree().quit(exit_code)
