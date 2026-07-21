extends Control

const UnitCatalog: GDScript = preload("res://scripts/game/shop/unit_catalog.gd")
const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")
const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/unit_art_presentation_pass"
const EXPECTED_UNIT_COUNT: int = 51

var _failures: Array[String] = []
var _manifest_rows: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport_size: Vector2i = Vector2i(1920, 1080)
	DisplayServer.window_set_size(viewport_size)
	var window: Window = get_window()
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.010, 0.009, 0.013, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	background.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var title: Label = Label.new()
	title.text = "UNIT ART PRESENTATION AUDIT - RAW / NORMALIZED AT 96 PX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.72, 0.38, 1.0))
	stack.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Same live PNGs. Alpha-content framing only. Team color remains outside the portrait."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.67, 0.59, 1.0))
	stack.add_child(subtitle)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	stack.add_child(grid)

	var catalog: UnitCatalog = UnitCatalog.new()
	catalog.refresh()
	var unit_ids: Array[String] = _all_playable_ids(catalog)
	var profile_ids: Array[String] = UnitArtPresentation.profile_ids()
	_expect(unit_ids.size() == EXPECTED_UNIT_COUNT, "expected %d playable units, got %d" % [EXPECTED_UNIT_COUNT, unit_ids.size()])
	_expect(profile_ids == unit_ids, "presentation profile ids do not exactly match playable unit ids")
	for unit_id: String in unit_ids:
		var meta: Dictionary = catalog.get_unit_meta(unit_id)
		var sprite_path: String = String(meta.get("sprite_path", ""))
		var expected_path: String = UnitArtPresentation.expected_sprite_path(unit_id)
		_expect(sprite_path != "", "%s has no live sprite path" % unit_id)
		_expect(sprite_path == expected_path, "%s profile path mismatch: %s != %s" % [unit_id, expected_path, sprite_path])
		var raw_texture: Texture2D = TextureUtils.try_load_texture(sprite_path)
		var normalized_texture: Texture2D = UnitArtPresentation.texture_for(unit_id, sprite_path)
		_expect(raw_texture != null, "%s live texture did not load" % unit_id)
		_expect(normalized_texture != null, "%s normalized texture did not load" % unit_id)
		if raw_texture != null and normalized_texture != null:
			_expect(normalized_texture.get_width() <= raw_texture.get_width(), "%s normalized width exceeds source" % unit_id)
			_expect(normalized_texture.get_height() <= raw_texture.get_height(), "%s normalized height exceeds source" % unit_id)
			_manifest_rows.append({
				"unit_id": unit_id,
				"sprite_path": sprite_path,
				"source_size": [raw_texture.get_width(), raw_texture.get_height()],
				"normalized_size": [normalized_texture.get_width(), normalized_texture.get_height()],
			})
		_add_unit_card(grid, unit_id, raw_texture, normalized_texture)

	_expect(UnitArtPresentation.expected_sprite_path("korath") == "res://assets/units/korath.png", "Korath must use canonical portrait path")
	_expect(UnitArtPresentation.expected_sprite_path("sari") == "res://assets/units/sari.png", "Sari must use canonical portrait path")
	await _settle_frames(8)
	_save_capture("01_all_units_raw_vs_normalized_96px.png")
	_write_manifest(viewport_size)
	_finish()

func _all_playable_ids(catalog: UnitCatalog) -> Array[String]:
	var ids: Array[String] = []
	for cost: int in catalog.get_all_costs():
		for unit_id: String in catalog.get_ids_by_cost(cost):
			if not ids.has(unit_id):
				ids.append(unit_id)
	ids.sort()
	return ids

func _add_unit_card(parent: GridContainer, unit_id: String, raw_texture: Texture2D, normalized_texture: Texture2D) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(228.0, 134.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.030, 0.040, 0.98)
	style.border_color = Color(0.27, 0.21, 0.18, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 5.0
	style.content_margin_top = 3.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 3.0
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var name_label: Label = Label.new()
	name_label.text = unit_id.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.87, 0.78, 1.0))
	box.add_child(name_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_add_art_cell(row, "RAW", raw_texture)
	_add_art_cell(row, "NORM", normalized_texture)

func _add_art_cell(parent: HBoxContainer, label_text: String, texture: Texture2D) -> void:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	parent.add_child(cell)
	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.62, 0.58, 0.54, 1.0))
	cell.add_child(label)
	var art_back: ColorRect = ColorRect.new()
	art_back.custom_minimum_size = Vector2(96.0, 96.0)
	art_back.color = Color(0.014, 0.014, 0.018, 1.0)
	cell.add_child(art_back)
	var art: TextureRect = TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.modulate = Color.WHITE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_back.add_child(art)

func _write_manifest(viewport_size: Vector2i) -> void:
	var path: String = "%s/manifest.json" % OUTPUT_DIR
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("manifest could not be opened for writing")
		return
	var manifest: Dictionary = {
		"runtime": "Godot player-facing scene",
		"viewport": [viewport_size.x, viewport_size.y],
		"unit_count": _manifest_rows.size(),
		"portrait_assets_modified": false,
		"rows": _manifest_rows,
	}
	file.store_string(JSON.stringify(manifest, "  "))

func _save_capture(filename: String) -> void:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("viewport texture unavailable")
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("viewport image unavailable")
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_failures.append("capture failed error=%d" % int(error))
		return
	print("UnitArtPresentationAudit: saved %s" % ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("UnitArtPresentationAudit: OK units=%d" % _manifest_rows.size())
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("UnitArtPresentationAudit: " + failure)
	get_tree().quit(1)
