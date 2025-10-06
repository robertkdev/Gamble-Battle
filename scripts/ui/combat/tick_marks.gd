extends Control
class_name TickMarks

@export var max_value: int = 100 : set = set_max
@export var minor_step: int = 10 : set = set_minor
@export var major_step: int = 0 : set = set_major
@export var rtl: bool = false : set = set_rtl
@export var minor_color: Color = Color(0,0,0,0.4) : set = set_minor_color
@export var major_color: Color = Color(0,0,0,0.6) : set = set_major_color
@export var thickness: int = 1 : set = set_thickness
@export var major_thickness: int = 2 : set = set_thickness_major

func set_max(v: int) -> void:
    max_value = max(1, v)
    queue_redraw()

func set_minor(v: int) -> void:
    minor_step = max(1, v)
    queue_redraw()

func set_major(v: int) -> void:
    major_step = max(0, v)
    queue_redraw()

func set_rtl(v: bool) -> void:
    rtl = v
    queue_redraw()

func set_minor_color(c: Color) -> void:
    minor_color = c
    queue_redraw()

func set_major_color(c: Color) -> void:
    major_color = c
    queue_redraw()

func set_thickness(t: int) -> void:
    thickness = max(1, t)
    queue_redraw()

func set_thickness_major(t: int) -> void:
    major_thickness = max(1, t)
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _draw() -> void:
    if max_value <= 0 or minor_step <= 0:
        return
    var w: float = float(size.x)
    var h: float = float(size.y)
    # Minor ticks
    var n_minor: int = int(floor(float(max_value) / float(minor_step)))
    for i in range(1, n_minor):
        var frac: float = float(i * minor_step) / float(max_value)
        var x: float = (w * (1.0 - frac)) if rtl else (w * frac)
        var y1: float = 0.0
        var y2: float = h * 0.6
        draw_line(Vector2(x, y1), Vector2(x, y2), minor_color, float(thickness))
    # Major ticks (optional)
    if major_step > 0:
        var n_major: int = int(floor(float(max_value) / float(major_step)))
        for j in range(1, n_major):
            var frac2: float = float(j * major_step) / float(max_value)
            var x2: float = (w * (1.0 - frac2)) if rtl else (w * frac2)
            draw_line(Vector2(x2, 0), Vector2(x2, h), major_color, float(major_thickness))
