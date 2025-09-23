extends DragAndDroppable
class_name UnitView

const UI := preload("res://scripts/constants/ui_constants.gd")

var unit: Unit
var sprite: TextureRect
var hp_bar: ProgressBar
var mana_bar: ProgressBar

const TILE_SIZE := UI.TILE_SIZE

func _ready() -> void:
	super._ready()
	_ensure_children()
	# Drag base config
	content_root_path = NodePath(".")
	drag_size = Vector2(TILE_SIZE, TILE_SIZE)
	# Allow drag outside of combat for units
	allowed_phases = [GameState.GamePhase.PREVIEW, GameState.GamePhase.POST_COMBAT]

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
		hp_bar.offset_top = 0.0
		hp_bar.offset_right = 0.0
		hp_bar.offset_bottom = 8.0
	if not mana_bar:
		mana_bar = load("res://scripts/ui/combat/ui_bars.gd").make_mana_bar()
		add_child(mana_bar)
		mana_bar.anchor_left = 0.0
		mana_bar.anchor_top = 0.0
		mana_bar.anchor_right = 1.0
		mana_bar.anchor_bottom = 0.0
		mana_bar.offset_left = 0.0
		mana_bar.offset_top = 10.0
		mana_bar.offset_right = 0.0
		mana_bar.offset_bottom = 18.0
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
		tex = _make_circle_texture(Color(0.8, 0.8, 0.8), 96)
	sprite.texture = tex
	# Bars
	if hp_bar:
		hp_bar.max_value = max(1, unit.max_hp)
		hp_bar.value = clamp(unit.hp, 0, unit.max_hp)
	if mana_bar:
		mana_bar.max_value = max(0, unit.mana_max)
		mana_bar.value = clamp(unit.mana, 0, unit.mana_max)

func update_from_unit(u: Unit) -> void:
	if unit != u:
		unit = u
	_refresh_visual()

func attach_to(tile: Control) -> void:
	if not tile:
		return
	var par := get_parent()
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




func _make_circle_texture(color: Color, tex_size: int) -> ImageTexture:
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(tex_size) * 0.5
	var cy := float(tex_size) * 0.5
	var r := float(tex_size) * 0.45
	var r2 := r * r
	for y in range(tex_size):
		for x in range(tex_size):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d2 := dx * dx + dy * dy
			if d2 <= r2:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	return tex
