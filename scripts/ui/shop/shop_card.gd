extends Button
class_name ShopCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitIconScene := preload("res://scenes/ui/traits/TraitIcon.tscn")

const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.66, 0.60, 0.52, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.66, 0.32, 1.0)
const COLOR_BLOOD: Color = Color(0.52, 0.040, 0.072, 1.0)
const COLOR_PANEL: Color = Color(0.045, 0.037, 0.047, 0.97)
const COLOR_IRON: Color = Color(0.40, 0.34, 0.32, 0.94)

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $Name
@onready var _price_label: Label = $Price
@onready var _legacy_role_label: Label = get_node_or_null("Role") as Label
@onready var _traits_box: VBoxContainer = $TraitIcons
@onready var _identity_panel: VBoxContainer = $IdentityPanel
@onready var _role_badge: Label = $"IdentityPanel/RoleBadge"
@onready var _goal_label: Label = $"IdentityPanel/GoalLabel"
@onready var _approach_tags: FlowContainer = $"IdentityPanel/ApproachTags"

var offer_id: String = ""
var _disabled_reason: String = ""
var slot_index: int = -1
var _hover_tween: Tween = null

func _resolve_child(paths: Array) -> Node:
	for p in paths:
		var node := get_node_or_null(String(p))
		if node:
			return node
	return null

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	clip_text = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_static_style()
	_wire_hover()
	if not is_connected("pressed", Callable(self, "_on_pressed")):
		pressed.connect(_on_pressed)

func set_data(props: Dictionary) -> void:
	if not disabled:
		_disabled_reason = ""
		set_meta("shop_disabled_reason", "")
	offer_id = String(props.get("id", ""))
	var title := String(props.get("name", "?"))
	var price_i := int(props.get("price", props.get("cost", 0)))
	var img_path := String(props.get("image_path", props.get("sprite_path", "")))
	var roles: Array = _coerce_array(props.get("roles", []))
	var traits: Array = _coerce_array(props.get("traits", []))
	var primary_role := String(props.get("primary_role", ""))
	var primary_goal := String(props.get("primary_goal", ""))
	var approaches: Array = _coerce_array(props.get("approaches", []))
	var alt_goals: Array = _coerce_array(props.get("alt_goals", []))
	var identity_path := String(props.get("identity_path", ""))

	var display_role := _format_role(primary_role)
	if display_role == "" and roles.size() > 0:
		display_role = _format_role(roles[0])
	var display_goal := _format_goal(primary_goal)

	if _name_label:
		_name_label.text = title
	if _price_label:
		_price_label.text = str(price_i) + "g"
	if _icon:
		var tex: Texture2D = null
		if img_path != "":
			tex = load(img_path)
		if tex == null:
			tex = TextureUtils.make_circle_texture(Color(0.75, 0.75, 0.75), 96)
		_icon.texture = tex

	_update_identity_panel(display_role, display_goal, approaches)
	_set_traits(traits)
	_apply_static_style()

	var tooltip_lines: Array[String] = []
	if display_role != "":
		tooltip_lines.append("Role: %s" % display_role)
	if display_goal != "":
		tooltip_lines.append("Goal: %s" % display_goal)
	var approach_text := _format_list(approaches, 4)
	if approach_text != "":
		tooltip_lines.append("Approaches: %s" % approach_text)
	var alt_text := _format_list(alt_goals, 3)
	if alt_text != "":
		tooltip_lines.append("Alt Goals: %s" % alt_text)
	if identity_path != "":
		tooltip_lines.append(identity_path)
	var identity_tip := "\n".join(tooltip_lines)
	set_meta("identity_tooltip", identity_tip)
	if _disabled_reason != "":
		tooltip_text = _disabled_reason
	elif identity_tip != "":
		tooltip_text = identity_tip
	else:
		tooltip_text = title

func _update_identity_panel(display_role: String, display_goal: String, approaches: Array) -> void:
	var has_identity := false
	if _role_badge:
		if display_role != "":
			_role_badge.text = display_role.to_upper()
			_role_badge.visible = true
			has_identity = true
		else:
			_role_badge.visible = false
	if _goal_label:
		_goal_label.text = display_goal
		_goal_label.visible = false
	_set_approach_tags(approaches)
	if _approach_tags:
		_approach_tags.visible = false
	if _identity_panel:
		_identity_panel.visible = has_identity

func set_affordable(affordable: bool) -> void:
	var ok := bool(affordable)
	var shop_reason := String(get_meta("shop_disabled_reason", ""))
	if shop_reason != "":
		disabled = true
	else:
		disabled = not ok
	var base_tip := String(get_meta("identity_tooltip", ""))
	if base_tip == "":
		base_tip = tooltip_text
	if _price_label:
		_price_label.modulate = Color(1, 1, 0.8, 0.95) if ok else Color(1, 0.5, 0.5, 0.85)
	tooltip_text = base_tip if ok else "Not enough gold"
	_refresh_cursor()

func set_shop_disabled(reason) -> void:
	_disabled_reason = String(reason)
	set_meta("shop_disabled_reason", _disabled_reason)
	disabled = true
	tooltip_text = _disabled_reason
	modulate = Color(1, 1, 1, 0.6)
	_refresh_cursor()

func set_slot_index(i: int) -> void:
	slot_index = int(i)

func _set_traits(traits: Array) -> void:
	if _traits_box == null:
		return
	for c in _traits_box.get_children():
		c.queue_free()
	var shown := 0
	for t in traits:
		var trait_id := String(t).strip_edges()
		if trait_id == "":
			continue
		var trait_icon = (TraitIconScene.instantiate() if TraitIconScene else null)
		if trait_icon == null:
			continue
		if trait_icon.has_method("set_trait"):
			trait_icon.call("set_trait", trait_id)
		_traits_box.add_child(trait_icon)
		shown += 1
		if shown >= 3:
			break
	_traits_box.visible = shown > 0

func _set_approach_tags(approaches: Array) -> void:
	if _approach_tags == null:
		return
	for child in _approach_tags.get_children():
		child.queue_free()
	var seen: Dictionary = {}
	var shown := 0
	for approach in approaches:
		var pretty := _prettify_token(String(approach))
		if pretty == "" or seen.has(pretty):
			continue
		seen[pretty] = true
		var label := Label.new()
		label.text = pretty
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1, 1, 1, 0.92)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_stylebox_override("normal", _make_tag_style())
		_approach_tags.add_child(label)
		shown += 1
		if shown >= 4:
			break
	_approach_tags.visible = shown > 0
func _make_tag_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.046, 0.043, 0.050, 0.96)
	sb.border_color = Color(0.36, 0.28, 0.22, 0.86)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

func _apply_static_style() -> void:
	pivot_offset = size * 0.5
	custom_minimum_size = Vector2(150.0, 138.0)
	add_theme_stylebox_override("normal", _make_card_style(false, false))
	add_theme_stylebox_override("hover", _make_card_style(false, true))
	add_theme_stylebox_override("pressed", _make_card_style(true, true))
	add_theme_stylebox_override("disabled", _make_card_style(false, false, true))
	add_theme_stylebox_override("focus", _make_card_style(false, true))
	add_theme_color_override("font_disabled_color", Color(0.74, 0.67, 0.56, 0.92))
	if _icon:
		_icon.z_index = 2
		_icon.modulate = Color(1.0, 0.93, 0.82, 1.0)
		_icon.anchor_left = 0.12
		_icon.anchor_top = 0.21
		_icon.anchor_right = 0.88
		_icon.anchor_bottom = 0.78
		_icon.offset_left = 0.0
		_icon.offset_top = 0.0
		_icon.offset_right = 0.0
		_icon.offset_bottom = 0.0
	if _traits_box:
		_traits_box.z_index = 4
		_traits_box.visible = false
	if _identity_panel:
		_identity_panel.z_index = 5
		_identity_panel.anchor_left = 0.06
		_identity_panel.anchor_top = 0.040
		_identity_panel.anchor_right = 0.94
		_identity_panel.anchor_bottom = 0.18
		_identity_panel.offset_left = 0.0
		_identity_panel.offset_top = 0.0
		_identity_panel.offset_right = 0.0
		_identity_panel.offset_bottom = 0.0
	if _legacy_role_label:
		_legacy_role_label.visible = false
	if _role_badge:
		_role_badge.add_theme_font_size_override("font_size", 11)
		_role_badge.add_theme_color_override("font_color", COLOR_GOLD)
		_role_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		_role_badge.add_theme_constant_override("outline_size", 1)
	if _goal_label:
		_goal_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _name_label:
		_name_label.z_index = 6
		_name_label.add_theme_font_size_override("font_size", 13)
		_name_label.add_theme_color_override("font_color", COLOR_TEXT)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_name_label.add_theme_constant_override("outline_size", 1)
	if _price_label:
		_price_label.z_index = 6
		_price_label.add_theme_font_size_override("font_size", 13)
		_price_label.add_theme_color_override("font_color", COLOR_GOLD)
		_price_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_price_label.add_theme_constant_override("outline_size", 1)

func _make_card_style(pressed_state: bool, highlighted: bool, disabled_state: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_IRON
	if highlighted:
		style.bg_color = Color(0.092, 0.054, 0.062, 0.99)
		style.border_color = COLOR_GOLD
	if pressed_state:
		style.bg_color = Color(0.13, 0.026, 0.040, 0.98)
		style.border_color = COLOR_BLOOD
	if disabled_state:
		style.bg_color = Color(0.038, 0.032, 0.040, 0.96)
		style.border_color = Color(0.33, 0.29, 0.29, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 12 if highlighted else 8
	style.shadow_color = Color(0.58, 0.18, 0.060, 0.30) if highlighted else Color(0.0, 0.0, 0.0, 0.46)
	return style

func _wire_hover() -> void:
	if not is_connected("mouse_entered", Callable(self, "_on_hover_entered")):
		mouse_entered.connect(_on_hover_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_hover_exited")):
		mouse_exited.connect(_on_hover_exited)
	if not is_connected("resized", Callable(self, "_sync_pivot")):
		resized.connect(_sync_pivot)
	_sync_pivot()

func _sync_pivot() -> void:
	pivot_offset = size * 0.5

func _on_hover_entered() -> void:
	_apply_hover_motion(true)

func _on_hover_exited() -> void:
	_apply_hover_motion(false)

func _apply_hover_motion(active: bool) -> void:
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	var target_scale: Vector2 = Vector2.ONE
	if active and not disabled:
		target_scale = Vector2(1.035, 1.035)
		z_index = 70
		if _icon != null:
			_icon.modulate = Color(1.0, 0.93, 0.78, 1.0)
	else:
		z_index = 0
		if _icon != null:
			_icon.modulate = Color(0.96, 0.91, 0.84, 1.0)
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, 0.10)

func _refresh_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND

func _coerce_array(values) -> Array:
	var out: Array = []
	if values is Array:
		for v in values:
			out.append(String(v))
	elif values is PackedStringArray:
		for v in values:
			out.append(String(v))
	elif typeof(values) == TYPE_STRING:
		out.append(String(values))
	return out

func _format_role(role_value) -> String:
	var role_text := String(role_value).replace("_", " ").strip_edges()
	if role_text == "":
		return ""
	var parts := role_text.split(" ", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	if pretty.size() == 0:
		return role_text.capitalize()
	return " ".join(pretty)

func _format_goal(goal_value) -> String:
	var goal_text := String(goal_value).strip_edges()
	if goal_text == "":
		return ""
	var parts := goal_text.split(".", false, 2)
	if parts.size() >= 2:
		var role_part := _format_role(parts[0])
		var goal_part := _prettify_token(parts[1])
		if role_part != "":
			if goal_part != "":
				return "%s - %s" % [role_part, goal_part]
			return role_part
	return _prettify_token(goal_text)

func _format_list(values: Array, limit: int) -> String:
	if values == null or values.is_empty():
		return ""
	var formatted := PackedStringArray()
	for i in range(min(limit, values.size())):
		var token := _prettify_token(String(values[i]))
		if token != "":
			formatted.append(token)
	if values.size() > limit:
		formatted.append("+")
	return ", ".join(formatted)

func _prettify_token(value: String) -> String:
	var token_text := String(value).strip_edges().to_lower()
	if token_text == "":
		return ""
	var parts := token_text.split("_", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	return " ".join(pretty)

signal clicked(slot_index: int)

func _on_pressed() -> void:
	emit_signal("clicked", int(slot_index))
