extends Control
class_name DragAndDroppable

signal dropped_on_tile(tile_idx: int)
signal began_drag()
signal ended_drag()

@export var content_root_path: NodePath
@export var drag_size: Vector2 = Vector2(72, 72)
@export var allowed_phases: Array = []
@export var drag_channel: String = ""

var _grid: BoardGrid = null
var _dragging: bool = false
var _mouse_down: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _orig_tile_idx: int = -1

var _ghost: Control = null
var _drag_mgr: DragManager = null

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    if not is_connected("gui_input", Callable(self, "_on_gui_input_base")):
        gui_input.connect(_on_gui_input_base)

func set_drop_grid(grid: BoardGrid) -> void:
    _grid = grid
    if _grid:
        _orig_tile_idx = _grid.index_of(self)

func enable_drag(grid: BoardGrid) -> void:
    set_drop_grid(grid)

func can_drag_now() -> bool:
    # Prefer global GameState if available for phase checks
    var current_phase: int = -1
    if Engine.has_singleton("GameState") or has_node("/root/GameState"):
        current_phase = GameState.phase
    else:
        var main := get_tree().root.get_node_or_null("/root/Main")
        current_phase = (main.game_phase if main else -1)
    var phase_ok := (allowed_phases.is_empty() or allowed_phases.has(current_phase))
    return phase_ok and _can_drag_extra()

func _can_drag_extra() -> bool:
    return true

func on_drop(success: bool, index: int) -> void:
    # Overridable hook for subclasses (e.g., items)
    pass

func _on_gui_input_base(event: InputEvent) -> void:
    if not can_drag_now():
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _mouse_down = true
            var vp := get_viewport()
            _press_pos = (vp.get_mouse_position() if vp else Vector2.ZERO)
        else:
            _mouse_down = false
            if _dragging:
                _end_drag_internal()
    elif event is InputEventMouseMotion:
        var vp := get_viewport()
        var mp := (vp.get_mouse_position() if vp else Vector2.ZERO)
        if _mouse_down and not _dragging:
            if mp.distance_to(_press_pos) > 6.0:
                _begin_drag_internal()
        if _dragging and _drag_mgr:
            _drag_mgr.update()

func _begin_drag_internal() -> void:
    _dragging = true
    emit_signal("began_drag")
    mouse_filter = Control.MOUSE_FILTER_STOP
    if _drag_mgr == null:
        _drag_mgr = load("res://scripts/ui/drag/drag_manager.gd").new()
    if _grid and _orig_tile_idx == -1:
        _orig_tile_idx = _grid.index_of(self)
    # Build ghost from content root (clone subtree so bars/sprite follow)
    var src: Control = (get_node_or_null(content_root_path) as Control) if content_root_path != NodePath("") else self
    _ghost = Control.new()
    _ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ghost.anchor_left = 0.0
    _ghost.anchor_top = 0.0
    _ghost.anchor_right = 0.0
    _ghost.anchor_bottom = 0.0
    _ghost.size = drag_size
    _ghost.z_index = 2000
    if src:
        var clone := src.duplicate(true)
        if clone is Control:
            _ghost.add_child(clone)
            # Fill ghost
            (clone as Control).anchor_left = 0.0
            (clone as Control).anchor_top = 0.0
            (clone as Control).anchor_right = 1.0
            (clone as Control).anchor_bottom = 1.0
            (clone as Control).offset_left = 0.0
            (clone as Control).offset_top = 0.0
            (clone as Control).offset_right = 0.0
            (clone as Control).offset_bottom = 0.0
            _set_mouse_ignore_recursive(clone)
    # Place ghost at this control's position
    var rect := get_global_rect()
    _ghost.global_position = rect.position
    get_tree().root.add_child(_ghost)
    # Dim original during drag
    self.modulate.a = 0.35
    _drag_mgr.begin(_ghost, _grid)

func _set_mouse_ignore_recursive(n: Node) -> void:
    if n is Control:
        (n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    for c in n.get_children():
        _set_mouse_ignore_recursive(c)

func _end_drag_internal() -> void:
    _dragging = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    var did_drop := false
    var idx := -1
    if _grid:
        idx = _grid.index_at_global(get_viewport().get_mouse_position())
        if idx != -1:
            emit_signal("dropped_on_tile", idx)
            did_drop = true
        elif _orig_tile_idx >= 0:
            _grid.attach(self, _orig_tile_idx)
    on_drop(did_drop, idx)
    if _drag_mgr:
        _drag_mgr.end()
    if _ghost:
        var p := _ghost.get_parent()
        if p:
            p.remove_child(_ghost)
        _ghost.queue_free()
        _ghost = null
    self.modulate.a = 1.0
    emit_signal("ended_drag")
