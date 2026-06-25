extends Node

const SMOKE_NAME: String = "DevStarterInventorySmoke"

var _failures: Array[String] = []
var _original_dev_enabled: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var items: Node = _items_node()
	if items == null:
		_fail("Items autoload missing")
		_finish()
		return

	_original_dev_enabled = bool(items.get("DEV_STARTER_INVENTORY_ENABLED"))
	_expect(not _original_dev_enabled, "DEV_STARTER_INVENTORY_ENABLED should default to false for normal playtests")

	items.set("DEV_STARTER_INVENTORY_ENABLED", false)
	items.call("reset_run")
	_expect(_inventory_snapshot().is_empty(), "normal reset_run should not seed item inventory")
	_expect(_non_empty_inventory_slots() == 0, "normal reset_run should leave inventory slots empty")

	items.set("DEV_STARTER_INVENTORY_ENABLED", true)
	items.call("reset_run")
	_expect(not _inventory_snapshot().is_empty(), "dev reset_run should seed starter inventory when explicitly enabled")
	_expect(_non_empty_inventory_slots() > 0, "dev reset_run should populate visible inventory slots when explicitly enabled")

	items.set("DEV_STARTER_INVENTORY_ENABLED", _original_dev_enabled)
	items.call("reset_run")
	_expect(_inventory_snapshot().is_empty(), "restored normal reset_run should return to clean item inventory")
	_expect(_non_empty_inventory_slots() == 0, "restored normal reset_run should return to empty inventory slots")

	_finish()

func _items_node() -> Node:
	var root: Window = get_tree().root if get_tree() != null else null
	if root == null:
		return null
	return root.get_node_or_null("/root/Items")

func _inventory_snapshot() -> Dictionary:
	var items: Node = _items_node()
	if items == null:
		return {}
	var snapshot: Variant = items.call("get_inventory_snapshot")
	return snapshot if snapshot is Dictionary else {}

func _non_empty_inventory_slots() -> int:
	var count: int = 0
	var items: Node = _items_node()
	if items == null:
		return count
	var slots: Variant = items.call("get_inventory_slots")
	if not (slots is Array):
		return count
	for item_id: Variant in slots:
		if String(item_id).strip_edges() != "":
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	var items: Node = _items_node()
	if items != null:
		items.set("DEV_STARTER_INVENTORY_ENABLED", _original_dev_enabled)
		items.call("reset_run")
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		get_tree().quit(1)
		return
	print(SMOKE_NAME + ": OK")
	get_tree().quit(0)
