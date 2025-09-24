extends RefCounted
class_name IntermissionController


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
    _parent.add_child(_bar)
    _bar.anchor_left = 0.0
    _bar.anchor_top = 0.0
    _bar.anchor_right = 1.0
    _bar.anchor_bottom = 0.0
    _bar.offset_left = 16.0
    _bar.offset_right = -16.0
    _bar.offset_top = 8.0
    _bar.offset_bottom = 18.0
    _bar.min_value = 0.0
    _bar.max_value = 1.0
    _bar.value = 0.0
    _bar.visible = false

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
        var t = (_parent.get_tree() if _parent else null)
        if t:
            var timer = t.create_timer(max(0.1, float(seconds)))
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
