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

var items: Array = [] # [{ id, name, sprite_path, roles, traits }]
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
	# Hide legacy SelectedLabel if present
	var legacy: Label = right.get_node_or_null("SelectedLabel") as Label
	if legacy:
		legacy.visible = false
	# Ensure preview container exists
	var preview: VBoxContainer = right.get_node_or_null("Preview") as VBoxContainer
	if preview == null:
		preview = VBoxContainer.new()
		preview.name = "Preview"
		preview.add_theme_constant_override("separation", 8)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(preview)
	selected_label = (preview.get_node_or_null("SelectedLabel") as Label)
	if selected_label == null:
		selected_label = Label.new()
		selected_label.name = "SelectedLabel"
		selected_label.text = "Selected: (none)"
		selected_label.add_theme_font_size_override("font_size", 28)
		preview.add_child(selected_label)
	# Art wrapper (prevents over-expansion)
	var art_wrap: CenterContainer = preview.get_node_or_null("ArtWrap") as CenterContainer
	if art_wrap == null:
		# Remove any old direct Art node to avoid huge sizing
		var old_art = preview.get_node_or_null("Art")
		if old_art:
			preview.remove_child(old_art)
			old_art.queue_free()
		art_wrap = CenterContainer.new()
		art_wrap.name = "ArtWrap"
		art_wrap.custom_minimum_size = Vector2(380, 300)
		preview.add_child(art_wrap)
	preview_art = (art_wrap.get_node_or_null("Art") as TextureRect)
	if preview_art == null:
		preview_art = TextureRect.new()
		preview_art.name = "Art"
		preview_art.custom_minimum_size = Vector2(360, 360)
		preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_wrap.add_child(preview_art)
	details_label = (preview.get_node_or_null("Details") as Label)
	if details_label == null:
		details_label = Label.new()
		details_label.name = "Details"
		details_label.add_theme_font_size_override("font_size", 18)
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		details_label.text = "Hover a unit to preview"
		preview.add_child(details_label)
	# Ensure helper label exists
	help_label = (right.get_node_or_null("HelpLabel") as Label)
	if help_label == null:
		help_label = Label.new()
		help_label.name = "HelpLabel"
		help_label.text = "Select a unit to continue"
		help_label.modulate = Color(1,1,1,0.7)
		help_label.add_theme_font_size_override("font_size", 16)
		right.add_child(help_label)
	# Layout tweaks
	right.custom_minimum_size = Vector2(400, 0)
	right.size_flags_horizontal = 0
	start_button.size_flags_vertical = 0
	# Reorder so preview is first and start is last
	right.move_child(preview, 0)
	right.move_child(start_button, right.get_child_count() - 1)

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
		var id := ""
		var name := ""
		var sprite_path := ""
		var roles: PackedStringArray = PackedStringArray()
		var traits: PackedStringArray = PackedStringArray()
		if res is UnitProfile:
			var p: UnitProfile = res
			id = String(p.id)
			name = String(p.name)
			sprite_path = String(p.sprite_path)
			roles = p.role_names()
			traits = PackedStringArray(p.traits)
		elif res is UnitDef:
			var d: UnitDef = res
			id = String(d.id)
			name = String(d.name)
			sprite_path = String(d.sprite_path)
			roles = PackedStringArray(d.roles)
			traits = PackedStringArray(d.traits)
		if id == "":
			continue
		items.append({"id": id, "name": name, "sprite_path": sprite_path, "roles": roles, "traits": traits})
	dir.list_dir_end()
	# Sort by name, case-insensitive
	items.sort_custom(func(a, b): return String(a.get("name", "")).nocasecmp_to(String(b.get("name", ""))) < 0)
	for it in items:
		items_by_id[String(it.get("id", ""))] = it
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
		name_label.modulate = Color(1,1,1,0.9)
		tile.add_child(btn)
		tile.add_child(name_label)
		btn.pressed.connect(_on_unit_button_pressed.bind(btn, String(it.get("id", "")), String(it.get("name", ""))))
		btn.mouse_entered.connect(_on_unit_hovered.bind(String(it.get("id", ""))))
		btn.mouse_exited.connect(_on_unit_unhovered)
		grid.add_child(tile)
		buttons_by_id[String(it.get("id", ""))] = btn

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
		selected_label.text = "Selected: (none)"
		if preview_art:
			preview_art.texture = null
		if details_label:
			details_label.text = ""
		return
	selected_label.text = ("Selected: %s" if is_selected else "Preview: %s") % String(it.get("name", ""))
	var sp: String = String(it.get("sprite_path", ""))
	if preview_art:
		preview_art.texture = load(sp) if sp != "" else null
	var roles: PackedStringArray = it.get("roles", PackedStringArray())
	var traits: PackedStringArray = it.get("traits", PackedStringArray())
	if details_label:
		var role_strings: Array = []
		for r in roles:
			role_strings.append(String(r).replace("_", " "))
		details_label.text = "Role: %s\nTraits: %s" % [
			String(", ".join(role_strings)),
			String(", ".join(traits))
		]

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
	if details_label:
		details_label.text = "Hover a unit to preview"

func _on_resized() -> void:
	var tile_w: float = 140.0
	var available: float = max(1.0, float(scroll.size.x))
	var cols: int = int(floor(available / tile_w))
	grid.columns = max(3, min(cols, 8))
