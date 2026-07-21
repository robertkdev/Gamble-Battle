extends Control
class_name BattleResultFlourish

signal cue_reached(cue: String, elapsed_ms: int)

const MIN_DURATION_SECONDS: float = 0.8
const REVEAL_FRACTION: float = 0.09
const SETTLE_FRACTION: float = 0.08
const RELEASE_FRACTION: float = 0.18
const MIN_REVEAL_SECONDS: float = 0.12
const MIN_SETTLE_SECONDS: float = 0.12
const MIN_RELEASE_SECONDS: float = 0.22
const CARD_REVEAL_SCALE: float = 0.94
const CARD_IMPACT_SCALE: float = 1.02
const BASE_RING_RADIUS: float = 126.0

var current_cue: String = "idle"

var _tween: Tween = null
var _card: Control = null
var _generation: int = 0
var _started_at_ticks: int = 0
var _mode: String = "victory"
var _accent_color: Color = Color(0.88, 0.63, 0.24, 1.0)
var _intensity: float = 0.0
var _pulse: float = 0.0
var _baseline_scale: Vector2 = Vector2.ONE
var _baseline_modulate: Color = Color.WHITE
var _baseline_pivot: Vector2 = Vector2.ZERO
var _has_card_baseline: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func _exit_tree() -> void:
	cancel()

func play(outcome: String, accent: Color, card: Control, duration: float) -> void:
	cancel()
	_generation += 1
	var play_generation: int = _generation
	_mode = _normalize_mode(outcome)
	_accent_color = accent
	_card = card
	_started_at_ticks = Time.get_ticks_msec()
	current_cue = "reveal"
	_intensity = 0.0
	_pulse = 0.0
	visible = true
	_capture_card_baseline()
	_prepare_card_for_reveal()
	queue_redraw()
	_emit_cue_if_current(play_generation, "reveal")

	var total_seconds: float = max(MIN_DURATION_SECONDS, duration)
	var reveal_seconds: float = max(MIN_REVEAL_SECONDS, total_seconds * REVEAL_FRACTION)
	var settle_seconds: float = max(MIN_SETTLE_SECONDS, total_seconds * SETTLE_FRACTION)
	var release_seconds: float = max(MIN_RELEASE_SECONDS, total_seconds * RELEASE_FRACTION)
	var hold_seconds: float = max(0.12, total_seconds - reveal_seconds - settle_seconds - release_seconds)

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_intensity, 0.0, 1.0, reveal_seconds)
	if _card != null and is_instance_valid(_card):
		_tween.parallel().tween_property(_card, "scale", _baseline_scale * CARD_IMPACT_SCALE, reveal_seconds)
		_tween.parallel().tween_property(_card, "modulate", _baseline_modulate, reveal_seconds)
	_tween.tween_callback(_emit_cue_if_current.bind(play_generation, "impact"))
	_tween.tween_method(_set_pulse, 0.0, 1.0, settle_seconds)
	if _card != null and is_instance_valid(_card):
		_tween.parallel().tween_property(_card, "scale", _baseline_scale, settle_seconds)
	_tween.tween_callback(_emit_cue_if_current.bind(play_generation, "hold"))
	_tween.tween_interval(hold_seconds)
	_tween.tween_callback(_emit_cue_if_current.bind(play_generation, "release"))
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_intensity, 1.0, 0.0, release_seconds)
	if _card != null and is_instance_valid(_card):
		_tween.parallel().tween_property(_card, "scale", _baseline_scale * 0.985, release_seconds)
		_tween.parallel().tween_property(_card, "modulate", _with_alpha(_baseline_modulate, 0.0), release_seconds)
	_tween.tween_callback(_finish_if_current.bind(play_generation))

func cancel() -> void:
	_generation += 1
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	_restore_card_baseline()
	_card = null
	current_cue = "idle"
	_intensity = 0.0
	_pulse = 0.0
	visible = false
	queue_redraw()

func _normalize_mode(outcome: String) -> String:
	var normalized: String = outcome.strip_edges().to_lower()
	if normalized.contains("boss") or normalized.contains("chapter"):
		return "boss_victory"
	if normalized.contains("defeat") or normalized.contains("loss"):
		return "defeat"
	if normalized.contains("tie") or normalized.contains("stalemate"):
		return "tie"
	return "victory"

func _capture_card_baseline() -> void:
	_has_card_baseline = _card != null and is_instance_valid(_card)
	if not _has_card_baseline:
		return
	_baseline_scale = _card.scale
	_baseline_modulate = _card.modulate
	_baseline_pivot = _card.pivot_offset

func _prepare_card_for_reveal() -> void:
	if not _has_card_baseline or _card == null or not is_instance_valid(_card):
		return
	_card.pivot_offset = _card.size * 0.5
	_card.scale = _baseline_scale * CARD_REVEAL_SCALE
	_card.modulate = _with_alpha(_baseline_modulate, 0.0)

func _restore_card_baseline() -> void:
	if not _has_card_baseline or _card == null or not is_instance_valid(_card):
		_has_card_baseline = false
		return
	_card.scale = _baseline_scale
	_card.modulate = _baseline_modulate
	_card.pivot_offset = _baseline_pivot
	_has_card_baseline = false

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))

func _set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	queue_redraw()

func _set_pulse(value: float) -> void:
	_pulse = clampf(value, 0.0, 1.0)
	queue_redraw()

func _emit_cue_if_current(play_generation: int, cue: String) -> void:
	if play_generation != _generation:
		return
	current_cue = cue
	var elapsed_ms: int = max(0, Time.get_ticks_msec() - _started_at_ticks)
	cue_reached.emit(cue, elapsed_ms)

func _finish_if_current(play_generation: int) -> void:
	if play_generation != _generation:
		return
	_tween = null
	current_cue = "complete"
	_intensity = 0.0
	_pulse = 0.0
	visible = false
	queue_redraw()

func _draw() -> void:
	if _intensity <= 0.001:
		return
	var center: Vector2 = size * 0.5
	var card_half_width: float = 330.0
	if _card != null and is_instance_valid(_card):
		var card_rect: Rect2 = _card.get_global_rect()
		center = card_rect.get_center() - get_global_rect().position
		card_half_width = max(220.0, card_rect.size.x * 0.5)
	var ring_radius: float = BASE_RING_RADIUS + 22.0 * _pulse
	var soft_accent: Color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.15 * _intensity)
	var bright_accent: Color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.48 * _intensity)
	draw_circle(center, ring_radius * 0.88, soft_accent)
	draw_arc(center, ring_radius, 0.0, TAU, 96, bright_accent, 1.6, true)
	draw_arc(center, ring_radius + 12.0, -PI * 0.82, -PI * 0.18, 40, soft_accent, 1.0, true)
	match _mode:
		"defeat":
			_draw_defeat_signature(center, ring_radius, bright_accent)
		"tie":
			_draw_tie_signature(center, ring_radius, bright_accent)
		"boss_victory":
			_draw_victory_signature(center, ring_radius, bright_accent, card_half_width)
			_draw_boss_signature(center, ring_radius, bright_accent)
		_:
			_draw_victory_signature(center, ring_radius, bright_accent, card_half_width)

func _draw_victory_signature(center: Vector2, ring_radius: float, color: Color, card_half_width: float) -> void:
	for ray_index: int in range(9):
		var ratio: float = float(ray_index) / 8.0
		var angle: float = lerpf(-PI * 0.92, -PI * 0.08, ratio)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var inner: Vector2 = center + direction * (ring_radius + 8.0)
		var length: float = 24.0 + 18.0 * sin(ratio * PI) + 10.0 * _pulse
		draw_line(inner, inner + direction * length, color, 1.3, true)
	var rule_y: float = ring_radius * 0.18
	draw_line(center + Vector2(-card_half_width * 0.72, rule_y), center + Vector2(-ring_radius - 22.0, rule_y), color, 1.0, true)
	draw_line(center + Vector2(ring_radius + 22.0, rule_y), center + Vector2(card_half_width * 0.72, rule_y), color, 1.0, true)

func _draw_defeat_signature(center: Vector2, ring_radius: float, color: Color) -> void:
	for shard_index: int in range(7):
		var ratio: float = float(shard_index) / 6.0
		var angle: float = lerpf(PI * 0.12, PI * 0.88, ratio)
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var inner: Vector2 = center + direction * (ring_radius + 4.0)
		var outer: Vector2 = inner + direction * (28.0 + 18.0 * _pulse)
		draw_line(inner, outer, color, 1.5, true)
		draw_line(outer, outer + Vector2(-direction.y, direction.x) * (4.0 if shard_index % 2 == 0 else -4.0), Color(color.r, color.g, color.b, color.a * 0.58), 1.0, true)
	draw_arc(center + Vector2(0.0, 5.0), ring_radius + 20.0, PI * 0.08, PI * 0.92, 48, Color(color.r, color.g, color.b, color.a * 0.58), 2.0, true)

func _draw_tie_signature(center: Vector2, ring_radius: float, color: Color) -> void:
	var orbit_offset: float = 20.0 + 8.0 * _pulse
	draw_arc(center + Vector2(-orbit_offset, 0.0), ring_radius * 0.72, -PI * 0.70, PI * 0.70, 56, color, 1.5, true)
	draw_arc(center + Vector2(orbit_offset, 0.0), ring_radius * 0.72, PI * 0.30, PI * 1.70, 56, color, 1.5, true)
	draw_circle(center, 3.0 + 2.0 * _pulse, color)

func _draw_boss_signature(center: Vector2, ring_radius: float, color: Color) -> void:
	var outer_radius: float = ring_radius + 34.0 + 12.0 * _pulse
	var aura_color: Color = Color(color.r, color.g, color.b, color.a * 0.16)
	draw_circle(center, outer_radius * 1.32, aura_color)
	draw_arc(center, outer_radius, 0.0, TAU, 112, Color(color.r, color.g, color.b, color.a * 0.68), 2.2, true)
	draw_arc(center, outer_radius + 16.0, -PI * 0.82, -PI * 0.18, 48, Color(color.r, color.g, color.b, color.a * 0.82), 2.0, true)
	for ray_index: int in range(12):
		var ray_angle: float = float(ray_index) * TAU / 12.0
		var ray_direction: Vector2 = Vector2(cos(ray_angle), sin(ray_angle))
		var ray_start: Vector2 = center + ray_direction * (outer_radius + 8.0)
		var ray_length: float = 18.0 + (12.0 if ray_index % 3 == 0 else 4.0) + 10.0 * _pulse
		draw_line(ray_start, ray_start + ray_direction * ray_length, Color(color.r, color.g, color.b, color.a * 0.72), 1.4, true)
	for point_index: int in range(4):
		var angle: float = -PI * 0.5 + float(point_index) * PI * 0.5
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var point: Vector2 = center + direction * outer_radius
		var tangent: Vector2 = Vector2(-direction.y, direction.x)
		var diamond: PackedVector2Array = PackedVector2Array([
			point + direction * 7.0,
			point + tangent * 4.0,
			point - direction * 7.0,
			point - tangent * 4.0,
		])
		draw_colored_polygon(diamond, color)
	var crown_y: float = center.y - outer_radius - 30.0
	var crown: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - 30.0, crown_y + 18.0),
		Vector2(center.x - 23.0, crown_y - 2.0),
		Vector2(center.x - 8.0, crown_y + 10.0),
		Vector2(center.x, crown_y - 12.0 - 5.0 * _pulse),
		Vector2(center.x + 8.0, crown_y + 10.0),
		Vector2(center.x + 23.0, crown_y - 2.0),
		Vector2(center.x + 30.0, crown_y + 18.0),
	])
	draw_polyline(crown, Color(color.r, color.g, color.b, color.a * 0.92), 2.2, true)
