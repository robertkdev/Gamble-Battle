extends Control
class_name UnitItemsView

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")

var unit: Unit = null
var _container: HBoxContainer = null
var _connected: bool = false
var _max_slots: int = 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_ensure_container()
	_subscribe_items()
	_refresh()

func set_unit(u: Unit) -> void:
	unit = u
	_subscribe_items()
	_refresh()

func _ensure_container() -> void:
	if _container != null:
		return
	_container = HBoxContainer.new()
	add_child(_container)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_theme_constant_override("separation", 4)
	# Anchor to bottom-right of the UnitView
	_container.anchor_left = 1.0
	_container.anchor_top = 1.0
	_container.anchor_right = 1.0
	_container.anchor_bottom = 1.0
	_container.offset_left = -2
	_container.offset_top = -22
	_container.offset_right = -2
	_container.offset_bottom = -2

func _subscribe_items() -> void:
	if _connected:
		return
	var items = _items_singleton()
	if items != null:
		if not items.is_connected("equipped_changed", Callable(self, "_on_items_equipped_changed")):
			items.equipped_changed.connect(_on_items_equipped_changed)
		_connected = true

func _on_items_equipped_changed(changed_unit) -> void:
	if changed_unit == unit:
		_refresh()

func _refresh() -> void:
	_ensure_container()
	var ids: Array[String] = []
	var items = _items_singleton()
	if unit != null and items != null and items.has_method("get_equipped"):
		var raw = items.get_equipped(unit)
		if raw is Array:
			for v in raw:
				ids.append(String(v))
	_render_ids(ids)

func _render_ids(ids: Array[String]) -> void:
	# Limit and build textures
	var n: int = min(_max_slots, ids.size())
	# Clear and rebuild to keep simple and robust
	for c in _container.get_children():
		_container.remove_child(c)
		c.queue_free()
	for i in range(n):
		var id: String = String(ids[i])
		var tex: Texture2D = _icon_for(id)
		var tr := TextureRect.new()
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.custom_minimum_size = Vector2(18, 18)
		tr.size = Vector2(18, 18)
		tr.texture = tex
		_container.add_child(tr)

func _icon_for(id: String) -> Texture2D:
	var def = ItemCatalog.get_def(id)
	if def != null and String(def.icon_path) != "":
		var t: Texture2D = load(def.icon_path)
		if t != null:
			return t
	return TextureUtils.make_circle_texture(Color(0.85, 0.85, 0.85), 32)

func _items_singleton():
	if Engine.has_singleton("Items"):
		return Items
	# Safely resolve the root before accessing it to avoid null instance warnings
	var root_node = null
	if has_method("get_tree"):
		var tree = get_tree()
		if tree and tree.has_method("get_root"):
			root_node = tree.get_root()
	if root_node == null:
		var ml = Engine.get_main_loop()
		if ml and ml.has_method("get_root"):
			root_node = ml.get_root()
	if root_node and root_node.has_node("/root/Items"):
		return root_node.get_node("/root/Items")
	return null
