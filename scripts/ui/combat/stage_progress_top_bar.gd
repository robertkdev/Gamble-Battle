extends PanelContainer
class_name StageProgressTopBar

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")

const ICON_SIZE: Vector2 = Vector2(52.0, 52.0)
const BAR_MIN_SIZE: Vector2 = Vector2(560.0, 66.0)
const SELECTED_TEXTURE_PATHS: PackedStringArray = [
	"res://assets/ui/stage_icons/stage_1_creep_selected.png",
	"res://assets/ui/stage_icons/stage_2_challenge_selected.png",
	"res://assets/ui/stage_icons/stage_3_challenge_selected.png",
	"res://assets/ui/stage_icons/stage_4_boss_selected.png",
	"res://assets/ui/stage_icons/stage_5_mirror_selected.png",
]
const UNSELECTED_TEXTURE_PATHS: PackedStringArray = [
	"res://assets/ui/stage_icons/stage_1_creep_unselected.png",
	"res://assets/ui/stage_icons/stage_2_challenge_unselected.png",
	"res://assets/ui/stage_icons/stage_3_challenge_unselected.png",
	"res://assets/ui/stage_icons/stage_4_boss_unselected.png",
	"res://assets/ui/stage_icons/stage_5_mirror_unselected.png",
]
const STAGE_TOOLTIPS: PackedStringArray = [
	"Stage 1: Creeps",
	"Stage 2: Challenge",
	"Stage 3: Challenge",
	"Stage 4: Boss",
	"Stage 5: Mirror",
]

var _row: HBoxContainer
var _chapter_label: Label
var _icons: Array[TextureRect] = []
var _texture_cache: Dictionary[String, Texture2D] = {}

func _ready() -> void:
	_ensure_built()

func update_progress(chapter: int, stage_in_chapter: int, total_stages: int) -> void:
	_ensure_built()
	var safe_chapter: int = max(1, int(chapter))
	var safe_total: int = clampi(int(total_stages), 1, SELECTED_TEXTURE_PATHS.size())
	var safe_stage: int = clampi(int(stage_in_chapter), 1, safe_total)
	_chapter_label.text = ChapterCatalog.display_name_for(safe_chapter)
	for index: int in range(_icons.size()):
		var icon: TextureRect = _icons[index]
		var stage_number: int = index + 1
		icon.visible = stage_number <= safe_total
		if not icon.visible:
			continue
		var selected: bool = stage_number == safe_stage
		var texture_path: String = SELECTED_TEXTURE_PATHS[index] if selected else UNSELECTED_TEXTURE_PATHS[index]
		icon.texture = _load_icon_texture(texture_path)
		icon.tooltip_text = STAGE_TOOLTIPS[index]
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.78, 0.78, 0.78, 1.0)

func _ensure_built() -> void:
	if _row != null:
		return
	custom_minimum_size = BAR_MIN_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _make_panel_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 12)
	margin.add_child(_row)

	_chapter_label = Label.new()
	_chapter_label.name = "ChapterLabel"
	_chapter_label.custom_minimum_size = Vector2(150.0, 0.0)
	_chapter_label.text = "Chapter 1"
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chapter_label.add_theme_font_size_override("font_size", 24)
	_chapter_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.60, 1.0))
	_chapter_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	_chapter_label.add_theme_constant_override("shadow_offset_x", 1)
	_chapter_label.add_theme_constant_override("shadow_offset_y", 2)
	_row.add_child(_chapter_label)

	for index: int in range(SELECTED_TEXTURE_PATHS.size()):
		var icon: TextureRect = _make_icon(index)
		_icons.append(icon)
		_row.add_child(icon)

func _make_icon(index: int) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = "StageIcon%d" % int(index + 1)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.texture = _load_icon_texture(UNSELECTED_TEXTURE_PATHS[index])
	icon.tooltip_text = STAGE_TOOLTIPS[index]
	return icon

func _load_icon_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	if ResourceLoader.exists(path, "Texture2D"):
		var resource: Resource = ResourceLoader.load(path, "Texture2D")
		var imported_texture: Texture2D = resource as Texture2D
		if imported_texture != null:
			_texture_cache[path] = imported_texture
			return imported_texture
	var image: Image = Image.new()
	var err: Error = image.load(path)
	if err != OK:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		err = image.load(absolute_path)
	if err != OK:
		push_error("StageProgressTopBar: failed to load icon texture %s error=%d" % [path, int(err)])
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	_texture_cache[path] = texture
	return texture

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.024, 0.030, 0.86)
	style.border_color = Color(0.54, 0.38, 0.18, 0.74)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style
