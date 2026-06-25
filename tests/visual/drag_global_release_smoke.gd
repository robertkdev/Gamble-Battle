extends Node

const DragAndDroppableScript := preload("res://scripts/ui/drag/drag_and_droppable.gd")
const BoardGridScript := preload("res://scripts/board_grid.gd")

var _failures: Array[String] = []
var _dropped_grid: BoardGrid = null
var _dropped_idx: int = -1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(640, 360)
		window.content_scale_size = Vector2i(640, 360)

	var layout: Control = Control.new()
	layout.name = "DragGlobalReleaseLayout"
	layout.size = Vector2(640.0, 360.0)
	add_child(layout)

	var source_tile: Button = _make_tile("SourceTile", Vector2(80.0, 120.0))
	var target_tile: Button = _make_tile("TargetTile", Vector2(240.0, 120.0))
	layout.add_child(source_tile)
	layout.add_child(target_tile)
	await _settle_frames(2)

	var grid: BoardGrid = BoardGridScript.new()
	grid.configure([source_tile, target_tile], 2, 1)

	var drag: DragAndDroppable = DragAndDroppableScript.new()
	drag.name = "Draggable"
	drag.drag_size = Vector2(80.0, 80.0)
	drag.dropped_on_target.connect(_on_dropped)
	grid.attach(drag, 0)
	drag.set_drop_targets([grid])
	await _settle_frames(2)

	drag.call("_begin_drag_internal")
	_expect(bool(drag.get("_dragging")), "drag did not enter active state")
	var target_center: Vector2 = grid.get_center(1)
	_send_motion(target_center)
	await _settle_frames(2)
	_send_release(target_center)
	await _settle_frames(4)

	_expect(_dropped_grid == grid, "drag did not report the target grid")
	_expect(_dropped_idx == 1, "drag release reported tile %d instead of 1" % _dropped_idx)
	_expect(not bool(drag.get("_dragging")), "drag remained active after global release")
	_expect(drag.get("_ghost") == null, "drag ghost was not cleaned after global release")
	_finish()


func _make_tile(tile_name: String, tile_position: Vector2) -> Button:
	var tile: Button = Button.new()
	tile.name = tile_name
	tile.position = tile_position
	tile.size = Vector2(96.0, 96.0)
	tile.custom_minimum_size = Vector2(96.0, 96.0)
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	return tile


func _send_motion(position: Vector2) -> void:
	Input.warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _send_release(position: Vector2) -> void:
	Input.warp_mouse(position)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = 0
	event.position = position
	event.global_position = position
	event.pressed = false
	Input.parse_input_event(event)


func _on_dropped(grid: BoardGrid, tile_idx: int) -> void:
	_dropped_grid = grid
	_dropped_idx = tile_idx


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame


func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("DragGlobalReleaseSmoke: OK")
	else:
		for failure: String in _failures:
			push_error("DragGlobalReleaseSmoke: " + failure)
		exit_code = 1
	get_tree().quit(exit_code)
