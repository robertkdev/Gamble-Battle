extends Control
class_name ScoreboardRow

const TextureUtils := preload("res://scripts/util/texture_utils.gd")

var team: String = "player"
var index: int = -1
var unit_ref: Unit = null
var value: float = 0.0
var share: float = 0.0

@onready var portrait: TextureRect = $"HBox/Portrait"
@onready var bar_bg: ColorRect = $"HBox/Content/BarBG"
@onready var bar_fill: ColorRect = $"HBox/Content/BarFill"
@onready var value_label: Label = $"HBox/Content/Value"
@onready var content_box: Control = $"HBox/Content"

func set_row_data(row: Dictionary) -> void:
	team = String(row.get("team", team))
	index = int(row.get("index", index))
	unit_ref = row.get("unit")
	value = float(row.get("value", 0.0))
	share = clamp(float(row.get("share", 0.0)), 0.0, 1.0)
	_refresh()

func _refresh() -> void:
	_update_portrait()
	_update_bar()
	_center_value_label()

func _update_portrait() -> void:
	var tex: Texture2D = null
	if unit_ref != null and String(unit_ref.sprite_path) != "":
		tex = load(unit_ref.sprite_path)
	if tex == null:
		tex = TextureUtils.make_circle_texture(Color(0.6, 0.65, 0.75), 32)
	portrait.texture = tex

func _update_bar() -> void:
	var w: float = max(0.0, float(bar_bg.size.x))
	var fill_w: float = w * share
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = 0.0
	bar_fill.offset_left = 0.0
	bar_fill.offset_right = fill_w
	bar_fill.offset_top = 0.0
	bar_fill.offset_bottom = 0.0
	value_label.text = _format_value(value)
	_center_value_label()

func _format_value(v: float) -> String:
	if v >= 1000000.0:
		return String.num(v/1000000.0, 1) + "m"
	if v >= 1000.0:
		return String.num(v/1000.0, 1) + "k"
	return str(int(round(v)))

func tween_reorder_hint() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.6, 0.1)
	t.tween_property(self, "modulate:a", 1.0, 0.1)

func _center_value_label() -> void:
	if value_label == null:
		return
	# Center the label using explicit top/bottom offsets, independent of container sizing
	var row_h: float = (content_box.size.y if content_box else size.y)
	var font: Font = value_label.get_theme_font("font")
	var fsize: int = value_label.get_theme_font_size("font_size")
	var text_h: float = (font.get_height(fsize) if font else value_label.get_combined_minimum_size().y)
	var top: float = max(0.0, (row_h - text_h) * 0.5)
	# User request: push the value further down — double the offset but clamp
	top = row_h +4
	value_label.anchor_top = 0.0
	value_label.anchor_bottom = 0.0
	value_label.offset_top = top
	value_label.offset_bottom = top + text_h

func _ready() -> void:
	# Ensure centering reacts to resizes and enforce vertical alignment
	if not is_connected("resized", Callable(self, "_center_value_label")):
		resized.connect(_center_value_label)
	if content_box and not content_box.is_connected("resized", Callable(self, "_center_value_label")):
		content_box.resized.connect(_center_value_label)
	if value_label:
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_value_label()
