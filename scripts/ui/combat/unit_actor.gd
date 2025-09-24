extends Control
class_name UnitActor

const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")

var unit: Unit
var sprite: TextureRect
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var size_px: Vector2 = Vector2(64, 64)
var _base_screen_pos: Vector2 = Vector2.ZERO
var _effect_offset: Vector2 = Vector2.ZERO
var _knockup_offset_y: float = 0.0
var knockup_offset_y: float:
	get:
		return _knockup_offset_y
	set(value):
		_knockup_offset_y = value
		_effect_offset.y = value
		_update_screen_position()
var _knockup_tween: Tween = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_sprite()
	_ensure_bars()
	_update_visuals()

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

func _ensure_bars() -> void:
	if not (hp_bar and is_instance_valid(hp_bar)):
		hp_bar = UIBars.make_hp_bar()
		add_child(hp_bar)
		hp_bar.anchor_left = 0.0
		hp_bar.anchor_top = 0.0
		hp_bar.anchor_right = 1.0
		hp_bar.anchor_bottom = 0.0
		hp_bar.offset_left = 0.0
		hp_bar.offset_top = 0.0
		hp_bar.offset_right = 0.0
		hp_bar.offset_bottom = 8.0
		hp_bar.z_index = 1
	if not (mana_bar and is_instance_valid(mana_bar)):
		mana_bar = UIBars.make_mana_bar()
		add_child(mana_bar)
		mana_bar.anchor_left = 0.0
		mana_bar.anchor_top = 0.0
		mana_bar.anchor_right = 1.0
		mana_bar.anchor_bottom = 0.0
		mana_bar.offset_left = 0.0
		mana_bar.offset_top = 10.0
		mana_bar.offset_right = 0.0
		mana_bar.offset_bottom = 18.0
		mana_bar.z_index = 1

func set_unit(u: Unit) -> void:
	unit = u
	_ensure_sprite()
	_ensure_bars()
	_update_visuals()

func update_bars(updated_unit: Unit = null) -> void:
	if updated_unit:
		unit = updated_unit
	_update_bars()

# Avoid overriding Control.set_global_position(Vector2, bool)
func set_screen_position(pos: Vector2) -> void:
	_base_screen_pos = pos
	_update_screen_position()

func _update_screen_position() -> void:
	global_position = _base_screen_pos - size * 0.5 + _effect_offset

func _update_visuals() -> void:
	_update_texture()
	_update_bars()

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

func _update_bars() -> void:
	_ensure_bars()
	var hp_max := 1
	var hp_val := 1
	var mana_max := 0
	var mana_val := 0
	if unit:
		hp_max = max(1, unit.max_hp)
		hp_val = clamp(unit.hp, 0, unit.max_hp)
		mana_max = max(0, unit.mana_max)
		mana_val = clamp(unit.mana, 0, unit.mana_max)
	if hp_bar:
		hp_bar.max_value = hp_max
		hp_bar.value = hp_val
	if mana_bar:
		mana_bar.max_value = mana_max
		mana_bar.value = mana_val

func set_size_px(new_size: Vector2) -> void:
	size_px = new_size
	size = size_px
	_update_visuals()

func play_knockup(duration_s: float) -> void:
	# Simple up-then-down bounce using a vertical effect offset; non-intrusive to arena positioning.
	var dur: float = max(0.05, duration_s)
	var half: float = dur * 0.5
	var amp: float = -min(24.0, size_px.y * 0.35) # negative = up on screen
	# Cancel existing tween on this property
	if _knockup_tween and is_instance_valid(_knockup_tween):
		_knockup_tween.kill()
	_knockup_tween = create_tween()
	_knockup_tween.set_trans(Tween.TRANS_SINE)
	_knockup_tween.set_ease(Tween.EASE_OUT)
	_knockup_tween.tween_property(self, "knockup_offset_y", amp, half)
	_knockup_tween.set_trans(Tween.TRANS_SINE)
	_knockup_tween.set_ease(Tween.EASE_IN)
	_knockup_tween.tween_property(self, "knockup_offset_y", 0.0, half)
