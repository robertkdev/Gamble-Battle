extends Button
class_name ShopCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")

@onready var _icon: TextureRect = $Box/Icon
@onready var _name_label: Label = $Box/Name
@onready var _price_label: Label = $Box/Price
@onready var _tags_box: HBoxContainer = $Box/Tags

var offer_id: String = ""
var _disabled_reason: String = ""
var slot_index: int = -1

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
	var tags: Array = (props.get("tags", []) as Array)

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
	_set_tags(tags)

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

func _set_tags(tags: Array) -> void:
	if _tags_box == null:
		return
	for c in _tags_box.get_children():
		c.queue_free()
	var count := 0
	for t in tags:
		if String(t).strip_edges() == "":
			continue
		var lbl := Label.new()
		lbl.text = String(t)
		lbl.modulate = Color(1,1,1,0.7)
		_tags_box.add_child(lbl)
		count += 1
	_tags_box.visible = count > 0

func set_slot_index(i: int) -> void:
	slot_index = int(i)

signal clicked(slot_index: int)

func _on_pressed() -> void:
	emit_signal("clicked", int(slot_index))
