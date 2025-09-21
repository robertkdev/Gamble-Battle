extends Control
class_name UnitActor

var unit: Unit
var sprite: TextureRect
var size_px: Vector2 = Vector2(64, 64)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_sprite()
	_update_texture()

func _ensure_sprite() -> void:
	if sprite and is_instance_valid(sprite):
		if sprite.get_parent() != self:
			add_child(sprite)
		return
	sprite = TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.anchor_left = 0.0
	sprite.anchor_top = 0.0
	sprite.anchor_right = 1.0
	sprite.anchor_bottom = 1.0
	sprite.offset_left = 0.0
	sprite.offset_top = 0.0
	sprite.offset_right = 0.0
	sprite.offset_bottom = 0.0
	add_child(sprite)

func set_unit(u: Unit) -> void:
	unit = u
	_ensure_sprite()
	_update_texture()

# Avoid overriding Control.set_global_position(Vector2, bool)
func set_screen_position(pos: Vector2) -> void:
	global_position = pos - size * 0.5

func _update_texture() -> void:
	_ensure_sprite()
	if sprite == null:
		return
	var tex: Texture2D = null
	if unit != null and unit.sprite_path != "":
		tex = load(unit.sprite_path)
	if tex == null:
		var img: Image = Image.create(int(size_px.x), int(size_px.y), false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var center: Vector2 = size_px * 0.5
		var radius: float = min(size_px.x, size_px.y) * 0.45
		var r2: float = radius * radius
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var dx: float = float(x) - center.x
				var dy: float = float(y) - center.y
				if dx * dx + dy * dy <= r2:
					img.set_pixel(x, y, Color(0.7, 0.7, 0.9, 1.0))
		tex = ImageTexture.create_from_image(img)
	sprite.texture = tex

func set_size_px(new_size: Vector2) -> void:
	size_px = new_size
	size = size_px
	_update_texture()
