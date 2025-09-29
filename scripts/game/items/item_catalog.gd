extends Object
class_name ItemCatalog

const ItemDef := preload("res://scripts/game/items/item_def.gd")

static var _loaded: bool = false
static var _items_by_id: Dictionary = {}           # id -> ItemDef
static var _by_type: Dictionary = {}               # type -> Array[ItemDef]

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_scan_dir("res://data/items")
	_loaded = true

static func reload() -> void:
	_loaded = false
	_items_by_id.clear()
	_by_type.clear()
	_ensure_loaded()

static func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full := path + "/" + name
		if dir.current_is_dir():
			_scan_dir(full)
		else:
			if not name.ends_with(".tres"):
				continue
			if not ResourceLoader.exists(full):
				continue
			var res = load(full)
			if res is ItemDef:
				_add_item(res as ItemDef)
	dir.list_dir_end()

static func _add_item(def: ItemDef) -> void:
	if def == null:
		return
	var key := String(def.id).strip_edges()
	if key == "":
		push_warning("ItemCatalog: skipping item with empty id: " + str(def))
		return
	# On id collision, last one wins; warn to assist debugging.
	if _items_by_id.has(key):
		push_warning("ItemCatalog: duplicate id '" + key + "' — replacing previous definition")
	_items_by_id[key] = def
	var t := String(def.type)
	if not _by_type.has(t):
		_by_type[t] = []
	(_by_type[t] as Array).append(def)

static func get_def(id: String) -> ItemDef:
	_ensure_loaded()
	var key := String(id)
	return _items_by_id.get(key, null)

static func by_type(kind: String) -> Array:
	_ensure_loaded()
	var t := String(kind)
	if not _by_type.has(t):
		return []
	# Return a shallow copy to avoid external mutation of cache
	return (_by_type[t] as Array).duplicate()

static func is_component(id: String) -> bool:
	var def: ItemDef = get_def(id)
	if def == null:
		return false
	return String(def.type) == "component"

static func components_of(completed_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var def: ItemDef = get_def(completed_id)
	if def == null:
		return out
	if String(def.type) != "completed":
		return out
	# Ensure we return a copy to avoid external mutation
	for c in def.components:
		out.append(String(c))
	return out
