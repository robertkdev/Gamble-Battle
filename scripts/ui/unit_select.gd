extends Control
class_name UnitSelect

signal unit_selected(unit_id: String)

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

var items: Array = []
var items_by_id: Dictionary = {}
var buttons_by_id: Dictionary = {}
var selected_id: String = ""
var button_group: ButtonGroup = ButtonGroup.new()

func _ready() -> void:
	_ensure_preview_panel()
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
		selected_label.text = "Selected: (none)"
		selected_label.add_theme_font_size_override("font_size", 28)
		preview.add_child(selected_label)
	_ensure_identity_panel(preview)
	var art_wrap: CenterContainer = preview.get_node_or_null("ArtWrap") as CenterContainer
	if art_wrap == null:
		var old_art = preview.get_node_or_null("Art")
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
		details_label.add_theme_font_size_override("font_size", 18)
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		details_label.text = "Hover a unit to preview"
		preview.add_child(details_label)
	help_label = right.get_node_or_null("HelpLabel") as Label
	if help_label == null:
		help_label = Label.new()
		help_label.name = "HelpLabel"
		help_label.text = "Select a unit to continue"
		help_label.modulate = Color(1, 1, 1, 0.7)
		help_label.add_theme_font_size_override("font_size", 16)
		right.add_child(help_label)
	right.custom_minimum_size = Vector2(400, 0)
	right.size_flags_horizontal = 0
	start_button.size_flags_vertical = 0
	right.move_child(preview, 0)
	right.move_child(start_button, right.get_child_count() - 1)

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
	start_button.disabled = selected_id == ""
	if help_label:
		help_label.visible = start_button.disabled
	_on_resized()

func hide_screen() -> void:
	visible = false

func _populate_units() -> void:
	items.clear()
	items_by_id.clear()
	buttons_by_id.clear()
	for child in grid.get_children():
		child.queue_free()
	var dir := DirAccess.open("res://data/units")
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if f.begins_with(".") or dir.current_is_dir():
			continue
		if not f.ends_with(".tres"):
			continue
		var path := "res://data/units/%s" % f
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		var unit_data := _unit_entry_from_resource(res)
		if unit_data.is_empty():
			continue
		items.append(unit_data)
	dir.list_dir_end()
	items.sort_custom(func(a, b): return String(a.get("name", "")).nocasecmp_to(String(b.get("name", ""))) < 0)
	for it in items:
		var uid := String(it.get("id", ""))
		if uid == "":
			continue
		items_by_id[uid] = it
		var tile := VBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(120, 140)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = button_group
		btn.focus_mode = Control.FOCUS_ALL
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(120, 120)
		var sp: String = String(it.get("sprite_path", ""))
		if sp != "":
			var icon: Texture2D = load(sp)
			if icon:
				btn.icon = icon
		var name_label := Label.new()
		name_label.text = String(it.get("name", ""))
		name_label.horizontal_alignment = 1
		name_label.modulate = Color(1, 1, 1, 0.9)
		tile.add_child(btn)
		tile.add_child(name_label)
		btn.pressed.connect(_on_unit_button_pressed.bind(btn, uid, String(it.get("name", ""))))
		btn.mouse_entered.connect(_on_unit_hovered.bind(uid))
		btn.mouse_exited.connect(_on_unit_unhovered)
		grid.add_child(tile)
		buttons_by_id[uid] = btn

func _unit_entry_from_resource(res) -> Dictionary:
	var id := ""
	var name := ""
	var sprite_path := ""
	var roles := PackedStringArray()
	var traits := PackedStringArray()
	var primary_role := ""
	var primary_goal := ""
	var approaches := PackedStringArray()
	var alt_goals := PackedStringArray()
	if res is UnitProfile:
		var p: UnitProfile = res
		id = String(p.id)
		name = String(p.name)
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
	elif res is UnitDef:
		var d: UnitDef = res
		id = String(d.id)
		name = String(d.name)
		sprite_path = String(d.sprite_path)
		roles = PackedStringArray(d.roles)
		traits = PackedStringArray(d.traits)
		primary_role = _normalize_role(d.primary_role)
		primary_goal = _normalize_key(d.primary_goal)
		approaches = PackedStringArray(d.approaches)
		alt_goals = PackedStringArray(d.alt_goals)
		if d.identity != null:
			primary_role = _normalize_role(d.identity.primary_role)
			primary_goal = _normalize_key(d.identity.primary_goal)
			approaches = PackedStringArray(d.identity.approaches)
			alt_goals = PackedStringArray(d.identity.alt_goals)
	if id == "":
		return {}
	if primary_role == "" and roles.size() > 0:
		primary_role = _normalize_role(roles[0])
	return {
		"id": id,
		"name": name,
		"sprite_path": sprite_path,
		"roles": roles,
		"traits": traits,
		"primary_role": primary_role,
		"primary_goal": primary_goal,
		"approaches": approaches,
		"alt_goals": alt_goals,
	}

func _on_unit_button_pressed(btn: Button, id: String, name: String) -> void:
	selected_id = id
	_update_preview(id, true)
	start_button.disabled = false
	if help_label:
		help_label.visible = false

func _on_StartButton_pressed() -> void:
	if selected_id == "":
		return
	emit_signal("unit_selected", selected_id)

func _on_unit_hovered(id: String) -> void:
	if id != "":
		_update_preview(id, false)

func _update_preview(id: String, is_selected: bool = false) -> void:
	if selected_label == null:
		return
	var it = items_by_id.get(id, null)
	if it == null:
		_clear_preview()
		return
	var name := String(it.get("name", ""))
	selected_label.text = ("Selected: %s" if is_selected else "Preview: %s") % [name]
	var role_text := _format_role(String(it.get("primary_role", "")))
	var goal_text := _format_goal(String(it.get("primary_goal", "")))
	var approach_arr := _duplicate_strings(it.get("approaches", PackedStringArray()))
	_set_identity_summary(role_text, goal_text, approach_arr)
	var sp: String = String(it.get("sprite_path", ""))
	if preview_art:
		preview_art.texture = load(sp) if sp != "" else null
	if details_label:
		var alt_goals := _format_list(_duplicate_strings(it.get("alt_goals", PackedStringArray())), 3)
		var trait_text := _format_list(_duplicate_strings(it.get("traits", PackedStringArray())), 5)
		var lines: Array[String] = []
		if alt_goals != "":
			lines.append("Alt Goals: %s" % alt_goals)
		if trait_text != "":
			lines.append("Traits: %s" % trait_text)
		if lines.is_empty():
			lines.append("Identity summary above")
		details_label.text = "\n".join(lines)

func _on_unit_unhovered() -> void:
	if selected_id != "":
		_update_preview(selected_id, true)
		return
	_clear_preview()

func _clear_preview() -> void:
	if selected_label:
		selected_label.text = "Selected: (none)"
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
	var tile_w: float = 140.0
	var available: float = max(1.0, float(scroll.size.x))
	var cols: int = int(floor(available / tile_w))
	grid.columns = max(3, min(cols, 8))

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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.121569, 0.211765, 0.266667, 0.95)
	sb.corner_radius_top_left = 7
	sb.corner_radius_top_right = 7
	sb.corner_radius_bottom_right = 7
	sb.corner_radius_bottom_left = 7
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

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
