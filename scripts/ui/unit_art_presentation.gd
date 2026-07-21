extends Object
class_name UnitArtPresentation

const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")
const PROFILE_PATH: String = "res://data/ui/unit_art_presentation_profiles.json"
const FALLBACK_PADDING_RATIO: float = 0.045

static var _loaded: bool = false
static var _default_padding_ratio: float = FALLBACK_PADDING_RATIO
static var _profiles: Dictionary[String, Dictionary] = {}
static var _texture_cache: Dictionary[String, Texture2D] = {}

static func texture_for(unit_id: String, sprite_path: String) -> Texture2D:
	var clean_id: String = String(unit_id).strip_edges()
	var clean_path: String = String(sprite_path).strip_edges()
	if clean_path == "":
		return null
	_ensure_profiles_loaded()
	var cache_key: String = "%s|%s" % [clean_id, clean_path]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	var source: Texture2D = TextureUtils.try_load_texture(clean_path)
	if source == null:
		return null
	var profile: Dictionary = _profiles.get(clean_id, {})
	var normalized: Texture2D = _normalized_texture(source, profile)
	_texture_cache[cache_key] = normalized
	return normalized

static func apply_texture_rect(rect: TextureRect, unit_id: String, sprite_path: String) -> Texture2D:
	if rect == null:
		return null
	var texture: Texture2D = texture_for(unit_id, sprite_path)
	if texture != null:
		rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = Color.WHITE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.set_meta("unit_art_presented", texture != null)
	rect.set_meta("unit_art_id", String(unit_id))
	return texture

static func apply_button_icon(button: Button, unit_id: String, sprite_path: String) -> Texture2D:
	if button == null:
		return null
	var texture: Texture2D = texture_for(unit_id, sprite_path)
	if texture != null:
		button.icon = texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.set_meta("unit_art_presented", texture != null)
	button.set_meta("unit_art_id", String(unit_id))
	return texture

static func profile_ids() -> Array[String]:
	_ensure_profiles_loaded()
	var ids: Array[String] = []
	for raw_id: String in _profiles.keys():
		ids.append(raw_id)
	ids.sort()
	return ids

static func expected_sprite_path(unit_id: String) -> String:
	_ensure_profiles_loaded()
	var profile: Dictionary = _profiles.get(String(unit_id), {})
	return String(profile.get("sprite_path", ""))

static func clear_cache() -> void:
	_texture_cache.clear()

static func _ensure_profiles_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PROFILE_PATH):
		push_warning("Unit art presentation profile missing: %s" % PROFILE_PATH)
		return
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to open unit art presentation profile: %s" % PROFILE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Unit art presentation profile is invalid JSON: %s" % PROFILE_PATH)
		return
	var root: Dictionary = parsed as Dictionary
	_default_padding_ratio = clampf(float(root.get("default_padding_ratio", FALLBACK_PADDING_RATIO)), 0.0, 0.20)
	var raw_profiles: Variant = root.get("profiles", {})
	if not (raw_profiles is Dictionary):
		return
	for raw_id: Variant in (raw_profiles as Dictionary).keys():
		var clean_id: String = String(raw_id)
		var raw_profile: Variant = (raw_profiles as Dictionary).get(raw_id, {})
		if raw_profile is Dictionary:
			_profiles[clean_id] = (raw_profile as Dictionary).duplicate(true)

static func _normalized_texture(source: Texture2D, profile: Dictionary) -> Texture2D:
	var source_width: int = source.get_width()
	var source_height: int = source.get_height()
	if source_width <= 0 or source_height <= 0:
		return source
	var source_rect: Rect2i = Rect2i(0, 0, source_width, source_height)
	var content_rect: Rect2i = _profile_content_rect(profile, source_rect)
	if content_rect.size.x <= 0 or content_rect.size.y <= 0:
		var image: Image = source.get_image()
		if image != null and not image.is_empty():
			content_rect = image.get_used_rect()
	if content_rect.size.x <= 0 or content_rect.size.y <= 0:
		return source
	var padding_ratio: float = clampf(float(profile.get("padding_ratio", _default_padding_ratio)), 0.0, 0.20)
	var padding: int = int(ceil(float(maxi(content_rect.size.x, content_rect.size.y)) * padding_ratio))
	content_rect = content_rect.grow(padding).intersection(source_rect)
	if content_rect == source_rect:
		return source
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(content_rect)
	atlas.filter_clip = true
	return atlas

static func _profile_content_rect(profile: Dictionary, source_rect: Rect2i) -> Rect2i:
	var raw_rect: Variant = profile.get("content_rect", [])
	if not (raw_rect is Array) or (raw_rect as Array).size() != 4:
		return Rect2i()
	var values: Array = raw_rect as Array
	var candidate: Rect2i = Rect2i(
		int(values[0]),
		int(values[1]),
		int(values[2]),
		int(values[3])
	)
	return candidate.intersection(source_rect)
