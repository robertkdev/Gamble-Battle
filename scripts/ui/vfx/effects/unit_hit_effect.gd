extends Node
class_name UnitHitEffect

signal finished

const FLASH_SHADER := preload("res://shaders/hit_flash_overlay.gdshader")

var host: Control
var sprite: TextureRect
var flash_color: Color = Color(1.8, 0.0, 1.8, 1.0)
var fade_duration: float = 0.22
var hold_duration: float = 0.06

var _overlay: TextureRect = null
var _completed: bool = false

func configure(payload: Dictionary) -> void:
	host = payload.get("host") if payload.has("host") else null
	var maybe_sprite = payload.get("sprite") if payload.has("sprite") else null
	if maybe_sprite is TextureRect:
		sprite = maybe_sprite
	elif host is TextureRect:
		sprite = host

	var maybe_color = payload.get("flash_color") if payload.has("flash_color") else flash_color
	if maybe_color is Color:
		flash_color = maybe_color
	var maybe_fade = payload.get("fade_duration") if payload.has("fade_duration") else fade_duration
	if typeof(maybe_fade) in [TYPE_FLOAT, TYPE_INT]:
		fade_duration = max(0.01, float(maybe_fade))
	var maybe_hold = payload.get("hold_duration") if payload.has("hold_duration") else hold_duration
	if typeof(maybe_hold) in [TYPE_FLOAT, TYPE_INT]:
		hold_duration = max(0.0, float(maybe_hold))

func play() -> void:
	if host == null or sprite == null or not is_instance_valid(host) or not is_instance_valid(sprite):

		_emit_finished()
		return
	if sprite.texture == null:

		_emit_finished()
		return
	_spawn_overlay()
	if _overlay == null or not is_instance_valid(_overlay):

		_emit_finished()
		return
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter("flash_color", flash_color)
	mat.set_shader_parameter("amount", 1.0)
	_overlay.material = mat
	# One-time debug: report overlay rect to help diagnose visibility
	var _r := _overlay.get_global_rect()

	# Animate amount -> 0 using a setter to guarantee uniform updates
	var tween_host: Node = self
	if host != null:
		tween_host = host
	var t := tween_host.create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_duration > 0.0:
		t.tween_interval(hold_duration)
	# Drive via method to avoid any property-path quirks
	t.tween_method(func(v):
		if is_instance_valid(_overlay) and _overlay.material == mat:
			mat.set_shader_parameter("amount", float(v))
	, 1.0, 0.0, fade_duration)
	t.finished.connect(_emit_finished)

func _spawn_overlay() -> void:
	# Create a TextureRect overlaid above the sprite, with matching stretch/expand.
	var parent: Control = host
	if parent == null:
		return
	_overlay = TextureRect.new()
	_overlay.name = "HitFlashOverlay"
	_overlay.texture = sprite.texture
	_overlay.stretch_mode = sprite.stretch_mode
	_overlay.expand_mode = sprite.expand_mode
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = max(sprite.z_index, 0) + 1
	parent.add_child(_overlay)
	# Align overlay to host rect
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.offset_left = 0
	_overlay.offset_top = 0
	_overlay.offset_right = 0
	_overlay.offset_bottom = 0

func _emit_finished() -> void:
	if _completed:
		return
	_completed = true
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	emit_signal("finished")

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE) and not _completed:
		if _overlay and is_instance_valid(_overlay):
			_overlay.queue_free()
		_completed = true
