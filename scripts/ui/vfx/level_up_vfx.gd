extends Control
class_name LevelUpVfx

@export var color: Color = Color(1.0, 0.85, 0.2, 0.95)
@export var duration: float = 0.6
@export var start_radius: float = 6.0
@export var end_radius: float = 56.0
@export var line_width: float = 4.0
@export var progress: float = 0.0 : set = set_progress

var _t: float = 0.0
var _tween: Tween

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	# If this control wasn't given an explicit size (e.g., added under UnitView),
	# and it's not top-level, fill the parent rect. When used as a top-level
	# overlay with a preset size/position, keep those values so the arc centers
	# over the intended tile.
	var needs_fill: bool = (not top_level) and (size.x <= 1.0 or size.y <= 1.0)
	if needs_fill:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		offset_left = 0
		offset_top = 0
		offset_right = 0
		offset_bottom = 0
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_t = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, max(0.05, duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(func(): queue_free())

func set_progress(v: float) -> void:
	_t = clamp(float(v), 0.0, 1.0)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var r := lerpf(start_radius, end_radius, _t)
	var a := clampf(1.0 - _t, 0.0, 1.0)
	var c := Color(color.r, color.g, color.b, color.a * a)
	# Draw an expanding ring
	draw_arc(center, r, 0.0, TAU, 48, c, line_width, true)
