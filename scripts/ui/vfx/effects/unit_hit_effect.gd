extends Node
class_name UnitHitEffect

signal finished

const FLASH_SHADER: Shader = preload("res://shaders/hit_flash_overlay.gdshader")
const ImpactRing: GDScript = preload("res://scripts/ui/vfx/level_up_vfx.gd")

var host: Control
var sprite: TextureRect
var ring_parent: Control = null
var flash_parent: Control = null
var flash_color: Color = Color(1.8, 0.0, 1.8, 1.0)
var fade_duration: float = 0.22
var hold_duration: float = 0.06
var ring_color: Color = Color(1.0, 0.66, 0.24, 0.82)
var ring_duration: float = 0.24

var _overlay: TextureRect = null
var _overlay_ref: WeakRef = null
var _completed: bool = false

func configure(payload: Dictionary) -> void:
	host = payload.get("host") if payload.has("host") else null
	var maybe_sprite: Variant = payload.get("sprite") if payload.has("sprite") else null
	if maybe_sprite is TextureRect:
		sprite = maybe_sprite
	elif host is TextureRect:
		sprite = host
	var maybe_ring_parent: Variant = payload.get("ring_parent") if payload.has("ring_parent") else null
	if maybe_ring_parent is Control:
		ring_parent = maybe_ring_parent
	var maybe_flash_parent: Variant = payload.get("flash_parent") if payload.has("flash_parent") else null
	if maybe_flash_parent is Control:
		flash_parent = maybe_flash_parent

	var maybe_color: Variant = payload.get("flash_color") if payload.has("flash_color") else flash_color
	if maybe_color is Color:
		flash_color = maybe_color
	var maybe_fade: Variant = payload.get("fade_duration") if payload.has("fade_duration") else fade_duration
	if typeof(maybe_fade) in [TYPE_FLOAT, TYPE_INT]:
		fade_duration = max(0.01, float(maybe_fade))
	var maybe_hold: Variant = payload.get("hold_duration") if payload.has("hold_duration") else hold_duration
	if typeof(maybe_hold) in [TYPE_FLOAT, TYPE_INT]:
		hold_duration = max(0.0, float(maybe_hold))
	var maybe_ring_color: Variant = payload.get("ring_color") if payload.has("ring_color") else ring_color
	if maybe_ring_color is Color:
		ring_color = maybe_ring_color
	var maybe_ring_duration: Variant = payload.get("ring_duration") if payload.has("ring_duration") else ring_duration
	if typeof(maybe_ring_duration) in [TYPE_FLOAT, TYPE_INT]:
		ring_duration = clampf(float(maybe_ring_duration), 0.12, 0.40)

func play() -> void:
	if host == null or sprite == null:

		_emit_finished()
		return
	if sprite.texture == null:

		_emit_finished()
		return
	_spawn_overlay()
	_spawn_impact_ring()
	var overlay: TextureRect = _current_overlay()
	if overlay == null:

		_emit_finished()
		return
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter("flash_color", flash_color)
	mat.set_shader_parameter("amount", 1.0)
	overlay.material = mat
	# One-time debug: report overlay rect to help diagnose visibility
	var _overlay_rect: Rect2 = overlay.get_global_rect()

	# Animate amount -> 0 using a setter to guarantee uniform updates
	var tween_host: Node = self
	if host != null:
		tween_host = host
	var t: Tween = tween_host.create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold_duration > 0.0:
		t.tween_interval(hold_duration)
	# Drive via method to avoid any property-path quirks
	var overlay_ref: WeakRef = _overlay_ref
	t.tween_method(func(value: float) -> void:
		var current_overlay: TextureRect = null
		if overlay_ref != null:
			current_overlay = overlay_ref.get_ref() as TextureRect
		if current_overlay != null and current_overlay.material == mat:
			mat.set_shader_parameter("amount", value)
	, 1.0, 0.0, fade_duration)
	t.finished.connect(_emit_finished)

func _spawn_impact_ring() -> void:
	if host == null:
		return
	var parent: Control = ring_parent if ring_parent != null and is_instance_valid(ring_parent) else host
	var ring: LevelUpVfx = ImpactRing.new() as LevelUpVfx
	ring.name = "HitImpactRing"
	ring.color = ring_color
	ring.duration = ring_duration
	ring.start_radius = 5.0
	ring.end_radius = max(22.0, min(host.size.x, host.size.y) * 0.46)
	ring.line_width = 3.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = max(sprite.z_index if sprite != null else 0, 0) + 2
	parent.add_child(ring)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.offset_left = 0.0
	ring.offset_top = 0.0
	ring.offset_right = 0.0
	ring.offset_bottom = 0.0

func _spawn_overlay() -> void:
	# Create a TextureRect overlaid above the sprite, with matching stretch/expand.
	var parent: Control = flash_parent if flash_parent != null and is_instance_valid(flash_parent) else host
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
	_overlay_ref = weakref(_overlay)
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
	var overlay: TextureRect = _current_overlay()
	if overlay != null:
		overlay.queue_free()
	_overlay = null
	_overlay_ref = null
	emit_signal("finished")

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE) and not _completed:
		var overlay: TextureRect = _current_overlay()
		if overlay != null:
			overlay.queue_free()
		_overlay = null
		_overlay_ref = null
		_completed = true

func _current_overlay() -> TextureRect:
	if _overlay_ref == null:
		return null
	return _overlay_ref.get_ref() as TextureRect
