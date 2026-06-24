extends Control
class_name UnitActor

const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")
const UnitEffectPlayer := preload("res://scripts/ui/vfx/unit_effect_player.gd")

var unit: Unit
var focus_plate: Panel
var sprite: TextureRect
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var shield_bar: ProgressBar
var hp_ticks: TickMarks
var mana_ticks: TickMarks
var shield_ticks: TickMarks
var size_px: Vector2 = Vector2(64, 64)
var _effect_player: UnitEffectPlayer
var _team_tint: Color = Color(0.40, 0.08, 0.10, 0.68)
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
	_ensure_focus_plate()
	_ensure_sprite()
	_ensure_bars()
	_ensure_effect_player()
	_update_effect_player_sprite()
	_update_visuals()

func _ensure_focus_plate() -> void:
	if focus_plate and is_instance_valid(focus_plate):
		if focus_plate.get_parent() != self:
			add_child(focus_plate)
		_apply_focus_plate_style()
		return
	focus_plate = Panel.new()
	focus_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_plate.z_index = 0
	focus_plate.anchor_left = 0.0
	focus_plate.anchor_top = 0.0
	focus_plate.anchor_right = 1.0
	focus_plate.anchor_bottom = 1.0
	focus_plate.offset_left = -9.0
	focus_plate.offset_top = -9.0
	focus_plate.offset_right = 9.0
	focus_plate.offset_bottom = 9.0
	add_child(focus_plate)
	_apply_focus_plate_style()

func _apply_focus_plate_style() -> void:
	if focus_plate == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(_team_tint.r, _team_tint.g, _team_tint.b, min(_team_tint.a, 0.46))
	style.border_color = Color(_team_tint.r, _team_tint.g, _team_tint.b, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_size = 14
	style.shadow_color = Color(_team_tint.r, _team_tint.g, _team_tint.b, 0.30)
	focus_plate.add_theme_stylebox_override("panel", style)

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
	sprite.z_index = 4
	add_child(sprite)
	_update_effect_player_sprite()

func _ensure_bars() -> void:
	if not (hp_bar and is_instance_valid(hp_bar)):
		hp_bar = UIBars.make_hp_bar()
		add_child(hp_bar)
		hp_bar.anchor_left = 0.0
		hp_bar.anchor_top = 0.0
		hp_bar.anchor_right = 1.0
		hp_bar.anchor_bottom = 0.0
		hp_bar.offset_left = 0.0
		hp_bar.offset_top = -22.0
		hp_bar.offset_right = 0.0
		hp_bar.offset_bottom = -14.0
		hp_bar.z_index = 8
		# HP tick marks
		if not (hp_ticks and is_instance_valid(hp_ticks)):
			hp_ticks = load("res://scripts/ui/combat/tick_marks.gd").new()
			add_child(hp_ticks)
			hp_ticks.anchor_left = 0.0
			hp_ticks.anchor_top = 0.0
			hp_ticks.anchor_right = 1.0
			hp_ticks.anchor_bottom = 0.0
			hp_ticks.offset_left = 0.0
			hp_ticks.offset_top = -22.0
			hp_ticks.offset_right = 0.0
			hp_ticks.offset_bottom = -14.0
			hp_ticks.z_index = 9
			hp_ticks.minor_step = 200
			hp_ticks.major_step = 1000
			hp_ticks.minor_color = Color(0, 0, 0, 0.45)
			hp_ticks.major_color = Color(0, 0, 0, 0.65)
	if not (mana_bar and is_instance_valid(mana_bar)):
		mana_bar = UIBars.make_mana_bar()
		add_child(mana_bar)
		mana_bar.anchor_left = 0.0
		mana_bar.anchor_top = 0.0
		mana_bar.anchor_right = 1.0
		mana_bar.anchor_bottom = 0.0
		mana_bar.offset_left = 0.0
		mana_bar.offset_top = -12.0
		mana_bar.offset_right = 0.0
		mana_bar.offset_bottom = -6.0
		mana_bar.z_index = 8
		# Mana tick marks
		if not (mana_ticks and is_instance_valid(mana_ticks)):
			mana_ticks = load("res://scripts/ui/combat/tick_marks.gd").new()
			add_child(mana_ticks)
			mana_ticks.anchor_left = 0.0
			mana_ticks.anchor_top = 0.0
			mana_ticks.anchor_right = 1.0
			mana_ticks.anchor_bottom = 0.0
			mana_ticks.offset_left = 0.0
			mana_ticks.offset_top = -12.0
			mana_ticks.offset_right = 0.0
			mana_ticks.offset_bottom = -6.0
			mana_ticks.z_index = 9
			mana_ticks.minor_step = 10
			mana_ticks.major_step = 50
			mana_ticks.minor_color = Color(0, 0, 0, 0.5)
			mana_ticks.major_color = Color(0, 0, 0, 0.7)
		# Shield bar (thin, above HP)
		if not (shield_bar and is_instance_valid(shield_bar)):
			shield_bar = ProgressBar.new()
			add_child(shield_bar)
			shield_bar.anchor_left = 0.0
			shield_bar.anchor_top = 0.0
			shield_bar.anchor_right = 1.0
			shield_bar.anchor_bottom = 0.0
			shield_bar.offset_left = 0.0
			shield_bar.offset_top = -30.0
			shield_bar.offset_right = 0.0
			shield_bar.offset_bottom = -23.0
			shield_bar.z_index = 3
			shield_bar.show_percentage = false
			shield_bar.min_value = 0
			shield_bar.max_value = 1
			shield_bar.value = 0
			# Style: thin white fill, same background
			var sbg: StyleBox = load("res://themes/pb_bg.tres")
			var sfill := StyleBoxFlat.new()
			sfill.bg_color = Color(0.85, 0.95, 1.0, 0.95)
			sfill.border_width_left = 1
			sfill.border_width_top = 1
			sfill.border_width_right = 1
			sfill.border_width_bottom = 1
			sfill.border_color = Color(1,1,1,0.15)
			shield_bar.add_theme_stylebox_override("background", sbg)
			shield_bar.add_theme_stylebox_override("fill", sfill)
			# Right-to-left fill
			if shield_bar.has_method("set_fill_mode"):
				# Godot 4 API: enum ProgressBar.FillMode
				shield_bar.fill_mode = 1 # RightToLeft
			else:
				shield_bar.fill_mode = 1
		if not (shield_ticks and is_instance_valid(shield_ticks)):
			shield_ticks = load("res://scripts/ui/combat/tick_marks.gd").new()
			add_child(shield_ticks)
			shield_ticks.anchor_left = 0.0
			shield_ticks.anchor_top = 0.0
			shield_ticks.anchor_right = 1.0
			shield_ticks.anchor_bottom = 0.0
			shield_ticks.offset_left = 0.0
			shield_ticks.offset_top = -30.0
			shield_ticks.offset_right = 0.0
			shield_ticks.offset_bottom = -23.0
			shield_ticks.z_index = 4
			shield_ticks.minor_step = 200
			shield_ticks.major_step = 1000
			shield_ticks.minor_color = Color(0.85, 0.95, 1.0, 0.55)
			shield_ticks.major_color = Color(1.0, 1.0, 1.0, 0.75)
			shield_ticks.rtl = true

func set_unit(u: Unit) -> void:
	unit = u
	_ensure_focus_plate()
	_ensure_sprite()
	_ensure_bars()
	_ensure_effect_player()
	_update_effect_player_sprite()
	_update_visuals()

func play_hit_flash(opts: Dictionary = {}) -> void:
	_ensure_effect_player()
	_update_effect_player_sprite()
	var payload := opts.duplicate(true)
	_effect_player.play(UnitEffectPlayer.EFFECT_HIT, payload)

func update_bars(updated_unit: Unit = null) -> void:
	if updated_unit:
		unit = updated_unit
	_update_bars()

# Avoid overriding Control.set_global_position(Vector2, bool)
func set_screen_position(pos: Vector2) -> void:
	_base_screen_pos = pos
	_update_screen_position()

func _ensure_effect_player() -> void:
	if _effect_player and is_instance_valid(_effect_player):
		return
	_effect_player = UnitEffectPlayer.new()
	_effect_player.name = "UnitEffectPlayer"
	add_child(_effect_player)
	_effect_player.configure(self, sprite)

func _update_effect_player_sprite() -> void:
	if _effect_player and is_instance_valid(_effect_player):
		_effect_player.set_sprite(sprite)

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
	var shield_max := 0
	var shield_val := 0
	if unit:
		hp_max = max(1, unit.max_hp)
		hp_val = clamp(unit.hp, 0, unit.max_hp)
		mana_max = max(0, unit.mana_max)
		mana_val = clamp(unit.mana, 0, unit.mana_max)
		shield_max = hp_max
		shield_val = clamp(int(unit.ui_shield), 0, shield_max)
	if hp_bar:
		hp_bar.max_value = hp_max
		hp_bar.value = hp_val
	if hp_ticks:
		hp_ticks.max_value = hp_max
	if mana_bar:
		mana_bar.max_value = mana_max
		mana_bar.value = mana_val
	if mana_ticks:
		mana_ticks.max_value = mana_max
	if shield_bar:
		shield_bar.visible = (shield_val > 0)
		if shield_val > 0:
			shield_bar.max_value = shield_max
			shield_bar.value = shield_val
	if shield_ticks:
		shield_ticks.visible = (shield_val > 0)
		if shield_val > 0:
			shield_ticks.max_value = shield_max

func set_size_px(new_size: Vector2) -> void:
	size_px = new_size
	size = size_px
	_update_visuals()

func set_team_tint(color: Color) -> void:
	_team_tint = color
	_ensure_focus_plate()

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
