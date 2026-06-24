extends RefCounted
class_name IntermissionController

const COLOR_PANEL_DEEP: Color = Color(0.025, 0.020, 0.028, 0.92)
const COLOR_BLOOD: Color = Color(0.50, 0.025, 0.050, 0.98)
const COLOR_GOLD: Color = Color(0.88, 0.56, 0.22, 0.88)
const COLOR_BORDER: Color = Color(0.34, 0.24, 0.20, 0.86)

var _parent: Node = null
var _bar: ProgressBar = null
var _tween: Tween = null

func configure(parent: Node) -> void:
    _parent = parent

func _ensure_bar() -> void:
    if _bar and is_instance_valid(_bar):
        return
    if _parent == null:
        return
    _bar = ProgressBar.new()
    _bar.name = "GothicIntermissionBar"
    _parent.add_child(_bar)
    _bar.anchor_left = 0.5
    _bar.anchor_top = 0.0
    _bar.anchor_right = 0.5
    _bar.anchor_bottom = 0.0
    _bar.offset_left = -280.0
    _bar.offset_right = 280.0
    _bar.offset_top = 92.0
    _bar.offset_bottom = 102.0
    _bar.z_index = 2000
    _bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _bar.min_value = 0.0
    _bar.max_value = 1.0
    _bar.value = 0.0
    _bar.show_percentage = false
    _bar.add_theme_stylebox_override("background", _make_bar_background_style())
    _bar.add_theme_stylebox_override("fill", _make_bar_fill_style())
    _bar.visible = false

func _make_bar_background_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = COLOR_PANEL_DEEP
    style.border_color = COLOR_BORDER
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 3
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_right = 3
    style.corner_radius_bottom_left = 3
    style.shadow_size = 8
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
    return style

func _make_bar_fill_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = COLOR_BLOOD
    style.border_color = COLOR_GOLD
    style.border_width_top = 1
    style.corner_radius_top_left = 3
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_right = 3
    style.corner_radius_bottom_left = 3
    return style

func start(seconds: float, on_finished: Callable) -> void:
    _ensure_bar()
    if _bar == null:
        # No parent; finish immediately
        if on_finished.is_valid():
            on_finished.call()
        return
    # Reset and show bar
    _bar.value = 0.0
    _bar.visible = true
    # Kill any prior tween
    if _tween and is_instance_valid(_tween):
        _tween.kill()
    # Create tween on parent for progress animation
    if _parent != null and _parent.has_method("create_tween"):
        _tween = _parent.create_tween()
        _tween.tween_property(_bar, "value", 1.0, max(0.1, float(seconds)))
        _tween.finished.connect(func():
            _bar.visible = false
            if on_finished.is_valid():
                on_finished.call()
        )
    else:
        # Fallback: use SceneTreeTimer and snap to done
        var tree: SceneTree = (_parent.get_tree() if _parent else null)
        if tree:
            var timer: SceneTreeTimer = tree.create_timer(max(0.1, float(seconds)))
            timer.timeout.connect(func():
                _bar.value = 1.0
                _bar.visible = false
                if on_finished.is_valid():
                    on_finished.call()
            )
        else:
            # Final fallback: immediate finish
            _bar.visible = false
            if on_finished.is_valid():
                on_finished.call()

func stop() -> void:
    if _tween and is_instance_valid(_tween):
        _tween.kill()
        _tween = null
    if _bar:
        _bar.visible = false
