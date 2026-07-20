extends Control
class_name ArenaAtmosphere

const MOTE_COUNT: int = 18
const SCUFF_COUNT: int = 7

var _elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, 120.0)
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_draw_floor_scuffs()
	_draw_ambient_motes()

func _draw_floor_scuffs() -> void:
	for index: int in range(SCUFF_COUNT):
		var px: float = _unit_value(index * 131 + 19) * size.x
		var py: float = lerpf(size.y * 0.22, size.y * 0.84, _unit_value(index * 89 + 43))
		var radius: float = lerpf(24.0, 58.0, _unit_value(index * 47 + 7))
		var tone: Color = Color(0.30, 0.19, 0.12, 0.045 if index % 2 == 0 else 0.030)
		draw_arc(Vector2(px, py), radius, 0.12, PI - 0.18, 28, tone, 1.0, true)
		draw_arc(Vector2(px + radius * 0.12, py + radius * 0.28), radius * 0.66, PI + 0.18, TAU - 0.24, 24, tone, 1.0, true)

func _draw_ambient_motes() -> void:
	for index: int in range(MOTE_COUNT):
		var speed: float = lerpf(0.7, 1.7, _unit_value(index * 61 + 5))
		var drift: float = sin(_elapsed * speed + float(index) * 1.37)
		var px: float = fposmod(_unit_value(index * 97 + 11) * size.x + _elapsed * (2.0 + float(index % 3)), size.x)
		var py: float = lerpf(size.y * 0.14, size.y * 0.88, _unit_value(index * 73 + 29)) + drift * 4.0
		var radius: float = 0.7 + float(index % 3) * 0.45
		var color: Color = Color(0.88, 0.53, 0.25, 0.075) if index % 4 == 0 else Color(0.60, 0.76, 0.73, 0.050)
		draw_circle(Vector2(px, py), radius, color)

func _unit_value(seed: int) -> float:
	return float(posmod(seed * 1103515245 + 12345, 997)) / 996.0
