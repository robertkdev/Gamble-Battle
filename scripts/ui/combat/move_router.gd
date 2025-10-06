extends RefCounted
class_name MoveRouter

const Debug := preload("res://scripts/util/debug.gd")

# Loose-typed external refs to avoid circular deps
var manager
var roster # Roster autoload
var board_grid
var bench_grid
var grid_placement
var bench_placement

var refresh_cb: Callable = Callable()

func configure(_manager, _roster, _board_grid, _bench_grid, _grid_placement, _bench_placement) -> void:
	manager = _manager
	roster = _roster
	board_grid = _board_grid
	bench_grid = _bench_grid
	grid_placement = _grid_placement
	bench_placement = _bench_placement

func set_refresh_callback(cb: Callable) -> void:
	refresh_cb = cb

func connect_unit_view(uv: UnitView) -> void:
	if uv and not uv.is_connected("dropped_on_target", Callable(self, "_on_unit_dropped")):
		uv.dropped_on_target.connect(_on_unit_dropped.bind(uv))

func _on_unit_dropped(target_grid, tile_idx: int, uv: UnitView) -> void:
	if uv == null or target_grid == null or tile_idx < 0:
		return
	# Phase guard
	if Engine.has_singleton("GameState") or uv.has_node("/root/GameState"):
		if GameState.phase == GameState.GamePhase.COMBAT:
			if Debug.enabled:
				print("[MoveRouter] Drop ignored: in COMBAT phase")
			return
	var from_board: bool = (board_grid != null and board_grid.index_of(uv) != -1)
	var from_bench: bool = (bench_grid != null and bench_grid.index_of(uv) != -1)
	if target_grid == board_grid and from_bench:
		_bench_to_board(uv, tile_idx)
		return
	if target_grid == bench_grid and from_board:
		_board_to_bench(uv, tile_idx)
		return
	if target_grid == bench_grid and from_bench:
		_bench_to_bench(uv, tile_idx)
		return
	# Board↔Board is handled by GridPlacement via dropped_on_tile
	if target_grid == board_grid and from_board:
		return
	# If target is neither board nor bench (e.g., shop sell grid), leave handling to controller
	if target_grid != board_grid and target_grid != bench_grid:
		return
	# Unknown route: snap back via helper
	_snap_back(uv)

func _bench_to_board(uv: UnitView, tile_idx: int) -> void:
	if manager == null or board_grid == null or bench_grid == null or grid_placement == null or bench_placement == null:
		return
	if board_grid.is_occupied(tile_idx):
		if Debug.enabled:
			print("[MoveRouter] Bench→Board failed: tile occupied", tile_idx)
		_snap_back(uv)
		return

	# Explicitly type and cast the unit
	var u: Unit = (uv.unit as Unit)
	if u == null:
		_snap_back(uv)
		return

	# Team size cap (only when enabled)
	var cap: int = (int(roster.max_team_size) if roster else -1)
	if cap >= 0 and manager.player_team.size() >= cap:
		if Debug.enabled:
			print("[MoveRouter] Bench→Board failed: max team size reached", cap)
		_snap_back(uv)
		return

	# Remove from bench
	if roster and roster.has_method("remove"):
		roster.remove(u)

	# Add to team
	manager.player_team.append(u)

	# Refresh views via controller callback when available (DRY)
	if refresh_cb.is_valid():
		refresh_cb.call()
	else:
		bench_placement.rebuild_bench_views(roster.bench_slots if roster else [], true)
		grid_placement.rebuild_player_views(manager.player_team, true)

	# Place new unit at desired tile (swap if needed)
	var idx_in_team: int = -1
	for i in range(manager.player_team.size()):
		if manager.player_team[i] == u:
			idx_in_team = i
			break
	if idx_in_team != -1 and grid_placement.has_method("_on_player_unit_dropped"):
		grid_placement._on_player_unit_dropped(idx_in_team, tile_idx)

	# Dispose original dragged view to avoid stale duplicates capturing input
	if uv:
		# Ensure any drag ghost is cleaned up before freeing the original view
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()

func _board_to_bench(uv: UnitView, tile_idx: int) -> void:
	if manager == null or board_grid == null or bench_grid == null or grid_placement == null or bench_placement == null or roster == null:
		return

	var u: Unit = (uv.unit as Unit)
	if u == null:
		_snap_back(uv)
		return

	# Prefer the exact target bench tile when available
	var slot: int = int(tile_idx)
	# If the chosen slot is invalid or occupied, fall back to first empty
	if slot < 0 or slot >= bench_grid.size() or (roster.get_slot(slot) != null):
		slot = roster.first_empty_slot() if roster.has_method("first_empty_slot") else -1
	if slot == -1:
		if Debug.enabled:
			print("[MoveRouter] Board→Bench failed: bench full or no valid slot")
		_snap_back(uv)
		return

	# Remove from board team by identity
	var rem_idx := -1
	for i in range(manager.player_team.size()):
		if manager.player_team[i] == u:
			rem_idx = i
			break
	if rem_idx == -1:
		_snap_back(uv)
		return

	manager.player_team.remove_at(rem_idx)
	roster.set_slot(slot, u)

	# Refresh views via controller callback when available (DRY)
	if refresh_cb.is_valid():
		refresh_cb.call()
	else:
		grid_placement.rebuild_player_views(manager.player_team, true)
		bench_placement.rebuild_bench_views(roster.bench_slots, true)

	# Dispose original dragged view to avoid stale duplicates capturing input
	if uv:
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()

func _bench_to_bench(uv: UnitView, tile_idx: int) -> void:
	if bench_grid == null or roster == null:
		_snap_back(uv)
		return
	if tile_idx < 0 or tile_idx >= bench_grid.size():
		_snap_back(uv)
		return

	var from_idx: int = bench_grid.index_of(uv)
	if from_idx == -1:
		_snap_back(uv)
		return
	if from_idx == tile_idx:
		# No-op drop on same tile
		bench_grid.attach(uv, from_idx)
		return

	# Explicit types fix the inference errors flagged on lines 151 and 155
	var u: Unit = (uv.unit as Unit)
	if u == null:
		_snap_back(uv)
		return

	var dest_u: Unit = (roster.get_slot(tile_idx) as Unit)

	# Place or swap
	roster.set_slot(tile_idx, u)
	roster.set_slot(from_idx, dest_u)

	# Views will be rebuilt via bench_changed signal; dispose dragged view
	if uv:
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()

func _snap_back(uv: UnitView) -> void:
	if uv == null:
		return
	# Return to original grid tile if possible
	if board_grid != null:
		var bi: int = board_grid.index_of(uv)
		if bi != -1:
			board_grid.attach(uv, bi)
			return
	if bench_grid != null:
		var si: int = bench_grid.index_of(uv)
		if si != -1:
			bench_grid.attach(uv, si)
			return
