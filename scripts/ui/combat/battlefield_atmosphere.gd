extends Control
class_name BattlefieldAtmosphere

const STATE_PLANNING: StringName = &"planning"
const STATE_COMBAT: StringName = &"combat"
const STATE_VICTORY: StringName = &"victory"
const STATE_DEFEAT: StringName = &"defeat"
const STATE_TIE: StringName = &"tie"

const PLANNING_TOP: Color = Color(0.24, 0.055, 0.070, 0.095)
const PLANNING_BOTTOM: Color = Color(0.065, 0.145, 0.170, 0.085)
const COMBAT_TOP: Color = Color(0.50, 0.035, 0.055, 0.165)
const COMBAT_BOTTOM: Color = Color(0.040, 0.155, 0.190, 0.120)
const VICTORY_TOP: Color = Color(0.36, 0.245, 0.065, 0.165)
const VICTORY_BOTTOM: Color = Color(0.075, 0.225, 0.155, 0.120)
const DEFEAT_TOP: Color = Color(0.54, 0.025, 0.030, 0.220)
const DEFEAT_BOTTOM: Color = Color(0.155, 0.025, 0.040, 0.145)
const TIE_TOP: Color = Color(0.245, 0.100, 0.355, 0.170)
const TIE_BOTTOM: Color = Color(0.090, 0.125, 0.205, 0.115)

const MOTION_SPEED: float = 0.20
const COLOR_RESPONSE: float = 4.5
const FLASH_DECAY: float = 1.9
const ESCALATION_RISE_SECONDS: float = 0.14
const ESCALATION_DECAY_SECONDS: float = 0.52
const BASE_MOTE_COUNT: int = 14
const COMBAT_MOTE_COUNT: int = 22
const TAU_F: float = TAU

var _state: StringName = STATE_PLANNING
var _current_top: Color = PLANNING_TOP
var _current_bottom: Color = PLANNING_BOTTOM
var _target_top: Color = PLANNING_TOP
var _target_bottom: Color = PLANNING_BOTTOM
var _accent: Color = Color(0.86, 0.64, 0.30, 0.28)
var _motion_time: float = 0.0
var _flash_strength: float = 0.0
var _intensity: float = 0.55
var _motion_enabled: bool = true
var _configured: bool = false
var _localized_flash: bool = false
var _escalation_elapsed: float = -1.0
var _escalation_peak: float = 0.92

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(true)
	queue_redraw()

func configure(host: Control, initial_state: StringName = STATE_PLANNING) -> void:
	if host == null:
		return
	if get_parent() != host:
		if get_parent() != null:
			get_parent().remove_child(self)
		host.add_child(self)
	name = "BattlefieldAtmosphere"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = -6
	show_behind_parent = false
	_configured = true
	set_state(initial_state, true)

func set_state(next_state: StringName, immediate: bool = false) -> void:
	_state = next_state
	match next_state:
		STATE_COMBAT:
			_target_top = COMBAT_TOP
			_target_bottom = COMBAT_BOTTOM
			_accent = Color(0.96, 0.22, 0.10, 0.34)
			_intensity = 1.0
		STATE_VICTORY:
			_target_top = VICTORY_TOP
			_target_bottom = VICTORY_BOTTOM
			_accent = Color(1.0, 0.76, 0.30, 0.40)
			_intensity = 0.88
		STATE_DEFEAT:
			_target_top = DEFEAT_TOP
			_target_bottom = DEFEAT_BOTTOM
			_accent = Color(1.0, 0.12, 0.08, 0.44)
			_intensity = 1.0
		STATE_TIE:
			_target_top = TIE_TOP
			_target_bottom = TIE_BOTTOM
			_accent = Color(0.74, 0.46, 1.0, 0.38)
			_intensity = 0.78
		_:
			_state = STATE_PLANNING
			_target_top = PLANNING_TOP
			_target_bottom = PLANNING_BOTTOM
			_accent = Color(0.82, 0.62, 0.30, 0.26)
			_intensity = 0.55
	if immediate:
		_current_top = _target_top
		_current_bottom = _target_bottom
		_flash_strength = 0.0
	else:
		_localized_flash = false
		_escalation_elapsed = -1.0
		_flash_strength = maxf(_flash_strength, 0.72 if _state == STATE_COMBAT else 0.52)
	queue_redraw()

func pulse_escalation(intensity: int = 1) -> void:
	if _state != STATE_COMBAT:
		set_state(STATE_COMBAT, false)
	var normalized: float = clampf(float(intensity) / 3.0, 0.34, 1.0)
	_escalation_peak = 0.66 + normalized * 0.26
	_flash_strength = 0.018 + normalized * 0.012
	_escalation_elapsed = 0.0
	_accent = Color(1.0, 0.09, 0.035, 0.48)
	_localized_flash = true
	queue_redraw()

func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	queue_redraw()

func presentation_snapshot() -> Dictionary[String, Variant]:
	return {
		"configured": _configured,
		"state": String(_state),
		"current_top": _current_top,
		"current_bottom": _current_bottom,
		"target_top": _target_top,
		"target_bottom": _target_bottom,
		"flash_strength": _flash_strength,
		"motion_time": _motion_time,
		"motion_enabled": _motion_enabled,
		"localized_flash": _localized_flash,
		"escalation_elapsed": _escalation_elapsed,
		"mote_count": _mote_count(),
		"z_index": z_index,
	}

func _process(delta: float) -> void:
	var response: float = 1.0 - exp(-COLOR_RESPONSE * delta)
	_current_top = _current_top.lerp(_target_top, response)
	_current_bottom = _current_bottom.lerp(_target_bottom, response)
	if _escalation_elapsed >= 0.0:
		_escalation_elapsed += delta
		if _escalation_elapsed <= ESCALATION_RISE_SECONDS:
			var rise_ratio: float = smoothstep(0.0, ESCALATION_RISE_SECONDS, _escalation_elapsed)
			_flash_strength = lerpf(0.024, _escalation_peak, rise_ratio)
		else:
			var decay_ratio: float = clampf((_escalation_elapsed - ESCALATION_RISE_SECONDS) / ESCALATION_DECAY_SECONDS, 0.0, 1.0)
			_flash_strength = lerpf(_escalation_peak, 0.0, decay_ratio)
			if decay_ratio >= 1.0:
				_escalation_elapsed = -1.0
	else:
		_flash_strength = move_toward(_flash_strength, 0.0, delta * FLASH_DECAY)
	if _motion_enabled:
		_motion_time = fmod(_motion_time + delta * MOTION_SPEED, 4096.0)
	queue_redraw()

func _draw() -> void:
	var bounds: Rect2 = Rect2(Vector2.ZERO, size)
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return
	_draw_color_pool(Vector2(bounds.size.x * 0.50, bounds.size.y * 0.08), bounds.size.x * 0.62, _current_top)
	_draw_color_pool(Vector2(bounds.size.x * 0.50, bounds.size.y * 0.94), bounds.size.x * 0.58, _current_bottom)
	_draw_horizon(bounds)
	_draw_ritual_geometry(bounds)
	_draw_motes(bounds)
	if _flash_strength > 0.001:
		var flash_color: Color = Color(_accent.r, _accent.g, _accent.b, _accent.a * _flash_strength * 0.42)
		if _localized_flash:
			var pulse_radius: float = minf(bounds.size.x, bounds.size.y) * 0.38
			_draw_color_pool(Vector2(bounds.size.x * 0.50, bounds.size.y * 0.10), pulse_radius, Color(flash_color.r, flash_color.g, flash_color.b, flash_color.a * 3.00))
			var top_edge: Rect2 = Rect2(3.0, 3.0, bounds.size.x - 6.0, bounds.size.y * 0.42)
			draw_rect(top_edge, Color(_accent.r, _accent.g, _accent.b, _flash_strength * 0.25), false, 2.0)
		else:
			draw_rect(bounds, flash_color, true)
			draw_rect(bounds.grow(-3.0), Color(_accent.r, _accent.g, _accent.b, _flash_strength * 0.34), false, 2.0)

func _draw_color_pool(center: Vector2, radius: float, color: Color) -> void:
	for ring_index: int in range(7, 0, -1):
		var ratio: float = float(ring_index) / 7.0
		var ring_alpha: float = color.a * (1.0 - ratio * 0.78) * 0.40
		var ring_color: Color = Color(color.r, color.g, color.b, ring_alpha)
		draw_circle(center, radius * ratio, ring_color)

func _draw_horizon(bounds: Rect2) -> void:
	var horizon_y: float = bounds.size.y * 0.50
	var pulse: float = 0.5 + 0.5 * sin(_motion_time * 2.7)
	var line_color: Color = Color(_accent.r, _accent.g, _accent.b, 0.045 + pulse * 0.025 * _intensity)
	draw_line(Vector2(bounds.size.x * 0.08, horizon_y), Vector2(bounds.size.x * 0.92, horizon_y), line_color, 1.0)
	draw_line(Vector2(bounds.size.x * 0.24, horizon_y - 3.0), Vector2(bounds.size.x * 0.76, horizon_y - 3.0), Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.55), 1.0)

func _draw_ritual_geometry(bounds: Rect2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_motion_time * 3.1)
	var radius: float = minf(bounds.size.x, bounds.size.y) * (0.16 + pulse * 0.006)
	var center: Vector2 = bounds.size * 0.5
	var rune_color: Color = Color(_accent.r, _accent.g, _accent.b, (0.030 + pulse * 0.024) * _intensity)
	draw_arc(center, radius, -PI * 0.94, -PI * 0.06, 64, rune_color, 1.2, true)
	draw_arc(center, radius, PI * 0.06, PI * 0.94, 64, rune_color, 1.2, true)
	for mark_index: int in range(8):
		var angle: float = float(mark_index) / 8.0 * TAU_F + _motion_time * 0.08
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var start: Vector2 = center + direction * (radius - 5.0)
		var finish: Vector2 = center + direction * (radius + 4.0)
		draw_line(start, finish, rune_color, 1.0)

func _draw_motes(bounds: Rect2) -> void:
	var count: int = _mote_count()
	for mote_index: int in range(count):
		var seed_value: float = float(mote_index) * 0.61803398875
		var x_ratio: float = fposmod(seed_value + sin(seed_value * 17.0) * 0.13, 1.0)
		var travel: float = fposmod(_motion_time * (0.22 + float(mote_index % 5) * 0.035) + seed_value, 1.0)
		var y_ratio: float = 1.04 - travel * 1.12
		var sway: float = sin(_motion_time * 4.0 + float(mote_index) * 1.7) * (4.0 + float(mote_index % 3) * 2.0)
		var position: Vector2 = Vector2(bounds.size.x * x_ratio + sway, bounds.size.y * y_ratio)
		var mote_alpha: float = (0.035 + float(mote_index % 4) * 0.012) * _intensity
		var mote_color: Color = Color(_accent.r, _accent.g, _accent.b, mote_alpha)
		draw_circle(position, 0.8 + float(mote_index % 3) * 0.55, mote_color)

func _mote_count() -> int:
	return COMBAT_MOTE_COUNT if _state == STATE_COMBAT or _state == STATE_DEFEAT else BASE_MOTE_COUNT
