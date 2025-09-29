extends RefCounted
class_name GridPlacement

const UnitViewClass := preload("res://scripts/ui/combat/unit_view.gd")
const UnitSlotView := preload("res://scripts/ui/combat/unit_slot_view.gd")
const UnitItemsView := preload("res://scripts/ui/items/unit_items_view.gd")
const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")

var grid_w: int = 8
var grid_h: int = 3
var tile_size: int = 72

var player_grid: GridContainer
var enemy_grid: GridContainer

var player_tiles: Array[Button] = []
var enemy_tiles: Array[Button] = []

var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid

var player_views: Array[UnitSlotView] = []
var enemy_views: Array[UnitSlotView] = []

var _player_indices: Array[int] = []
var _player_base_tile_idx: int = -1

func configure(_player_grid: GridContainer, _enemy_grid: GridContainer, _tile_size: int, _grid_w: int, _grid_h: int) -> void:
	player_grid = _player_grid
	enemy_grid = _enemy_grid
	tile_size = _tile_size
	grid_w = _grid_w
	grid_h = _grid_h
	_build_grids()

func set_player_base_tile(idx: int) -> void:
	_player_base_tile_idx = idx

func get_player_tiles() -> Array:
	return player_tiles

func get_enemy_tiles() -> Array:
	return enemy_tiles

func get_player_grid() -> BoardGrid:
	return player_grid_helper

func get_enemy_grid() -> BoardGrid:
	return enemy_grid_helper

func get_player_views() -> Array:
	return player_views

func get_enemy_views() -> Array:
	return enemy_views

func _build_grids() -> void:
	player_tiles.clear()
	enemy_tiles.clear()
	if player_grid:
		for c in player_grid.get_children():
			if c is Button:
				var pb := c as Button
				pb.text = ""
				pb.toggle_mode = false
				pb.focus_mode = Control.FOCUS_NONE
				pb.disabled = true
				# Always enforce tile size from constants to allow runtime scaling
				pb.custom_minimum_size = Vector2(tile_size, tile_size)
				player_tiles.append(pb)
	if enemy_grid:
		for c in enemy_grid.get_children():
			if c is Button:
				var eb := c as Button
				eb.text = ""
				eb.toggle_mode = false
				eb.focus_mode = Control.FOCUS_NONE
				eb.disabled = true
				# Always enforce tile size from constants to allow runtime scaling
				eb.custom_minimum_size = Vector2(tile_size, tile_size)
				enemy_tiles.append(eb)
	player_grid_helper = load("res://scripts/board_grid.gd").new()
	player_grid_helper.configure(player_tiles, grid_w, grid_h)
	enemy_grid_helper = load("res://scripts/board_grid.gd").new()
	enemy_grid_helper.configure(enemy_tiles, grid_w, grid_h)

func rebuild_enemy_views(enemy_team: Array) -> void:
	enemy_views.clear()
	if enemy_grid_helper:
		enemy_grid_helper.clear()
	var summary: Array[String] = []
	var n: int = min(enemy_team.size(), enemy_tiles.size())
	for i in range(n):
		var u: Unit = enemy_team[i]
		var uv: UnitView = UnitViewClass.new()
		uv.set_unit(u)
		# Items overlay
		var _items_view_e := UnitItemsView.new()
		_items_view_e.set_unit(u)
		uv.add_child(_items_view_e)
		var tile_idx: int = i
		if enemy_grid_helper:
			enemy_grid_helper.attach(uv, tile_idx)
		var slot := UnitSlotView.new()
		slot.unit = u
		slot.view = uv
		slot.tile_idx = tile_idx
		enemy_views.append(slot)
		var placement: String = "%d:%s" % [i, enemy_grid_helper.get_center(tile_idx)]
		summary.append(placement)
	if not summary.is_empty():
		Debug.log("Plan", "Enemy positions %s" % [Strings.join(summary, ", ")])

func rebuild_player_views(player_team: Array, allow_drag: bool) -> void:
	player_views.clear()
	if player_team.size() == 0:
		return
	if player_grid_helper:
		player_grid_helper.clear()
	# Ensure indices array length matches team size, preserving existing placements.
	var team_size: int = player_team.size()
	var tiles_count: int = player_tiles.size()
	if _player_indices.size() > team_size:
		# Shrink: drop trailing indices (units were removed from end)
		_player_indices.resize(team_size)
	elif _player_indices.size() < team_size:
		# Extend: keep existing indices and assign free tiles to new units
		var used: Dictionary = {}
		for v in _player_indices:
			var vi: int = int(v)
			if vi >= 0:
				used[vi] = true
		var base := (_player_base_tile_idx if _player_base_tile_idx >= 0 else 0)
		for i in range(_player_indices.size(), team_size):
			var picked: int = -1
			if tiles_count > 0:
				for off in range(tiles_count):
					var cand: int = (base + off) % tiles_count
					if not used.has(cand):
						picked = cand
						break
			if picked < 0:
				picked = max(0, min(tiles_count - 1, 0))
			_player_indices.append(picked)
			used[picked] = true
	var summary: Array[String] = []
	var n: int = min(player_team.size(), player_tiles.size())
	for i in range(n):
		var pu: Unit = player_team[i]
		var tile_idx: int = _player_indices[i]
		if tile_idx < 0:
			tile_idx = i % max(1, player_tiles.size())
			_player_indices[i] = tile_idx
		var uv: UnitView = UnitViewClass.new()
		uv.set_unit(pu)
		# Items overlay
		var _items_view_p := UnitItemsView.new()
		_items_view_p.set_unit(pu)
		uv.add_child(_items_view_p)
		if allow_drag:
			uv.enable_drag(player_grid_helper)
			uv.dropped_on_tile.connect(func(idx): _on_player_unit_dropped(i, idx))
		if player_grid_helper:
			player_grid_helper.attach(uv, tile_idx)
		var slot := UnitSlotView.new()
		slot.unit = pu
		slot.view = uv
		slot.tile_idx = tile_idx
		player_views.append(slot)
		var placement: String = "%d:%s" % [i, player_grid_helper.get_center(tile_idx)]
		summary.append(placement)
	if not summary.is_empty():
		Debug.log("Plan", "Player positions %s" % [Strings.join(summary, ", ")])

func _on_player_unit_dropped(i: int, idx: int) -> void:
	if idx < 0 or idx >= player_tiles.size():
		return
	if i < 0 or i >= player_views.size():
		return
	# If another unit occupies target, swap indices
	var j := -1
	for k in range(_player_indices.size()):
		if k != i and _player_indices[k] == idx:
			j = k
			break
	var old_idx := _player_indices[i]
	_player_indices[i] = idx
	if j != -1:
		if j < 0 or j >= player_views.size():
			return
		_player_indices[j] = old_idx
		var ctrl_i: Control = player_views[i].view
		var ctrl_j: Control = player_views[j].view
		if player_grid_helper:
			player_grid_helper.attach(ctrl_i, idx)
			player_grid_helper.attach(ctrl_j, old_idx)
		player_views[i].tile_idx = idx
		player_views[j].tile_idx = old_idx
	else:
		var ctrl: Control = player_views[i].view
		if player_grid_helper and ctrl:
			player_grid_helper.attach(ctrl, idx)
		player_views[i].tile_idx = idx
