extends RefCounted
class_name CombatController

const Trace := preload("res://scripts/util/trace.gd")
const UI := preload("res://scripts/constants/ui_constants.gd")
const G := preload("res://scripts/constants/gameplay_constants.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const Debug := preload("res://scripts/util/debug.gd")

const ArenaBridge := preload("res://scripts/ui/combat/arena_bridge.gd")
const GridPlacement := preload("res://scripts/ui/combat/grid_placement.gd")
const ProjectileBridge := preload("res://scripts/ui/combat/projectile_bridge.gd")
const EconomyUI := preload("res://scripts/ui/combat/economy_ui.gd")
const IntermissionController := preload("res://scripts/ui/combat/intermission_controller.gd")

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

# External engine manager
var manager: CombatManager

# Modules
var grid_placement: GridPlacement
var arena_bridge: ArenaBridge
var projectile_bridge: ProjectileBridge
var economy_ui: EconomyUI
var intermission: IntermissionController

# Grid helpers
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var player_tile_idx: int = -1

# Views
var player_views: Array[UnitSlotView] = []
var enemy_views: Array[UnitSlotView] = []

# Auto-battle
var auto_combat: bool = true
var _auto_loop_running: bool = false
var turn_delay: float = 0.6

# Other state
var _post_combat_outcome: String = ""
var _pending_continue: bool = false
var view_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _beam_overlay: Control = null

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
		if not manager.is_connected("victory", Callable(self, "_on_victory")):
			manager.victory.connect(_on_victory)
		if not manager.is_connected("defeat", Callable(self, "_on_defeat")):
			manager.defeat.connect(_on_defeat)
		if not manager.is_connected("projectile_fired", Callable(self, "_on_projectile_fired")):
			manager.projectile_fired.connect(_on_projectile_fired)

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
	player_grid_helper = grid_placement.get_player_grid()
	enemy_grid_helper = grid_placement.get_enemy_grid()

	_prepare_sprites()

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
	if manager:
		manager.stage = 1
		_on_log_line("Gamble Battle")
		manager.setup_stage_preview()
	if is_instance_valid(player_sprite):
		player_sprite.visible = false
	if grid_placement and manager:
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		enemy_views = grid_placement.get_enemy_views()
		grid_placement.rebuild_player_views(manager.player_team, true)
		player_views = grid_placement.get_player_views()
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.PREVIEW)

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
		var bet_ok: bool = Economy.set_bet(int(bet_slider.value))
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
	if stage_label:
		stage_label.text = "Stage " + str(stage)
	if grid_placement and manager:
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		enemy_views = grid_placement.get_enemy_views()
		grid_placement.rebuild_player_views(manager.player_team, false)
		player_views = grid_placement.get_player_views()
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.COMBAT)
	Trace.step("CombatView._on_battle_started: enter arena")
	_enter_combat_arena()

func _on_log_line(text: String) -> void:
	if Debug.enabled:
		print(text)
	if log_label:
		log_label.append_text(text + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)
	_log_to_file(text)

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
	if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
		if _post_combat_outcome != "":
			var win: bool = (_post_combat_outcome == "victory")
			Economy.resolve(win)
			if economy_ui:
				economy_ui.refresh()
				economy_ui.set_bet_editable(true)
	if _post_combat_outcome == "defeat" and (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")) and Economy.is_broke():
		_on_log_line("Out of gold. Press Restart to try again.")
		if continue_button:
			continue_button.text = "Restart"
			continue_button.disabled = false
			continue_button.visible = true
			continue_button.grab_focus()
	else:
		if continue_button:
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
