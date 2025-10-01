extends Button
class_name ShopCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitIconScene := preload("res://scenes/ui/traits/TraitIcon.tscn")

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $Name
@onready var _price_label: Label = $Price
@onready var _traits_box: VBoxContainer = $TraitIcons
@onready var _identity_panel: VBoxContainer = $IdentityPanel
@onready var _role_badge: Label = $"IdentityPanel/RoleBadge"
@onready var _goal_label: Label = $"IdentityPanel/GoalLabel"
@onready var _approach_tags: FlowContainer = $"IdentityPanel/ApproachTags"

var offer_id: String = ""
var _disabled_reason: String = ""
var slot_index: int = -1

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
			_role_badge.text = display_role
			_role_badge.visible = true
			has_identity = true
		else:
			_role_badge.visible = false
	if _goal_label:
		if display_goal != "":
			_goal_label.text = display_goal
			_goal_label.visible = true
			has_identity = true
		else:
			_goal_label.visible = false
	_set_approach_tags(approaches)
	if _approach_tags and _approach_tags.get_child_count() > 0:
		has_identity = true
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

func set_shop_disabled(reason) -> void:
	_disabled_reason = String(reason)
	set_meta("shop_disabled_reason", _disabled_reason)
	disabled = true
	tooltip_text = _disabled_reason
	modulate = Color(1, 1, 1, 0.6)

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
		var icon = (TraitIconScene.instantiate() if TraitIconScene else null)
		if icon == null:
			continue
		if icon.has_method("set_trait"):
			icon.call("set_trait", trait_id)
		_traits_box.add_child(icon)
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
	sb.bg_color = Color(0.0941177, 0.137255, 0.211765, 0.95)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

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
	var text := String(role_value).replace("_", " ").strip_edges()
	if text == "":
		return ""
	var parts := text.split(" ", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	if pretty.size() == 0:
		return text.capitalize()
	return " ".join(pretty)

func _format_goal(goal_value) -> String:
	var goal := String(goal_value).strip_edges()
	if goal == "":
		return ""
	var parts := goal.split(".", false, 2)
	if parts.size() >= 2:
		var role_part := _format_role(parts[0])
		var goal_part := _prettify_token(parts[1])
		if role_part != "":
			if goal_part != "":
				return "%s - %s" % [role_part, goal_part]
			return role_part
	return _prettify_token(goal)

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
	var text := String(value).strip_edges().to_lower()
	if text == "":
		return ""
	var parts := text.split("_", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	return " ".join(pretty)

signal clicked(slot_index: int)

func _on_pressed() -> void:
	emit_signal("clicked", int(slot_index))
