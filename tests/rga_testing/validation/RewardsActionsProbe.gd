extends Node

# Validates the rewards runtime actions in isolation by invoking actions directly.
# Uses autoloads Economy, Shop, Items. Exits 0 on success, 1 on failure.

const Runtime := preload("res://scripts/game/progression/creeps/creep_rewards_runtime.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var ok: bool = true
	# Ensure autoload nodes exist under /root
	if _find("/root/Economy") == null or _find("/root/Shop") == null or _find("/root/Items") == null:
		printerr("[RewardsTest] missing required autoload(s)")
		get_tree().quit(1)
		return

	var rt = Runtime.new()
	# Configure with null engine/pool; actions use autoloads directly
	rt.configure(null, null, {})

	# Snapshot
	var g0: int = (_find("/root/Economy").gold as int)
	var r0: int = int(_find("/root/Shop").state.free_rerolls)
	var inv0: Dictionary = _inv()
	var c0: int = _count_inv(inv0)

	# grant_gold
	rt._execute_action("grant_gold", {"amount": 1})
	var g1: int = (_find("/root/Economy").gold as int)
	if g1 != g0 + 1:
		printerr("[RewardsTest] grant_gold failed: ", g1, " != ", g0 + 1)
		ok = false

	# grant_rerolls
	rt._execute_action("grant_rerolls", {"count": 1})
	var r1: int = int(_find("/root/Shop").state.free_rerolls)
	if r1 != r0 + 1:
		printerr("[RewardsTest] grant_rerolls failed: ", r1, " != ", r0 + 1)
		ok = false

	# drop_component (uniform component)
	inv0 = _inv(); c0 = _count_inv(inv0)
	rt._execute_action("drop_component", {"count": 1})
	var c1: int = _count_inv(_inv())
	if c1 != c0 + 1:
		printerr("[RewardsTest] drop_component failed: ", c1, " != ", c0 + 1)
		ok = false

	# drop_completed (uniform completed)
	inv0 = _inv(); c0 = _count_inv(inv0)
	rt._execute_action("drop_completed", {"count": 1})
	c1 = _count_inv(_inv())
	if c1 != c0 + 1:
		printerr("[RewardsTest] drop_completed failed: ", c1, " != ", c0 + 1)
		ok = false

	# log (no assertion; ensure no crash)
	rt._execute_action("log", {"text": "test"})

	if ok:
		print("[RewardsTest] PASS")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _inv() -> Dictionary:
	var items = _find("/root/Items")
	if items != null and items.has_method("get_inventory_snapshot"):
		return items.get_inventory_snapshot()
	return {}

func _count_inv(inv: Dictionary) -> int:
	var sum: int = 0
	for k in inv.keys():
		sum += int(inv.get(k, 0))
	return sum

func _find(path: String) -> Node:
	var root: Node = get_tree().get_root()
	if root != null and root.has_node(path):
		return root.get_node(path)
	return null
