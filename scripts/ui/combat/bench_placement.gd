extends RefCounted
class_name BenchPlacement

const UI := preload("res://scripts/constants/ui_constants.gd")
const UnitViewClass := preload("res://scripts/ui/combat/unit_view.gd")

var bench_grid: GridContainer
var tile_size: int = UI.TILE_SIZE
var capacity: int = 10

var tiles: Array[Button] = []
var bench_grid_helper: BoardGrid
var _prev_units: Array = []
var _overlay_layer: Control = null

func configure(_bench_grid: GridContainer, _tile_size: int, _capacity: int) -> void:
    bench_grid = _bench_grid
    tile_size = _tile_size
    capacity = max(1, int(_capacity))
    _ensure_tiles()
    _build_helper()

func get_bench_grid() -> BoardGrid:
    return bench_grid_helper

func _ensure_tiles() -> void:
    tiles.clear()
    if bench_grid == null:
        return
    # Collect existing button children first
    for c in bench_grid.get_children():
        if c is Button:
            var b := c as Button
            b.text = ""
            b.toggle_mode = false
            b.focus_mode = Control.FOCUS_NONE
            b.disabled = true
            # Always enforce tile size from constants to allow runtime scaling
            b.custom_minimum_size = Vector2(tile_size, tile_size)
            tiles.append(b)
    # Create more tiles if needed to reach capacity
    while tiles.size() < capacity:
        var nb := Button.new()
        nb.text = ""
        nb.toggle_mode = false
        nb.focus_mode = Control.FOCUS_NONE
        nb.disabled = true
        nb.custom_minimum_size = Vector2(tile_size, tile_size)
        bench_grid.add_child(nb)
        tiles.append(nb)
    # Trim extra tiles if any
    if tiles.size() > capacity:
        tiles.resize(capacity)

func _build_helper() -> void:
    var cols: int = 1
    if bench_grid and bench_grid.has_method("get"):
        # GridContainer has a 'columns' property
        cols = max(1, int(bench_grid.columns))
    var rows: int = int(ceil(float(capacity) / float(cols)))
    bench_grid_helper = load("res://scripts/board_grid.gd").new()
    bench_grid_helper.configure(tiles, cols, rows)

func rebuild_bench_views(units: Array, allow_drag: bool) -> void:
    if bench_grid_helper:
        bench_grid_helper.clear()
    if units == null:
        units = []
    var n: int = min(capacity, min(units.size(), tiles.size()))
    # Determine which indices received a new/different unit since last rebuild
    var animate_indices: Dictionary = {}
    for i_check in range(n):
        var new_u: Unit = units[i_check]
        var old_u: Unit = (_prev_units[i_check] if i_check < _prev_units.size() else null)
        if new_u != null and (old_u == null or old_u != new_u):
            animate_indices[i_check] = true
    # Build views
    for i in range(n):
        var u: Unit = units[i]
        if u == null:
            continue
        var uv: UnitView = UnitViewClass.new()
        uv.set_unit(u)
        if allow_drag:
            uv.enable_drag(bench_grid_helper)
        bench_grid_helper.attach(uv, i)
        # Debug: play level-up animation whenever a unit is newly added to this bench slot
        if animate_indices.has(i):
            print("[BenchPlacement] Added to bench slot=", i, " unit=", (u.name if u else "?"), " level=", int(u.level))
            # Fire in-UnitView animation (may be cleared by immediate rebuilds)
            if uv.has_method("play_level_up"):
                uv.play_level_up(int(u.level))
            # Also spawn a top-level overlay at the tile position so it's always visible
            _spawn_overlay_for_tile(i, int(u.level))
    # Snapshot for next rebuild
    _prev_units.clear()
    for i2 in range(capacity):
        var v: Unit = (units[i2] if i2 < units.size() else null)
        _prev_units.append(v)

func _ensure_overlay_layer() -> void:
    if _overlay_layer and is_instance_valid(_overlay_layer):
        return
    # Create a canvas overlay above the bench grid to host temporary effects
    _overlay_layer = Control.new()
    if bench_grid and is_instance_valid(bench_grid):
        bench_grid.add_child(_overlay_layer)
        _overlay_layer.z_index = 10000
        _overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
        _overlay_layer.offset_left = 0
        _overlay_layer.offset_top = 0
        _overlay_layer.offset_right = 0
        _overlay_layer.offset_bottom = 0

func _spawn_overlay_for_tile(tile_index: int, to_level: int) -> void:
    if bench_grid == null or tile_index < 0 or tile_index >= tiles.size():
        return
    _ensure_overlay_layer()
    var tile: Control = tiles[tile_index]
    if tile == null:
        return
    var r: Rect2 = tile.get_global_rect()
    # Level-up ring overlay (top-level control positioned over the tile)
    var ring = load("res://scripts/ui/vfx/level_up_vfx.gd").new()
    ring.top_level = true
    ring.global_position = r.position
    ring.size = r.size
    ring.z_index = 12000
    if to_level >= 3:
        ring.end_radius = 40.0
        ring.color = Color(1.0, 0.92, 0.55, 0.95)
    _overlay_layer.add_child(ring)
    # Strong white flash overlay
    var flash := ColorRect.new()
    flash.top_level = true
    flash.global_position = r.position
    flash.size = r.size
    flash.z_index = 12010
    flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    flash.color = Color(1,1,1,0.4)
    _overlay_layer.add_child(flash)
    var ft := flash.create_tween()
    ft.tween_property(flash, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    ft.finished.connect(func(): if is_instance_valid(flash): flash.queue_free())
