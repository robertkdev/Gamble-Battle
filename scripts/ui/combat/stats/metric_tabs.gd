extends Control
class_name MetricTabs

signal metric_changed(metric)

# Default metrics per category (minimal MVP mapping)
var metrics_by_category: Dictionary = {
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
var _buttons: Dictionary = {}

func _ready() -> void:
    _build_for(category)

func set_category(cat: String) -> void:
    var key := String(cat)
    if key == category:
        return
    category = key
    _build_for(category)

func set_metrics_for_category(cat: String, list: Array) -> void:
    metrics_by_category[cat] = list.duplicate()
    if String(cat) == String(category):
        _build_for(category)

func set_selected_metric(metric: String) -> void:
    var key := String(metric)
    selected_metric = key
    _update_states()
    metric_changed.emit(selected_metric)

func get_selected_metric() -> String:
    return selected_metric

func _build_for(cat: String) -> void:
    _buttons.clear()
    _clear_children()
    var row := HBoxContainer.new()
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
    for m in list:
        var k: String = String(m.get("key", ""))
        if k == "":
            continue
        var label: String = String(m.get("label", k.capitalize()))
        var b := Button.new()
        b.text = label
        b.toggle_mode = true
        b.pressed.connect(func(): set_selected_metric(k))
        row.add_child(b)
        _buttons[k] = b
    _update_states()
    metric_changed.emit(selected_metric)

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

func _clear_children() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
