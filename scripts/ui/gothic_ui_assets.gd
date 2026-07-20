extends Object
class_name GothicUIAssets

const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")

const PANEL_PLATE_WIDE: String = "res://assets/ui/gothic/panel_plate_wide_v2.png"
const PANEL_PLATE_GRID: String = "res://assets/ui/gothic/panel_plate_grid_v2.png"
const PANEL_PLATE_ITEM_STORAGE: String = "res://assets/ui/gothic/panel_plate_item_storage.png"
const PANEL_PLATE_TRAITS: String = "res://assets/ui/gothic/panel_plate_traits.png"
const SHOP_CARD_FRAME: String = "res://assets/ui/gothic/shop_card_frame_v2.png"
const BUTTON_SMALL: String = "res://assets/ui/gothic/button_small_v2.png"
const BUTTON_PRIMARY: String = "res://assets/ui/gothic/button_primary_v2.png"
const SCREEN_BACKDROP: String = "res://assets/ui/gothic/screen_backdrop.png"
const BATTLEFIELD_SURFACE: String = "res://assets/ui/gothic/battlefield_surface.png"
const BATTLEFIELD_SURFACE_TOP: String = "res://assets/ui/gothic/battlefield_surface_top.png"
const BATTLEFIELD_SURFACE_BOTTOM: String = "res://assets/ui/gothic/battlefield_surface_bottom.png"
const BOARD_TILE_PLAYER: String = "res://assets/ui/gothic/board_tile_player.png"
const BOARD_TILE_ENEMY: String = "res://assets/ui/gothic/board_tile_enemy.png"
const BENCH_SLOT_FRAME: String = "res://assets/ui/gothic/bench_slot_frame.png"
const ITEM_ICON_FRAME: String = "res://assets/ui/gothic/item_icon_frame.png"
const UNIT_BASE_PLAYER: String = "res://assets/ui/gothic/unit_base_player.png"
const UNIT_BASE_ENEMY: String = "res://assets/ui/gothic/unit_base_enemy.png"
const ARENA_FRAME: String = "res://assets/ui/gothic/arena_frame.png"
const STATUS_STRIP: String = "res://assets/ui/gothic/status_strip.png"

# Shared visual language. Keep these semantic: screens may vary in composition,
# but the same information role should not silently change size or contrast.
const COLOR_VOID: Color = Color(0.012, 0.010, 0.014, 1.0)
const COLOR_SURFACE: Color = Color(0.036, 0.030, 0.040, 0.96)
const COLOR_SURFACE_RAISED: Color = Color(0.060, 0.043, 0.050, 0.98)
const COLOR_TEXT: Color = Color(0.94, 0.90, 0.82, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.70, 0.65, 0.57, 1.0)
const COLOR_GOLD: Color = Color(0.96, 0.72, 0.38, 1.0)
const COLOR_BLOOD: Color = Color(0.66, 0.055, 0.090, 1.0)
const COLOR_PLAYER: Color = Color(0.32, 0.69, 0.96, 1.0)
const COLOR_ENEMY: Color = Color(0.96, 0.32, 0.25, 1.0)

const FONT_DISPLAY: int = 36
const FONT_TITLE: int = 28
const FONT_HEADING: int = 20
const FONT_BODY: int = 16
const FONT_META: int = 14
const FONT_MICRO: int = 12

const SPACE_1: int = 4
const SPACE_2: int = 8
const SPACE_3: int = 12
const SPACE_4: int = 16
const SPACE_5: int = 24
const SPACE_6: int = 32

static func wide_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_WIDE, Vector4(42.0, 42.0, 42.0, 42.0), Vector4(22.0, 18.0, 22.0, 18.0), modulate)

static func grid_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_GRID, Vector4(40.0, 36.0, 40.0, 36.0), Vector4(18.0, 14.0, 18.0, 14.0), modulate)

static func item_storage_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_ITEM_STORAGE, Vector4(40.0, 36.0, 40.0, 36.0), Vector4(18.0, 14.0, 18.0, 14.0), modulate)

static func traits_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_TRAITS, Vector4(40.0, 40.0, 40.0, 40.0), Vector4(18.0, 18.0, 18.0, 18.0), modulate)

static func shop_card_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(SHOP_CARD_FRAME, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(8.0, 8.0, 8.0, 8.0), modulate)

static func small_button_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_SMALL, Vector4(18.0, 14.0, 18.0, 14.0), Vector4(16.0, 7.0, 16.0, 7.0), modulate)

static func primary_button_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_PRIMARY, Vector4(26.0, 16.0, 26.0, 16.0), Vector4(22.0, 8.0, 22.0, 8.0), modulate)

static func item_slot_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_SMALL, Vector4(10.0, 10.0, 10.0, 10.0), Vector4(3.0, 3.0, 3.0, 3.0), modulate)

static func bench_slot_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BENCH_SLOT_FRAME, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate)

static func item_icon_frame_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(ITEM_ICON_FRAME, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(4.0, 4.0, 4.0, 4.0), modulate)

static func unit_base_style(is_player: bool, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var path: String = UNIT_BASE_PLAYER if is_player else UNIT_BASE_ENEMY
	return texture_style(path, Vector4(36.0, 24.0, 36.0, 24.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate)

static func arena_frame_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(ARENA_FRAME, Vector4(58.0, 58.0, 58.0, 58.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate, false)

static func status_strip_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(STATUS_STRIP, Vector4(54.0, 24.0, 54.0, 24.0), Vector4(16.0, 6.0, 16.0, 6.0), modulate)

static func focus_outline_style(radius: int = 5, border_color: Color = Color(1.0, 0.80, 0.43, 1.0), border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.draw_center = false
	return style

static func semantic_surface_style(accent: Color = COLOR_GOLD, raised: bool = false, border_width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE_RAISED if raised else COLOR_SURFACE
	style.border_color = Color(accent.r, accent.g, accent.b, 0.76)
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = float(SPACE_3)
	style.content_margin_top = float(SPACE_2)
	style.content_margin_right = float(SPACE_3)
	style.content_margin_bottom = float(SPACE_2)
	style.shadow_size = 8 if raised else 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.56)
	return style

static func font_size(role: StringName, compact: bool = false) -> int:
	match role:
		&"display":
			return 30 if compact else FONT_DISPLAY
		&"title":
			return 24 if compact else FONT_TITLE
		&"heading":
			return 18 if compact else FONT_HEADING
		&"meta":
			return FONT_META
		&"micro":
			return FONT_MICRO
		_:
			return FONT_META if compact else FONT_BODY

static func screen_backdrop_texture() -> Texture2D:
	return TextureUtils.try_load_texture(SCREEN_BACKDROP)

static func battlefield_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE)

static func battlefield_top_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE_TOP)

static func battlefield_bottom_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE_BOTTOM)

static func board_tile_style(is_player: bool, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var path: String = BOARD_TILE_PLAYER if is_player else BOARD_TILE_ENEMY
	return texture_style(path, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate)

static func texture_style(path: String, texture_margins: Vector4, content_margins: Vector4, modulate: Color = Color.WHITE, draw_center: bool = true) -> StyleBoxTexture:
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
	style.draw_center = draw_center
	style.modulate_color = modulate
	return style

static func style_or_fallback(asset_style: StyleBoxTexture, fallback_style: StyleBox) -> StyleBox:
	if asset_style != null:
		return asset_style
	return fallback_style
