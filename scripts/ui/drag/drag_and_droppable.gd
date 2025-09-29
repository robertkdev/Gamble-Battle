extends Control
class_name DragAndDroppable

signal dropped_on_tile(tile_idx: int)
signal dropped_on_target(grid, tile_idx: int)
signal began_drag()
signal ended_drag()

@export var content_root_path: NodePath
@export var drag_size: Vector2 = Vector2(72, 72)
@export var allowed_phases: Array = []
@export var drag_channel: String = ""

var _grid: BoardGrid = null
var _grids: Array[BoardGrid] = [] # Optional multiple targets; first is preferred
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
    # Backward-compatible single-target API
    _grid = grid
    _grids.clear()
    if grid:
        _grids.append(grid)
        _orig_tile_idx = grid.index_of(self)

func enable_drag(grid: BoardGrid) -> void:
    set_drop_grid(grid)

func set_drop_targets(grids: Array) -> void:
    # Preferred multi-target API (KISS): store ordered list; first has precedence
    _grids.clear()
    for g in grids:
        if g != null:
            _grids.append(g)
    _grid = (_grids[0] if _grids.size() > 0 else null)

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
    print("[Drag] begin on=", name, " allowed=", can_drag_now())
    mouse_filter = Control.MOUSE_FILTER_STOP
    if _drag_mgr == null:
        _drag_mgr = load("res://scripts/ui/drag/drag_manager.gd").new()
    if _orig_tile_idx == -1:
        # Resolve origin grid from available targets to allow bench↔board drags
        var resolved: bool = false
        if _grid != null:
            var oi: int = _grid.index_of(self)
            if oi != -1:
                _orig_tile_idx = oi
                resolved = true
        if not resolved and _grids.size() > 0:
            for g in _grids:
                var idx: int = g.index_of(self)
                if idx != -1:
                    _grid = g
                    _orig_tile_idx = idx
                    resolved = true
                    break
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
    print("[Drag] ghost at=", rect.position, " orig_idx=", _orig_tile_idx, " grids=", _grids.size())

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
    var target_grid: BoardGrid = null
    var mp: Vector2 = get_viewport().get_mouse_position()
    print("[Drag] end at mouse=", mp, " grids=", _grids.size(), " single=", (_grid != null))
    if _grids.size() > 0:
        for g in _grids:
            var ti: int = g.index_at_global(mp)
            print("[Drag] test grid=", g, " -> tile=", ti)
            if ti != -1:
                idx = ti
                target_grid = g
                break
    elif _grid:
        idx = _grid.index_at_global(mp)
        if idx != -1:
            target_grid = _grid
    if target_grid != null and idx != -1:
        print("[Drag] dropped on tile=", idx)
        emit_signal("dropped_on_tile", idx)
        emit_signal("dropped_on_target", target_grid, idx)
        did_drop = true
    elif _orig_tile_idx >= 0 and _grid:
        print("[Drag] return to origin tile ", _orig_tile_idx)
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
    print("[Drag] ended; success=", did_drop)
