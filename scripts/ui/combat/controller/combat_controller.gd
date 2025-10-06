extends RefCounted
class_name CombatController

const Trace := preload("res://scripts/util/trace.gd")
const UI := preload("res://scripts/constants/ui_constants.gd")
const G := preload("res://scripts/constants/gameplay_constants.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const Debug := preload("res://scripts/util/debug.gd")
const BenchConstants := preload("res://scripts/constants/bench_constants.gd")

const ArenaBridge := preload("res://scripts/ui/combat/arena_bridge.gd")
const GridPlacement := preload("res://scripts/ui/combat/grid_placement.gd")
const BenchPlacement := preload("res://scripts/ui/combat/bench_placement.gd")
const MoveRouter := preload("res://scripts/ui/combat/move_router.gd")
const ProjectileBridge := preload("res://scripts/ui/combat/projectile_bridge.gd")
const EconomyUI := preload("res://scripts/ui/combat/economy_ui.gd")
const IntermissionController := preload("res://scripts/ui/combat/intermission_controller.gd")
const ShopPresenter := preload("res://scripts/ui/shop/shop_presenter.gd")
const SellZone := preload("res://scripts/ui/shop/sell_zone.gd") # legacy; no longer used visually
const SelectionService := preload("res://scripts/ui/combat/stats/selection_service.gd")
const StatsTracker := preload("res://scripts/ui/combat/stats/stats_tracker.gd")
const ItemsPresenter := preload("res://scripts/ui/items/items_presenter.gd")
const ItemRuntime := preload("res://scripts/game/items/item_runtime.gd")
const ItemDragRouter := preload("res://scripts/ui/items/item_drag_router.gd")
const TraitsPresenter := preload("res://scripts/ui/traits/traits_presenter.gd")
const LogSchema := preload("res://scripts/util/log_schema.gd")
const ProgressionService := preload("res://scripts/game/progression/progression_service.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const RosterUtils := preload("res://scripts/game/progression/roster_utils.gd")

# Parent scene (CombatView)
var parent: Control

# Nodes
var log_label: RichTextLabel
var player_stats_label: Label
var enemy_stats_label: Label
var stage_label: Label
var player_sprite: TextureRect
var enemy_sprite: TextureRect
var player_grid: GridContainer
var enemy_grid: GridContainer
var bench_grid: GridContainer
var shop_grid: GridContainer
# Legacy reference left for compatibility; no longer instantiated
var sell_zone: SellZone
var arena_container: Control
var arena_background: Control
var arena_units: Control
var planning_area: Control
var attack_button: Button
var continue_button: Button
var menu_button: Button
var gold_label: Label
var bet_slider: HSlider
var bet_value: Label
var stats_panel: Control

# External engine manager
var manager: CombatManager

# Modules
var grid_placement: GridPlacement
var bench_placement
var arena_bridge: ArenaBridge
var projectile_bridge: ProjectileBridge
var economy_ui: EconomyUI
var intermission: IntermissionController
var shop_presenter: ShopPresenter
var selection: SelectionService
var stats_tracker: StatsTracker
var items_presenter: ItemsPresenter
var traits_presenter: TraitsPresenter
var item_runtime: ItemRuntime
var item_drag_router: ItemDragRouter

# Grid helpers
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var bench_grid_helper: BoardGrid
var sell_grid_helper: BoardGrid
var player_tile_idx: int = -1

# Views
var player_views: Array[UnitSlotView] = []
var enemy_views: Array[UnitSlotView] = []
var move_router

# Auto-battle
var auto_combat: bool = true
var _auto_loop_running: bool = false
var turn_delay: float = 0.6

# Other state
var _post_combat_outcome: String = ""
var _pending_continue: bool = false
var view_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _beam_overlay: Control = null
var _layout_debug: bool = true

func _attach_clear_to_grid_tiles(grid: GridContainer) -> void:
	if selection == null or grid == null:
		return
	for child in grid.get_children():
		if child is Control:
			selection.attach_clear_on(child)

func configure(_parent: Control, _manager: CombatManager, nodes: Dictionary) -> void:
	parent = _parent
	manager = _manager
	log_label = nodes.get("log_label")
	player_stats_label = nodes.get("player_stats_label")
	enemy_stats_label = nodes.get("enemy_stats_label")
	stage_label = nodes.get("stage_label")
	player_sprite = nodes.get("player_sprite")
	enemy_sprite = nodes.get("enemy_sprite")
	player_grid = nodes.get("player_grid")
	bench_grid = nodes.get("bench_grid")
	shop_grid = nodes.get("shop_grid")
	enemy_grid = nodes.get("enemy_grid")
	arena_container = nodes.get("arena_container")
	arena_background = nodes.get("arena_background")
	arena_units = nodes.get("arena_units")
	planning_area = nodes.get("planning_area")
	attack_button = nodes.get("attack_button")
	continue_button = nodes.get("continue_button")
	menu_button = nodes.get("menu_button")
	gold_label = nodes.get("gold_label")
	bet_slider = nodes.get("bet_slider")
	bet_value = nodes.get("bet_value")
	stats_panel = nodes.get("stats_panel")

func initialize() -> void:
	# Wire manager
	if manager:
		if manager.get_parent() != parent:
			parent.add_child(manager)
		if not manager.is_connected("battle_started", Callable(self, "_on_battle_started")):
			manager.battle_started.connect(_on_battle_started)
		if not manager.is_connected("log_line", Callable(self, "_on_log_line")):
			manager.log_line.connect(_on_log_line)
		if not manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
			manager.stats_updated.connect(_on_stats_updated)
		if not manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
			manager.team_stats_updated.connect(_on_team_stats_updated)
		if not manager.is_connected("unit_stat_changed", Callable(self, "_on_unit_stat_changed")):
			manager.unit_stat_changed.connect(_on_unit_stat_changed)
		if not manager.is_connected("vfx_knockup", Callable(self, "_on_vfx_knockup")):
			manager.vfx_knockup.connect(_on_vfx_knockup)
		if not manager.is_connected("vfx_beam_line", Callable(self, "_on_vfx_beam_line")):
			manager.vfx_beam_line.connect(_on_vfx_beam_line)

	# Items runtime: orchestrates combat item effects based on equipped items
	if item_runtime == null:
		item_runtime = ItemRuntime.new()
		# Configure with manager; runtime will rebind to engine when available and on battle start
		item_runtime.configure(manager)

	# Listen to Items action logs and route to the same log pipeline as engine
	if Engine.has_singleton("Items") and not Items.is_connected("action_log", Callable(self, "_on_items_action_log")):
		Items.action_log.connect(_on_items_action_log)
	# Configure StatsPanel shell (optional)
	if stats_panel and stats_panel.has_method("configure"):
		stats_panel.configure(parent, manager)
		if not manager.is_connected("victory", Callable(self, "_on_victory")):
			manager.victory.connect(_on_victory)
		if not manager.is_connected("defeat", Callable(self, "_on_defeat")):
			manager.defeat.connect(_on_defeat)

	# Layout debug disabled by default; enable and add prints as needed
	if not manager.is_connected("projectile_fired", Callable(self, "_on_projectile_fired")):
		manager.projectile_fired.connect(_on_projectile_fired)

	# UI-side stats tracker
	if stats_tracker == null:
		stats_tracker = StatsTracker.new()
		parent.add_child(stats_tracker)
		stats_tracker.configure(manager)
		# Provide tracker to StatsPanel if it exposes a setter
		if stats_panel and stats_panel.has_method("set_tracker"):
			stats_panel.set_tracker(stats_tracker)

	# Selection service: clear when clicking empty space
	if selection == null:
		selection = SelectionService.new()
		selection.unit_selected.connect(_on_unit_selected)
	if arena_background:
		selection.attach_clear_on(arena_background)
	# Also clear when clicking the planning area (pre-combat grid space)
	if planning_area:
		selection.attach_clear_on(planning_area)
	# And on the grids themselves so empty tiles count as 'off unit'
	if player_grid:
		selection.attach_clear_on(player_grid)
		_attach_clear_to_grid_tiles(player_grid)
	if enemy_grid:
		selection.attach_clear_on(enemy_grid)
		_attach_clear_to_grid_tiles(enemy_grid)
	if bench_grid:
		selection.attach_clear_on(bench_grid)
		_attach_clear_to_grid_tiles(bench_grid)

	# Wire buttons
	if attack_button and not attack_button.is_connected("pressed", Callable(self, "_on_attack_pressed")):
		attack_button.pressed.connect(_on_attack_pressed)
	if continue_button and not continue_button.is_connected("pressed", Callable(self, "_on_continue_pressed")):
		continue_button.pressed.connect(_on_continue_pressed)
	if menu_button and not menu_button.is_connected("pressed", Callable(self, "_on_menu_pressed")):
		menu_button.pressed.connect(_on_menu_pressed)

	# Economy UI
	economy_ui = EconomyUI.new()
	economy_ui.configure(gold_label, bet_slider, bet_value, parent)
	if bet_slider and not bet_slider.is_connected("value_changed", Callable(self, "_on_bet_changed")):
		bet_slider.value_changed.connect(_on_bet_changed)

	# UI visuals
	if log_label: log_label.visible = false
	if player_stats_label: player_stats_label.visible = false
	if enemy_stats_label: enemy_stats_label.visible = false

	# Build grids
	view_rng.randomize()
	grid_placement = GridPlacement.new()
	grid_placement.configure(player_grid, enemy_grid, UI.TILE_SIZE, 8, 3)
	# Ensure grid containers match the configured tile size so the
	# runtime layout looks the same as the editor preview.
	_apply_grid_dimensions(UI.TILE_SIZE)
	player_grid_helper = grid_placement.get_player_grid()
	enemy_grid_helper = grid_placement.get_enemy_grid()

	# Bench setup
	bench_placement = BenchPlacement.new()
	bench_placement.configure(bench_grid, UI.TILE_SIZE, BenchConstants.BENCH_CAPACITY)
	bench_grid_helper = bench_placement.get_bench_grid()

	# Items: drag router for item cards (route drops to units on board or bench)
	if item_drag_router == null:
		item_drag_router = ItemDragRouter.new()
		item_drag_router.configure(parent, grid_placement, player_grid_helper, bench_grid_helper)

	# Movement router
	move_router = MoveRouter.new()
	move_router.configure(manager, Roster, player_grid_helper, bench_grid_helper, grid_placement, bench_placement)
	move_router.set_refresh_callback(Callable(self, "refresh_all_views"))

	# React to bench changes
	if Roster and not Roster.is_connected("bench_changed", Callable(self, "_on_bench_changed")):
		Roster.bench_changed.connect(_on_bench_changed)

	_prepare_sprites()

	# Progression label updates from GameState
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		var gs = GameState if Engine.has_singleton("GameState") else parent.get_node("/root/GameState")
		if gs and not gs.is_connected("chapter_changed", Callable(self, "_on_gs_chapter_changed")):
			gs.chapter_changed.connect(_on_gs_chapter_changed)
		if gs and not gs.is_connected("stage_changed", Callable(self, "_on_gs_stage_changed")):
			gs.stage_changed.connect(_on_gs_stage_changed)

	# Arena + projectiles
	arena_bridge = ArenaBridge.new()
	arena_bridge.configure(arena_container, arena_units, planning_area, arena_background, player_grid_helper, enemy_grid_helper, preload("res://scripts/ui/combat/unit_actor.gd"), UI.TILE_SIZE)

	projectile_bridge = ProjectileBridge.new()
	projectile_bridge.configure(parent, arena_bridge, player_grid_helper, enemy_grid_helper, manager, view_rng)

	# Default player position
	player_tile_idx = int(floor(float(3) / 2.0)) * 8 + 1
	grid_placement.set_player_base_tile(player_tile_idx)

	# Hide arena and attack button by default
	if attack_button:
		attack_button.visible = false
		attack_button.disabled = true
	if arena_container:
		arena_container.visible = false

	# Shop presenter (UI shell). Use the shop grid itself as the sell-drop target.
	if shop_grid:
		shop_presenter = ShopPresenter.new()
		shop_presenter.configure(parent, shop_grid)
		# Listen for combine promotions to play level-up effects on bench/board
		if not shop_presenter.is_connected("promotions_emitted", Callable(self, "_on_promotions_emitted")):
			shop_presenter.promotions_emitted.connect(_on_promotions_emitted)
		# Provide board-aware combine hooks to Shop/Transactions so bench+board triples upgrade.
		if Engine.has_singleton("Shop"):
			# Team provider returns the live player_team array
			var _prov_team := func():
				return (manager.player_team if manager else [])
			if Shop.has_method("set_board_team_provider"):
				Shop.set_board_team_provider(_prov_team)
			# Removal callback consumes a specific unit from the board when combining
			if Shop.has_method("set_remove_from_board"):
				Shop.set_remove_from_board(func(u: Unit) -> bool:
					if u == null or manager == null:
						return false
					var rem_idx := -1
					for i in range(manager.player_team.size()):
						if manager.player_team[i] == u:
							rem_idx = i
							break
					if rem_idx == -1:
						return false
					manager.player_team.remove_at(rem_idx)
					# Refresh views to reflect removal and any promotion on-board
					if has_method("refresh_all_views"):
						refresh_all_views()
					elif grid_placement:
						grid_placement.rebuild_player_views(manager.player_team, true)
					return true)
		# Use cards in the shop grid as a BoardGrid drop target for selling.
		if shop_presenter.has_method("get_drop_grid"):
			sell_grid_helper = shop_presenter.get_drop_grid()
		# Refresh bench views when the shop UI rebuilds so their drop
		# targets include the up-to-date shop grid tiles.
		if shop_presenter.has_signal("grid_updated"):
			shop_presenter.grid_updated.connect(func():
				sell_grid_helper = shop_presenter.get_drop_grid()
				_rebuild_bench_views(true)
			)
		# Move economy + start controls into the shop button bar for a single top row.
		var bar := (shop_presenter.get_button_bar() if shop_presenter and shop_presenter.has_method("get_button_bar") else null)
		if bar:
			# Preserve order: reroll, lock, buy xp, lvl, gold, start battle, bet
			if gold_label and gold_label.get_parent() != bar:
				var prev := gold_label.get_parent()
				if prev: prev.remove_child(gold_label)
				bar.add_child(gold_label)
			if continue_button and continue_button.get_parent() != bar:
				var prev2 := continue_button.get_parent()
				if prev2: prev2.remove_child(continue_button)
				bar.add_child(continue_button)
			if bet_slider:
				var bet_row := bet_slider.get_parent()
				if bet_row and bet_row is Control and bet_row.get_parent() != bar:
					var prev3 := bet_row.get_parent()
					if prev3: prev3.remove_child(bet_row)
					bar.add_child(bet_row)
			# Hide the original actions row container if empty/unused.
			var actions_row := (gold_label.get_parent() if gold_label else null)
			# gold_label was moved, so we cannot resolve original directly. Instead, use known path if available.
			if parent and parent.has_node("MarginContainer/VBoxContainer/ActionsRow"):
				var ar := parent.get_node("MarginContainer/VBoxContainer/ActionsRow")
				if ar is Control:
					(ar as Control).visible = false

func _apply_grid_dimensions(tile: int) -> void:
	# Compute desired grid size from constants and theme separations
	if enemy_grid == null or player_grid == null:
		return
	var cols := 8
	var rows := 3
	var hsep := enemy_grid.get_theme_constant("h_separation", "GridContainer")
	var vsep := enemy_grid.get_theme_constant("v_separation", "GridContainer")
	var grid_w := tile * cols + hsep * (cols - 1)
	var grid_h := tile * rows + vsep * (rows - 1)

	# Center enemy grid at top of its area
	enemy_grid.anchor_left = 0.5
	enemy_grid.anchor_right = 0.5
	enemy_grid.offset_left = -grid_w / 2
	enemy_grid.offset_right = grid_w / 2
	enemy_grid.offset_bottom = grid_h

	# Center player grid at bottom of its area
	player_grid.anchor_left = 0.5
	player_grid.anchor_right = 0.5
	player_grid.anchor_top = 1.0
	player_grid.anchor_bottom = 1.0
	player_grid.offset_left = -grid_w / 2
	player_grid.offset_right = grid_w / 2
	player_grid.offset_top = -grid_h

	# Make sure the containers holding the grids are tall enough
	var top_area := enemy_grid.get_parent() as Control
	if top_area:
		top_area.custom_minimum_size.y = grid_h
	var bottom_area := player_grid.get_parent() as Control
	if bottom_area:
		bottom_area.custom_minimum_size.y = grid_h

func process(delta: float) -> void:
	if arena_container and arena_container.visible:
		_sync_arena_units()

func _init_game() -> void:
	clear_log()
	if continue_button:
		continue_button.disabled = false
		continue_button.visible = true
		continue_button.text = "Start Battle"
	if attack_button:
		attack_button.disabled = true
	if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
		Economy.reset_run()
		if economy_ui:
			economy_ui.refresh()
	if Engine.has_singleton("Shop") or parent.has_node("/root/Shop"):
		Shop.reset_run()
	if Engine.has_singleton("Roster") and Roster.has_method("reset"):
		Roster.reset()
	# Initialize chapter/stage via GameState (authoritative) and keep manager compatibility
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		var gs = GameState if Engine.has_singleton("GameState") else parent.get_node("/root/GameState")
		if gs:
			if gs.has_method("set_chapter_and_stage"):
				gs.set_chapter_and_stage(1, 1)
			elif gs.has_method("set_stage"):
				gs.set_stage(1)
	# For compatibility with existing flows
	if manager:
		manager.stage = 1
		_on_log_line("Gamble Battle")
		# Build preview after state set so it reflects Chapter 1 — Stage 1
		manager.setup_stage_preview()
		# Update label to reflect preview stage
		_update_stage_label()
	if is_instance_valid(player_sprite):
		player_sprite.visible = false
	if grid_placement and manager:
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		enemy_views = grid_placement.get_enemy_views()
		refresh_all_views()
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.PREVIEW)
	# Mount inventory UI presenter (left panel)
	if items_presenter == null:
		items_presenter = ItemsPresenter.new()
		items_presenter.configure(parent)
		items_presenter.initialize()
		if item_drag_router != null and items_presenter.has_method("set_router"):
			items_presenter.set_router(item_drag_router)

	# Mount traits tracker overlay (non-invasive to HBox)
	if traits_presenter == null:
		traits_presenter = TraitsPresenter.new()
		traits_presenter.configure(parent, manager)
		traits_presenter.initialize()

func _on_items_action_log(t: String) -> void:
	# Route item logs into the same UI logger used by combat engine
	_on_log_line(t)

func refresh_all_views() -> void:
	# Rebuild player and bench views and rewire drag drop targets (KISS/DRY)
	if grid_placement and manager:
		grid_placement.rebuild_player_views(manager.player_team, true)
		player_views = grid_placement.get_player_views()
		for pv in player_views:
			if pv and pv.view:
				# Player views: allow board<->bench moves and selling via shop grid when available
				var targets: Array = [player_grid_helper, bench_grid_helper]
				if sell_grid_helper != null:
					targets.append(sell_grid_helper)
				pv.view.set_drop_targets(targets)
				move_router.connect_unit_view(pv.view)
				# Also route potential sell drops from board
				if not pv.view.is_connected("dropped_on_target", Callable(self, "_on_unit_dropped_any")):
					pv.view.dropped_on_target.connect(_on_unit_dropped_any.bind(pv.view))
				# Selection on grid tiles (unit provider bound to slot)
				var _pv = pv
				var __prov := func(): return _pv.unit
				selection.attach_to_unit_view(_pv.view, "player", _pv.tile_idx, __prov)
	_rebuild_bench_views(true)
	# Ensure grid tiles keep the 'clear selection' handler even after rebuilds
	if player_grid:
		_attach_clear_to_grid_tiles(player_grid)
	if enemy_grid:
		_attach_clear_to_grid_tiles(enemy_grid)
	if bench_grid:
		_attach_clear_to_grid_tiles(bench_grid)
	# Rebuild traits tracker (board-only traits)
	if traits_presenter:
		traits_presenter.rebuild()

func _on_attack_pressed() -> void:
	pass

func _on_menu_pressed() -> void:
	var main := parent.get_tree().root.get_node_or_null("/root/Main")
	if main and main.has_method("go_to_menu"):
		main.call("go_to_menu")
	else:
		parent.visible = false
		if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
			GameState.set_phase(GameState.GamePhase.MENU)

func _on_continue_pressed() -> void:
	if not continue_button:
		return
	if continue_button.text == "Start Battle":
		Trace.step("Continue pressed: Start Battle branch")
		if not (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")):
			if Debug.enabled:
				print("[CombatView] Economy not found")
			return
		var bet_val: int = int(bet_slider.value) if bet_slider else int(Economy.current_bet)
		# Auto-bump bet to 1 when player has gold but slider is 0 (post-combat edge)
		if bet_val <= 0 and (Engine.has_singleton("Economy") and int(Economy.gold) > 0):
			bet_val = 1
			if bet_slider:
				bet_slider.value = 1
		var bet_ok: bool = Economy.set_bet(int(bet_val))
		if not bet_ok:
			if Debug.enabled:
				print("[CombatView] Place a bet > 0 to start")
			return
		Trace.step("Economy bet accepted")
		continue_button.disabled = true
		if economy_ui:
			economy_ui.set_bet_editable(false)
		if manager.player_team.is_empty():
			if Debug.enabled:
				print("[CombatView] Cannot start combat: player team is empty")
			continue_button.disabled = false
			return
		# Precompute arena positions from current planning layout so engine starts at chosen tiles
		if grid_placement and arena_bridge and manager:
			var ts := float(UI.TILE_SIZE)
			var ppos: Array[Vector2] = []
			var epos: Array[Vector2] = []
			for pv in player_views:
				var idx: int = pv.tile_idx
				var pos: Vector2 = player_grid_helper.get_center(idx) if player_grid_helper and idx >= 0 else Vector2.ZERO
				ppos.append(pos)
			for ev in enemy_views:
				var idx2: int = ev.tile_idx
				var pos2: Vector2 = enemy_grid_helper.get_center(idx2) if enemy_grid_helper and idx2 >= 0 else Vector2.ZERO
				epos.append(pos2)
			var bounds: Rect2 = Rect2()
			if arena_background and is_instance_valid(arena_background):
				var r: Rect2 = arena_background.get_global_rect()
				bounds = Rect2(r.position, r.size)
			if bounds.size.y <= 1.0 or bounds.size.x <= 1.0:
				var all_pts: Array[Vector2] = []
				for v in ppos: if typeof(v) == TYPE_VECTOR2: all_pts.append(v)
				for v2 in epos: if typeof(v2) == TYPE_VECTOR2: all_pts.append(v2)
				if all_pts.size() > 0:
					var min_x: float = all_pts[0].x
					var max_x: float = all_pts[0].x
					var min_y: float = all_pts[0].y
					var max_y: float = all_pts[0].y
					for p in all_pts:
						min_x = min(min_x, p.x)
						max_x = max(max_x, p.x)
						min_y = min(min_y, p.y)
						max_y = max(max_y, p.y)
					var margin: float = ts
					var pos_b := Vector2(min_x - margin, min_y - margin)
					var size_b := Vector2(max(1.0, (max_x - min_x) + margin * 2.0), max(1.0, (max_y - min_y) + margin * 2.0))
					bounds = Rect2(pos_b, size_b)
			# When bounds are valid, keep as-is
			if manager.has_method("cache_arena_config"):
				manager.cache_arena_config(ts, ppos, epos, bounds)
		Trace.step("Calling manager.start_stage()")
		manager.start_stage()
		Trace.step("Returned from manager.start_stage()")
		return
	if continue_button.text == "Restart":
		_init_game()
		return
	# Continue branch
	if not (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")):
		if Debug.enabled:
			print("[CombatView] Economy not found")
		return
	var bet_ok2: bool = Economy.set_bet(int(bet_slider.value))
	if not bet_ok2:
		if Debug.enabled:
			print("[CombatView] Place a bet > 0 to continue")
		return
	continue_button.disabled = true
	if attack_button:
		attack_button.disabled = false
	if economy_ui:
		economy_ui.set_bet_editable(false)
	manager.continue_to_next_stage()

func _on_bench_changed() -> void:
	# Rebuild bench views first so visuals reflect any immediate bench changes
	_rebuild_bench_views(true)
	# Auto-try combines when bench changes during planning. This makes triples consistent
	# whether they are formed by buying or by moving units between bench/board.
	var in_planning: bool = true
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		in_planning = (int(GameState.phase) != int(GameState.GamePhase.COMBAT))
	if in_planning and Engine.has_singleton("Shop") and Shop.has_method("try_combine_now"):
		var promos: Array = Shop.try_combine_now()
		if promos is Array and promos.size() > 0:
			# Refresh both bench and player views since board units may be consumed or promoted
			refresh_all_views()
			# Play level-up effects for promoted units
			_play_promotions(promos)

func _on_promotions_emitted(promotions: Array) -> void:
	if promotions == null or promotions.size() == 0:
		return
	# Defer to next frame so bench/player views rebuild after roster/team mutations
	call_deferred("_play_promotions", promotions)

func _play_promotions(promotions: Array) -> void:
	# Stagger multiple effects for clarity
	var delay: float = 0.0
	for p in promotions:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var kind := String(p.get("kept_kind", ""))
		var idx: int = int(p.get("kept_index", -1))
		var to_level: int = int(p.get("to_level", 0))
		if kind == "bench" and idx >= 0:
			_play_bench_promo(idx, to_level, delay)
		elif kind == "board" and idx >= 0:
			_play_board_promo(idx, to_level, delay)
		delay += 0.05

func _play_bench_promo(bench_index: int, to_level: int, delay: float) -> void:
	if bench_grid == null:
		return
	# BenchPlacement attaches UnitView as child of button tile at same index
	var tiles: Array = bench_grid.get_children()
	if bench_index < 0 or bench_index >= tiles.size():
		return
	var tile = tiles[bench_index]
	if tile is Control:
		# Locate UnitView under this tile
		for c in (tile as Control).get_children():
			if c is UnitView:
				var uv: UnitView = c
				if delay > 0.0:
					var tree := parent.get_tree() if parent else null
					if tree:
						var tmr := tree.create_timer(delay)
						tmr.timeout.connect(func(): uv.play_level_up(to_level))
						return
				uv.play_level_up(to_level)
				return

func _play_board_promo(team_index: int, to_level: int, delay: float) -> void:
	# Resolve unit by team index, then find its UnitView and play effect
	if manager == null or team_index < 0 or team_index >= manager.player_team.size():
		return
	var u: Unit = manager.player_team[team_index]
	if u == null:
		return
	# Find matching UnitView in current player_views
	for sv in player_views:
		if sv != null and sv.unit == u and sv.view is UnitView:
			var uv: UnitView = sv.view
			if delay > 0.0:
				var tree := parent.get_tree() if parent else null
				if tree:
					var tmr := tree.create_timer(delay)
					tmr.timeout.connect(func(): uv.play_level_up(to_level))
					return
			uv.play_level_up(to_level)
			return

func _rebuild_bench_views(allow_drag: bool) -> void:
	if bench_placement == null:
		return
	var units: Array = []
	if Roster:
		units = Roster.bench_slots
	bench_placement.rebuild_bench_views(units, allow_drag)
	# Assign multi-targets and routing for bench UnitViews by scanning tile children
	if bench_grid:
		for tile in bench_grid.get_children():
			if tile is Control:
				for child in tile.get_children():
					if child is UnitView:
						var t: Array = [player_grid_helper, bench_grid_helper]
						if sell_grid_helper != null:
							t.append(sell_grid_helper)
						(child as UnitView).set_drop_targets(t)
						move_router.connect_unit_view(child)
						# Connect sell handling for bench units
						if not (child as UnitView).is_connected("dropped_on_target", Callable(self, "_on_unit_dropped_any")):
							(child as UnitView).dropped_on_target.connect(_on_unit_dropped_any.bind(child))
							# Selection on bench unit views
							var _uv: UnitView = (child as UnitView)
							var __prov2 := func(): return _uv.unit
							selection.attach_to_unit_view(_uv, "player", -1, __prov2)

func _on_unit_dropped_any(target_grid, _tile_idx: int, uv: UnitView) -> void:
	# Handle sell-zone drops
	if sell_grid_helper == null or uv == null:
		return
	if target_grid != sell_grid_helper:
		return
	var u: Unit = uv.unit
	if u == null:
		return
	# Attempt to sell via Shop (support both autoload and root node setups)
	var sell_ok: bool = false
	var res: Dictionary = {}
	if Engine.has_singleton("Shop"):
		res = Shop.sell_unit(u)
		sell_ok = bool(res.get("ok", false))
	else:
		var root := (parent.get_tree().root if parent else null)
		var shop_node := (root.get_node_or_null("/root/Shop") if root else null)
		if shop_node and shop_node.has_method("sell_unit"):
			res = shop_node.call("sell_unit", u)
			sell_ok = bool(res.get("ok", false))
	# On success, ensure drag artifacts are cleaned and the view is removed promptly
	if sell_ok:
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()
	# On success, views will be rebuilt via roster signal or board removal callback

func _auto_start_battle() -> void:
	if not auto_combat:
		return
	if continue_button and continue_button.text != "Start Battle":
		continue_button.text = "Start Battle"
	if Debug.enabled:
		print("[CombatView] Auto-starting battle")
	_on_continue_pressed()

func _on_bet_changed(val: float) -> void:
	if economy_ui:
		economy_ui.on_bet_changed(val)

func _on_battle_started(stage: int, enemy: Unit) -> void:
	Trace.step("CombatView._on_battle_started: begin")
	_on_log_line("Prepare to fight.")
	_refresh_hud()
	_update_stage_label()
	# Set COMBAT phase before starting Economy escrow so UI refresh sees correct phase
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.COMBAT)
	if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
		Economy.start_combat()
	if grid_placement and manager:
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		enemy_views = grid_placement.get_enemy_views()
		grid_placement.rebuild_player_views(manager.player_team, false)
		player_views = grid_placement.get_player_views()
	Trace.step("CombatView._on_battle_started: enter arena")
	_enter_combat_arena()
	# Optional: add layout prints here when debugging sizes
	# Ensure economy UI reflects combat lock state immediately
	if economy_ui:
		economy_ui.refresh()

	# Wire engine events for stats panel/tracker and ability casts
	var eng = (manager.get_engine() if manager and manager.has_method("get_engine") else null)
	if eng:
		if not eng.is_connected("hit_applied", Callable(self, "_on_engine_hit_applied")):
			eng.hit_applied.connect(_on_engine_hit_applied)
		if eng.ability_system and not eng.ability_system.is_connected("ability_cast", Callable(self, "_on_engine_ability_cast")):
			eng.ability_system.ability_cast.connect(_on_engine_ability_cast)
		# Provide ability system to stats panel if supported
		if stats_panel and stats_panel.has_method("set_ability_system"):
			stats_panel.set_ability_system(eng.ability_system)

	# Attach selection overlays to arena actors
	_attach_selection_to_arena()

func _attach_selection_to_arena() -> void:
	if arena_bridge == null or manager == null:
		return
	for i in range(manager.player_team.size()):
		var actor: UnitActor = arena_bridge.get_player_actor(i)
		if actor and is_instance_valid(actor):
			var _idx := i
			var _prov := func():
				return (manager.player_team[_idx] if _idx < manager.player_team.size() else null)
			selection.attach_to_unit_actor(actor, "player", _idx, _prov)
	for j in range(manager.enemy_team.size()):
		var eactor: UnitActor = arena_bridge.get_enemy_actor(j)
		if eactor and is_instance_valid(eactor):
			var _j := j
			var _prov2 := func():
				return (manager.enemy_team[_j] if _j < manager.enemy_team.size() else null)
			selection.attach_to_unit_actor(eactor, "enemy", _j, _prov2)

func _on_engine_hit_applied(team: String, si: int, ti: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	# Forward to StatsPanel if it exposes a handler (non-breaking)
	if stats_panel and stats_panel.has_method("_on_hit_applied"):
		stats_panel._on_hit_applied(team, si, ti, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd)

func _on_engine_ability_cast(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	if stats_panel and stats_panel.has_method("_on_ability_cast"):
		stats_panel._on_ability_cast(team, index, ability_id, target_team, target_index, target_point)

func _on_unit_selected(u: Unit) -> void:
	if stats_panel == null:
		return
	if u != null:
		if stats_panel.has_method("show_unit_metrics_ctx"):
			# Use selection service's current context if available
			var team := (selection.get_selected_team() if selection else "player")
			var idx := (selection.get_selected_index() if selection else -1)
			stats_panel.show_unit_metrics_ctx(team, idx, u)
		elif stats_panel.has_method("show_unit_metrics"):
			stats_panel.show_unit_metrics(u)
	elif stats_panel.has_method("show_team_metrics"):
		stats_panel.show_team_metrics()

func _on_log_line(text: String) -> void:
	if Debug.enabled:
		print(text)
	if log_label:
		log_label.append_text(text + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)
	_log_to_file(text)

func _on_gs_chapter_changed(_prev: int, _next: int) -> void:
	_update_stage_label()

func _on_gs_stage_changed(_prev: int, _next: int) -> void:
	_update_stage_label()

func _update_stage_label() -> void:
	if stage_label == null:
		return
	var ch: int = 1
	var sic: int = 1
	var total: int = 0
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		var gs = GameState if Engine.has_singleton("GameState") else parent.get_node("/root/GameState")
		if gs:
			ch = int(gs.chapter)
			sic = int(gs.stage_in_chapter)
			total = int(ChapterCatalog.stages_in(ch))
	else:
		# Fallback: derive from manager.stage
		var st: int = (int(manager.stage) if manager else 1)
		var map := ProgressionService.from_global_stage(st)
		ch = int(map.get("chapter", 1))
		sic = int(map.get("stage_in_chapter", 1))
		total = int(ChapterCatalog.stages_in(ch))
	var label := LogSchema.format_stage(ch, sic, total)
	if RosterUtils.is_boss_stage(sic):
		label += " " + LogSchema.format_boss_badge()
	stage_label.text = label

func _log_to_file(_text: String) -> void:
	return

func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	if not enemy_views.is_empty():
		for v in enemy_views:
			if v and v.unit and v.view and v.view.has_method("update_from_unit"):
				v.view.update_from_unit(v.unit)
	if not player_views.is_empty():
		for pv in player_views:
			if pv and pv.unit and pv.view and pv.view.has_method("update_from_unit"):
				pv.view.update_from_unit(pv.unit)
	if manager:
		for i in range(manager.player_team.size()):
			var actor: UnitActor = arena_bridge.get_player_actor(i) if arena_bridge else null
			if actor and is_instance_valid(actor):
				actor.update_bars(manager.player_team[i])
		for i in range(manager.enemy_team.size()):
			var enemy_actor: UnitActor = arena_bridge.get_enemy_actor(i) if arena_bridge else null
			if enemy_actor and is_instance_valid(enemy_actor):
				enemy_actor.update_bars(manager.enemy_team[i])

func _refresh_stats() -> void:
	var p: Unit = null
	if manager and manager.player_team.size() > 0:
		for u in manager.player_team:
			if u and u.is_alive():
				p = u
				break
		if p == null:
			p = manager.player_team[0]
	if player_stats_label:
		if p:
			player_stats_label.text = "Team: " + p.summary()
		else:
			player_stats_label.text = "Team: (empty)"
	if enemy_stats_label:
		if manager and manager.enemy:
			enemy_stats_label.text = "Enemy:  " + manager.enemy.summary()
		else:
			enemy_stats_label.text = "Enemy:  "

func _on_victory(_stage: int) -> void:
	if attack_button:
		attack_button.disabled = true
	_post_combat_outcome = "victory"
	_auto_loop_running = false
	_start_intermission(2.0)

func _on_defeat(_stage: int) -> void:
	if attack_button:
		attack_button.disabled = true
	_post_combat_outcome = "defeat"
	_start_intermission(2.0)
	_auto_loop_running = false

func clear_log() -> void:
	if log_label:
		log_label.clear()

func _start_intermission(seconds: float = 5.0) -> void:
	if intermission == null:
		intermission = IntermissionController.new()
		intermission.configure(parent)
	intermission.start(seconds, Callable(self, "_on_intermission_finished"))

func _on_intermission_finished() -> void:
	if arena_container and arena_container.visible:
		_exit_combat_arena()
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.POST_COMBAT)
	if projectile_bridge:
		projectile_bridge.clear()
	if manager and manager.has_method("finalize_post_combat"):
		manager.finalize_post_combat()
		# Advance progression on victory so planning shows the upcoming enemy
		var win2: bool = (_post_combat_outcome == "victory")
		if win2 and (Engine.has_singleton("GameState") or parent.has_node("/root/GameState")):
			GameState.advance_after_victory()
		# Build a fresh preview for the next attempt (next stage on win, same stage on defeat)
		if manager.has_method("setup_stage_preview"):
			manager.setup_stage_preview()
		# Rebuild UI after state changes
		refresh_all_views()
		if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
			if _post_combat_outcome != "":
				var win: bool = (_post_combat_outcome == "victory")
				Economy.resolve(win)
			if economy_ui:
				economy_ui.refresh()
				economy_ui.set_bet_editable(true)
	# Optional: add layout prints here when debugging sizes
			# Auto-refresh the shop after combat ends (respect lock; free refresh)
			if Engine.has_singleton("Shop") or parent.has_node("/root/Shop"):
				var locked: bool = (bool(Shop.state.locked) if Shop and Shop.state else false)
				if not locked:
					Shop.add_free_rerolls(1)
					Shop.reroll()
	# Refresh label to reflect the stage/round the player will fight next
	_update_stage_label()
	if _post_combat_outcome == "defeat" and (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")) and Economy.is_broke():
		# Show loss screen instead of flipping the continue button to Restart
		var Loss = load("res://scenes/ui/LossScreen.tscn")
		if Loss:
			var screen: Control = Loss.instantiate()
			if screen:
				screen.z_index = 10000
				# Configure with last battle stats if available
				if screen.has_method("configure") and stats_tracker != null:
					screen.call("configure", stats_tracker)
				# Add above CombatView
				if parent and parent is Control:
					(parent as Control).add_child(screen)
				else:
					var ml := Engine.get_main_loop()
					if ml is SceneTree:
						(ml as SceneTree).root.add_child(screen)
		# Hide/disable continue button under overlay
		if continue_button:
			continue_button.disabled = true
			continue_button.visible = false
	else:
		if continue_button:
			# After victory we've already advanced and built a preview; use Start Battle.
			if _post_combat_outcome == "victory":
				continue_button.text = "Start Battle"
			else:
				continue_button.text = "Continue"
			continue_button.disabled = false
			continue_button.visible = true
	_pending_continue = false
	_post_combat_outcome = ""

func _start_auto_loop() -> void:
	if not auto_combat:
		return
	if _auto_loop_running:
		return
	_auto_loop_running = true
	call_deferred("_auto_loop")

	# No-op helpers removed; inline prints used instead

func _auto_loop() -> void:
	while _auto_loop_running and auto_combat:
		if not manager or manager.player_team.is_empty():
			break
		if manager.is_team_defeated("player") or manager.is_team_defeated("enemy"):
			break
		if projectile_bridge and projectile_bridge.has_active():
			pass
		elif manager.is_turn_in_progress():
			pass
		else:
			pass
		await parent.get_tree().create_timer(turn_delay).timeout
	_auto_loop_running = false

func _prepare_sprites() -> void:
	if player_sprite:
		player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		player_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	if enemy_sprite:
		enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_projectile_manager(pm: ProjectileManager) -> void:
	if not projectile_bridge:
		projectile_bridge = ProjectileBridge.new()
		projectile_bridge.configure(parent, arena_bridge, player_grid_helper, enemy_grid_helper, manager, view_rng)
	projectile_bridge.set_projectile_manager(pm)

func _on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not projectile_bridge:
		return
	projectile_bridge.on_projectile_fired(source_team, source_index, target_index, damage, crit)

func _set_sprite_texture(rect: TextureRect, path: String, fallback_color: Color) -> void:
	var tex: Texture2D = null
	if path != "":
		tex = load(path)
	if tex == null:
		tex = TextureUtils.make_circle_texture(fallback_color, 96)
	if rect:
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _get_enemy_sprite_by_index(i: int) -> Control:
	if i >= 0 and i < enemy_views.size():
		var v: UnitSlotView = enemy_views[i]
		if v and v.view:
			return v.view
	return null

func _get_player_sprite_by_index(i: int) -> Control:
	if i >= 0 and i < player_views.size():
		var v: UnitSlotView = player_views[i]
		if v and v.view:
			return v.view
	return null

func _on_team_stats_updated(_pteam, _eteam) -> void:
	_refresh_hud()

func _on_unit_stat_changed(team: String, index: int, fields: Dictionary) -> void:
	var views: Array[UnitSlotView] = (player_views if team == "player" else enemy_views)
	if index < 0 or index >= views.size():
		return
	var v: UnitSlotView = views[index]
	var u: Unit = v.unit
	if v and v.view and v.view.has_method("update_from_unit") and u:
		v.view.update_from_unit(u)
	if team == "player":
		var actor: UnitActor = arena_bridge.get_player_actor(index) if arena_bridge else null
		if actor and is_instance_valid(actor):
			actor.update_bars(u)
	else:
		var eactor: UnitActor = arena_bridge.get_enemy_actor(index) if arena_bridge else null
		if eactor and is_instance_valid(eactor):
			eactor.update_bars(u)

func _on_vfx_knockup(team: String, index: int, duration: float) -> void:
	if arena_bridge == null:
		return
	var actor: UnitActor = arena_bridge.get_actor(team, index)
	if actor and is_instance_valid(actor):
		actor.play_knockup(duration)

func _ensure_beam_overlay() -> void:
	if _beam_overlay and is_instance_valid(_beam_overlay):
		return
	var Overlay = load("res://scripts/ui/combat/beam_overlay.gd")
	_beam_overlay = Overlay.new()
	# Attach to arena_units so it sits above actors
	if parent and parent.has_method("get_node") and arena_units:
		arena_units.add_child(_beam_overlay)
		_beam_overlay.anchor_left = 0.0
		_beam_overlay.anchor_top = 0.0
		_beam_overlay.anchor_right = 1.0
		_beam_overlay.anchor_bottom = 1.0
		_beam_overlay.offset_left = 0.0
		_beam_overlay.offset_top = 0.0
		_beam_overlay.offset_right = 0.0
		_beam_overlay.offset_bottom = 0.0
		_beam_overlay.z_index = 100

func _on_vfx_beam_line(start: Vector2, end_: Vector2, color: Color, width: float, duration: float) -> void:
	_ensure_beam_overlay()
	if _beam_overlay and is_instance_valid(_beam_overlay) and _beam_overlay.has_method("add_beam"):
		_beam_overlay.add_beam(start, end_, color, width, duration)

func _enter_combat_arena() -> void:
	if not arena_container:
		return
	Trace.step("CombatView._enter_combat_arena: calling enter_arena")
	arena_bridge.enter_arena(player_views, enemy_views)
	Trace.step("CombatView._enter_combat_arena: defer configure engine arena")
	parent.call_deferred("_cv_configure_engine_arena")

func _sync_arena_units() -> void:
	arena_bridge.sync(manager, player_views, enemy_views)

func _exit_combat_arena() -> void:
	arena_bridge.exit_arena()

func _configure_engine_arena() -> void:
	if not manager:
		return
	arena_bridge.configure_engine_arena(manager, player_views, enemy_views)

func _log_start_positions_and_targets() -> void:
	arena_bridge._log_start_positions_and_targets(manager)

func set_player_team_ids(ids: Array) -> void:
	if not manager:
		return
	manager.player_team.clear()
	var uf = load("res://scripts/unit_factory.gd")
	for id in ids:
		var u: Unit = uf.spawn(String(id))
		if u:
			manager.player_team.append(u)
