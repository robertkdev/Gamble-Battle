extends Control
class_name UnitSelect

signal unit_selected(unit_id: String)

const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")

const COLOR_VOID: Color = Color(0.012, 0.010, 0.014, 1.0)
const COLOR_PANEL: Color = Color(0.034, 0.029, 0.039, 0.94)
const COLOR_PANEL_DEEP: Color = Color(0.018, 0.015, 0.023, 0.98)
const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.65, 0.60, 0.53, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.66, 0.32, 1.0)
const COLOR_BLOOD: Color = Color(0.52, 0.040, 0.080, 1.0)
const COLOR_BLOOD_HOT: Color = Color(0.82, 0.070, 0.120, 1.0)

@onready var background: ColorRect = $Background
@onready var hbox: HBoxContainer = $Center/HBox
@onready var left_column: VBoxContainer = $Center/HBox/Left
@onready var right_column: VBoxContainer = $Center/HBox/Right
@onready var heading_label: Label = $Center/HBox/Left/Label
@onready var scroll: ScrollContainer = $Center/HBox/Left/Scroll
@onready var grid: GridContainer = $Center/HBox/Left/Scroll/Grid
@onready var start_button: Button = $Center/HBox/Right/StartButton

var selected_label: Label = null
var preview_art: TextureRect = null
var details_label: Label = null
var help_label: Label = null
var identity_panel: VBoxContainer = null
var identity_role_label: Label = null
var identity_goal_label: Label = null
var identity_approach_tags: FlowContainer = null

var items: Array[Dictionary] = []
var items_by_id: Dictionary[String, Dictionary] = {}
var buttons_by_id: Dictionary[String, Button] = {}
var selected_id: String = ""
var button_group: ButtonGroup = ButtonGroup.new()
var _hovered_id: String = ""
var _start_button_hover_tween: Tween = null
var _left_plate: Panel = null
var _right_plate: Panel = null
var _preview_art_plate: Panel = null

func _ready() -> void:
	_ensure_preview_panel()
	_apply_gothic_layout()
	_wire_start_button_hover()
	start_button.disabled = true
	if help_label:
		help_label.visible = true
	if not start_button.is_connected("pressed", Callable(self, "_on_StartButton_pressed")):
		start_button.pressed.connect(_on_StartButton_pressed)
	resized.connect(_on_resized)
	_populate_units()
	_on_resized()

func _ensure_preview_panel() -> void:
	var right: VBoxContainer = $"Center/HBox/Right"
	if right == null:
		return
	var legacy: Label = right.get_node_or_null("SelectedLabel") as Label
	if legacy:
		legacy.visible = false
	var preview: VBoxContainer = right.get_node_or_null("Preview") as VBoxContainer
	if preview == null:
		preview = VBoxContainer.new()
		preview.name = "Preview"
		preview.add_theme_constant_override("separation", 10)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(preview)
	selected_label = preview.get_node_or_null("SelectedLabel") as Label
	if selected_label == null:
		selected_label = Label.new()
		selected_label.name = "SelectedLabel"
		selected_label.text = "No champion chosen"
		preview.add_child(selected_label)
	_ensure_identity_panel(preview)
	var art_wrap: CenterContainer = preview.get_node_or_null("ArtWrap") as CenterContainer
	if art_wrap == null:
		var old_art: Node = preview.get_node_or_null("Art")
		if old_art:
			preview.remove_child(old_art)
			old_art.queue_free()
		art_wrap = CenterContainer.new()
		art_wrap.name = "ArtWrap"
		art_wrap.custom_minimum_size = Vector2(380, 300)
		preview.add_child(art_wrap)
	preview_art = art_wrap.get_node_or_null("Art") as TextureRect
	if preview_art == null:
		preview_art = TextureRect.new()
		preview_art.name = "Art"
		preview_art.custom_minimum_size = Vector2(360, 360)
		preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_wrap.add_child(preview_art)
	details_label = preview.get_node_or_null("Details") as Label
	if details_label == null:
		details_label = Label.new()
		details_label.name = "Details"
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		details_label.text = "Hover a unit to preview"
		preview.add_child(details_label)
	help_label = right.get_node_or_null("HelpLabel") as Label
	if help_label == null:
		help_label = Label.new()
		help_label.name = "HelpLabel"
		help_label.text = "Select a unit to continue"
		right.add_child(help_label)
	right.custom_minimum_size = Vector2(500, 0)
	right.size_flags_horizontal = 0
	start_button.size_flags_vertical = 0
	right.move_child(preview, 0)
	right.move_child(start_button, right.get_child_count() - 1)

func _apply_gothic_layout() -> void:
	if background:
		background.color = COLOR_VOID
		if background.material is ShaderMaterial:
			var mat: ShaderMaterial = background.material as ShaderMaterial
			mat.set_shader_parameter("top_color", Color(0.034, 0.026, 0.036, 1.0))
			mat.set_shader_parameter("bottom_color", Color(0.006, 0.005, 0.008, 1.0))
			mat.set_shader_parameter("vignette", 0.48)
			mat.set_shader_parameter("vignette_softness", 0.62)
	if hbox:
		hbox.custom_minimum_size = Vector2(1320.0, 760.0)
		hbox.add_theme_constant_override("separation", 34)
	if left_column:
		left_column.custom_minimum_size = Vector2(760.0, 740.0)
		left_column.add_theme_constant_override("separation", 14)
		_left_plate = _ensure_float_plate(left_column, "GothicRosterPlate", _make_panel_style(COLOR_PANEL, Color(0.36, 0.29, 0.27, 0.86), 1, 7), -2, 18.0)
	if right_column:
		right_column.custom_minimum_size = Vector2(500.0, 740.0)
		right_column.add_theme_constant_override("separation", 16)
		_right_plate = _ensure_float_plate(right_column, "GothicPreviewPlate", _make_panel_style(Color(0.030, 0.025, 0.034, 0.96), Color(0.48, 0.34, 0.25, 0.88), 1, 7), -2, 18.0)
	if heading_label:
		heading_label.text = "Choose Your Starting Unit"
		heading_label.add_theme_font_size_override("font_size", 38)
		heading_label.add_theme_color_override("font_color", COLOR_TEXT)
		heading_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.76))
		heading_label.add_theme_constant_override("outline_size", 3)
	if scroll:
		scroll.custom_minimum_size = Vector2(720.0, 650.0)
		scroll.add_theme_stylebox_override("focus", _make_panel_style(Color(0.0, 0.0, 0.0, 0.0), COLOR_GOLD, 1, 4))
	if grid:
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 14)
	if selected_label:
		selected_label.add_theme_font_size_override("font_size", 32)
		selected_label.add_theme_color_override("font_color", COLOR_TEXT)
		selected_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		selected_label.add_theme_constant_override("outline_size", 2)
	if identity_goal_label:
		identity_goal_label.add_theme_color_override("font_color", COLOR_MUTED)
	if details_label:
		details_label.add_theme_font_size_override("font_size", 18)
		details_label.add_theme_color_override("font_color", COLOR_MUTED)
	if help_label:
		help_label.add_theme_font_size_override("font_size", 16)
		help_label.add_theme_color_override("font_color", COLOR_MUTED)
	if preview_art:
		preview_art.custom_minimum_size = Vector2(410.0, 410.0)
		preview_art.modulate = Color(0.92, 0.88, 0.82, 1.0)
	var art_wrap: Control = right_column.get_node_or_null("Preview/ArtWrap") as Control
	if art_wrap:
		art_wrap.custom_minimum_size = Vector2(460.0, 430.0)
		_preview_art_plate = _ensure_float_plate(art_wrap, "GothicArtPlate", _make_panel_style(Color(0.014, 0.012, 0.018, 0.86), Color(0.32, 0.24, 0.23, 0.84), 1, 6), -1, 8.0)
	call_deferred("_position_gothic_plates")
	_style_start_button()

func _ensure_identity_panel(preview: VBoxContainer) -> void:
	identity_panel = preview.get_node_or_null("IdentityPanel") as VBoxContainer
	if identity_panel == null:
		identity_panel = VBoxContainer.new()
		identity_panel.name = "IdentityPanel"
		identity_panel.add_theme_constant_override("separation", 4)
		identity_panel.visible = false
		preview.add_child(identity_panel)
	if selected_label:
		var index := selected_label.get_index() + 1
		preview.move_child(identity_panel, min(index, preview.get_child_count() - 1))
	identity_role_label = identity_panel.get_node_or_null("RoleBadge") as Label
	if identity_role_label == null:
		identity_role_label = Label.new()
		identity_role_label.name = "RoleBadge"
		identity_role_label.uppercase = true
		identity_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity_role_label.add_theme_stylebox_override("normal", _make_badge_style())
		identity_role_label.modulate = Color(1, 1, 1, 0.95)
		identity_panel.add_child(identity_role_label)
	identity_goal_label = identity_panel.get_node_or_null("GoalLabel") as Label
	if identity_goal_label == null:
		identity_goal_label = Label.new()
		identity_goal_label.name = "GoalLabel"
		identity_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity_goal_label.add_theme_font_size_override("font_size", 18)
		identity_goal_label.modulate = Color(1, 1, 1, 0.9)
		identity_panel.add_child(identity_goal_label)
	identity_approach_tags = identity_panel.get_node_or_null("ApproachTags") as FlowContainer
	if identity_approach_tags == null:
		identity_approach_tags = FlowContainer.new()
		identity_approach_tags.name = "ApproachTags"
		identity_approach_tags.vertical = false
		identity_approach_tags.add_theme_constant_override("h_separation", 6)
		identity_approach_tags.add_theme_constant_override("v_separation", 4)
		identity_panel.add_child(identity_approach_tags)

func show_screen() -> void:
	visible = true
	_apply_gothic_layout()
	_style_unit_cards()
	start_button.disabled = selected_id == ""
	if help_label:
		help_label.visible = start_button.disabled
	_on_resized()

func hide_screen() -> void:
	visible = false

func reset_selection() -> void:
	selected_id = ""
	_hovered_id = ""
	for unit_id: String in buttons_by_id.keys():
		var button: Button = buttons_by_id.get(unit_id, null) as Button
		if button == null:
			continue
		button.button_pressed = false
		button.scale = Vector2.ONE
		button.z_index = 0
		if button.has_meta("hover_tween"):
			var hover_tween: Tween = button.get_meta("hover_tween") as Tween
			if hover_tween != null and is_instance_valid(hover_tween):
				hover_tween.kill()
	if start_button != null:
		start_button.disabled = true
		start_button.scale = Vector2.ONE
		_style_start_button()
	if help_label != null:
		help_label.visible = true
	_clear_preview()
	_style_unit_cards()

func _populate_units() -> void:
	items.clear()
	items_by_id.clear()
	buttons_by_id.clear()
	for child in grid.get_children():
		child.queue_free()
	# Use catalog to obtain starter-eligible units at starting level
	var catalog: UnitCatalog = UnitCatalog.new()
	catalog.refresh()
	var level: int = int(ShopConfig.STARTING_LEVEL)
	var ids: Array[String] = catalog.list_starter_ids(level)
	var meta_items: Array[Dictionary] = []
	for uid: String in ids:
		var meta: Dictionary = catalog.get_unit_meta(String(uid))
		if meta.is_empty():
			continue
		var entry: Dictionary = meta.duplicate(true)
		entry["id"] = String(uid)
		meta_items.append(entry)
	# Sort by name for display
	meta_items.sort_custom(func(a, b): return String(a.get("name", "")).nocasecmp_to(String(b.get("name", ""))) < 0)
	items = meta_items
	for it: Dictionary in items:
		var uid2: String = String(it.get("id", ""))
		if uid2 == "":
			continue
		items_by_id[uid2] = it
		var tile: VBoxContainer = VBoxContainer.new()
		tile.name = "UnitCard_%s" % _node_safe_id(uid2)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(150, 184)
		tile.add_theme_constant_override("separation", 4)
		var btn: Button = Button.new()
		btn.name = "UnitButton_%s" % _node_safe_id(uid2)
		btn.toggle_mode = true
		btn.button_group = button_group
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(150, 138)
		btn.set_meta("unit_id", uid2)
		var sp: String = String(it.get("sprite_path", ""))
		if sp != "":
			var icon: Texture2D = load(sp) as Texture2D
			if icon:
				btn.icon = icon
		var name_label: Label = Label.new()
		name_label.name = "UnitName"
		name_label.text = String(it.get("name", ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var role_label: Label = Label.new()
		role_label.name = "UnitRole"
		role_label.text = _format_role(String(it.get("primary_role", ""))).to_upper()
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(btn)
		tile.add_child(name_label)
		tile.add_child(role_label)
		btn.pressed.connect(_on_unit_button_pressed.bind(btn, uid2, String(it.get("name", ""))))
		btn.mouse_entered.connect(_on_unit_hovered.bind(uid2))
		btn.mouse_exited.connect(_on_unit_unhovered)
		btn.focus_entered.connect(_on_unit_hovered.bind(uid2))
		btn.focus_exited.connect(_on_unit_unhovered)
		grid.add_child(tile)
		buttons_by_id[uid2] = btn
		_style_unit_card(tile, btn, name_label, role_label, false)
	_style_unit_cards()
	if selected_id == "" and items.size() > 0:
		var first_id: String = String(items[0].get("id", ""))
		if first_id != "":
			_update_preview(first_id, false)

func _unit_entry_from_resource(res: Resource) -> Dictionary:
	var id: String = ""
	var display_name: String = ""
	var sprite_path: String = ""
	var roles: PackedStringArray = PackedStringArray()
	var traits: PackedStringArray = PackedStringArray()
	var primary_role: String = ""
	var primary_goal: String = ""
	var approaches: PackedStringArray = PackedStringArray()
	var alt_goals: PackedStringArray = PackedStringArray()
	if res is UnitProfile:
		var p: UnitProfile = res
		id = String(p.id)
		display_name = String(p.name)
		sprite_path = String(p.sprite_path)
		roles = p.role_names()
		traits = PackedStringArray(p.traits)
		primary_role = _normalize_role(p.primary_role)
		primary_goal = _normalize_key(p.primary_goal)
		approaches = PackedStringArray(p.approaches)
		alt_goals = PackedStringArray(p.alt_goals)
		if p.identity != null:
			primary_role = _normalize_role(p.identity.primary_role)
			primary_goal = _normalize_key(p.identity.primary_goal)
			approaches = PackedStringArray(p.identity.approaches)
			alt_goals = PackedStringArray(p.identity.alt_goals)
	else:
		return {}
	if id == "":
		return {}
	if primary_role == "" and roles.size() > 0:
		primary_role = _normalize_role(roles[0])
	return {
		"id": id,
		"name": display_name,
		"sprite_path": sprite_path,
		"roles": roles,
		"traits": traits,
		"primary_role": primary_role,
		"primary_goal": primary_goal,
		"approaches": approaches,
		"alt_goals": alt_goals,
	}

func _on_unit_button_pressed(_btn: Button, id: String, _name: String) -> void:
	selected_id = id
	_update_preview(id, true)
	start_button.disabled = false
	_style_start_button()
	_style_unit_cards()
	if help_label:
		help_label.visible = false

func _on_StartButton_pressed() -> void:
	if selected_id == "":
		return
	emit_signal("unit_selected", selected_id)

func _on_unit_hovered(id: String) -> void:
	if id != "":
		if _hovered_id != id and _hovered_id != "":
			_apply_unit_button_motion(_hovered_id, false)
		_hovered_id = id
		_apply_unit_button_motion(id, true)
		_update_preview(id, false)
		_style_unit_cards()

func _update_preview(id: String, is_selected: bool = false) -> void:
	if selected_label == null:
		return
	var it: Dictionary = items_by_id.get(id, {})
	if it.is_empty():
		_clear_preview()
		return
	var display_name: String = String(it.get("name", ""))
	selected_label.text = ("%s" if is_selected else "Inspecting %s") % [display_name]
	var role_text := _format_role(String(it.get("primary_role", "")))
	var goal_text := _format_goal(String(it.get("primary_goal", "")))
	var approach_arr := _duplicate_strings(it.get("approaches", PackedStringArray()))
	_set_identity_summary(role_text, goal_text, approach_arr)
	var sp: String = String(it.get("sprite_path", ""))
	if preview_art:
		preview_art.texture = load(sp) if sp != "" else null
	if details_label:
		var alt_goals: String = _format_list(_duplicate_strings(it.get("alt_goals", PackedStringArray())), 3)
		var trait_text: String = _format_list(_duplicate_strings(it.get("traits", PackedStringArray())), 5)
		var lines: Array[String] = []
		if alt_goals != "":
			lines.append("Alt Goals: %s" % alt_goals)
		if trait_text != "":
			lines.append("Traits: %s" % trait_text)
		if lines.is_empty():
			lines.append("Identity summary above")
		details_label.text = "\n".join(lines)

func _on_unit_unhovered() -> void:
	if _hovered_id != "":
		_apply_unit_button_motion(_hovered_id, false)
		_hovered_id = ""
		_style_unit_cards()
	if selected_id != "":
		_update_preview(selected_id, true)
		return
	_clear_preview()

func _clear_preview() -> void:
	if selected_label:
		selected_label.text = "No champion chosen"
	if preview_art:
		preview_art.texture = null
	_clear_identity_panel()
	if details_label:
		details_label.text = "Hover a unit to preview"

func _set_identity_summary(role_text: String, goal_text: String, approaches: Array) -> void:
	var show_role := role_text.strip_edges() != ""
	if identity_role_label:
		identity_role_label.text = role_text
		identity_role_label.visible = show_role
	var show_goal := goal_text.strip_edges() != ""
	if identity_goal_label:
		identity_goal_label.text = goal_text
		identity_goal_label.visible = show_goal
	var show_tags := _set_identity_approach_tags(approaches)
	if identity_panel:
		identity_panel.visible = show_role or show_goal or show_tags

func _set_identity_approach_tags(approaches: Array) -> bool:
	if identity_approach_tags == null:
		return false
	for child in identity_approach_tags.get_children():
		child.queue_free()
	var seen: Dictionary = {}
	var shown := 0
	for approach in approaches:
		var pretty := _format_token(String(approach))
		if pretty == "" or seen.has(pretty):
			continue
		seen[pretty] = true
		var label := Label.new()
		label.text = pretty
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1, 1, 1, 0.9)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_stylebox_override("normal", _make_tag_style())
		identity_approach_tags.add_child(label)
		shown += 1
		if shown >= 5:
			break
	identity_approach_tags.visible = shown > 0
	return identity_approach_tags.visible

func _clear_identity_panel() -> void:
	if identity_role_label:
		identity_role_label.visible = false
	if identity_goal_label:
		identity_goal_label.visible = false
	if identity_approach_tags:
		for child in identity_approach_tags.get_children():
			child.queue_free()
		identity_approach_tags.visible = false
	if identity_panel:
		identity_panel.visible = false

func _on_resized() -> void:
	var tile_w: float = 170.0
	var available: float = max(1.0, float(scroll.size.x))
	var cols: int = int(floor(available / tile_w))
	grid.columns = max(3, min(cols, 5))
	_position_gothic_plates()

func _format_role(value: String) -> String:
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

func _format_goal(goal_value: String) -> String:
	var goal := String(goal_value).strip_edges()
	if goal == "":
		return ""
	var parts := goal.split(".", false, 2)
	if parts.size() >= 2:
		var role_part := _format_role(parts[0])
		var goal_part := _format_token(parts[1])
		if role_part != "":
			if goal_part != "":
				return "%s - %s" % [role_part, goal_part]
			return role_part
	return _format_token(goal)

func _format_list(values: Array, limit: int) -> String:
	if values == null or values.is_empty():
		return ""
	var formatted := PackedStringArray()
	var seen: Dictionary = {}
	for i in range(values.size()):
		if formatted.size() >= limit:
			break
		var token := _format_token(String(values[i]))
		if token == "" or seen.has(token):
			continue
		seen[token] = true
		formatted.append(token)
	if values.size() > limit and formatted.size() == limit:
		formatted.append("+")
	return ", ".join(formatted)

func _format_token(value: String) -> String:
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

func _normalize_role(value: String) -> String:
	var s := String(value).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

func _normalize_key(value: String) -> String:
	return String(value).strip_edges().to_lower()

func _duplicate_strings(values) -> Array:
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

func _make_badge_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = _make_panel_style(Color(0.16, 0.075, 0.090, 0.94), Color(0.72, 0.42, 0.25, 0.88), 1, 5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

func _make_tag_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = _make_panel_style(Color(0.046, 0.042, 0.050, 0.95), Color(0.36, 0.28, 0.22, 0.90), 1, 4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

func _style_unit_cards() -> void:
	for tile_node in grid.get_children():
		var tile: VBoxContainer = tile_node as VBoxContainer
		if tile == null:
			continue
		var button: Button = null
		var name_label: Label = null
		var role_label: Label = null
		for child in tile.get_children():
			if child is Button:
				button = child as Button
			elif child is Label and child.name == "UnitName":
				name_label = child as Label
			elif child is Label and child.name == "UnitRole":
				role_label = child as Label
		if button == null:
			continue
		var unit_id: String = String(button.get_meta("unit_id")) if button.has_meta("unit_id") else ""
		var hovered: bool = unit_id != "" and unit_id == _hovered_id
		_style_unit_card(tile, button, name_label, role_label, button.button_pressed, hovered)

func _style_unit_card(tile: VBoxContainer, button: Button, name_label: Label, role_label: Label, selected: bool, hovered: bool = false) -> void:
	tile.add_theme_constant_override("separation", 4)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pivot_offset = button.size * 0.5 if button.size != Vector2.ZERO else button.custom_minimum_size * 0.5
	button.add_theme_stylebox_override("normal", _make_unit_button_style(selected, hovered))
	button.add_theme_stylebox_override("hover", _make_unit_button_style(false, true))
	button.add_theme_stylebox_override("pressed", _make_unit_button_style(true, true))
	button.add_theme_stylebox_override("focus", _make_unit_button_style(selected, true))
	button.add_theme_stylebox_override("disabled", _make_unit_button_style(false, false))
	if name_label:
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", COLOR_TEXT if selected or hovered else Color(0.82, 0.78, 0.70, 1.0))
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
		name_label.add_theme_constant_override("outline_size", 1)
	if role_label:
		role_label.add_theme_font_size_override("font_size", 11)
		role_label.add_theme_color_override("font_color", COLOR_GOLD if selected or hovered else COLOR_MUTED)

func _make_unit_button_style(selected: bool, highlighted: bool) -> StyleBoxFlat:
	var bg: Color = Color(0.040, 0.035, 0.045, 0.96)
	var border: Color = Color(0.24, 0.21, 0.22, 0.92)
	if selected:
		bg = Color(0.105, 0.044, 0.056, 0.98)
		border = COLOR_GOLD
	elif highlighted:
		bg = Color(0.070, 0.047, 0.057, 0.98)
		border = Color(0.62, 0.38, 0.25, 0.96)
	var sb: StyleBoxFlat = _make_panel_style(bg, border, 2 if selected or highlighted else 1, 5)
	sb.shadow_size = 10 if selected or highlighted else 5
	sb.shadow_color = Color(0.56, 0.15, 0.040, 0.30) if selected or highlighted else Color(0.0, 0.0, 0.0, 0.38)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _style_start_button() -> void:
	if start_button == null:
		return
	start_button.custom_minimum_size = Vector2(500.0, 68.0)
	start_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if start_button.disabled else Control.CURSOR_POINTING_HAND
	start_button.add_theme_font_size_override("font_size", 27)
	start_button.add_theme_color_override("font_color", COLOR_TEXT)
	start_button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.76, 1.0))
	start_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.80, 0.58, 1.0))
	start_button.add_theme_color_override("font_disabled_color", Color(0.43, 0.40, 0.38, 1.0))
	start_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_BLOOD, Color(0.92, 0.47, 0.30, 0.86), 2, 5))
	start_button.add_theme_stylebox_override("hover", _make_panel_style(COLOR_BLOOD_HOT, COLOR_GOLD, 2, 5))
	start_button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.22, 0.020, 0.040, 1.0), COLOR_GOLD, 2, 5))
	start_button.add_theme_stylebox_override("focus", _make_panel_style(Color(0.18, 0.040, 0.052, 1.0), COLOR_GOLD, 2, 5))
	start_button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.030, 0.027, 0.034, 0.84), Color(0.16, 0.15, 0.17, 0.88), 1, 5))

func _wire_start_button_hover() -> void:
	if start_button == null:
		return
	start_button.pivot_offset = start_button.size * 0.5 if start_button.size != Vector2.ZERO else start_button.custom_minimum_size * 0.5
	if not start_button.is_connected("mouse_entered", Callable(self, "_on_start_button_entered")):
		start_button.mouse_entered.connect(_on_start_button_entered)
	if not start_button.is_connected("mouse_exited", Callable(self, "_on_start_button_exited")):
		start_button.mouse_exited.connect(_on_start_button_exited)
	if not start_button.is_connected("focus_entered", Callable(self, "_on_start_button_entered")):
		start_button.focus_entered.connect(_on_start_button_entered)
	if not start_button.is_connected("focus_exited", Callable(self, "_on_start_button_exited")):
		start_button.focus_exited.connect(_on_start_button_exited)
	if not start_button.is_connected("resized", Callable(self, "_sync_start_button_pivot")):
		start_button.resized.connect(_sync_start_button_pivot)

func _on_start_button_entered() -> void:
	_apply_start_button_motion(true)

func _on_start_button_exited() -> void:
	_apply_start_button_motion(false)

func _apply_start_button_motion(active: bool) -> void:
	if start_button == null:
		return
	if _start_button_hover_tween != null and is_instance_valid(_start_button_hover_tween):
		_start_button_hover_tween.kill()
	var target_scale: Vector2 = Vector2(1.025, 1.025) if active and not start_button.disabled else Vector2.ONE
	_start_button_hover_tween = create_tween()
	_start_button_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_button_hover_tween.tween_property(start_button, "scale", target_scale, 0.10)

func _sync_start_button_pivot() -> void:
	if start_button != null:
		start_button.pivot_offset = start_button.size * 0.5 if start_button.size != Vector2.ZERO else start_button.custom_minimum_size * 0.5

func _apply_unit_button_motion(id: String, active: bool) -> void:
	var button: Button = buttons_by_id.get(id, null) as Button
	if button == null:
		return
	var existing: Tween = button.get_meta("hover_tween") as Tween if button.has_meta("hover_tween") else null
	if existing != null and is_instance_valid(existing):
		existing.kill()
	button.pivot_offset = button.size * 0.5 if button.size != Vector2.ZERO else button.custom_minimum_size * 0.5
	button.z_index = 55 if active else 0
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.035, 1.035) if active else Vector2.ONE, 0.09)
	button.set_meta("hover_tween", tween)

func _ensure_float_plate(control: Control, plate_name: String, style: StyleBoxFlat, z_value: int, pad: float) -> Panel:
	var plate: Panel = get_node_or_null(plate_name) as Panel
	if plate == null:
		plate = Panel.new()
		plate.name = plate_name
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.z_index = z_value
		plate.z_as_relative = false
		add_child(plate)
		move_child(plate, 1)
	plate.set_meta("target_path", get_path_to(control))
	plate.set_meta("pad", pad)
	plate.add_theme_stylebox_override("panel", style)
	_position_float_plate(plate)
	return plate

func _position_gothic_plates() -> void:
	_position_float_plate(_left_plate)
	_position_float_plate(_right_plate)
	_position_float_plate(_preview_art_plate)

func _position_float_plate(plate: Panel) -> void:
	if plate == null or not plate.has_meta("target_path"):
		return
	var target: Control = get_node_or_null(plate.get_meta("target_path")) as Control
	if target == null:
		return
	var pad: float = float(plate.get_meta("pad", 0.0))
	var root_origin: Vector2 = global_position
	plate.position = target.global_position - root_origin - Vector2(pad, pad)
	plate.size = target.size + Vector2(pad * 2.0, pad * 2.0)

func _make_panel_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.shadow_size = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	return sb

func _node_safe_id(value: String) -> String:
	var out: String = value.strip_edges().to_lower()
	out = out.replace(" ", "_")
	out = out.replace("-", "_")
	out = out.replace(".", "_")
	out = out.replace("/", "_")
	return out
