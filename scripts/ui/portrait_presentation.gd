extends RefCounted
class_name PortraitPresentation

const DEFAULT_FOCUS_Y: float = 0.36
const MIN_CROP_RATIO: float = 1.08

static func normalize(texture: Texture2D, focus_y: float = DEFAULT_FOCUS_Y) -> Texture2D:
	if texture == null:
		return null
	var width: float = float(texture.get_width())
	var height: float = float(texture.get_height())
	if width <= 0.0 or height <= 0.0:
		return texture
	var long_side: float = maxf(width, height)
	var short_side: float = minf(width, height)
	if long_side / short_side < MIN_CROP_RATIO:
		return texture
	var region: Rect2 = Rect2()
	if height > width:
		var center_y: float = height * clampf(focus_y, 0.0, 1.0)
		var top: float = clampf(center_y - width * 0.5, 0.0, height - width)
		region = Rect2(0.0, top, width, width)
	else:
		var left: float = (width - height) * 0.5
		region = Rect2(left, 0.0, height, height)
	var portrait: AtlasTexture = AtlasTexture.new()
	portrait.atlas = texture
	portrait.region = region
	portrait.filter_clip = true
	return portrait

static func configure(rect: TextureRect, texture: Texture2D, focus_y: float = DEFAULT_FOCUS_Y) -> void:
	if rect == null:
		return
	rect.texture = normalize(texture, focus_y)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.clip_contents = true
