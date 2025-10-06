extends RefCounted
class_name ItemDragRouter

const Debug := preload("res://scripts/util/debug.gd")

var view: Control
var grid_placement
var player_grid_helper: BoardGrid
var bench_grid_helper: BoardGrid
var item_grid_helper: BoardGrid = null

func configure(_view: Control, _grid_placement, _player_grid_helper: BoardGrid, _bench_grid_helper: BoardGrid) -> void:
	view = _view
	grid_placement = _grid_placement
	player_grid_helper = _player_grid_helper
	bench_grid_helper = _bench_grid_helper

func attach_card(card: Node) -> void:
	if card == null:
		return
	# Expect DragAndDroppable API
	if card.has_method("set_drop_targets"):
		var targets: Array = []
		if player_grid_helper != null:
			targets.append(player_grid_helper)
		if bench_grid_helper != null:
			targets.append(bench_grid_helper)
		if item_grid_helper != null:
			targets.append(item_grid_helper)
		card.set_drop_targets(targets)
	# Connect to drop signal once
	var sig := "dropped_on_target"
	# In Godot 4, connect expects a Callable; bind the card as extra arg
	if not card.is_connected(sig, Callable(self, "_on_card_dropped")):
		card.connect(sig, Callable(self, "_on_card_dropped").bind(card))


func _on_card_dropped(grid, tile_idx: int, card) -> void:
	if grid == null or tile_idx < 0 or card == null:
		return
	var iid: String = ""
	if card.has_method("get"):
		iid = String(card.get("item_id"))
	if iid == "":
		if card.has_method("get_item_id"):
			iid = String(card.get_item_id())
	if iid == "":
		return
	# Handle inventory-to-inventory combination BEFORE resolving a unit.
	if grid == item_grid_helper:
		var items = _items_singleton()
		print("[ItemDrag] Items singleton node=", items)
		if items == null:
			return
		var src_idx := -1
		if card.has_method("get_slot_index"):
			src_idx = int(card.get_slot_index())
		if src_idx == -1:
			return
		if src_idx == tile_idx:
			return
		var target_ctrl: Control = item_grid_helper.tile_at(tile_idx)
		var target_id: String = ""
		if target_ctrl != null:
			if target_ctrl.has_method("get"):
				target_id = String(target_ctrl.get("item_id"))
			elif target_ctrl.has_method("get_item_id"):
				target_id = String(target_ctrl.get_item_id())
		print("[ItemDrag] inventory drop src=", iid, " tgt=", target_id, " src_idx=", src_idx, " dst=", tile_idx)
		var did_combine := false
		if target_id != "" and items.has_method("combine_inventory_slots"):
			var cres = items.combine_inventory_slots(src_idx, tile_idx)
			print("[ItemDrag] combine result => ", cres)
			if cres is Dictionary and bool(cres.get("ok", false)):
				did_combine = true
		if did_combine:
			return
		if items.has_method("swap_inventory_slots"):
			items.swap_inventory_slots(src_idx, tile_idx)
		return
	# Otherwise, resolve the unit at the drop location on a board grid.
	var unit: Unit = _resolve_unit(grid, tile_idx)
	print("[ItemDrag] Drop iid=", iid, " on tile=", tile_idx, " -> unit=", (unit.name if unit else "null"))
	if unit == null:
		return
	# Route to Items service (robustly resolve the autoload/node)
	var items = _items_singleton()
	print("[ItemDrag] Items singleton node=", items)
	if items == null:
		return
	if iid == "remover":
		print("[ItemDrag] calling remove_all on Items node")
		var rr = null
		if items.has_method("remove_all"):
			rr = items.remove_all(unit)
		else:
			rr = items.call_deferred("remove_all", unit)
		print("[ItemDrag] remove_all => ", rr)
	else:
		print("[ItemDrag] calling equip on Items node with ", iid)
		var res = null
		if items.has_method("equip"):
			res = items.equip(unit, iid)
		else:
			res = items.call_deferred("equip", unit, iid)
		print("[ItemDrag] equip result => ", res)

func _resolve_unit(grid, tile_idx: int) -> Unit:
	if grid == player_grid_helper:
		# Find unit by tile index in player views
		if grid_placement != null and grid_placement.has_method("get_player_views"):
			var pviews = grid_placement.get_player_views()
			if pviews is Array:
				for v in pviews:
					if v != null and int(v.tile_idx) == int(tile_idx):
						return v.unit
	return null
	if grid == bench_grid_helper:
		# Bench slots map 1:1 with grid indices
		if Engine.has_singleton("Roster"):
			return Roster.get_slot(int(tile_idx))
		# Fallback: attempt to read bench array directly
		if view and view.has_node("/root/Roster"):
			var roster_node = view.get_node("/root/Roster")
			if roster_node and roster_node.has_method("get_slot"):
				return roster_node.get_slot(int(tile_idx))
		return null
	return null

func _items_singleton():
	if Engine.has_singleton("Items"):
		return Items
	var root_node = null
	if view and view.has_method("get_tree"):
		var tree = view.get_tree()
		if tree and tree.has_method("get_root"):
			root_node = tree.get_root()
	if root_node == null:
		var ml = Engine.get_main_loop()
		if ml and ml.has_method("get_root"):
			root_node = ml.get_root()
	if root_node and root_node.has_node("/root/Items"):
		return root_node.get_node("/root/Items")
	return null

func set_item_grid(helper: BoardGrid) -> void:
	item_grid_helper = helper
