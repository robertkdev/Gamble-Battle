extends Control
class_name SellZone

const UI := preload("res://scripts/constants/ui_constants.gd")

var _grid_container: GridContainer = null
var _tile: Button = null
var _grid_helper: BoardGrid = null

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _ensure_ui()
    _build_grid()

func _ensure_ui() -> void:
    if _grid_container and is_instance_valid(_grid_container):
        return
    _grid_container = GridContainer.new()
    add_child(_grid_container)
    _grid_container.columns = 1
    _grid_container.anchor_left = 0.0
    _grid_container.anchor_top = 0.0
    _grid_container.anchor_right = 0.0
    _grid_container.anchor_bottom = 0.0
    _grid_container.offset_left = 0.0
    _grid_container.offset_top = 0.0
    _grid_container.offset_right = 0.0
    _grid_container.offset_bottom = 0.0
    _tile = Button.new()
    _tile.text = "Sell"
    _tile.focus_mode = Control.FOCUS_NONE
    _tile.toggle_mode = false
    _tile.disabled = true # acts as a drop target only
    _tile.custom_minimum_size = Vector2(UI.TILE_SIZE, UI.TILE_SIZE)
    _grid_container.add_child(_tile)

func _build_grid() -> void:
    _grid_helper = load("res://scripts/board_grid.gd").new()
    _grid_helper.configure([_tile], 1, 1)

func get_grid() -> BoardGrid:
    return _grid_helper

