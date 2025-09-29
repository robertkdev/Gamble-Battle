extends Node


signal inventory_changed()
signal equipped_changed(unit)
signal action_log(text: String)

const MAX_SLOTS := 3

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const CombineRules := preload("res://scripts/game/items/combine_rules.gd")
const Combiner := preload("res://scripts/game/items/combiner.gd")
const EquipService := preload("res://scripts/game/items/equip_service.gd")

var _inventory: Dictionary = {}            # id -> count
var _equipped: Dictionary = {}             # Unit -> Array[String]
var _unit_refs: Dictionary = {}            # Unit -> WeakRef (for liveness checks)
var _equip_service: EquipService = null

# DEV: starter inventory seeding (disabled by default)
# Toggle this on during development to auto‑populate inventory at startup.
@export var DEV_STARTER_INVENTORY_ENABLED: bool = true
# Array of [item_id: String, count: int]
@export var DEV_STARTER_INVENTORY: Array = [
	["hammer", 2],
	["crystal", 2],
	["wand", 2],
	["core", 2],
	["plate", 1],
	["veil", 1],
	["orb", 1],
	["spike", 1],
	["remover", 1],
]

func _ready() -> void:
	# Wire combiner providers to this autoload
	Combiner.configure(Callable(self, "get_equipped_ids"), Callable(self, "consume_components"))
	_equip_service = EquipService.new()
	_maybe_seed_dev_inventory()

func add_to_inventory(id: String, n: int = 1) -> Dictionary:
	_cleanup_invalid_units()
	var res := {"ok": false, "reason": ""}
	var key := String(id).strip_edges()
	var cnt := int(n)
	if key == "" or cnt == 0:
		res.reason = "invalid_args"
		return res
	if ItemCatalog.get_def(key) == null:
		res.reason = "unknown_item"
		return res
	_inventory[key] = int(_inventory.get(key, 0)) + cnt
	inventory_changed.emit()
	action_log.emit("+%d %s" % [cnt, key])
	print("[Items] add_to_inventory id=", key, " n=", cnt, " new_count=", int(_inventory[key]))
	res.ok = true
	res["count"] = int(_inventory[key])
	return res

func equip(unit, id: String) -> Dictionary:
	_cleanup_invalid_units()
	var result := {"ok": false, "reason": ""}
	print("[Items] equip start unit=", (unit.name if unit and unit.has_method("get") else unit), " id=", id)
	if unit == null:
		result.reason = "no_unit"
		return result
	var key := String(id).strip_edges()
	if key == "":
		result.reason = "invalid_id"
		return result
	var def = ItemCatalog.get_def(key)
	if def == null:
		result.reason = "unknown_item"
		return result
	if int(_inventory.get(key, 0)) <= 0:
		result.reason = "not_in_inventory"
		return result

	# Special: remover clears all items outside combat
	if key == "remover":
		if Engine.has_singleton("GameState") and int(GameState.phase) == int(GameState.GamePhase.COMBAT):
			result.reason = "cannot_remove_in_combat"
			action_log.emit("Cannot remove items during combat")
			return result
		if not _dec_inventory(key, 1):
			result.reason = "inventory_underflow"
			return result
		var rr := remove_all(unit)
		var uname: String = (unit.name if unit != null and unit.has_method("get") else "unit")
		action_log.emit("Removed %d item(s) from %s" % [int(rr.get("returned", 0)), str(uname)])
		print("[Items] remover used on ", uname, " -> ", rr)
		result.ok = true
		result["removed"] = int(rr.get("returned", 0))
		return result

	var eq: Array = _ensure_unit_array(unit)

	# Attempt auto-combine first when equipping a component (orderless, does not require temp slot)
	if String(def.type) == "component":
		var combined_id: String = Combiner.try_combine_on_equip(unit, key)
		if combined_id != "":
			# Place the completed item; consumes components via consumer
			# Capacity is safe (2 -> 1 swap)
			eq.append(combined_id)
			_watch_unit(unit)
			if _equip_service:
				_equip_service.recompute_for(unit)
			equipped_changed.emit(unit)
			inventory_changed.emit() # consumed new component from inventory
			action_log.emit("Auto-combined to %s" % combined_id)
			print("[Items] auto-combined ", key, " -> ", combined_id, " on unit=", (unit.name if unit else "unit"))
			result.ok = true
			result["combined_id"] = combined_id
			return result

	# No combine: require capacity
	if eq.size() >= MAX_SLOTS:
		result.reason = "no_slot"
		action_log.emit("No empty item slots")
		print("[Items] equip blocked: no_slot for ", (unit.name if unit else "unit"))
		return result

	# Consume from inventory and equip
	if not _dec_inventory(key, 1):
		result.reason = "inventory_underflow"
		print("[Items] inventory_underflow id=", key)
		return result
	eq.append(key)
	_watch_unit(unit)
	if _equip_service:
		_equip_service.recompute_for(unit)
	equipped_changed.emit(unit)
	inventory_changed.emit()
	var uname2: String = (unit.name if unit != null and unit.has_method("get") else "unit")
	action_log.emit("Equipped %s on %s" % [key, str(uname2)])
	print("[Items] equipped id=", key, " on=", uname2)
	result.ok = true
	return result

func remove_all(unit) -> Dictionary:
	_cleanup_invalid_units()
	var result := {"ok": false, "returned": 0}
	if unit == null:
		result.ok = true
		return result
	var eq: Array = _equipped.get(unit, [])
	if eq is Array and eq.size() > 0:
		for id in eq:
			_inc_inventory(String(id), 1)
		_equipped.erase(unit)
		_unit_refs.erase(unit)
		if _equip_service:
			_equip_service.recompute_for(unit)
		equipped_changed.emit(unit)
		inventory_changed.emit()
		result["returned"] = int(eq.size())
	result.ok = true
	var uname3: String = (unit.name if unit != null and unit.has_method("get") else "unit")
	print("[Items] remove_all on=", uname3, " -> returned=", int(result.get("returned", 0)))
	return result

func get_equipped(unit) -> Array:
	_cleanup_invalid_units()
	var eq: Array = _equipped.get(unit, [])
	return (eq.duplicate() if eq is Array else [])

func get_equipped_ids(unit) -> Array:
	return get_equipped(unit)

func slot_count(_unit = null) -> int:
	return int(MAX_SLOTS)

func get_inventory_snapshot() -> Dictionary:
	# Return a shallow copy for UI display
	return _inventory.duplicate()

# Combine two components directly in inventory (no unit involved)
func try_combine_in_inventory(a: String, b: String) -> Dictionary:
	var res := {"ok": false, "reason": ""}
	var ia := String(a).strip_edges()
	var ib := String(b).strip_edges()
	if ia == "" or ib == "":
		res.reason = "invalid_args"
		return res
	if not ItemCatalog.is_component(ia) or not ItemCatalog.is_component(ib):
		res.reason = "not_components"
		return res
	var cid := CombineRules.completed_for(ia, ib)
	if cid == "":
		res.reason = "no_recipe"
		return res
	var need_a := 1
	var need_b := 1
	if ia == ib:
		need_a = 2
		need_b = 0
	var have_a := int(_inventory.get(ia, 0))
	var have_b := int(_inventory.get(ib, 0))
	if have_a < need_a or have_b < need_b:
		res.reason = "insufficient_components"
		return res
	# Consume components
	if need_a > 0 and not _dec_inventory(ia, need_a):
		res.reason = "inventory_underflow_a"
		return res
	if need_b > 0 and not _dec_inventory(ib, need_b):
		res.reason = "inventory_underflow_b"
		return res
	# Add completed item
	_inc_inventory(cid, 1)
	inventory_changed.emit()
	action_log.emit("Combined %s + %s -> %s" % [ia, ib, cid])
	print("[Items] combined in inventory: ", ia, " + ", ib, " -> ", cid)
	res.ok = true
	res["completed_id"] = cid
	return res

# Lifecycle helpers

func release_for(unit) -> void:
	if unit == null:
		return
	_equipped.erase(unit)
	_unit_refs.erase(unit)

func replace_unit(old_unit, new_unit) -> void:
	if old_unit == null or new_unit == null:
		return
	if not _equipped.has(old_unit):
		return
	var arr: Array = (_equipped[old_unit] as Array).duplicate()
	_equipped.erase(old_unit)
	_unit_refs.erase(old_unit)
	_equipped[new_unit] = arr
	_watch_unit(new_unit)
	equipped_changed.emit(new_unit)

# -- Combiner consumer/provider helpers --

func consume_components(unit, ids: Array) -> void:
	if unit == null or ids == null:
		return
	var eq: Array = _ensure_unit_array(unit)
	for raw in ids:
		var id := String(raw)
		if id == "":
			continue
		# Prefer removing from equipped (existing component)
		var idx := eq.find(id)
		if idx != -1:
			eq.remove_at(idx)
		else:
			# Otherwise consume from inventory (the new component being combined)
			_dec_inventory(id, 1)

	# Ensure unit is tracked and notify
	_watch_unit(unit)
	if _equip_service:
		_equip_service.recompute_for(unit)
	equipped_changed.emit(unit)

# -- Internals --

func _ensure_unit_array(unit) -> Array:
	if not _equipped.has(unit):
		_equipped[unit] = []
		_watch_unit(unit)
	return (_equipped[unit] as Array)

func _dec_inventory(id: String, n: int) -> bool:
	var key := String(id)
	var need := int(n)
	if need <= 0:
		return true
	var have := int(_inventory.get(key, 0))
	if have < need:
		return false
	_inventory[key] = have - need
	if int(_inventory[key]) <= 0:
		_inventory.erase(key)
	return true

func _inc_inventory(id: String, n: int) -> void:
	var key := String(id)
	var inc := int(n)
	if inc <= 0:
		return
	_inventory[key] = int(_inventory.get(key, 0)) + inc

func _watch_unit(unit) -> void:
	if unit == null:
		return
	# Keep a weakref to detect GC/freed refs (RefCounted)
	_unit_refs[unit] = weakref(unit)

func _cleanup_invalid_units() -> void:
	# Remove entries for units that are no longer valid (freed/replaced)
	var to_erase: Array = []
	for u in _equipped.keys():
		var wr: WeakRef = _unit_refs.get(u, null)
		if wr == null:
			continue
		if wr.get_ref() == null:
			to_erase.append(u)
	for dead in to_erase:
		_equipped.erase(dead)
		_unit_refs.erase(dead)

func _maybe_seed_dev_inventory() -> void:
	if not DEV_STARTER_INVENTORY_ENABLED:
		return
	if DEV_STARTER_INVENTORY == null:
		return
	for entry in DEV_STARTER_INVENTORY:
		var id := ""
		var cnt: int = 1
		if entry is Array and entry.size() >= 1:
			id = String(entry[0])
			if entry.size() >= 2:
				cnt = int(entry[1])
		elif entry is Dictionary:
			id = String(entry.get("id", ""))
			cnt = int(entry.get("count", 1))
		if id != "" and cnt != 0:
			add_to_inventory(id, cnt)
