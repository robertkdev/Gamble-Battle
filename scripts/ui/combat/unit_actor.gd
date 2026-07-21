extends Control
class_name UnitActor

const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")
const UnitEffectPlayer := preload("res://scripts/ui/vfx/unit_effect_player.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")

var unit: Unit
var focus_plate: Panel
var contact_shadow: Panel
var team_rim: Panel
var bar_plate: Panel
var portrait_motion_root: Control
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
var _screen_position_initialized: bool = false
var _effect_offset: Vector2 = Vector2.ZERO
var _texture_signature_cache: String = ""
var _bar_signature_cache: String = ""
var _bars_initialized: bool = false
var _knockup_offset_y: float = 0.0
var knockup_offset_y: float:
	get:
		return _knockup_offset_y
	set(value):
		_knockup_offset_y = value
		_effect_offset.y = value
		_update_screen_position()
var _knockup_tween: Tween = null
var _presentation_tween: Tween = null
var _idle_clock: float = 0.0
var _idle_phase: float = 0.0
var _presentation_state: String = "idle"
var _presentation_hidden_by_death: bool = false
var _presentation_death_in_progress: bool = false
var _last_hit_reaction_msec: int = -1000
var _presentation_offset: Vector2 = Vector2.ZERO
var _presentation_scale: Vector2 = Vector2.ONE
var _presentation_rotation: float = 0.0
var _presentation_alpha: float = 1.0
var _shadow_action_scale: Vector2 = Vector2.ONE
var _shadow_alpha: float = 1.0
var _applied_interface_alpha: float = -1.0

const IDLE_AMPLITUDE_PX: float = 1.35
const IDLE_PERIOD_S: float = 2.8
const MAX_PRESENTATION_OFFSET_PX: float = 22.0

static var diagnostics_enabled: bool = false
static var diagnostic_update_bars_calls: int = 0
static var diagnostic_bar_apply_calls: int = 0
static var diagnostic_bar_skip_calls: int = 0
static var diagnostic_texture_refresh_calls: int = 0
static var diagnostic_texture_skip_calls: int = 0
static var diagnostic_texture_load_attempts: int = 0
static var diagnostic_position_update_calls: int = 0
static var diagnostic_position_apply_calls: int = 0
static var diagnostic_position_skip_calls: int = 0

static func set_diagnostics_enabled(enabled: bool) -> void:
	diagnostics_enabled = bool(enabled)

static func reset_diagnostics() -> void:
	diagnostic_update_bars_calls = 0
	diagnostic_bar_apply_calls = 0
	diagnostic_bar_skip_calls = 0
	diagnostic_texture_refresh_calls = 0
	diagnostic_texture_skip_calls = 0
	diagnostic_texture_load_attempts = 0
	diagnostic_position_update_calls = 0
	diagnostic_position_apply_calls = 0
	diagnostic_position_skip_calls = 0

static func diagnostic_snapshot() -> Dictionary:
	return {
		"update_bars_calls": diagnostic_update_bars_calls,
		"bar_apply_calls": diagnostic_bar_apply_calls,
		"bar_skip_calls": diagnostic_bar_skip_calls,
		"texture_refresh_calls": diagnostic_texture_refresh_calls,
		"texture_skip_calls": diagnostic_texture_skip_calls,
		"texture_load_attempts": diagnostic_texture_load_attempts,
		"position_update_calls": diagnostic_position_update_calls,
		"position_apply_calls": diagnostic_position_apply_calls,
		"position_skip_calls": diagnostic_position_skip_calls
	}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_focus_plate()
	_ensure_contact_shadow()
	_ensure_sprite()
	_update_actor_visual_layout()
	_ensure_bars()
	_ensure_effect_player()
	_update_effect_player_sprite()
	_update_visuals()
	set_process(true)

func _process(delta: float) -> void:
	_idle_clock += maxf(0.0, delta)
	_apply_presentation_transform()

func _exit_tree() -> void:
	if _knockup_tween != null and is_instance_valid(_knockup_tween):
		_knockup_tween.kill()
	_knockup_tween = null
	_kill_presentation_tween()
	if _effect_player != null and is_instance_valid(_effect_player) and _effect_player.has_method("dispose"):
		_effect_player.dispose()
	_effect_player = null
	unit = null

func _ensure_contact_shadow() -> void:
	if contact_shadow != null and is_instance_valid(contact_shadow):
		if contact_shadow.get_parent() != self:
			contact_shadow.reparent(self)
		_apply_contact_shadow_style()
		_apply_contact_shadow_layout()
		return
	contact_shadow = Panel.new()
	contact_shadow.name = "ContactShadow"
	contact_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contact_shadow.z_index = 1
	add_child(contact_shadow)
	_apply_contact_shadow_style()
	_apply_contact_shadow_layout()

func _apply_contact_shadow_style() -> void:
	if contact_shadow == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.005, 0.004, 0.008, 0.54)
	style.corner_radius_top_left = 64
	style.corner_radius_top_right = 64
	style.corner_radius_bottom_left = 64
	style.corner_radius_bottom_right = 64
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 8
	contact_shadow.add_theme_stylebox_override("panel", style)

func _apply_contact_shadow_layout() -> void:
	if contact_shadow == null:
		return
	var shadow_width: float = maxf(28.0, size_px.x * 0.68)
	var shadow_height: float = maxf(9.0, size_px.y * 0.15)
	contact_shadow.anchor_left = 0.5
	contact_shadow.anchor_top = 0.78
	contact_shadow.anchor_right = 0.5
	contact_shadow.anchor_bottom = 0.78
	contact_shadow.offset_left = -shadow_width * 0.5
	contact_shadow.offset_top = -shadow_height * 0.5
	contact_shadow.offset_right = shadow_width * 0.5
	contact_shadow.offset_bottom = shadow_height * 0.5
	contact_shadow.pivot_offset = Vector2(shadow_width * 0.5, shadow_height * 0.5)

func _ensure_portrait_motion_root() -> void:
	if portrait_motion_root != null and is_instance_valid(portrait_motion_root):
		if portrait_motion_root.get_parent() != self:
			portrait_motion_root.reparent(self)
		_update_portrait_motion_root_layout()
		return
	portrait_motion_root = Control.new()
	portrait_motion_root.name = "PortraitMotionRoot"
	portrait_motion_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_motion_root.z_index = 4
	add_child(portrait_motion_root)
	_update_portrait_motion_root_layout()

func _update_portrait_motion_root_layout() -> void:
	if portrait_motion_root == null:
		return
	portrait_motion_root.anchor_left = 0.0
	portrait_motion_root.anchor_top = 0.0
	portrait_motion_root.anchor_right = 1.0
	portrait_motion_root.anchor_bottom = 1.0
	portrait_motion_root.offset_left = 0.0
	portrait_motion_root.offset_top = 0.0
	portrait_motion_root.offset_right = 0.0
	portrait_motion_root.offset_bottom = 0.0
	portrait_motion_root.pivot_offset = size_px * 0.5

func _ensure_focus_plate() -> void:
	if focus_plate and is_instance_valid(focus_plate):
		if focus_plate.get_parent() != self:
			add_child(focus_plate)
		_apply_focus_plate_style()
		_ensure_team_rim()
		return
	focus_plate = Panel.new()
	focus_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_plate.z_index = 0
	focus_plate.anchor_left = 0.0
	focus_plate.anchor_top = 0.56
	focus_plate.anchor_right = 1.0
	focus_plate.anchor_bottom = 1.0
	focus_plate.offset_left = -16.0
	focus_plate.offset_top = -4.0
	focus_plate.offset_right = 16.0
	focus_plate.offset_bottom = 14.0
	add_child(focus_plate)
	_apply_focus_plate_style()
	_ensure_team_rim()

func _apply_focus_plate_style() -> void:
	if focus_plate == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(_team_tint.r, _team_tint.g, _team_tint.b, min(_team_tint.a, 0.24))
	style.border_color = Color(_team_tint.r, _team_tint.g, _team_tint.b, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.shadow_size = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.56)
	var is_player: bool = _team_tint.b >= _team_tint.r
	var asset_tint: Color = Color(0.72, 0.88, 1.0, 1.0) if is_player else Color(1.0, 0.68, 0.60, 1.0)
	var asset: StyleBoxTexture = GothicUIAssets.unit_base_style(is_player, asset_tint)
	focus_plate.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(asset, style))

func _ensure_team_rim() -> void:
	if team_rim != null and is_instance_valid(team_rim):
		_apply_team_rim_style()
		return
	team_rim = Panel.new()
	team_rim.name = "TeamRim"
	team_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	team_rim.z_index = 3
	team_rim.anchor_left = 0.0
	team_rim.anchor_top = 0.0
	team_rim.anchor_right = 1.0
	team_rim.anchor_bottom = 1.0
	add_child(team_rim)
	_apply_team_rim_style()

func _apply_team_rim_style() -> void:
	if team_rim == null:
		return
	var rim_color: Color = Color(_team_tint.r, _team_tint.g, _team_tint.b, 0.88)
	team_rim.add_theme_stylebox_override("panel", GothicUIAssets.focus_outline_style(18, rim_color, 2))

func _update_actor_visual_layout() -> void:
	var visual_margin: float = max(5.0, min(size_px.x, size_px.y) * 0.09)
	_update_portrait_motion_root_layout()
	_apply_contact_shadow_layout()
	if sprite != null:
		sprite.offset_left = -visual_margin
		sprite.offset_top = -visual_margin * 1.45
		sprite.offset_right = visual_margin
		sprite.offset_bottom = visual_margin * 0.45
		sprite.modulate = Color.WHITE
	if team_rim != null:
		team_rim.offset_left = -visual_margin * 0.55
		team_rim.offset_top = -visual_margin * 0.85
		team_rim.offset_right = visual_margin * 0.55
		team_rim.offset_bottom = visual_margin * 0.35

func _ensure_bar_plate() -> void:
	if bar_plate and is_instance_valid(bar_plate):
		if bar_plate.get_parent() != self:
			add_child(bar_plate)
		_apply_bar_plate_style()
		return
	bar_plate = Panel.new()
	bar_plate.name = "BarPlate"
	bar_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_plate.anchor_left = 0.0
	bar_plate.anchor_top = 0.0
	bar_plate.anchor_right = 1.0
	bar_plate.anchor_bottom = 0.0
	bar_plate.offset_left = -6.0
	bar_plate.offset_top = -32.0
	bar_plate.offset_right = 6.0
	bar_plate.offset_bottom = -5.0
	bar_plate.z_index = 7
	add_child(bar_plate)
	_apply_bar_plate_style()

func _apply_bar_plate_style() -> void:
	if bar_plate == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.015, 0.021, 0.82)
	style.border_color = Color(0.44, 0.32, 0.20, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	bar_plate.add_theme_stylebox_override("panel", style)

func _ensure_sprite() -> void:
	_ensure_portrait_motion_root()
	if sprite and is_instance_valid(sprite):
		if sprite.get_parent() != portrait_motion_root:
			sprite.reparent(portrait_motion_root)
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
	sprite.z_index = 0
	portrait_motion_root.add_child(sprite)
	_update_effect_player_sprite()

func _ensure_bars() -> void:
	_ensure_bar_plate()
	if not (hp_bar and is_instance_valid(hp_bar)):
		hp_bar = UIBars.make_hp_bar()
		add_child(hp_bar)
		hp_bar.anchor_left = 0.0
		hp_bar.anchor_top = 0.0
		hp_bar.anchor_right = 1.0
		hp_bar.anchor_bottom = 0.0
		hp_bar.offset_left = 5.0
		hp_bar.offset_top = -25.0
		hp_bar.offset_right = -5.0
		hp_bar.offset_bottom = -16.0
		hp_bar.z_index = 8
		# HP tick marks
		if not (hp_ticks and is_instance_valid(hp_ticks)):
			hp_ticks = load("res://scripts/ui/combat/tick_marks.gd").new()
			add_child(hp_ticks)
			hp_ticks.anchor_left = 0.0
			hp_ticks.anchor_top = 0.0
			hp_ticks.anchor_right = 1.0
			hp_ticks.anchor_bottom = 0.0
			hp_ticks.offset_left = 5.0
			hp_ticks.offset_top = -25.0
			hp_ticks.offset_right = -5.0
			hp_ticks.offset_bottom = -16.0
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
		mana_bar.offset_left = 5.0
		mana_bar.offset_top = -14.0
		mana_bar.offset_right = -5.0
		mana_bar.offset_bottom = -8.0
		mana_bar.z_index = 8
		# Mana tick marks
		if not (mana_ticks and is_instance_valid(mana_ticks)):
			mana_ticks = load("res://scripts/ui/combat/tick_marks.gd").new()
			add_child(mana_ticks)
			mana_ticks.anchor_left = 0.0
			mana_ticks.anchor_top = 0.0
			mana_ticks.anchor_right = 1.0
			mana_ticks.anchor_bottom = 0.0
			mana_ticks.offset_left = 5.0
			mana_ticks.offset_top = -14.0
			mana_ticks.offset_right = -5.0
			mana_ticks.offset_bottom = -8.0
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
			shield_bar.offset_left = 5.0
			shield_bar.offset_top = -30.0
			shield_bar.offset_right = -5.0
			shield_bar.offset_bottom = -23.0
			shield_bar.z_index = 8
			shield_bar.show_percentage = false
			shield_bar.min_value = 0
			shield_bar.max_value = 1
			shield_bar.value = 0
			# Style: thin white fill, same background
			var sbg: StyleBox = load("res://themes/pb_bg.tres")
			var sfill: StyleBoxFlat = StyleBoxFlat.new()
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
			shield_ticks.offset_left = 5.0
			shield_ticks.offset_top = -30.0
			shield_ticks.offset_right = -5.0
			shield_ticks.offset_bottom = -23.0
			shield_ticks.z_index = 9
			shield_ticks.minor_step = 200
			shield_ticks.major_step = 1000
			shield_ticks.minor_color = Color(0.85, 0.95, 1.0, 0.55)
			shield_ticks.major_color = Color(1.0, 1.0, 1.0, 0.75)
			shield_ticks.rtl = true

func set_unit(u: Unit) -> void:
	unit = u
	_refresh_idle_phase()
	_ensure_focus_plate()
	_ensure_contact_shadow()
	_ensure_sprite()
	_update_actor_visual_layout()
	_ensure_bars()
	_ensure_effect_player()
	_update_effect_player_sprite()
	_update_visuals()

func play_hit_flash(opts: Dictionary = {}) -> void:
	_ensure_effect_player()
	_update_effect_player_sprite()
	var payload: Dictionary = opts.duplicate(true)
	_effect_player.play(UnitEffectPlayer.EFFECT_HIT, payload)
	if not bool(payload.get("suppress_motion", false)) and not _presentation_death_in_progress:
		var source_global: Vector2 = _fallback_source_global()
		var source_value: Variant = payload.get("source_global", payload.get("source_position", source_global))
		if source_value is Vector2:
			source_global = source_value as Vector2
		play_hit_reaction(source_global, payload)

func update_bars(updated_unit: Unit = null) -> void:
	if updated_unit:
		unit = updated_unit
	_update_bars()

# Avoid overriding Control.set_global_position(Vector2, bool)
func set_screen_position(pos: Vector2) -> void:
	if diagnostics_enabled:
		diagnostic_position_update_calls += 1
	if _screen_position_initialized and pos.is_equal_approx(_base_screen_pos):
		if diagnostics_enabled:
			diagnostic_position_skip_calls += 1
		return
	_base_screen_pos = pos
	_screen_position_initialized = true
	if diagnostics_enabled:
		diagnostic_position_apply_calls += 1
	_update_screen_position()

func _ensure_effect_player() -> void:
	if _effect_player and is_instance_valid(_effect_player):
		return
	_effect_player = UnitEffectPlayer.new()
	_effect_player.name = "UnitEffectPlayer"
	add_child(_effect_player)
	_effect_player.configure(self, sprite)
	_effect_player.set_default_overlay_parents(self, portrait_motion_root)

func _update_effect_player_sprite() -> void:
	if _effect_player and is_instance_valid(_effect_player):
		_effect_player.set_sprite(sprite)
		_effect_player.set_default_overlay_parents(self, portrait_motion_root)

func _update_screen_position() -> void:
	global_position = _base_screen_pos - size * 0.5 + _effect_offset

func _update_visuals() -> void:
	_update_texture()
	_update_bars()

func _update_texture() -> void:
	_ensure_sprite()
	if sprite == null:
		return
	var sprite_path: String = String(unit.sprite_path) if unit != null else ""
	var next_signature: String = sprite_path
	if next_signature == "":
		next_signature = "fallback:%d:%d" % [int(size_px.x), int(size_px.y)]
	if next_signature == _texture_signature_cache and sprite.texture != null:
		if diagnostics_enabled:
			diagnostic_texture_skip_calls += 1
		return
	if diagnostics_enabled:
		diagnostic_texture_refresh_calls += 1
	var tex: Texture2D = null
	if sprite_path != "":
		if diagnostics_enabled:
			diagnostic_texture_load_attempts += 1
		var unit_id: String = String(unit.id) if unit != null else ""
		tex = UnitArtPresentation.texture_for(unit_id, sprite_path)
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
	_texture_signature_cache = next_signature

func _update_bars() -> void:
	_ensure_bars()
	if diagnostics_enabled:
		diagnostic_update_bars_calls += 1
	var hp_max: int = 1
	var hp_val: int = 1
	var mana_max: int = 0
	var mana_val: int = 0
	var shield_max: int = 0
	var shield_val: int = 0
	if unit:
		hp_max = max(1, unit.max_hp)
		hp_val = clamp(unit.hp, 0, unit.max_hp)
		mana_max = max(0, unit.mana_max)
		mana_val = clamp(unit.mana, 0, unit.mana_max)
		shield_max = hp_max
		shield_val = clamp(int(unit.ui_shield), 0, shield_max)
	var unit_instance_id: int = int(unit.get_instance_id()) if unit != null else 0
	var next_signature: String = "%d:%d:%d:%d:%d:%d:%d" % [
		unit_instance_id,
		hp_max,
		hp_val,
		mana_max,
		mana_val,
		shield_max,
		shield_val
	]
	if _bars_initialized and next_signature == _bar_signature_cache:
		if diagnostics_enabled:
			diagnostic_bar_skip_calls += 1
		return
	if diagnostics_enabled:
		diagnostic_bar_apply_calls += 1
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
	_bar_signature_cache = next_signature
	_bars_initialized = true

func set_size_px(new_size: Vector2) -> void:
	size_px = new_size
	size = size_px
	_update_actor_visual_layout()
	_update_visuals()
	_update_screen_position()
	_apply_presentation_transform()

func set_team_tint(color: Color) -> void:
	_team_tint = color
	_ensure_focus_plate()
	_ensure_team_rim()

func play_attack_motion(target_global: Vector2, style: Dictionary = {}) -> void:
	if _presentation_death_in_progress:
		return
	_ensure_portrait_motion_root()
	_ensure_contact_shadow()
	_kill_presentation_tween()
	var direction: Vector2 = _direction_from_global_point(target_global, _default_attack_direction())
	var shape: String = String(style.get("shape", "orb")).strip_edges().to_lower()
	var profile: Dictionary[String, Variant] = _attack_motion_profile(shape)
	var lunge: float = minf(MAX_PRESENTATION_OFFSET_PX, float(profile.get("lunge", 9.0)))
	var lift: float = float(profile.get("lift", 0.0))
	var anticipation_s: float = float(profile.get("anticipation_s", 0.06))
	var strike_s: float = float(profile.get("strike_s", 0.08))
	var recovery_s: float = float(profile.get("recovery_s", 0.18))
	var tilt: float = float(profile.get("tilt", 0.045)) * _rotation_sign(direction)
	var anticipation_offset: Vector2 = -direction * minf(4.0, lunge * 0.30) + Vector2(0.0, lift * 0.35)
	var strike_offset: Vector2 = direction * lunge + Vector2(0.0, lift)
	_set_presentation_state("anticipation")
	_presentation_tween = create_tween()
	_presentation_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(self, "presentation_offset", anticipation_offset, anticipation_s)
	_presentation_tween.parallel().tween_property(self, "presentation_scale", profile.get("anticipation_scale", Vector2(0.96, 1.04)), anticipation_s)
	_presentation_tween.parallel().tween_property(self, "presentation_rotation", -tilt * 0.55, anticipation_s)
	_presentation_tween.tween_callback(Callable(self, "_set_presentation_state").bind("strike"))
	_presentation_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(self, "presentation_offset", strike_offset, strike_s)
	_presentation_tween.parallel().tween_property(self, "presentation_scale", profile.get("strike_scale", Vector2(1.06, 0.96)), strike_s)
	_presentation_tween.parallel().tween_property(self, "presentation_rotation", tilt, strike_s)
	_presentation_tween.parallel().tween_property(self, "shadow_action_scale", Vector2(1.18, 0.82), strike_s)
	_presentation_tween.tween_callback(Callable(self, "_set_presentation_state").bind("recovery"))
	_presentation_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(self, "presentation_offset", Vector2.ZERO, recovery_s)
	_presentation_tween.parallel().tween_property(self, "presentation_scale", Vector2.ONE, recovery_s)
	_presentation_tween.parallel().tween_property(self, "presentation_rotation", 0.0, recovery_s)
	_presentation_tween.parallel().tween_property(self, "shadow_action_scale", Vector2.ONE, recovery_s)
	_presentation_tween.tween_callback(Callable(self, "_complete_presentation_action"))

func play_hit_reaction(source_global: Vector2, opts: Dictionary = {}) -> void:
	if _presentation_death_in_progress:
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_hit_reaction_msec < 20:
		return
	_last_hit_reaction_msec = now_msec
	_kill_presentation_tween()
	var away: Vector2 = _direction_from_global_point(source_global, _default_hit_direction()) * -1.0
	var crit: bool = bool(opts.get("crit", false))
	var strength: float = 9.0 if crit else 6.0
	var strike_s: float = 0.075 if crit else 0.06
	var recovery_s: float = 0.18 if crit else 0.14
	_set_presentation_state("hit")
	_presentation_tween = create_tween()
	_presentation_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(self, "presentation_offset", away * strength, strike_s)
	_presentation_tween.parallel().tween_property(self, "presentation_scale", Vector2(1.06, 0.90), strike_s)
	_presentation_tween.parallel().tween_property(self, "presentation_rotation", _rotation_sign(away) * (0.085 if crit else 0.055), strike_s)
	_presentation_tween.parallel().tween_property(self, "shadow_action_scale", Vector2(1.22, 0.76), strike_s)
	_presentation_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(self, "presentation_offset", Vector2.ZERO, recovery_s)
	_presentation_tween.parallel().tween_property(self, "presentation_scale", Vector2.ONE, recovery_s)
	_presentation_tween.parallel().tween_property(self, "presentation_rotation", 0.0, recovery_s)
	_presentation_tween.parallel().tween_property(self, "shadow_action_scale", Vector2.ONE, recovery_s)
	_presentation_tween.tween_callback(Callable(self, "_complete_presentation_action"))

func queue_death_reaction(source_global: Vector2, opts: Dictionary = {}) -> void:
	play_death_reaction(source_global, opts)

func play_death_reaction(source_global: Vector2, opts: Dictionary = {}) -> void:
	if _presentation_death_in_progress or _presentation_hidden_by_death:
		return
	_kill_presentation_tween()
	visible = true
	_presentation_death_in_progress = true
	var away: Vector2 = _direction_from_global_point(source_global, _default_hit_direction()) * -1.0
	var duration_scale: float = clampf(float(opts.get("duration_scale", 1.0)), 0.25, 2.0)
	var collapse_s: float = 0.16 * duration_scale
	var fade_s: float = 0.30 * duration_scale
	_set_presentation_state("death")
	_presentation_tween = create_tween()
	_presentation_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(self, "presentation_offset", away * 5.0 + Vector2(0.0, 4.0), collapse_s)
	_presentation_tween.parallel().tween_property(self, "presentation_scale", Vector2(1.08, 0.80), collapse_s)
	_presentation_tween.parallel().tween_property(self, "presentation_rotation", _rotation_sign(away) * 0.12, collapse_s)
	_presentation_tween.parallel().tween_property(self, "shadow_action_scale", Vector2(1.34, 0.72), collapse_s)
	_presentation_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_presentation_tween.tween_property(self, "presentation_offset", away * 7.0 + Vector2(0.0, 12.0), fade_s)
	_presentation_tween.parallel().tween_property(self, "presentation_scale", Vector2(1.12, 0.68), fade_s)
	_presentation_tween.parallel().tween_property(self, "presentation_alpha", 0.0, fade_s)
	_presentation_tween.parallel().tween_property(self, "shadow_action_scale", Vector2(1.58, 0.60), fade_s)
	_presentation_tween.parallel().tween_property(self, "shadow_alpha", 0.0, fade_s)
	_presentation_tween.tween_callback(Callable(self, "_complete_death_reaction"))

func sync_alive_visibility(alive: bool) -> void:
	if alive:
		if _presentation_hidden_by_death or not visible:
			_reset_presentation_visuals()
		visible = true
		_presentation_hidden_by_death = false
		_presentation_death_in_progress = false
		_set_presentation_state("idle")
		return
	if _presentation_death_in_progress:
		visible = true
		return
	if _presentation_hidden_by_death:
		visible = false
		return
	play_death_reaction(_fallback_source_global())

func is_death_in_progress() -> bool:
	return _presentation_death_in_progress

func presentation_snapshot() -> Dictionary[String, Variant]:
	return {
		"state": _presentation_state,
		"offset": _presentation_offset,
		"scale": _presentation_scale,
		"rotation": _presentation_rotation,
		"alpha": _presentation_alpha,
		"shadow_scale": _shadow_action_scale,
		"shadow_alpha": _shadow_alpha,
		"idle_phase": _idle_phase,
		"portrait_position": portrait_motion_root.position if portrait_motion_root != null else Vector2.ZERO,
		"has_motion_root": portrait_motion_root != null and is_instance_valid(portrait_motion_root),
		"has_contact_shadow": contact_shadow != null and is_instance_valid(contact_shadow),
		"sprite_parent_is_motion_root": sprite != null and sprite.get_parent() == portrait_motion_root,
		"death_in_progress": _presentation_death_in_progress,
		"hidden_by_death": _presentation_hidden_by_death,
		"visible": visible,
	}

var presentation_offset: Vector2:
	get:
		return _presentation_offset
	set(value):
		_presentation_offset = value.limit_length(MAX_PRESENTATION_OFFSET_PX)
		_apply_presentation_transform()

var presentation_scale: Vector2:
	get:
		return _presentation_scale
	set(value):
		_presentation_scale = value
		_apply_presentation_transform()

var presentation_rotation: float:
	get:
		return _presentation_rotation
	set(value):
		_presentation_rotation = value
		_apply_presentation_transform()

var presentation_alpha: float:
	get:
		return _presentation_alpha
	set(value):
		_presentation_alpha = clampf(value, 0.0, 1.0)
		_apply_presentation_transform()

var shadow_action_scale: Vector2:
	get:
		return _shadow_action_scale
	set(value):
		_shadow_action_scale = value
		_apply_presentation_transform()

var shadow_alpha: float:
	get:
		return _shadow_alpha
	set(value):
		_shadow_alpha = clampf(value, 0.0, 1.0)
		_apply_presentation_transform()

func _apply_presentation_transform() -> void:
	if portrait_motion_root == null or not is_instance_valid(portrait_motion_root):
		return
	var idle_weight: float = 1.0 if _presentation_state == "idle" else 0.12
	var idle_angle: float = _idle_phase + (_idle_clock / IDLE_PERIOD_S) * TAU
	var idle_y: float = sin(idle_angle) * IDLE_AMPLITUDE_PX * idle_weight
	var idle_scale_delta: float = sin(idle_angle) * 0.008 * idle_weight
	portrait_motion_root.position = _presentation_offset + Vector2(0.0, idle_y)
	portrait_motion_root.scale = _presentation_scale * (1.0 + idle_scale_delta)
	portrait_motion_root.rotation = _presentation_rotation
	portrait_motion_root.modulate.a = _presentation_alpha
	_set_interface_alpha(_presentation_alpha)
	if contact_shadow != null and is_instance_valid(contact_shadow):
		var lift_ratio: float = clampf(maxf(0.0, -_presentation_offset.y) / MAX_PRESENTATION_OFFSET_PX, 0.0, 1.0)
		contact_shadow.scale = _shadow_action_scale * Vector2(1.0 - lift_ratio * 0.12, 1.0 - lift_ratio * 0.18)
		contact_shadow.modulate.a = _shadow_alpha * (1.0 - lift_ratio * 0.38)

func _set_interface_alpha(alpha: float) -> void:
	if is_equal_approx(_applied_interface_alpha, alpha):
		return
	_applied_interface_alpha = alpha
	var interface_nodes: Array[CanvasItem] = []
	if focus_plate != null:
		interface_nodes.append(focus_plate)
	if team_rim != null:
		interface_nodes.append(team_rim)
	if bar_plate != null:
		interface_nodes.append(bar_plate)
	if hp_bar != null:
		interface_nodes.append(hp_bar)
	if mana_bar != null:
		interface_nodes.append(mana_bar)
	if shield_bar != null:
		interface_nodes.append(shield_bar)
	if hp_ticks != null:
		interface_nodes.append(hp_ticks)
	if mana_ticks != null:
		interface_nodes.append(mana_ticks)
	if shield_ticks != null:
		interface_nodes.append(shield_ticks)
	for item: CanvasItem in interface_nodes:
		if item != null and is_instance_valid(item):
			item.modulate.a = alpha

func _refresh_idle_phase() -> void:
	var identity: String = String(unit.id) if unit != null else str(get_instance_id())
	_idle_phase = (float(posmod(identity.hash(), 1000)) / 1000.0) * TAU

func _attack_motion_profile(shape: String) -> Dictionary[String, Variant]:
	if ["hammer", "shield", "stone", "blood"].has(shape):
		return {"lunge": 20.0, "lift": 1.0, "anticipation_s": 0.085, "strike_s": 0.10, "recovery_s": 0.22, "tilt": 0.085, "anticipation_scale": Vector2(1.10, 0.86), "strike_scale": Vector2(1.16, 0.86)}
	if ["needle", "bolt", "card", "paper"].has(shape):
		return {"lunge": 13.0, "lift": -1.0, "anticipation_s": 0.045, "strike_s": 0.065, "recovery_s": 0.15, "tilt": 0.055, "anticipation_scale": Vector2(0.93, 1.06), "strike_scale": Vector2(1.10, 0.94)}
	if ["rune", "ring", "glyph", "bubble", "star", "crescent", "orb"].has(shape):
		return {"lunge": 11.0, "lift": -10.0, "anticipation_s": 0.075, "strike_s": 0.10, "recovery_s": 0.22, "tilt": 0.095, "anticipation_scale": Vector2(0.90, 0.90), "strike_scale": Vector2(1.15, 1.15)}
	return {"lunge": 16.0, "lift": -1.0, "anticipation_s": 0.06, "strike_s": 0.08, "recovery_s": 0.18, "tilt": 0.075, "anticipation_scale": Vector2(0.92, 1.07), "strike_scale": Vector2(1.13, 0.91)}

func _direction_from_global_point(global_point: Vector2, fallback: Vector2) -> Vector2:
	var origin: Vector2 = get_global_rect().get_center()
	var direction: Vector2 = global_point - origin
	if direction.length_squared() <= 0.001:
		return fallback.normalized()
	return direction.normalized()

func _default_attack_direction() -> Vector2:
	return Vector2(0.0, -1.0) if _is_player_team() else Vector2(0.0, 1.0)

func _default_hit_direction() -> Vector2:
	return _default_attack_direction() * -1.0

func _fallback_source_global() -> Vector2:
	return get_global_rect().get_center() - _default_hit_direction() * 100.0

func _is_player_team() -> bool:
	return _team_tint.b >= _team_tint.r

func _rotation_sign(direction: Vector2) -> float:
	if absf(direction.x) > 0.05:
		return signf(direction.x)
	return -1.0 if _is_player_team() else 1.0

func _set_presentation_state(next_state: String) -> void:
	_presentation_state = next_state

func _complete_presentation_action() -> void:
	_presentation_tween = null
	_set_presentation_state("idle")
	_apply_presentation_transform()

func _complete_death_reaction() -> void:
	_presentation_tween = null
	_presentation_death_in_progress = false
	_presentation_hidden_by_death = true
	visible = false
	_reset_presentation_visuals()
	_set_presentation_state("dead")

func _reset_presentation_visuals() -> void:
	_presentation_offset = Vector2.ZERO
	_presentation_scale = Vector2.ONE
	_presentation_rotation = 0.0
	_presentation_alpha = 1.0
	_shadow_action_scale = Vector2.ONE
	_shadow_alpha = 1.0
	_apply_presentation_transform()

func _kill_presentation_tween() -> void:
	if _presentation_tween != null and is_instance_valid(_presentation_tween):
		_presentation_tween.kill()
	_presentation_tween = null

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
