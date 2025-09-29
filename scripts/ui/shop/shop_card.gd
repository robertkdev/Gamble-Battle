extends Button
class_name ShopCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitIconScene := preload("res://scenes/ui/traits/TraitIcon.tscn")

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $Name
@onready var _price_label: Label = $Price
@onready var _role_label: Label = $Role
@onready var _traits_box: VBoxContainer = $TraitIcons

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
	offer_id = String(props.get("id", ""))
	var title := String(props.get("name", "?"))
	var price_i := int(props.get("price", props.get("cost", 0)))
	var img_path := String(props.get("image_path", props.get("sprite_path", "")))
	var role_text := String(props.get("role", ""))
	var roles: Array = _coerce_array(props.get("roles", []))
	var traits: Array = _coerce_array(props.get("traits", []))

	if role_text == "" and roles.size() > 0:
		role_text = _format_role(roles[0])

	if _name_label:
		_name_label.text = title
	if _price_label:
		_price_label.text = str(price_i) + "g"
	if _icon:
		var tex: Texture2D = null
		if img_path != "":
			tex = load(img_path)
		if tex == null:
			tex = TextureUtils.make_circle_texture(Color(0.75,0.75,0.75), 96)
		_icon.texture = tex
	if _role_label:
		if role_text.strip_edges() != "":
			_role_label.text = "Role: %s" % role_text
			_role_label.visible = true
		else:
			_role_label.text = ""
			_role_label.visible = false
	_set_traits(traits)

func set_affordable(affordable: bool) -> void:
	var ok := bool(affordable)
	disabled = disabled and not ok # don't re-enable if disabled for other reasons
	if _price_label:
		_price_label.modulate = Color(1,1,0.8,0.95) if ok else Color(1,0.5,0.5,0.85)
	tooltip_text = "" if ok else "Not enough gold"

func set_shop_disabled(reason) -> void:
	_disabled_reason = String(reason)
	disabled = true
	tooltip_text = _disabled_reason
	modulate = Color(1,1,1,0.6)

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

signal clicked(slot_index: int)

func _on_pressed() -> void:
	emit_signal("clicked", int(slot_index))
