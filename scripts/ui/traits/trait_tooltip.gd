extends Panel
class_name TraitTooltip

@onready var _name_label: Label = $VBox/Name
@onready var _state_label: Label = $VBox/State
@onready var _threshold_label: Label = $VBox/Thresholds
@onready var _description_label: Label = $VBox/Description
@onready var _footer_label: Label = $VBox/Footer
@onready var _vbox: VBoxContainer = $VBox

const TOOLTIP_WIDTH: float = 304.0
const PADDING: float = 10.0
const EDGE_PADDING: float = 12.0
const CURSOR_OFFSET: Vector2 = Vector2(18.0, -14.0)
const COLOR_PANEL: Color = Color(0.024, 0.020, 0.030, 0.985)
const COLOR_BORDER: Color = Color(0.64, 0.42, 0.22, 0.94)
const COLOR_BORDER_ACTIVE: Color = Color(0.95, 0.69, 0.31, 1.0)
const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.68, 0.61, 0.53, 1.0)
const COLOR_GOLD: Color = Color(0.94, 0.70, 0.36, 1.0)
const COLOR_BLOOD: Color = Color(0.80, 0.085, 0.12, 1.0)
const COLOR_GREEN: Color = Color(0.50, 0.72, 0.58, 1.0)

var trait_id: String = ""
var trait_count: int = 0
var trait_tier: int = -1
var is_active: bool = false

func _ready() -> void:
	top_level = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 900
	custom_minimum_size.x = TOOLTIP_WIDTH
	_apply_style()
	_update_labels()

func _apply_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER_ACTIVE if is_active else COLOR_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	add_theme_stylebox_override("panel", style)
	var background: ColorRect = get_node_or_null("ColorRect") as ColorRect
	if background != null:
		background.color = Color(0.050, 0.033, 0.040, 0.94)
	if _vbox != null:
		_vbox.add_theme_constant_override("separation", 7)
	if _name_label != null:
		_name_label.add_theme_font_size_override("font_size", 18)
		_name_label.add_theme_color_override("font_color", COLOR_GOLD)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.74))
		_name_label.add_theme_constant_override("outline_size", 1)
	if _state_label != null:
		_state_label.add_theme_font_size_override("font_size", 12)
		_state_label.add_theme_color_override("font_color", COLOR_GREEN if is_active else COLOR_BLOOD)
	if _threshold_label != null:
		_threshold_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _description_label != null:
		_description_label.add_theme_color_override("font_color", COLOR_TEXT)
		_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _footer_label != null:
		_footer_label.add_theme_color_override("font_color", COLOR_MUTED)
		_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func set_trait(id: String) -> void:
	trait_id = String(id)
	_update_labels()

func set_context(active: bool, count: int, tier: int) -> void:
	is_active = bool(active)
	trait_count = int(count)
	trait_tier = int(tier)
	_apply_style()
	_update_labels()

func show_at(viewport_pos: Vector2) -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.985, 0.985)
	await get_tree().process_frame
	_sync_size()
	move_to(viewport_pos)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.08)

func move_to(viewport_pos: Vector2) -> void:
	_sync_size()
	global_position = _clamped_position(viewport_pos + CURSOR_OFFSET)

func _update_labels() -> void:
	var def: TraitDef = _load_trait_def(trait_id)
	var title: String = trait_id
	if def != null and String(def.name).strip_edges() != "":
		title = String(def.name)
	if _name_label:
		_name_label.text = title
	var state_text: String = _format_state(def)
	if _state_label:
		_state_label.text = state_text
		_state_label.visible = state_text != ""
	var thresholds_text: String = _format_thresholds(def)
	if _threshold_label:
		_threshold_label.text = thresholds_text
		_threshold_label.visible = thresholds_text != ""
	var description: String = ""
	if def != null and def.description != null:
		description = String(def.description)
	if _description_label:
		_description_label.text = description
		_description_label.visible = description.strip_edges() != ""
	if _footer_label:
		_footer_label.text = _format_footer(def)
		_footer_label.visible = _footer_label.text.strip_edges() != ""
	_sync_size()
	queue_redraw()

func _format_state(def: TraitDef) -> String:
	var count_text: String = "Members: %d" % trait_count if trait_count > 0 else "Members: hidden"
	if is_active:
		return "ACTIVE  |  %s  |  Tier %d" % [count_text, trait_tier + 1]
	var next_threshold: int = _next_threshold(def)
	if next_threshold > 0:
		return "DORMANT  |  %s  |  Next at %d" % [count_text, next_threshold]
	return "DORMANT  |  %s" % count_text

func _format_thresholds(def: TraitDef) -> String:
	# Godot 4 does not have Object.has_property(); TraitDef always defines
	# an exported Array[int] `thresholds`, so access it directly and guard nulls.
	var values: Array[int] = []
	if def != null:
		var arr: Array = def.thresholds
		if arr != null and arr.size() > 0:
			for v in arr:
				values.append(int(v))
	var parts: PackedStringArray = PackedStringArray()
	for v in values:
		parts.append(str(v))
	if parts.size() == 0:
		return ""
	return "Thresholds: %s" % " / ".join(parts)

func _format_footer(def: TraitDef) -> String:
	if def == null:
		return "Trait definition was not found."
	if is_active:
		return "The bonus is live for the current board."
	var next_threshold: int = _next_threshold(def)
	if next_threshold > 0:
		var needed: int = max(0, next_threshold - trait_count)
		return "%d more matching member%s to awaken." % [needed, "" if needed == 1 else "s"]
	return ""

func _next_threshold(def: TraitDef) -> int:
	if def == null:
		return 0
	for threshold: int in def.thresholds:
		if trait_count < threshold:
			return threshold
	return 0

func _load_trait_def(id: String) -> TraitDef:
	var key: String = String(id).strip_edges()
	if key == "":
		return null
	var path: String = "res://data/traits/%s.tres" % key
	if ResourceLoader.exists(path):
		return load(path) as TraitDef
	return null

func _sync_size() -> void:
	if _vbox == null:
		return
	var content_width: float = TOOLTIP_WIDTH - PADDING * 2.0
	for child: Node in _vbox.get_children():
		var child_control: Control = child as Control
		if child_control != null:
			child_control.custom_minimum_size.x = content_width
			child_control.size.x = content_width
	size.x = TOOLTIP_WIDTH
	var desired_height: float = _vbox.get_combined_minimum_size().y + PADDING * 2.0
	size.y = max(desired_height, 112.0)

func _clamped_position(raw_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return raw_position
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var new_position: Vector2 = raw_position
	if new_position.x + size.x + EDGE_PADDING > viewport_size.x:
		new_position.x = raw_position.x - size.x - CURSOR_OFFSET.x * 1.5
	if new_position.y + size.y + EDGE_PADDING > viewport_size.y:
		new_position.y = viewport_size.y - size.y - EDGE_PADDING
	if new_position.x < EDGE_PADDING:
		new_position.x = EDGE_PADDING
	if new_position.y < EDGE_PADDING:
		new_position.y = EDGE_PADDING
	return new_position
