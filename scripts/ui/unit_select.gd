extends Control
class_name UnitSelect

signal unit_selected(unit_id: String)

const UnitFactory = preload("res://scripts/unit_factory.gd")

@onready var scroll: ScrollContainer = $Center/HBox/Left/Scroll
@onready var grid: GridContainer = $Center/HBox/Left/Scroll/Grid
@onready var selected_label: Label = $Center/HBox/Right/SelectedLabel
@onready var start_button: Button = $Center/HBox/Right/StartButton

var items: Array = [] # [{ id, name, sprite_path }]
var selected_id: String = ""

func _ready() -> void:
	start_button.disabled = true
	_populate_units()

func show_screen() -> void:
	visible = true
	start_button.disabled = selected_id == ""

func hide_screen() -> void:
	visible = false

func _populate_units() -> void:
	items.clear()
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
		if res is UnitProfile:
			var p: UnitProfile = res
			id = String(p.id)
			name = String(p.name)
			sprite_path = String(p.sprite_path)
		elif res is UnitDef:
			var d: UnitDef = res
			id = String(d.id)
			name = String(d.name)
			sprite_path = String(d.sprite_path)
		if id == "":
			continue
		items.append({"id": id, "name": name, "sprite_path": sprite_path})
	dir.list_dir_end()
	for it in items:
		var btn := Button.new()
		btn.text = String(it.get("name", ""))
		btn.expand_icon = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 100
		btn.custom_minimum_size.x = 100
		var icon: Texture2D = null
		var sp: String = String(it.get("sprite_path", ""))
		if sp != "":
			icon = load(sp)
		if icon:
			btn.icon = icon
		btn.pressed.connect(_on_unit_button_pressed.bind(btn, String(it.get("id", "")), String(it.get("name", ""))))
		grid.add_child(btn)

func _on_unit_button_pressed(btn: Button, id: String, name: String) -> void:
	for child in grid.get_children():
		if child is Button and child != btn:
			(child as Button).button_pressed = false
	btn.button_pressed = true
	selected_id = id
	selected_label.text = "Selected: %s" % name
	start_button.disabled = false

func _on_StartButton_pressed() -> void:
	if selected_id == "":
		return
	emit_signal("unit_selected", selected_id)
