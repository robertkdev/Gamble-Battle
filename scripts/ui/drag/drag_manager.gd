extends Object
class_name DragManager

signal began_drag(node)
signal ended_drag(node, dropped_success: bool)

var _dragging: bool = false
var _target: Control = null
var _grid: BoardGrid = null
var _orig_parent: Node = null
var _orig_tile_idx: int = -1
var _drag_offset: Vector2 = Vector2.ZERO

func begin(control: Control, grid: BoardGrid) -> void:
    if not control:
        return
    _dragging = true
    _target = control
    _grid = grid
    _orig_parent = control.get_parent()
    if _grid:
        _orig_tile_idx = _grid.index_of(control)
    _target.set_as_top_level(true)
    _target.z_index = 1000
    var vp := _target.get_viewport()
    var mp := (vp.get_mouse_position() if vp else Vector2.ZERO)
    var rect := _target.get_global_rect()
    _drag_offset = rect.position - mp
    began_drag.emit(_target)

func update() -> void:
    if not _dragging or not _target:
        return
    var vp := _target.get_viewport()
    var mp := (vp.get_mouse_position() if vp else Vector2.ZERO)
    _target.global_position = mp + _drag_offset

func end() -> void:
    if not _dragging or not _target:
        return
    var dropped := false
    if _grid:
        var idx := _grid.index_at_global(_target.get_viewport().get_mouse_position())
        if idx != -1:
            dropped = true
    _target.set_as_top_level(false)
    _target.z_index = 0
    ended_drag.emit(_target, dropped)
    _dragging = false
    _target = null
    _grid = null
    _orig_parent = null
    _orig_tile_idx = -1

