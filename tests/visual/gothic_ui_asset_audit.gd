extends Node

const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/gothic_ui_asset_audit"
const ASSET_PATHS: Array[String] = [
	GothicUIAssets.PANEL_PLATE_WIDE,
	GothicUIAssets.PANEL_PLATE_GRID,
	GothicUIAssets.PANEL_PLATE_ITEM_STORAGE,
	GothicUIAssets.PANEL_PLATE_TRAITS,
	GothicUIAssets.SHOP_CARD_FRAME,
	GothicUIAssets.BUTTON_SMALL,
	GothicUIAssets.BUTTON_PRIMARY,
	GothicUIAssets.SCREEN_BACKDROP,
	GothicUIAssets.BATTLEFIELD_SURFACE,
	GothicUIAssets.BATTLEFIELD_SURFACE_TOP,
	GothicUIAssets.BATTLEFIELD_SURFACE_BOTTOM,
	GothicUIAssets.BOARD_TILE_PLAYER,
	GothicUIAssets.BOARD_TILE_ENEMY,
	GothicUIAssets.BENCH_SLOT_FRAME,
	GothicUIAssets.ITEM_ICON_FRAME,
	GothicUIAssets.UNIT_BASE_PLAYER,
	GothicUIAssets.UNIT_BASE_ENEMY,
	GothicUIAssets.ARENA_FRAME,
	GothicUIAssets.STATUS_STRIP,
]
const ASSET_SIZES: Array[Vector2i] = [
	Vector2i(1120, 238),
	Vector2i(1120, 178),
	Vector2i(320, 180),
	Vector2i(320, 320),
	Vector2i(150, 138),
	Vector2i(100, 44),
	Vector2i(240, 54),
	Vector2i(1920, 1080),
	Vector2i(1536, 768),
	Vector2i(1536, 384),
	Vector2i(1536, 384),
	Vector2i(96, 96),
	Vector2i(96, 96),
	Vector2i(96, 96),
	Vector2i(96, 96),
	Vector2i(128, 96),
	Vector2i(128, 96),
	Vector2i(640, 360),
	Vector2i(512, 64),
]
const KEY_GREEN_AUDIT_PATHS: Array[String] = [
	GothicUIAssets.PANEL_PLATE_WIDE,
	GothicUIAssets.PANEL_PLATE_GRID,
	GothicUIAssets.SHOP_CARD_FRAME,
	GothicUIAssets.BUTTON_SMALL,
	GothicUIAssets.BUTTON_PRIMARY,
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failures: Array[String] = []
	var asset_records: Array[Dictionary] = []
	var visible_green_total: int = 0
	var transparent_green_total: int = 0
	var all_imports_clean: bool = true
	for index: int in range(ASSET_PATHS.size()):
		var path: String = ASSET_PATHS[index]
		var expected_size: Vector2i = ASSET_SIZES[index]
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var source_exists: bool = FileAccess.file_exists(path)
		var import_sidecar_exists: bool = FileAccess.file_exists(path + ".import")
		var resource_exists: bool = ResourceLoader.exists(path, "Texture2D")
		var loaded_resource: Resource = ResourceLoader.load(path, "Texture2D") if resource_exists else null
		var loaded_texture: Texture2D = loaded_resource as Texture2D
		var runtime_import_ok: bool = loaded_texture != null
		all_imports_clean = all_imports_clean and source_exists and import_sidecar_exists and resource_exists and runtime_import_ok
		if not source_exists:
			failures.append("source missing %s" % path)
		if not import_sidecar_exists:
			failures.append("import sidecar missing %s.import" % path)
		if not resource_exists or not runtime_import_ok:
			failures.append("Texture2D runtime import failed %s" % path)
		var image: Image = Image.load_from_file(absolute_path)
		var actual_size: Vector2i = Vector2i.ZERO
		if image == null or image.is_empty():
			failures.append("could not load %s" % path)
		else:
			actual_size = image.get_size()
			if actual_size != expected_size:
				failures.append("%s size=%s expected=%s" % [path, actual_size, expected_size])
			if KEY_GREEN_AUDIT_PATHS.has(path):
				var counts: Vector2i = _count_key_green(image)
				visible_green_total += counts.x
				transparent_green_total += counts.y
				if counts.x > 0 or counts.y > 0:
					failures.append("%s key-green visible=%d transparent=%d" % [path, counts.x, counts.y])
		asset_records.append({
			"path": path,
			"expected_size": "%dx%d" % [expected_size.x, expected_size.y],
			"actual_size": "%dx%d" % [actual_size.x, actual_size.y],
			"source_exists": source_exists,
			"import_sidecar_exists": import_sidecar_exists,
			"resource_loader_exists": resource_exists,
			"runtime_texture_load_ok": runtime_import_ok,
			"key_green_audited": KEY_GREEN_AUDIT_PATHS.has(path),
		})
	var fallback_style: StyleBoxFlat = StyleBoxFlat.new()
	var resolved_fallback: StyleBox = GothicUIAssets.style_or_fallback(null, fallback_style)
	var style_fallback_ok: bool = resolved_fallback == fallback_style
	var fallback_texture: Texture2D = TextureUtils.load_texture("res://assets/ui/gothic/__intentional_missing_fallback_probe__.png", Color(0.6, 0.2, 0.2, 1.0), 16)
	var texture_fallback_ok: bool = fallback_texture != null and fallback_texture.get_width() == 16 and fallback_texture.get_height() == 16
	if not style_fallback_ok:
		failures.append("style_or_fallback did not return the supplied fallback")
	if not texture_fallback_ok:
		failures.append("TextureUtils missing-path fallback did not produce the expected 16x16 texture")
	_write_identity_manifest(asset_records, all_imports_clean, style_fallback_ok, texture_fallback_ok, failures)
	if failures.size() > 0:
		for failure: String in failures:
			push_error("GothicUIAssetAudit: " + failure)
		get_tree().quit(1)
		return
	print("GothicUIAssetAudit: OK assets=%d visible_green=%d transparent_green=%d" % [ASSET_PATHS.size(), visible_green_total, transparent_green_total])
	get_tree().quit(0)

func _write_identity_manifest(asset_records: Array[Dictionary], all_imports_clean: bool, style_fallback_ok: bool, texture_fallback_ok: bool, failures: Array[String]) -> void:
	var manifest_path: String = "%s/identity_manifest.json" % OUTPUT_DIR
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		failures.append("could not write identity manifest")
		return
	var custom_font_assets: Array[String] = []
	var manifest: Dictionary[String, Variant] = {
		"runtime": "Godot ResourceLoader audit",
		"scene": "res://tests/visual/GothicUIAssetAudit.tscn",
		"font_identity": {
			"policy": "engine_default_theme",
			"custom_font_assets": custom_font_assets,
			"semantic_sizes": {
				"display": GothicUIAssets.FONT_DISPLAY,
				"title": GothicUIAssets.FONT_TITLE,
				"heading": GothicUIAssets.FONT_HEADING,
				"body": GothicUIAssets.FONT_BODY,
				"meta": GothicUIAssets.FONT_META,
				"micro": GothicUIAssets.FONT_MICRO,
			},
		},
		"active_gothic_textures": asset_records,
		"all_texture_imports_clean": all_imports_clean,
		"fallback_contract": {
			"style_or_fallback_ok": style_fallback_ok,
			"missing_texture_fallback_ok": texture_fallback_ok,
		},
		"failures": failures,
	}
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("GothicUIAssetAudit: manifest %s" % ProjectSettings.globalize_path(manifest_path))

func _count_key_green(image: Image) -> Vector2i:
	var visible: int = 0
	var transparent: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			var red: int = int(round(color.r * 255.0))
			var green: int = int(round(color.g * 255.0))
			var blue: int = int(round(color.b * 255.0))
			var alpha: int = int(round(color.a * 255.0))
			var is_key_green: bool = green >= 120 and float(green) > float(red) * 1.32 and float(green) > float(blue) * 1.32
			if not is_key_green:
				continue
			if alpha > 0:
				visible += 1
			else:
				transparent += 1
	return Vector2i(visible, transparent)
