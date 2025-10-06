extends Control

@onready var center_vbox: VBoxContainer = $Center/VBox
@onready var title_label: Label = $Center/VBox/GameTitle
@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var bg_rect: TextureRect = $TextureRect2
@onready var logo: TextureRect = get_node_or_null("../TextureRect")

var _did_initial_intro := false

func _ready() -> void:
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

func _on_visibility_changed() -> void:
	if visible:
		_play_intro()

func _play_intro() -> void:
	# Reset initial state
	title_label.modulate.a = 0.0
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
	t.tween_property(title_label, "modulate:a", 1.0, 0.16)
	t.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.18)
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
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.12)

func _on_btn_exit(btn: Button) -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, 0.12)

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
