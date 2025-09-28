extends RefCounted
class_name BenchPlacement

const UI := preload("res://scripts/constants/ui_constants.gd")
const UnitViewClass := preload("res://scripts/ui/combat/unit_view.gd")

var bench_grid: GridContainer
var tile_size: int = UI.TILE_SIZE
var capacity: int = 10

var tiles: Array[Button] = []
var bench_grid_helper: BoardGrid

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
    if units.is_empty():
        return
    var n: int = min(capacity, min(units.size(), tiles.size()))
    for i in range(n):
        var u: Unit = units[i]
        if u == null:
            continue
        var uv: UnitView = UnitViewClass.new()
        uv.set_unit(u)
        if allow_drag:
            uv.enable_drag(bench_grid_helper)
        bench_grid_helper.attach(uv, i)
