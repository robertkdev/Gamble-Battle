extends Node
class_name UnitLevelUpEffect

signal finished

const LevelUpVfx := preload("res://scripts/ui/vfx/level_up_vfx.gd")
const ScanShader := preload("res://shaders/scan_highlight.gdshader")

var host: Control
var sprite: Control
var level: int = 0
var ring_parent: Control
var ring_rect: Rect2 = Rect2()
var ring_top_level: bool = false
var flash_parent: Control
var flash_rect: Rect2 = Rect2()
var flash_top_level: bool = false
var options: Dictionary = {}

func configure(payload: Dictionary) -> void:
	options = payload.duplicate(true)
	host = options.get("host")
	sprite = options.get("sprite")
	level = int(options.get("level", options.get("to_level", 0)))
	ring_parent = options.get("ring_parent", host)
	flash_parent = options.get("flash_parent", host)
	ring_rect = options.get("ring_rect", ring_rect)
	flash_rect = options.get("flash_rect", flash_rect)
	ring_top_level = bool(options.get("ring_top_level", false))
	flash_top_level = bool(options.get("flash_top_level", false))

func play() -> void:
	if host == null:
		emit_signal("finished")
		return
	_play_sprite_punch()
	_spawn_ring()
	_spawn_flash()
	if bool(options.get("scan", true)):
		_play_scan_highlight(float(options.get("scan_duration", 0.55)))
	_schedule_cleanup()

func _play_sprite_punch() -> void:
	if sprite == null or host == null:
		return
	var base_scale: Vector2 = sprite.scale
	var base_color: Color = sprite.modulate
	sprite.modulate = Color(1, 1, 1, 1)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", base_scale * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
	tween.chain().set_parallel(true)
	tween.tween_property(sprite, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "modulate", base_color, 0.14)

func _spawn_ring() -> void:
	var parent: Control = ring_parent if ring_parent else host
	if parent == null:
		return
	var ring: LevelUpVfx = LevelUpVfx.new()
	parent.add_child(ring)
	ring.z_index = int(options.get("ring_z_index", 100))
	var base_color: Color = options.get("ring_color_override", Color()) if options.has("ring_color_override") else ring.color
	if options.has("ring_color_override") and base_color is Color:
		ring.color = base_color
	elif level >= int(options.get("ring_large_level", 3)):
		ring.end_radius = float(options.get("ring_large_radius", 40.0))
		ring.color = options.get("ring_large_color", Color(1.0, 0.92, 0.55, 0.95))
	if ring_top_level:
		ring.top_level = true
		ring.global_position = ring_rect.position
		ring.size = ring_rect.size
		return
	if parent == host:
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.offset_left = 0
		ring.offset_top = 0
		ring.offset_right = 0
		ring.offset_bottom = 0
		return
	if ring_rect.size == Vector2.ZERO:
		ring_rect.size = host.size if host else Vector2.ZERO
	var local_pos := ring_rect.position
	if parent.has_method("to_local"):
		local_pos = parent.to_local(ring_rect.position)
	ring.position = local_pos
	ring.size = ring_rect.size

func _spawn_flash() -> void:
	var parent: Control = flash_parent if flash_parent else host
	if parent == null:
		return
	var flash := ColorRect.new()
	parent.add_child(flash)
	flash.z_index = int(options.get("flash_z_index", 120))
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = options.get("flash_color", Color(1, 1, 1, 0.45))
	if flash_top_level:
		flash.top_level = true
		flash.global_position = flash_rect.position
		flash.size = flash_rect.size
	else:
		if parent == host:
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.offset_left = 0
			flash.offset_top = 0
			flash.offset_right = 0
			flash.offset_bottom = 0
		else:
			var rect := flash_rect
			if rect.size == Vector2.ZERO and host:
				rect.size = host.size
			var local_pos := rect.position
			if parent.has_method("to_local"):
				local_pos = parent.to_local(rect.position)
			flash.position = local_pos
			flash.size = rect.size
	var duration := float(options.get("flash_duration", 0.25))
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, max(0.05, duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		if is_instance_valid(flash):
			flash.queue_free()
	)

func _play_scan_highlight(duration: float) -> void:
	if sprite == null:
		return
	var shader: Shader = ScanShader
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("width", options.get("scan_width", 0.22))
	mat.set_shader_parameter("strength", options.get("scan_strength", 0.85))
	mat.set_shader_parameter("alpha_threshold", options.get("scan_alpha_threshold", 0.01))
	mat.set_shader_parameter("color", options.get("scan_color", Color(1.0, 0.9, 0.3, 1.0)))
	mat.set_shader_parameter("progress", 0.0)
	sprite.material = mat
	var tween_host: Node = self
	if host != null:
		tween_host = host
	var tween := tween_host.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v):
		if is_instance_valid(sprite) and sprite.material == mat:
			mat.set_shader_parameter("progress", float(v))
	, 0.0, 1.0, max(0.1, float(duration)))
	tween.finished.connect(func():
		if is_instance_valid(sprite) and sprite.material == mat:
			sprite.material = null
	)

func _schedule_cleanup() -> void:
	var lifetime := float(options.get("min_lifetime", 0.6))
	var scan_duration := float(options.get("scan_duration", 0.55))
	lifetime = max(lifetime, scan_duration)
	var tree := get_tree()
	if tree:
		var tmr := tree.create_timer(max(0.05, lifetime))
		tmr.timeout.connect(func():
			emit_signal("finished")
		)
	else:
		emit_signal("finished")
