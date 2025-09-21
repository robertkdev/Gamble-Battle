extends Object
class_name UIBars

static var _pb_bg_style: StyleBox = null
static var _pb_hp_fill: StyleBox = null
static var _pb_mana_fill: StyleBox = null

static func _ensure_loaded() -> void:
    if _pb_bg_style == null:
        _pb_bg_style = load("res://themes/pb_bg.tres")
    if _pb_hp_fill == null:
        _pb_hp_fill = load("res://themes/pb_hp_fill.tres")
    if _pb_mana_fill == null:
        _pb_mana_fill = load("res://themes/pb_mana_fill.tres")

static func style_bar(pb: ProgressBar, is_mana: bool) -> void:
    if pb == null:
        return
    _ensure_loaded()
    pb.add_theme_stylebox_override("background", _pb_bg_style)
    pb.add_theme_stylebox_override("fill", (_pb_mana_fill if is_mana else _pb_hp_fill))
    pb.custom_minimum_size = Vector2(0, (6 if is_mana else 8))
    pb.show_percentage = false

static func make_hp_bar() -> ProgressBar:
    var pb := ProgressBar.new()
    pb.min_value = 0
    pb.max_value = 1
    pb.value = 1
    pb.custom_minimum_size = Vector2(0, 8)
    pb.show_percentage = false
    style_bar(pb, false)
    return pb

static func make_mana_bar() -> ProgressBar:
    var pb := ProgressBar.new()
    pb.min_value = 0
    pb.max_value = 0
    pb.value = 0
    pb.custom_minimum_size = Vector2(0, 6)
    pb.show_percentage = false
    style_bar(pb, true)
    return pb

