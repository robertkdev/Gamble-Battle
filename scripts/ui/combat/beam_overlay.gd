extends Control
class_name BeamOverlay

# Draws ephemeral beam lines (e.g., ability rays) on top of the arena.

var _beams: Array = [] # [{ p1: Vector2, p2: Vector2, color: Color, width: float, remaining: float }]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func add_beam(start_world: Vector2, end_world: Vector2, color: Color, width: float, duration: float) -> void:
	# Convert from global/canvas coordinates into this Control's local space.
	var xf: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var p1: Vector2 = xf * start_world
	var p2: Vector2 = xf * end_world
	var w: float = max(1.0, float(width))
	var d: float = max(0.05, float(duration))
	_beams.append({"p1": p1, "p2": p2, "color": color, "width": w, "remaining": d})
	queue_redraw()

func _process(delta: float) -> void:
	if _beams.is_empty():
		return
	var keep: Array = []
	for b in _beams:
		var rem: float = float(b.get("remaining", 0.0)) - delta
		if rem > 0.0:
			b["remaining"] = rem
			keep.append(b)
	if keep.size() != _beams.size():
		_beams = keep
		queue_redraw()

func _draw() -> void:
	if _beams.is_empty():
		return
	for b in _beams:
		var p1: Vector2 = b.get("p1", Vector2.ZERO)
		var p2: Vector2 = b.get("p2", Vector2.ZERO)
		var c: Color = b.get("color", Color.WHITE)
		var w: float = float(b.get("width", 2.0))
		# Slight outer glow by drawing a translucent, wider line first
		draw_line(p1, p2, Color(c.r, c.g, c.b, c.a * 0.25), w * 2.0)
		draw_line(p1, p2, c, w)
