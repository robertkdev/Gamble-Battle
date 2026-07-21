extends Control
class_name BattlePhaseStinger

signal cue_reached(cue: StringName)

const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const MIN_DURATION_SECONDS: float = 0.72
const PANEL_HEIGHT: float = 106.0

var current_cue: StringName = &"idle"

var _title_label: Label = null
var _detail_label: Label = null
var _tween: Tween = null
var _generation: int = 0
var _intensity: float = 0.0
var _sweep: float = 0.0
var _accent: Color = Color(0.86, 0.58, 0.24, 1.0)
var _boss_mode: bool = false
var _motion_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_as_relative = false
	z_index = 142
	visible = false
	_build_labels()
	_layout_labels()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_labels()

func _exit_tree() -> void:
	cancel()

func play_round(stage_number: int, chapter_number: int, wager: int, boss: bool = false) -> void:
	var title: String = "BOSS CONTRACT" if boss else "BATTLE %d" % max(1, stage_number)
	var detail: String = "CHAPTER %d  |  WAGER %dg LOCKED" % [max(1, chapter_number), max(0, wager)]
	var accent: Color = Color(0.86, 0.22, 0.16, 1.0) if boss else Color(0.88, 0.62, 0.28, 1.0)
	play(title, detail, accent, boss, 1.05)

func play(title: String, detail: String, accent: Color, boss: bool = false, duration: float = 1.05) -> void:
	cancel()
	_generation += 1
	var play_generation: int = _generation
	_accent = accent
	_boss_mode = boss
	_intensity = 0.0
	_sweep = 0.0
	_set_copy(title, detail)
	visible = true
	current_cue = &"reveal"
	cue_reached.emit(current_cue)
	queue_redraw()
	if not _motion_enabled:
		_set_intensity(1.0)
		_set_sweep(1.0)
		current_cue = &"hold"
		cue_reached.emit(current_cue)
		return
	var total_seconds: float = maxf(MIN_DURATION_SECONDS, duration)
	var reveal_seconds: float = minf(0.16, total_seconds * 0.18)
	var settle_seconds: float = minf(0.18, total_seconds * 0.20)
	var release_seconds: float = minf(0.32, total_seconds * 0.30)
	var hold_seconds: float = maxf(0.14, total_seconds - reveal_seconds - settle_seconds - release_seconds)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_intensity, 0.0, 1.0, reveal_seconds)
	_tween.parallel().tween_method(_set_sweep, 0.0, 1.0, reveal_seconds + settle_seconds)
	_tween.tween_callback(_set_cue_if_current.bind(play_generation, &"hold"))
	_tween.tween_interval(hold_seconds)
	_tween.tween_callback(_set_cue_if_current.bind(play_generation, &"release"))
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_intensity, 1.0, 0.0, release_seconds)
	_tween.tween_callback(_finish_if_current.bind(play_generation))

func cancel() -> void:
	_generation += 1
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	_intensity = 0.0
	_sweep = 0.0
	current_cue = &"idle"
	visible = false
	_update_label_alpha()
	queue_redraw()

func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled

func presentation_snapshot() -> Dictionary[String, Variant]:
	return {
		"cue": current_cue,
		"title": _title_label.text if _title_label != null else "",
		"detail": _detail_label.text if _detail_label != null else "",
		"boss": _boss_mode,
		"intensity": _intensity,
		"sweep": _sweep,
		"mouse_filter": mouse_filter,
		"z_index": z_index,
	}

func _build_labels() -> void:
	if _title_label != null and is_instance_valid(_title_label):
		return
	_title_label = Label.new()
	_title_label.name = "StingerTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GothicUIAssets.apply_type(_title_label, &"title")
	_title_label.add_theme_color_override("font_color", GothicUIAssets.COLOR_TEXT)
	_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	_title_label.add_theme_constant_override("outline_size", 2)
	add_child(_title_label)
	_detail_label = Label.new()
	_detail_label.name = "StingerDetail"
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GothicUIAssets.apply_type(_detail_label, &"meta")
	_detail_label.add_theme_color_override("font_color", GothicUIAssets.COLOR_TEXT_MUTED)
	add_child(_detail_label)

func _layout_labels() -> void:
	if _title_label == null or _detail_label == null:
		return
	var center_y: float = size.y * 0.28
	var panel_width: float = minf(720.0, size.x * 0.62)
	_title_label.position = Vector2((size.x - panel_width) * 0.5, center_y - 36.0)
	_title_label.size = Vector2(panel_width, 48.0)
	_detail_label.position = Vector2((size.x - panel_width) * 0.5, center_y + 10.0)
	_detail_label.size = Vector2(panel_width, 28.0)

func _set_copy(title: String, detail: String) -> void:
	_build_labels()
	_title_label.text = title.strip_edges().to_upper()
	_detail_label.text = detail.strip_edges().to_upper()
	_layout_labels()
	_update_label_alpha()

func _set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	_update_label_alpha()
	queue_redraw()

func _set_sweep(value: float) -> void:
	_sweep = clampf(value, 0.0, 1.0)
	queue_redraw()

func _update_label_alpha() -> void:
	var label_color: Color = Color(1.0, 1.0, 1.0, _intensity)
	if _title_label != null:
		_title_label.modulate = label_color
	if _detail_label != null:
		_detail_label.modulate = label_color

func _set_cue_if_current(play_generation: int, cue: StringName) -> void:
	if play_generation != _generation:
		return
	current_cue = cue
	cue_reached.emit(current_cue)

func _finish_if_current(play_generation: int) -> void:
	if play_generation != _generation:
		return
	_tween = null
	current_cue = &"complete"
	visible = false
	_intensity = 0.0
	_sweep = 0.0
	_update_label_alpha()
	queue_redraw()
	cue_reached.emit(current_cue)

func _draw() -> void:
	if _intensity <= 0.001:
		return
	var center_y: float = size.y * 0.28
	var panel_width: float = minf(720.0, size.x * 0.62)
	var panel_rect: Rect2 = Rect2(Vector2((size.x - panel_width) * 0.5, center_y - PANEL_HEIGHT * 0.5), Vector2(panel_width, PANEL_HEIGHT))
	var bar_height: float = maxf(28.0, size.y * 0.055)
	var veil_alpha: float = 0.72 * _intensity
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, bar_height)), Color(0.006, 0.004, 0.008, veil_alpha))
	draw_rect(Rect2(Vector2(0.0, size.y - bar_height), Vector2(size.x, bar_height)), Color(0.006, 0.004, 0.008, veil_alpha))
	draw_rect(panel_rect, Color(0.012, 0.008, 0.012, 0.88 * _intensity))
	var edge_color: Color = Color(_accent.r, _accent.g, _accent.b, 0.84 * _intensity)
	draw_line(panel_rect.position, Vector2(panel_rect.end.x, panel_rect.position.y), edge_color, 1.2, true)
	draw_line(Vector2(panel_rect.position.x, panel_rect.end.y), panel_rect.end, edge_color, 1.2, true)
	var sweep_half: float = panel_width * 0.5 * _sweep
	draw_line(Vector2(size.x * 0.5 - sweep_half, center_y), Vector2(size.x * 0.5 + sweep_half, center_y), Color(_accent.r, _accent.g, _accent.b, 0.26 * _intensity), 1.0, true)
	if _boss_mode:
		var radius: float = 46.0 + 8.0 * _sweep
		draw_arc(Vector2(size.x * 0.5, center_y), radius, 0.0, TAU, 64, Color(_accent.r, _accent.g, _accent.b, 0.34 * _intensity), 2.0, true)
		for point_index: int in range(4):
			var angle: float = -PI * 0.5 + float(point_index) * PI * 0.5
			var direction: Vector2 = Vector2(cos(angle), sin(angle))
			draw_circle(Vector2(size.x * 0.5, center_y) + direction * radius, 3.0, edge_color)
