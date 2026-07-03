extends Object
class_name GothicUIAssets

const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")

const PANEL_PLATE_WIDE: String = "res://assets/ui/gothic/panel_plate_wide.png"
const PANEL_PLATE_GRID: String = "res://assets/ui/gothic/panel_plate_grid.png"
const SHOP_CARD_FRAME: String = "res://assets/ui/gothic/shop_card_frame.png"
const BUTTON_SMALL: String = "res://assets/ui/gothic/button_small.png"
const BUTTON_PRIMARY: String = "res://assets/ui/gothic/button_primary.png"

static func wide_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_WIDE, Vector4(42.0, 42.0, 42.0, 42.0), Vector4(22.0, 18.0, 22.0, 18.0), modulate)

static func grid_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_GRID, Vector4(40.0, 36.0, 40.0, 36.0), Vector4(18.0, 14.0, 18.0, 14.0), modulate)

static func shop_card_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(SHOP_CARD_FRAME, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(8.0, 8.0, 8.0, 8.0), modulate)

static func small_button_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_SMALL, Vector4(18.0, 14.0, 18.0, 14.0), Vector4(16.0, 7.0, 16.0, 7.0), modulate)

static func primary_button_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_PRIMARY, Vector4(26.0, 16.0, 26.0, 16.0), Vector4(22.0, 8.0, 22.0, 8.0), modulate)

static func item_slot_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_SMALL, Vector4(10.0, 10.0, 10.0, 10.0), Vector4(3.0, 3.0, 3.0, 3.0), modulate)

static func texture_style(path: String, texture_margins: Vector4, content_margins: Vector4, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var texture: Texture2D = TextureUtils.try_load_texture(path)
	if texture == null:
		push_warning("Gothic UI asset missing: %s" % path)
		return null
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = texture_margins.x
	style.texture_margin_top = texture_margins.y
	style.texture_margin_right = texture_margins.z
	style.texture_margin_bottom = texture_margins.w
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	style.draw_center = true
	style.modulate_color = modulate
	return style

static func style_or_fallback(asset_style: StyleBoxTexture, fallback_style: StyleBox) -> StyleBox:
	if asset_style != null:
		return asset_style
	return fallback_style
