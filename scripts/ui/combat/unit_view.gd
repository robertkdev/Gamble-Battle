extends "res://scripts/ui/drag/drag_and_droppable.gd"
class_name UnitView

const UI = preload("res://scripts/constants/ui_constants.gd")
const TextureUtils = preload("res://scripts/util/texture_utils.gd")

var unit
var sprite
var hp_bar
var mana_bar
var hp_ticks
var mana_ticks
var _levelup_flash_tween: Tween
var _scan_material: ShaderMaterial
var _scan_tween: Tween

const TILE_SIZE = UI.TILE_SIZE

func _ready() -> void:
	super._ready()
	_ensure_children()
	# Drag base config
	content_root_path = NodePath(".")
	drag_size = Vector2(TILE_SIZE, TILE_SIZE)
	# Drag phases left default (allowed) to avoid compile-time deps

func _ensure_children() -> void:
	if not sprite:
		sprite = TextureRect.new()
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
		sprite.anchor_left = 0.0
		sprite.anchor_top = 0.0
		sprite.anchor_right = 1.0
		sprite.anchor_bottom = 1.0
		sprite.offset_left = 0.0
		sprite.offset_top = 0.0
		sprite.offset_right = 0.0
		sprite.offset_bottom = 0.0
	if not hp_bar:
		hp_bar = load("res://scripts/ui/combat/ui_bars.gd").make_hp_bar()
		add_child(hp_bar)
		hp_bar.anchor_left = 0.0
		hp_bar.anchor_top = 0.0
		hp_bar.anchor_right = 1.0
		hp_bar.anchor_bottom = 0.0
		hp_bar.offset_left = 0.0
		hp_bar.offset_top = -22.0
		hp_bar.offset_right = 0.0
		hp_bar.offset_bottom = -14.0
		# HP tick marks overlay
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
			hp_ticks.z_index = 2
			hp_ticks.minor_step = 200
			hp_ticks.major_step = 1000
			hp_ticks.minor_color = Color(0, 0, 0, 0.45)
			hp_ticks.major_color = Color(0, 0, 0, 0.65)
	if not mana_bar:
		mana_bar = load("res://scripts/ui/combat/ui_bars.gd").make_mana_bar()
		add_child(mana_bar)
		mana_bar.anchor_left = 0.0
		mana_bar.anchor_top = 0.0
		mana_bar.anchor_right = 1.0
		mana_bar.anchor_bottom = 0.0
		mana_bar.offset_left = 0.0
		mana_bar.offset_top = -12.0
		mana_bar.offset_right = 0.0
		mana_bar.offset_bottom = -6.0
		# Mana tick marks overlay
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
			mana_ticks.z_index = 2
			mana_ticks.minor_step = 10
			mana_ticks.major_step = 50
			mana_ticks.minor_color = Color(0, 0, 0, 0.5)
			mana_ticks.major_color = Color(0, 0, 0, 0.7)
	# DragAndDroppable wires gui_input

func set_unit(u: Unit) -> void:
	unit = u
	_ensure_children()
	_refresh_visual()

func _refresh_visual() -> void:
	if not unit:
		return
	# Sprite
	var tex: Texture2D = null
	if unit.sprite_path != "":
		tex = load(unit.sprite_path)
	if tex == null:
		tex = TextureUtils.make_circle_texture(Color(0.8, 0.8, 0.8), 96)
	sprite.texture = tex
	# Bars
	if hp_bar:
		hp_bar.max_value = max(1, unit.max_hp)
		hp_bar.value = clamp(unit.hp, 0, unit.max_hp)
		if hp_ticks:
			hp_ticks.max_value = max(1, unit.max_hp)
	if mana_bar:
		mana_bar.max_value = max(0, unit.mana_max)
		mana_bar.value = clamp(unit.mana, 0, unit.mana_max)
		if mana_ticks:
			mana_ticks.max_value = max(0, unit.mana_max)

func play_level_up(to_level: int = 0) -> void:
	# Scale punch + quick flash on sprite, plus expanding ring VFX
	_ensure_children()
	# Debug print to verify this is firing
	var uname: String = (String(unit.name) if unit != null else "")
	print("[UnitView] play_level_up -> ", uname, " to ", int(to_level))
	if sprite:
		# Kill existing tween
		if _levelup_flash_tween and is_instance_valid(_levelup_flash_tween):
			_levelup_flash_tween.kill()
		var base_scale = sprite.scale
		var base_mod = sprite.modulate
		sprite.modulate = Color(1, 1, 1, 1)
		_levelup_flash_tween = create_tween()
		_levelup_flash_tween.set_parallel(true)
		_levelup_flash_tween.tween_property(sprite, "scale", base_scale * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_levelup_flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
		_levelup_flash_tween.chain().set_parallel(true)
		_levelup_flash_tween.tween_property(sprite, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_levelup_flash_tween.tween_property(sprite, "modulate", base_mod, 0.14)
	# Spawn ring VFX centered over the tile
	var ring = load("res://scripts/ui/vfx/level_up_vfx.gd").new()
	add_child(ring)
	ring.z_index = 100
	ring.anchor_left = 0.0
	ring.anchor_top = 0.0
	ring.anchor_right = 1.0
	ring.anchor_bottom = 1.0
	ring.offset_left = 0
	ring.offset_top = 0
	ring.offset_right = 0
	ring.offset_bottom = 0
	# Slightly increase radii on higher level ups
	if to_level >= 3:
		ring.end_radius = 40.0
		ring.color = Color(1.0, 0.92, 0.55, 0.95)

	# Strong debug flash overlay to guarantee visibility during testing
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.45)
	add_child(flash)
	flash.z_index = 120
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.offset_left = 0
	flash.offset_top = 0
	flash.offset_right = 0
	flash.offset_bottom = 0
	var ft := create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ft.finished.connect(func(): if is_instance_valid(flash): flash.queue_free())

	# Bottom-up scan highlight over the sprite's non-transparent pixels
	_play_scan_highlight(0.55)

func _play_scan_highlight(duration: float = 0.6) -> void:
	if sprite == null:
		return
	# Build/reuse shader material
	if _scan_material == null or not is_instance_valid(_scan_material):
		var sh: Shader = load("res://shaders/scan_highlight.gdshader")
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_scan_material = mat
	_scan_material.set_shader_parameter("width", 0.22)
	_scan_material.set_shader_parameter("strength", 0.85)
	_scan_material.set_shader_parameter("alpha_threshold", 0.01)
	_scan_material.set_shader_parameter("color", Color(1.0, 0.9, 0.3, 1.0))
	_scan_material.set_shader_parameter("progress", 0.0)
	# Apply to sprite
	sprite.material = _scan_material
	# Animate progress 0->1 (bottom to top)
	if _scan_tween and is_instance_valid(_scan_tween):
		_scan_tween.kill()
	_scan_tween = create_tween()
	_scan_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var setter := func(v): if _scan_material and is_instance_valid(_scan_material): _scan_material.set_shader_parameter("progress", float(v))
	_scan_tween.tween_method(setter, 0.0, 1.0, max(0.1, float(duration)))
	_scan_tween.finished.connect(func():
		if is_instance_valid(self) and is_instance_valid(sprite):
			# Clear material to avoid affecting normal rendering
			if sprite.material == _scan_material:
				sprite.material = null
	)

func update_from_unit(u: Unit) -> void:
	if unit != u:
		unit = u
	_refresh_visual()

func attach_to(tile: Control) -> void:
	if not tile:
		return
	var par = get_parent()
	if par:
		par.remove_child(self)
	tile.add_child(self)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if _grid:
		_orig_tile_idx = _grid.index_of(self)

func enable_drag(grid: BoardGrid) -> void:
	set_drop_grid(grid)




## moved to TextureUtils.make_circle_texture
