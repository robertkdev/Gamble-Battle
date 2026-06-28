extends Node

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const SMOKE_NAME: String = "UnitSelectPreviewVisualSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/unit_select_preview_pass"

var _view: UnitSelect = null
var _failures: Array[String] = []
var _saved_captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)

	_view = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.offset_left = 0.0
	_view.offset_top = 0.0
	_view.offset_right = 0.0
	_view.offset_bottom = 0.0
	get_tree().root.add_child(_view)
	await _settle_frames(4)

	_expect_neutral_preview("initial")
	_save_capture("01_neutral_preview.png")

	var first_button: Button = _first_unit_button()
	_expect(first_button != null, "No generated unit button available for hover preview")
	if first_button != null:
		first_button.emit_signal("mouse_entered")
		await _settle_frames(4)
		_expect_hover_preview()
		_save_capture("02_hover_preview.png")

		var moved_by_scroll: bool = await _try_scroll_clear()
		if not moved_by_scroll and _view.has_method("_clear_hover_for_scroll"):
			_view.call("_clear_hover_for_scroll")
			await _settle_frames(3)
		_expect_neutral_preview("scroll-clear")
		_save_capture("03_after_scroll_clear.png")

	_finish()

func _expect_neutral_preview(context: String) -> void:
	var selected_label: Label = _selected_label()
	var details_label: Label = _details_label()
	var preview_art: TextureRect = _preview_art()
	var identity_panel: Control = _identity_panel()
	var start_button: Button = _start_button()
	_expect(_view != null and _view.selected_id == "", "%s Unit Select should not have a selected unit" % context)
	_expect(selected_label != null and String(selected_label.text) == "No champion chosen", "%s preview title should be neutral" % context)
	_expect(details_label != null and String(details_label.text) == "Hover a unit to preview", "%s preview help should be neutral" % context)
	_expect(preview_art != null and preview_art.texture == null, "%s preview art should be empty" % context)
	_expect(identity_panel == null or not identity_panel.visible, "%s identity summary should be hidden" % context)
	_expect(start_button != null and start_button.disabled, "%s Start Game should remain disabled" % context)

func _expect_hover_preview() -> void:
	var selected_label: Label = _selected_label()
	var details_label: Label = _details_label()
	var preview_art: TextureRect = _preview_art()
	var identity_panel: Control = _identity_panel()
	var start_button: Button = _start_button()
	_expect(_view != null and _view.selected_id == "", "hover preview should not select a unit")
	_expect(selected_label != null and String(selected_label.text).begins_with("Inspecting "), "hover preview title should show inspecting state")
	_expect(details_label != null and String(details_label.text) != "Hover a unit to preview", "hover preview should show unit details")
	_expect(preview_art != null and preview_art.texture != null, "hover preview should show unit art")
	_expect(identity_panel != null and identity_panel.visible, "hover preview should show identity summary")
	_expect(start_button != null and start_button.disabled, "hover preview should not enable Start Game")

func _try_scroll_clear() -> bool:
	var scroll: ScrollContainer = _view.get_node_or_null("Center/HBox/Left/Scroll") as ScrollContainer
	if scroll == null:
		return false
	var scroll_bar: VScrollBar = scroll.get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= scroll_bar.min_value:
		return false
	var start_value: float = float(scroll.scroll_vertical)
	var target_value: float = float(scroll_bar.max_value)
	if absf(target_value - start_value) < 0.5:
		target_value = float(scroll_bar.min_value)
	scroll.scroll_vertical = int(roundf(target_value))
	await _settle_frames(4)
	var moved_value: float = float(scroll.scroll_vertical)
	return absf(moved_value - start_value) >= 0.5

func _first_unit_button() -> Button:
	if _view == null:
		return null
	return _view.find_child("UnitButton_*", true, false) as Button

func _selected_label() -> Label:
	return _view.get_node_or_null("Center/HBox/Right/Preview/SelectedLabel") as Label

func _details_label() -> Label:
	return _view.get_node_or_null("Center/HBox/Right/Preview/Details") as Label

func _preview_art() -> TextureRect:
	return _view.get_node_or_null("Center/HBox/Right/Preview/ArtWrap/Art") as TextureRect

func _identity_panel() -> Control:
	return _view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel") as Control

func _start_button() -> Button:
	return _view.get_node_or_null("Center/HBox/Right/StartButton") as Button

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_save_vision_capture(filename)
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

func _save_vision_capture(filename: String) -> void:
	var root_node: Node = _view if _view != null else self
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(root_node, filename.get_basename(), OUTPUT_DIR)
	if not bool(result.get("ok", false)):
		push_error("%s: vision fallback failed for %s reason=%s" % [SMOKE_NAME, filename, str(result.get("reason", ""))])
		return
	_saved_captures += 1
	print("%s: saved %s via %s" % [SMOKE_NAME, ProjectSettings.globalize_path(str(result.get("path", ""))), str(result.get("kind", ""))])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	get_tree().quit(exit_code)
