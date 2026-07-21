extends Control
class_name MetricTabs

const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

signal metric_changed(metric: String)

# Default metrics per category (minimal MVP mapping)
var metrics_by_category: Dictionary[String, Array] = {
    "damage": [
        {"key": "damage", "label": "Total"},
        {"key": "dps", "label": "DPS"},
        {"key": "casts", "label": "Casts"},
        {"key": "kills", "label": "Kills"},
        {"key": "deaths", "label": "Deaths"},
        {"key": "focus", "label": "Focus%"},
        {"key": "overkill", "label": "Overkill"},
        {"key": "time", "label": "Time"},
    ],
    "tanking": [
        {"key": "taken", "label": "Taken"},
        {"key": "absorbed", "label": "Shield"},
        {"key": "mitigated", "label": "Mitigated"},
    ],
    "sustain": [
        {"key": "healing", "label": "Healing"},
        {"key": "overheal", "label": "Overheal"},
        {"key": "hps", "label": "HPS"},
    ],
    "control": [
        {"key": "cc_inflicted", "label": "CC Inf"},
        {"key": "cc_received", "label": "CC Rec"},
    ],
}

var category: String = "damage"
var selected_metric: String = "damage"
var _buttons: Dictionary[String, Button] = {}
var _secondary_keys: Array[String] = []
var _secondary_labels: Dictionary[String, String] = {}
var _secondary_menu: MenuButton = null

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_for(category)

func set_category(cat: String) -> void:
    var key: String = String(cat)
    if key == category:
        return
    category = key
    _build_for(category)

func set_metrics_for_category(cat: String, list: Array) -> void:
    metrics_by_category[cat] = list.duplicate()
    if String(cat) == String(category):
        _build_for(category)

func set_selected_metric(metric: String) -> void:
    var key: String = String(metric)
    selected_metric = key
    _update_states()
    metric_changed.emit(selected_metric)

func get_selected_metric() -> String:
    return selected_metric

func _build_for(cat: String) -> void:
    _buttons.clear()
    _secondary_keys.clear()
    _secondary_labels.clear()
    _secondary_menu = null
    _clear_children()
    mouse_filter = Control.MOUSE_FILTER_PASS
    custom_minimum_size = Vector2(0.0, 34.0)
    var row: HBoxContainer = HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_PASS
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    row.anchor_left = 0.0
    row.anchor_top = 1.0
    row.anchor_right = 1.0
    row.anchor_bottom = 1.0
    row.offset_left = 0.0
    row.offset_top = -40.0
    row.offset_right = 0.0
    row.offset_bottom = 0.0
    var list: Array = metrics_by_category.get(cat, [])
    if list.is_empty():
        list = [{"key": "damage", "label": "Total"}]
    # Ensure selected is valid
    var first_key: String = String(list[0].get("key", "damage"))
    if not _has_key(list, selected_metric):
        selected_metric = first_key
    var primary_metrics: Array[Dictionary] = []
    var secondary_metrics: Array[Dictionary] = []
    for metric_index: int in range(list.size()):
        var metric: Dictionary = list[metric_index] as Dictionary
        if list.size() <= 3 or metric_index < 2:
            primary_metrics.append(metric)
        else:
            secondary_metrics.append(metric)
    for m: Dictionary in primary_metrics:
        var k: String = String(m.get("key", ""))
        if k == "":
            continue
        var label: String = String(m.get("label", k.capitalize()))
        var b: Button = Button.new()
        b.text = label
        b.mouse_filter = Control.MOUSE_FILTER_STOP
        b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        b.focus_mode = Control.FOCUS_ALL
        b.custom_minimum_size = Vector2(44.0, 30.0)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.toggle_mode = true
        _apply_button_style(b)
        b.pressed.connect(func(): set_selected_metric(k))
        row.add_child(b)
        _buttons[k] = b
    if not secondary_metrics.is_empty():
        _secondary_menu = MenuButton.new()
        _secondary_menu.name = "SecondaryMetricsButton"
        _secondary_menu.text = "More"
        _secondary_menu.mouse_filter = Control.MOUSE_FILTER_STOP
        _secondary_menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        _secondary_menu.focus_mode = Control.FOCUS_ALL
        _secondary_menu.custom_minimum_size = Vector2(52.0, 30.0)
        _secondary_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _apply_button_style(_secondary_menu)
        row.add_child(_secondary_menu)
        var popup: PopupMenu = _secondary_menu.get_popup()
        for metric_index: int in range(secondary_metrics.size()):
            var metric: Dictionary = secondary_metrics[metric_index]
            var key: String = String(metric.get("key", ""))
            if key == "":
                continue
            var label: String = String(metric.get("label", key.capitalize()))
            _secondary_keys.append(key)
            _secondary_labels[key] = label
            popup.add_item(label, _secondary_keys.size() - 1)
        popup.id_pressed.connect(_on_secondary_metric_selected)
    _update_states()
    metric_changed.emit(selected_metric)

func _on_secondary_metric_selected(item_id: int) -> void:
    if item_id < 0 or item_id >= _secondary_keys.size():
        return
    set_selected_metric(_secondary_keys[item_id])

func _has_key(list: Array, k: String) -> bool:
    for m in list:
        if String(m.get("key", "")) == String(k):
            return true
    return false

func _update_states() -> void:
    for k in _buttons.keys():
        var b: Button = _buttons[k]
        if b:
            b.button_pressed = (String(k) == String(selected_metric))
    if _secondary_menu != null:
        var secondary_selected: bool = _secondary_labels.has(selected_metric)
        _secondary_menu.text = "%s ▾" % _secondary_labels[selected_metric] if secondary_selected else "More ▾"
        _secondary_menu.add_theme_color_override("font_color", Color(1.0, 0.74, 0.48, 1.0) if secondary_selected else Color(0.90, 0.82, 0.68, 1.0))

func _clear_children() -> void:
    for child: Node in get_children():
        remove_child(child)
        child.queue_free()

func _apply_button_style(button: Button) -> void:
    button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _make_button_fallback(Color(0.043, 0.037, 0.047, 0.96), Color(0.36, 0.30, 0.26, 0.96))))
    button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.14, 1.05, 0.92, 1.0)), _make_button_fallback(Color(0.120, 0.078, 0.090, 0.99), Color(1.0, 0.80, 0.43, 1.0))))
    button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.86, 0.72, 0.68, 1.0)), _make_button_fallback(Color(0.20, 0.026, 0.044, 1.0), Color(0.92, 0.68, 0.34, 1.0))))
    button.add_theme_stylebox_override("focus", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.10, 1.02, 0.88, 1.0)), _make_button_fallback(Color(0.12, 0.07, 0.08, 1.0), Color(0.92, 0.68, 0.34, 1.0))))
    button.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68, 1.0))
    button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.48, 1.0))
    button.add_theme_font_size_override("font_size", 12)

func _make_button_fallback(bg_color: Color, border_color: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = bg_color
    style.border_color = border_color
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_right = 5
    style.corner_radius_bottom_left = 5
    return style
