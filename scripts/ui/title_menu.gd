extends Control

const HERO_TEXTURE: Texture2D = preload("res://assets/units/mortem.png")
const SIGIL_TEXTURE: Texture2D = preload("res://assets/ui/gold icon.png")

const COLOR_VOID: Color = Color(0.012, 0.010, 0.014, 1.0)
const COLOR_PANEL: Color = Color(0.030, 0.026, 0.034, 0.90)
const COLOR_PANEL_EDGE: Color = Color(0.42, 0.31, 0.24, 0.88)
const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.62, 0.57, 0.50, 1.0)
const COLOR_BLOOD: Color = Color(0.48, 0.035, 0.070, 1.0)
const COLOR_BLOOD_HOT: Color = Color(0.78, 0.060, 0.105, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.66, 0.32, 1.0)

@onready var center_vbox: VBoxContainer = $Center/VBox
@onready var title_label: Label = $Center/VBox/GameTitle
@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var center: CenterContainer = $Center
@onready var background: ColorRect = $Background
@onready var bg_rect: TextureRect = $TextureRect2
@onready var logo: TextureRect = get_node_or_null("../TextureRect")

var _did_initial_intro := false
var _title_panel: Panel = null
var _shade: ColorRect = null
var _hero: TextureRect = null
var _sigil: TextureRect = null
var _subtitle: Label = null
var _rule: ColorRect = null

func _ready() -> void:
	_apply_gothic_layout()
	# Ensure buttons scale from center when animated
	_center_pivot(start_button)
	_center_pivot(quit_button)
	_wire_button_hover(start_button)
	_wire_button_hover(quit_button)
	if start_button:
		start_button.grab_focus()
	# Prepare and run intro once when first shown
	if visible:
		_play_intro()
	visibility_changed.connect(_on_visibility_changed)
	# Start subtle looping background animation
	_start_bg_loop()
	_start_logo_float()

func _apply_gothic_layout() -> void:
	if background:
		background.color = COLOR_VOID
	if bg_rect:
		bg_rect.modulate = Color(0.70, 0.24, 0.27, 0.82)
		if bg_rect.material is ShaderMaterial:
			var mat: ShaderMaterial = bg_rect.material as ShaderMaterial
			mat.set_shader_parameter("color_a", Color(0.012, 0.010, 0.014, 1.0))
			mat.set_shader_parameter("color_b", Color(0.13, 0.020, 0.035, 1.0))
			mat.set_shader_parameter("vine_color", Color(0.54, 0.045, 0.070, 1.0))
			mat.set_shader_parameter("base_brightness", 0.70)
			mat.set_shader_parameter("field_scale", 3.1)
			mat.set_shader_parameter("line_width", 0.42)
			mat.set_shader_parameter("mix_amount", 1.48)
			mat.set_shader_parameter("vignette_strength", 0.92)
	if center:
		center.anchor_left = 0.055
		center.anchor_top = 0.08
		center.anchor_right = 0.58
		center.anchor_bottom = 0.92
		center.offset_left = 0.0
		center.offset_top = 0.0
		center.offset_right = 0.0
		center.offset_bottom = 0.0
	if center_vbox:
		center_vbox.custom_minimum_size = Vector2(760.0, 0.0)
		center_vbox.add_theme_constant_override("separation", 18)
	if title_label:
		title_label.text = "Gamble Battle"
		title_label.add_theme_font_size_override("font_size", 90)
		title_label.add_theme_color_override("font_color", COLOR_TEXT)
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		title_label.add_theme_constant_override("outline_size", 5)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ensure_title_panel()
	_ensure_shade()
	_ensure_hero()
	_ensure_sigil()
	_ensure_subtitle()
	_style_menu_button(start_button, true)
	_style_menu_button(quit_button, false)

func _ensure_title_panel() -> void:
	_title_panel = get_node_or_null("TitlePanel") as Panel
	if _title_panel == null:
		_title_panel = Panel.new()
		_title_panel.name = "TitlePanel"
		_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title_panel)
		move_child(_title_panel, max(0, center.get_index() if center else 0))
	_title_panel.z_index = 2
	_title_panel.anchor_left = 0.055
	_title_panel.anchor_top = 0.16
	_title_panel.anchor_right = 0.58
	_title_panel.anchor_bottom = 0.84
	_title_panel.offset_left = 0.0
	_title_panel.offset_top = 0.0
	_title_panel.offset_right = 0.0
	_title_panel.offset_bottom = 0.0
	_title_panel.add_theme_stylebox_override("panel", _make_panel_style())
	if center:
		center.z_index = 4

func _ensure_shade() -> void:
	_shade = get_node_or_null("TitleVignette") as ColorRect
	if _shade == null:
		_shade = ColorRect.new()
		_shade.name = "TitleVignette"
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shade)
		move_child(_shade, min(_shade.get_index(), 2))
	_shade.z_index = 1
	_shade.anchor_left = 0.0
	_shade.anchor_top = 0.0
	_shade.anchor_right = 1.0
	_shade.anchor_bottom = 1.0
	_shade.offset_left = 0.0
	_shade.offset_top = 0.0
	_shade.offset_right = 0.0
	_shade.offset_bottom = 0.0
	_shade.color = Color(0.0, 0.0, 0.0, 0.36)

func _ensure_hero() -> void:
	_hero = get_node_or_null("TitleHero") as TextureRect
	if _hero == null:
		_hero = TextureRect.new()
		_hero.name = "TitleHero"
		_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hero)
	_hero.texture = HERO_TEXTURE
	_hero.z_index = 3
	_hero.anchor_left = 0.55
	_hero.anchor_top = -0.04
	_hero.anchor_right = 1.05
	_hero.anchor_bottom = 1.06
	_hero.offset_left = 0.0
	_hero.offset_top = 0.0
	_hero.offset_right = 0.0
	_hero.offset_bottom = 0.0
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.modulate = Color(0.82, 0.76, 0.72, 0.92)

func _ensure_sigil() -> void:
	_sigil = get_node_or_null("TitleSigil") as TextureRect
	if _sigil == null:
		_sigil = TextureRect.new()
		_sigil.name = "TitleSigil"
		_sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sigil)
	_sigil.texture = SIGIL_TEXTURE
	_sigil.z_index = 2
	_sigil.anchor_left = 0.02
	_sigil.anchor_top = 0.08
	_sigil.anchor_right = 0.28
	_sigil.anchor_bottom = 0.52
	_sigil.offset_left = 0.0
	_sigil.offset_top = 0.0
	_sigil.offset_right = 0.0
	_sigil.offset_bottom = 0.0
	_sigil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sigil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sigil.modulate = Color(0.62, 0.48, 0.32, 0.26)

func _ensure_subtitle() -> void:
	_subtitle = center_vbox.get_node_or_null("Subtitle") as Label
	if _subtitle == null:
		_subtitle = Label.new()
		_subtitle.name = "Subtitle"
		center_vbox.add_child(_subtitle)
		center_vbox.move_child(_subtitle, min(1, center_vbox.get_child_count() - 1))
	_subtitle.text = "Blood. Gold. Consequence."
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	_subtitle.add_theme_constant_override("outline_size", 2)
	_rule = center_vbox.get_node_or_null("TitleRule") as ColorRect
	if _rule == null:
		_rule = ColorRect.new()
		_rule.name = "TitleRule"
		_rule.custom_minimum_size = Vector2(420.0, 2.0)
		center_vbox.add_child(_rule)
		center_vbox.move_child(_rule, min(2, center_vbox.get_child_count() - 1))
	_rule.color = Color(0.70, 0.42, 0.22, 0.86)

func _style_menu_button(button: Button, primary: bool) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(480.0, 62.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.76, 0.55, 1.0))
	if primary:
		button.add_theme_stylebox_override("normal", _make_button_style(COLOR_BLOOD, Color(0.92, 0.48, 0.30, 0.92), 2))
		button.add_theme_stylebox_override("hover", _make_button_style(COLOR_BLOOD_HOT, Color(1.0, 0.80, 0.43, 1.0), 2))
	else:
		button.add_theme_stylebox_override("normal", _make_button_style(Color(0.055, 0.047, 0.058, 0.96), Color(0.33, 0.28, 0.28, 0.96), 1))
		button.add_theme_stylebox_override("hover", _make_button_style(Color(0.120, 0.078, 0.090, 0.99), Color(1.0, 0.80, 0.43, 1.0), 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.20, 0.026, 0.044, 1.0), COLOR_GOLD, 2))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.12, 0.07, 0.08, 1.0), COLOR_GOLD, 2))

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_PANEL_EDGE
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.shadow_size = 22
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	return style

func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_size = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	return style

func _on_visibility_changed() -> void:
	if visible:
		_apply_gothic_layout()
		_play_intro()

func _play_intro() -> void:
	# Reset initial state
	title_label.modulate.a = 0.0
	if _subtitle:
		_subtitle.modulate.a = 0.0
	if _rule:
		_rule.modulate.a = 0.0
	if _title_panel:
		_title_panel.modulate.a = 0.0
	if _hero:
		_hero.modulate.a = 0.0
	if _sigil:
		_sigil.modulate.a = 0.0
	start_button.modulate.a = 0.0
	quit_button.modulate.a = 0.0
	if logo:
		logo.modulate.a = 0.0
	title_label.scale = Vector2(0.92, 0.92)
	start_button.scale = Vector2(0.98, 0.98)
	quit_button.scale = Vector2(0.98, 0.98)

	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Make intro animation much faster
	if _title_panel:
		t.tween_property(_title_panel, "modulate:a", 1.0, 0.12)
	if _hero:
		t.parallel().tween_property(_hero, "modulate:a", 0.92, 0.18)
	if _sigil:
		t.parallel().tween_property(_sigil, "modulate:a", 0.26, 0.18)
	t.tween_property(title_label, "modulate:a", 1.0, 0.16)
	t.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.18)
	if _subtitle:
		t.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.18)
	if _rule:
		t.parallel().tween_property(_rule, "modulate:a", 1.0, 0.18)
	if logo:
		t.parallel().tween_property(logo, "modulate:a", 1.0, 0.16)
	# Button staggers
	t.tween_interval(0.02)
	t.tween_property(start_button, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(start_button, "scale", Vector2.ONE, 0.12)
	t.tween_interval(0.02)
	t.tween_property(quit_button, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(quit_button, "scale", Vector2.ONE, 0.12)
	_did_initial_intro = true

func _wire_button_hover(btn: Button) -> void:
	if not btn:
		return
	# Hover
	if not btn.is_connected("mouse_entered", Callable(self, "_on_btn_enter").bind(btn)):
		btn.mouse_entered.connect(Callable(self, "_on_btn_enter").bind(btn))
	if not btn.is_connected("mouse_exited", Callable(self, "_on_btn_exit").bind(btn)):
		btn.mouse_exited.connect(Callable(self, "_on_btn_exit").bind(btn))
	# Keyboard/Controller focus
	if not btn.is_connected("focus_entered", Callable(self, "_on_btn_enter").bind(btn)):
		btn.focus_entered.connect(Callable(self, "_on_btn_enter").bind(btn))
	if not btn.is_connected("focus_exited", Callable(self, "_on_btn_exit").bind(btn)):
		btn.focus_exited.connect(Callable(self, "_on_btn_exit").bind(btn))

func _on_btn_enter(btn: Button) -> void:
	_tween_button_scale(btn, Vector2(1.035, 1.035), 0.11)

func _on_btn_exit(btn: Button) -> void:
	_tween_button_scale(btn, Vector2.ONE, 0.11)

func _tween_button_scale(btn: Button, target_scale: Vector2, duration: float) -> void:
	if btn == null:
		return
	var existing: Tween = btn.get_meta("hover_tween") as Tween if btn.has_meta("hover_tween") else null
	if existing != null and is_instance_valid(existing):
		existing.kill()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", target_scale, duration)
	btn.set_meta("hover_tween", tween)

func _center_pivot(ctrl: Control) -> void:
	if not ctrl:
		return
	# Set pivot to center so scale animates evenly
	ctrl.pivot_offset = ctrl.size * 0.5
	# Keep pivot centered when layout/size changes
	var cb := Callable(self, "_on_ctrl_resized").bind(ctrl)
	if not ctrl.is_connected("resized", cb):
		ctrl.resized.connect(cb)

func _on_ctrl_resized(ctrl: Control) -> void:
	if ctrl:
		ctrl.pivot_offset = ctrl.size * 0.5

func _start_bg_loop() -> void:
	var mat: ShaderMaterial = null
	if bg_rect and bg_rect.material is ShaderMaterial:
		mat = bg_rect.material
	if mat:
		# Animate a couple shader params subtly in a ping-pong loop
		var t := create_tween()
		t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(mat, "shader_parameter/warp_strength", 3.2, 6.0)
		t.parallel().tween_property(mat, "shader_parameter/mix_amount", 1.7, 6.0)
		t.parallel().tween_property(mat, "shader_parameter/field_speed", 0.95, 6.0)
		t.tween_property(mat, "shader_parameter/warp_strength", 2.8, 6.0)
		t.parallel().tween_property(mat, "shader_parameter/mix_amount", 1.4, 6.0)
		t.parallel().tween_property(mat, "shader_parameter/field_speed", 1.05, 6.0)
		t.finished.connect(_start_bg_loop)

func _start_logo_float() -> void:
	if not logo:
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(logo, "scale", Vector2(1.02, 1.02), 2.0)
	t.tween_property(logo, "scale", Vector2.ONE, 2.0)
	t.finished.connect(_start_logo_float)
