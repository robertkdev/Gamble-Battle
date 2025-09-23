extends Control

const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")
const Trace := preload("res://scripts/util/trace.gd")
const UI := preload("res://scripts/constants/ui_constants.gd")
const G := preload("res://scripts/constants/gameplay_constants.gd")
const ArenaControllerClass := preload("res://scripts/ui/combat/arena_controller.gd")
const UnitSlotView := preload("res://scripts/ui/combat/unit_slot_view.gd")
const UnitViewClass := preload("res://scripts/ui/combat/unit_view.gd")
const ProjectileManagerScript := preload("res://scripts/projectile_manager.gd")
const Debug := preload("res://scripts/util/debug.gd")

@onready var log_label: RichTextLabel = $"MarginContainer/VBoxContainer/Log"
@onready var player_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/PlayerStatsLabel"
@onready var enemy_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/EnemyStatsLabel"
@onready var stage_label: Label = $"MarginContainer/VBoxContainer/StageLabel"
@onready var player_sprite: TextureRect = $"MarginContainer/VBoxContainer/BattleArea/PlanningArea/BottomArea/PlayerUnitHolder/PlayerSprite"
@onready var enemy_sprite: TextureRect = $"MarginContainer/VBoxContainer/BattleArea/PlanningArea/TopArea/EnemyUnitHolder/EnemySprite"
var player_hp_bar: ProgressBar = null
var enemy_hp_bar: ProgressBar = null
@onready var player_grid: GridContainer = $"MarginContainer/VBoxContainer/BattleArea/PlanningArea/BottomArea/PlayerGrid"
@onready var arena_container: Control = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer"
@onready var arena_background: ColorRect = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground"
@onready var arena_units: Control = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits"
@onready var top_area: Control = $"MarginContainer/VBoxContainer/BattleArea/PlanningArea/TopArea"
@onready var bottom_area: Control = $"MarginContainer/VBoxContainer/BattleArea/PlanningArea/BottomArea"
@onready var planning_area: Control = $"MarginContainer/VBoxContainer/BattleArea/PlanningArea"
const UnitActorScene := preload("res://scripts/ui/combat/unit_actor.gd")
var player_actors: Array[UnitActor] = []
var enemy_actors: Array[UnitActor] = []
var arena_bounds_rect: Rect2 = Rect2()
@onready var enemy_grid: GridContainer = $"MarginContainer/VBoxContainer/BattleArea/PlanningArea/TopArea/EnemyGrid"
@onready var attack_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/AttackButton"
@onready var continue_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/ContinueButton"
@onready var menu_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/MenuButton"
@onready var gold_label: Label = $"MarginContainer/VBoxContainer/ActionsRow/GoldLabel"
@onready var bet_row: HBoxContainer = $"MarginContainer/VBoxContainer/ActionsRow/BetRow"
@onready var bet_slider: HSlider = $"MarginContainer/VBoxContainer/ActionsRow/BetRow/BetSlider"
@onready var bet_value: Label = $"MarginContainer/VBoxContainer/ActionsRow/BetRow/BetValue"
## Title screen removed

var manager: CombatManager
var player_name: String = "Hero"
var projectile_manager: ProjectileManager

# Auto-battle settings
var auto_combat: bool = true
var _auto_loop_running: bool = false
var turn_delay: float = 0.6

# Grid settings
const GRID_W := 8
const GRID_H := 3
const TILE_SIZE := UI.TILE_SIZE
const GRID_TILE_GAP := 8
const GRID_BETWEEN_GAP := 24
var player_tiles: Array[Button] = []
var enemy_tiles: Array[Button] = []
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var player_tile_idx: int = -1
var enemy_tile_idx: int = -1
var enemy2_tile_idx: int = -1
var ally_tile_idx: int = -1
var view_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Extra UI created dynamically to support multi-enemy + mana
var enemy_sprite2: TextureRect
var enemy2_hp_bar: ProgressBar
var player_mana_bar: ProgressBar
var enemy_mana_bar: ProgressBar
var enemy2_mana_bar: ProgressBar
var enemy_views: Array[UnitSlotView] = []
var player_views: Array[UnitSlotView] = []

# Index arrays for multi-unit placement
var player_indices: Array[int] = []
var enemy_indices: Array[int] = []
var ally_sprite: TextureRect
var ally_hp_bar: ProgressBar
var ally_mana_bar: ProgressBar

var arena

var _planning_area_prev_mouse_filter: int = 0

# --- Post-combat intermission UI ---
var _intermission_active: bool = false
var _intermission_elapsed: float = 0.0
var _intermission_duration: float = 2.0
var _intermission_bar: ProgressBar = null
var _post_combat_outcome: String = "" # "victory" | "defeat" | ""
var _pending_continue: bool = false

func _ensure_intermission_bar() -> void:
	if _intermission_bar and is_instance_valid(_intermission_bar):
		return
	_intermission_bar = ProgressBar.new()
	add_child(_intermission_bar)
	_intermission_bar.anchor_left = 0.0
	_intermission_bar.anchor_top = 0.0
	_intermission_bar.anchor_right = 1.0
	_intermission_bar.anchor_bottom = 0.0
	_intermission_bar.offset_left = 16.0
	_intermission_bar.offset_right = -16.0
	_intermission_bar.offset_top = 8.0
	_intermission_bar.offset_bottom = 18.0
	_intermission_bar.min_value = 0.0
	_intermission_bar.max_value = 1.0
	_intermission_bar.value = 0.0
	_intermission_bar.visible = false

func _start_intermission(seconds: float = 5.0) -> void:
	_ensure_intermission_bar()
	_intermission_duration = max(0.1, seconds)
	_intermission_elapsed = 0.0
	_intermission_active = true
	_intermission_bar.value = 0.0
	_intermission_bar.visible = true
	set_process(true)

func _finish_intermission() -> void:
	_intermission_active = false
	if _intermission_bar:
		_intermission_bar.visible = false
	# Reveal planning phase after the brief intermission
	if arena_container and arena_container.visible:
		_exit_combat_arena()
	# Now enter POST_COMBAT and show deferred UI
	GameState.set_phase(GameState.GamePhase.POST_COMBAT)
	if projectile_manager:
		projectile_manager.clear()
	# Heal/reset units only now that the timer has finished
	if manager and manager.has_method("finalize_post_combat"):
		manager.finalize_post_combat()
	if Engine.has_singleton("Economy") or has_node("/root/Economy"):
		if _post_combat_outcome != "":
			var win := _post_combat_outcome == "victory"
			Economy.resolve(win)
			_refresh_economy_ui()
			if bet_slider:
				bet_slider.editable = true
	# Otherwise, show continue/restart prompt if pending or default flow
	if _post_combat_outcome == "defeat" and (Engine.has_singleton("Economy") or has_node("/root/Economy")) and Economy.is_broke():
		_on_log_line("Out of gold. Press Restart to try again.")
		continue_button.text = "Restart"
		continue_button.disabled = false
		continue_button.visible = true
		continue_button.grab_focus()
	else:
		continue_button.text = "Continue"
		continue_button.disabled = false
		continue_button.visible = true
	_pending_continue = false
	_post_combat_outcome = ""

func set_combat_manager(m: CombatManager) -> void:
	# Allows DI of CombatManager; wires signals safely
	if manager and is_instance_valid(manager):
		if manager.is_connected("battle_started", Callable(self, "_on_battle_started")):
			manager.battle_started.disconnect(_on_battle_started)
		if manager.is_connected("log_line", Callable(self, "_on_log_line")):
			manager.log_line.disconnect(_on_log_line)
		if manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
			manager.stats_updated.disconnect(_on_stats_updated)
		if manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
			manager.team_stats_updated.disconnect(_on_team_stats_updated)
		if manager.is_connected("unit_stat_changed", Callable(self, "_on_unit_stat_changed")):
			manager.unit_stat_changed.disconnect(_on_unit_stat_changed)
	manager = m
	if manager:
		if manager.get_parent() != self:
			add_child(manager)
		# Wire engine target selector so units move toward nearest valid enemy
		# (manager defines select_closest_target: Callable)
		manager.select_closest_target = Callable(self, "select_closest_target")
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

func _join_strings(arr: Array, sep: String) -> String:
	var out := ""
	for i in range(arr.size()):
		if i > 0:
			out += sep
		out += str(arr[i])
	return out

func _update_grid_metrics() -> void:
	# No-op: sizing is controlled in the scene. Move/resize BattleArea in the editor.
	pass

func _ready() -> void:
	if manager == null:
		manager = load("res://scripts/combat_manager.gd").new()
		add_child(manager)

	# Connect signals
	manager.battle_started.connect(_on_battle_started)
	manager.log_line.connect(_on_log_line)
	manager.stats_updated.connect(_on_stats_updated)
	if not manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
		manager.team_stats_updated.connect(_on_team_stats_updated)
	if not manager.is_connected("unit_stat_changed", Callable(self, "_on_unit_stat_changed")):
		manager.unit_stat_changed.connect(_on_unit_stat_changed)
	manager.victory.connect(_on_victory)
	manager.defeat.connect(_on_defeat)
	manager.projectile_fired.connect(_on_projectile_fired)
	# Ensure engine uses our closest-target selector for movement/aiming
	if manager:
		manager.select_closest_target = Callable(self, "select_closest_target")

	# Hide legacy HUD bars (single set) to keep unit bars as the only source of truth
	if is_instance_valid(player_hp_bar):
		player_hp_bar.visible = false
	if is_instance_valid(enemy_hp_bar):
		enemy_hp_bar.visible = false

	# Wire buttons
	attack_button.pressed.connect(_on_attack_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	if menu_button and not menu_button.is_connected("pressed", Callable(self, "_on_menu_pressed")):
		menu_button.pressed.connect(_on_menu_pressed)
	# title start removed
	# Economy UI wiring
	if bet_slider and not bet_slider.is_connected("value_changed", Callable(self, "_on_bet_changed")):
		bet_slider.value_changed.connect(_on_bet_changed)
	_refresh_economy_ui()
	if Engine.has_singleton("Economy") or has_node("/root/Economy"):
		Economy.gold_changed.connect(func(_g): _refresh_economy_ui())
		Economy.bet_changed.connect(func(_b): _refresh_economy_ui())

	# Optional fade-in kept minimal
	self.modulate.a = 1.0

	# Build grids and prepare sprites
	view_rng.randomize()
	_build_grids()
	_prepare_sprites()
	_prepare_projectiles()

	# Configure Arena controller
	arena = ArenaControllerClass.new()
	arena.configure(arena_container, arena_units, player_grid_helper, enemy_grid_helper, UnitActorScene, TILE_SIZE)
	# Set default player position (center row, column 1)
	var default_idx := int(floor(float(GRID_H) / 2.0)) * GRID_W + 1
	player_tile_idx = default_idx

	# Attack button is hidden for autobattler gameplay
	attack_button.visible = false
	attack_button.disabled = true

	if arena_container:
		arena_container.visible = false
	set_process(true)
	# Title screen removed; awaiting external start

	# Prefer HUD over verbose text to keep buttons visible
	log_label.visible = false
	player_stats_label.visible = false
	enemy_stats_label.visible = false

func _init_game() -> void:
	clear_log()
	continue_button.disabled = false
	continue_button.visible = true
	continue_button.text = "Start Battle"
	attack_button.disabled = true
	# Reset economy for a new run
	if Engine.has_singleton("Economy") or has_node("/root/Economy"):
		Economy.reset_run()
		_refresh_economy_ui()
	manager.stage = 1
	# Legacy HUD bars hidden; styling not applied
	_on_log_line("Gamble Battle")
	# Build teams for preview so both player and ally are visible before battle
	manager.setup_stage_preview()
	# Do not auto-start the battle; player starts via Continue/Start Battle
	# Deterministic enemy preview placement (record indices only; attach during rebuild)
	if enemy_tiles.size() == GRID_W * GRID_H:
		enemy_tile_idx = 0
		# Build linear enemy indices for preview
		enemy_indices.clear()
		for i in range(min(manager.enemy_team.size(), enemy_tiles.size())):
			enemy_indices.append(i)
	_rebuild_enemy_views()
	_rebuild_player_views()
	# Phase: PREVIEW (setup phase, allow editing)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	# Player ally will be provided by manager.start_stage via player_team; views built on battle_started

func _on_attack_pressed() -> void:
	# No manual attacks in realtime autobattler
	pass

func _on_menu_pressed() -> void:
	var main := get_tree().root.get_node_or_null("/root/Main")
	if main and main.has_method("go_to_menu"):
		main.call("go_to_menu")
	else:
		# Fallback: hide self and set phase
		self.visible = false
		GameState.set_phase(GameState.GamePhase.MENU)

func _on_continue_pressed() -> void:
	if continue_button.text == "Start Battle":
		Trace.step("Continue pressed: Start Battle branch")
		# Require a valid bet to start combat
		if (not (Engine.has_singleton("Economy") or has_node("/root/Economy"))):
			print("[CombatView] Economy not found")
			return
		var bet_ok: bool = Economy.set_bet(int(bet_slider.value))
		if not bet_ok:
			print("[CombatView] Place a bet > 0 to start")
			return
		Trace.step("Economy bet accepted")
		continue_button.disabled = true
		# Lock bet during combat
		if bet_slider: bet_slider.editable = false
		# Do not allow start if player team is empty
		if manager.player_team.is_empty():
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
	# Post-victory continue to next stage
	# Require a valid bet before continuing to the next stage
	if not (Engine.has_singleton("Economy") or has_node("/root/Economy")):
		print("[CombatView] Economy not found")
		return
	var bet_ok2: bool = Economy.set_bet(int(bet_slider.value))
	if not bet_ok2:
		print("[CombatView] Place a bet > 0 to continue")
		return
	continue_button.disabled = true
	attack_button.disabled = false
	if bet_slider: bet_slider.editable = false
	manager.continue_to_next_stage()

func _auto_start_battle() -> void:
	if not auto_combat:
		return
	if continue_button and continue_button.text != "Start Battle":
		continue_button.text = "Start Battle"
	print("[CombatView] Auto-starting battle")
	_on_continue_pressed()

func _refresh_economy_ui() -> void:
	if not (Engine.has_singleton("Economy") or has_node("/root/Economy")):
		return
	if gold_label:
		gold_label.text = "Gold: " + str(Economy.gold)
	if bet_slider:
		bet_slider.min_value = 1 if Economy.gold > 0 else 0
		bet_slider.max_value = max(1, Economy.gold)
		if Economy.current_bet > 0:
			bet_slider.value = clamp(Economy.current_bet, bet_slider.min_value, bet_slider.max_value)
		else:
			bet_slider.value = min(1, bet_slider.max_value)
	if bet_value:
		bet_value.text = str(int(bet_slider.value))

func _on_bet_changed(val: float) -> void:
	if not (Engine.has_singleton("Economy") or has_node("/root/Economy")):
		return
	Economy.set_bet(int(val))
	if bet_value:
		bet_value.text = str(int(val))

func _on_battle_started(stage: int, enemy: Unit) -> void:
	Trace.step("CombatView._on_battle_started: begin")
	_on_log_line("Prepare to fight.")
	_refresh_hud()
	stage_label.text = "Stage " + str(stage)
	# Deterministic enemy placement: fill tiles linearly
	if enemy_tiles.size() == GRID_W * GRID_H:
		enemy_tile_idx = 0
		enemy_indices.clear()
		for i in range(min(manager.enemy_team.size(), enemy_tiles.size())):
			enemy_indices.append(i)
	# Enemy UnitViews will be built in _rebuild_enemy_views
	# Build/attach views for both teams
	Trace.step("CombatView._on_battle_started: rebuild enemy views")
	_rebuild_enemy_views()
	Trace.step("CombatView._on_battle_started: rebuild player views")
	_rebuild_player_views()
	# Phase: COMBAT (disable editing)
	GameState.set_phase(GameState.GamePhase.COMBAT)
	Trace.step("CombatView._on_battle_started: enter arena")
	_enter_combat_arena()
	# Realtime combat handled by CombatManager; no manual loop needed.

func _on_log_line(text: String) -> void:
	print(text)
	log_label.append_text(text + "\n")
	log_label.scroll_to_line(log_label.get_line_count() - 1)
	_log_to_file(text)

func _log_to_file(text: String) -> void:
	# Disable synchronous per-line file writes during combat to avoid stalls
	return


func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	# Unit bars are updated on their own views and actors; no HUD bar updates
	# Generic enemy bars (typed UnitSlotView)
	if not enemy_views.is_empty():
		for v in enemy_views:
			if v and v.unit and v.view:
				var u: Unit = v.unit
				if v.view.hp_bar:
					v.view.hp_bar.max_value = max(1, u.max_hp)
					v.view.hp_bar.value = clamp(u.hp, 0, u.max_hp)
				if v.view.mana_bar:
					v.view.mana_bar.max_value = max(0, u.mana_max)
					v.view.mana_bar.value = clamp(u.mana, 0, u.mana_max)

	# Player team bars (typed UnitSlotView)
	if not player_views.is_empty():
		for pv in player_views:
			if pv and pv.unit and pv.view:
				var pu: Unit = pv.unit
				if pv.view.hp_bar:
					pv.view.hp_bar.max_value = max(1, pu.max_hp)
					pv.view.hp_bar.value = clamp(pu.hp, 0, pu.max_hp)
				if pv.view.mana_bar:
					pv.view.mana_bar.max_value = max(0, pu.mana_max)
					pv.view.mana_bar.value = clamp(pu.mana, 0, pu.mana_max)

	if manager:
		for i in range(min(player_actors.size(), manager.player_team.size())):
			var actor: UnitActor = player_actors[i]
			if actor and is_instance_valid(actor):
				actor.update_bars(manager.player_team[i])
		for i in range(min(enemy_actors.size(), manager.enemy_team.size())):
			var enemy_actor: UnitActor = enemy_actors[i]
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
	if p:
		player_stats_label.text = "Team: " + p.summary()
	else:
		player_stats_label.text = "Team: (empty)"
	if manager.enemy:
		enemy_stats_label.text = "Enemy:  " + manager.enemy.summary()
	else:
		enemy_stats_label.text = "Enemy:  "

func _on_victory(_stage: int) -> void:
	attack_button.disabled = true
	_post_combat_outcome = "victory"
	_auto_loop_running = false
	# Begin intermission delay before leaving combat and showing any post-combat UI
	_start_intermission(2.0)

func _on_defeat(_stage: int) -> void:
	attack_button.disabled = true
	_post_combat_outcome = "defeat"
	# Begin intermission delay before leaving combat and showing any post-combat UI
	_start_intermission(2.0)
	_auto_loop_running = false
	# Defer any post-combat UI until after intermission

func clear_log() -> void:
	log_label.clear()

## Title overlay removed; start via Main

# --- Auto-battle helpers ---

func _start_auto_loop() -> void:
	if not auto_combat:
		return
	if _auto_loop_running:
		return
	_auto_loop_running = true
	call_deferred("_auto_loop")

func _auto_loop() -> void:
	# Run until a team is eliminated or we enter a selection state
	while _auto_loop_running and auto_combat:
		if not manager or manager.player_team.is_empty():
			break
		if manager.is_team_defeated("player") or manager.is_team_defeated("enemy"):
			break
		if projectile_manager and projectile_manager.has_active():
			pass
		elif manager.is_turn_in_progress():
			pass
		else:
			pass
		await get_tree().create_timer(turn_delay).timeout
	_auto_loop_running = false

# --- Simple procedural sprites ---

func _prepare_sprites() -> void:
	if player_sprite:
		player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Allow sprite to receive mouse for drag
		player_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	if enemy_sprite:
		enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect drag handling once
	# Drag handled by UnitView; no direct sprite dragging

func _prepare_projectiles() -> void:
	if not projectile_manager:
		projectile_manager = ProjectileManagerScript.new()
	if projectile_manager.get_parent() != self:
		add_child(projectile_manager)
	projectile_manager.configure()

func set_projectile_manager(pm: ProjectileManager) -> void:
	projectile_manager = pm
	if projectile_manager.get_parent() != self:
		add_child(projectile_manager)
	projectile_manager.configure()

func _on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not projectile_manager:
		return
	var start_pos: Vector2
	var end_pos: Vector2
	var tgt_control: Control = null
	var color: Color
	var src_control: Control = null
	if source_team == "player":
		# Source is on player team
		var actor_src: UnitActor = arena.get_player_actor(source_index) if arena else null
		if actor_src:
			start_pos = actor_src.get_global_rect().get_center()
		else:
			var psrc := _get_player_sprite_by_index(source_index)
			start_pos = psrc.get_global_rect().get_center() if psrc else player_grid_helper.get_center(player_tile_idx)
		src_control = actor_src if actor_src else _get_player_sprite_by_index(source_index)
		var actor_tgt: UnitActor = arena.get_enemy_actor(target_index) if arena else null
		if actor_tgt:
			tgt_control = actor_tgt
			end_pos = actor_tgt.get_global_rect().get_center()
		else:
			var spr: Control = _get_enemy_sprite_by_index(target_index)
			if spr:
				tgt_control = spr
				end_pos = spr.get_global_rect().get_center()
			else:
				end_pos = enemy_grid_helper.get_center(target_index)
		color = Color(0.2, 0.8, 1.0)
	else:
		# Source is on enemy team
		var actor_esrc: UnitActor = arena.get_enemy_actor(source_index) if arena else null
		if actor_esrc:
			start_pos = actor_esrc.get_global_rect().get_center()
		else:
			var esrc := _get_enemy_sprite_by_index(source_index)
			start_pos = esrc.get_global_rect().get_center() if esrc else enemy_grid_helper.get_center(source_index)
		src_control = actor_esrc if actor_esrc else _get_enemy_sprite_by_index(source_index)
		var actor_ptgt: UnitActor = arena.get_player_actor(target_index) if arena else null
		if actor_ptgt:
			tgt_control = actor_ptgt
			end_pos = actor_ptgt.get_global_rect().get_center()
		else:
			tgt_control = _get_player_sprite_by_index(target_index)
			end_pos = (tgt_control as Control).get_global_rect().get_center() if tgt_control else player_grid_helper.get_center(target_index)
		color = Color(1.0, 0.4, 0.2)
	var speed := G.PROJECTILE_SPEED
	var radius := G.PROJECTILE_RADIUS
		# Determine arc effect for ability multishot (Nyxa Chaos Volley)
	var arc_curve: float = 0.0
	var arc_freq: float = 6.0
	if manager and manager.get_engine():
		var eng = manager.get_engine()
		if eng and eng.buff_system and eng.state and eng.buff_system.has_tag(eng.state, source_team, source_index, "nyxa_cv_active"):
			arc_curve = 0.35 + view_rng.randf() * 0.25 # slight randomness
			arc_freq = 5.0 + view_rng.randf() * 4.0
	projectile_manager.fire_basic(
		source_team,
		source_index,
		start_pos,
		end_pos,
		damage,
		crit,
		speed,
		radius,
		color,
		tgt_control,
		target_index,
		src_control,
		arc_curve,
		arc_freq
	)
	# Ensure hit bridging is connected
	if not projectile_manager.is_connected("projectile_hit", Callable(manager, "on_projectile_hit")):
		projectile_manager.projectile_hit.connect(manager.on_projectile_hit)

func _set_sprite_texture(rect: TextureRect, path: String, fallback_color: Color) -> void:
	var tex: Texture2D = null
	if path != "":
		tex = load(path)
	if tex == null:
		tex = _make_circle_texture(fallback_color, 96)
	if rect:
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

# Direct sprite drag removed; UnitView handles drag-and-drop
func _begin_drag(_sprite: TextureRect, _hp_bar: ProgressBar, _mana_bar: ProgressBar) -> void:
	pass

func _update_drag_bars_position(_sprite: TextureRect) -> void:
	pass

func _end_drag_bars() -> void:
	pass

func _on_player_sprite_gui_input(event: InputEvent) -> void:
	pass

func _input(event: InputEvent) -> void:
	pass

func _process(_delta: float) -> void:
	if _intermission_active:
		_intermission_elapsed += _delta
		if _intermission_bar and _intermission_duration > 0.0:
			_intermission_bar.value = clamp(_intermission_elapsed / _intermission_duration, 0.0, 1.0)
		if _intermission_elapsed >= _intermission_duration:
			_finish_intermission()
	if arena_container and arena_container.visible:
		_sync_arena_units()

## Ally sprite direct drag removed; UnitView handles placement and snapping
func _on_ally_sprite_gui_input(_event: InputEvent) -> void:
	pass

func _snap_ally_to_mouse_tile() -> void:
	pass

func _snap_player_to_mouse_tile() -> void:
	pass

func _player_tile_index_from_global(_gpos: Vector2) -> int:
	return -1



func _make_circle_texture(color: Color, tex_size: int) -> ImageTexture:
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(tex_size) * 0.5
	var cy := float(tex_size) * 0.5
	var r := float(tex_size) * 0.45
	var r2 := r * r
	for y in range(tex_size):
		for x in range(tex_size):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d2: float = dx * dx + dy * dy
			if d2 <= r2:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	return tex

# --- Grid helpers ---

func _build_grids() -> void:
	# Collect pre-placed tiles from the scene (no dynamic creation)
	player_tiles.clear()
	enemy_tiles.clear()
	# Player tiles
	if player_grid:
		for c in player_grid.get_children():
			if c is Button:
				var pb := c as Button
				pb.text = ""
				pb.toggle_mode = false
				pb.focus_mode = Control.FOCUS_NONE
				pb.disabled = true
				if pb.custom_minimum_size == Vector2.ZERO:
					pb.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
				player_tiles.append(pb)
	# Enemy tiles
	if enemy_grid:
		for c in enemy_grid.get_children():
			if c is Button:
				var eb := c as Button
				eb.text = ""
				eb.toggle_mode = false
				eb.focus_mode = Control.FOCUS_NONE
				eb.disabled = true
				if eb.custom_minimum_size == Vector2.ZERO:
					eb.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
				enemy_tiles.append(eb)

	# Initialize grid helpers
	player_grid_helper = load("res://scripts/board_grid.gd").new()
	player_grid_helper.configure(player_tiles, GRID_W, GRID_H)
	enemy_grid_helper = load("res://scripts/board_grid.gd").new()
	enemy_grid_helper.configure(enemy_tiles, GRID_W, GRID_H)

	# No dynamic sizing here; use BattleArea in the scene to control layout.

# Click-to-place disabled entirely; placement is drag-only
func _on_player_tile_pressed(idx: int) -> void:
	pass

func _set_player_tile(idx: int) -> void:
	if idx < 0 or idx >= player_tiles.size():
		return
	player_tile_idx = idx
	for i in range(player_tiles.size()):
		player_tiles[i].button_pressed = (i == idx)
	# If player exists, ensure bar values are up to date before attaching
	# Legacy HUD bars removed; skip attach

func _set_enemy_tile(idx: int) -> void:
	if idx < 0 or idx >= enemy_tiles.size():
		return
	enemy_tile_idx = idx
	# Legacy HUD bars removed; enemy UnitViews handle their own bars

func _set_enemy2_tile(idx: int) -> void:
	if idx < 0 or idx >= enemy_tiles.size():
		return
	enemy2_tile_idx = idx
	# Legacy HUD bars removed; enemy UnitViews handle their own bars

func _attach_unit_to_tile(sprite: Control, hp_bar: ProgressBar, tile: Control) -> void:
	if not sprite or not tile:
		return
	var parent := sprite.get_parent()
	if parent:
		parent.remove_child(sprite)
	tile.add_child(sprite)
	sprite.anchor_left = 0.0
	sprite.anchor_top = 0.0
	sprite.anchor_right = 1.0
	sprite.anchor_bottom = 1.0
	sprite.offset_left = 0.0
	sprite.offset_top = 0.0
	sprite.offset_right = 0.0
	sprite.offset_bottom = 0.0

func _attach_mana_bar_to_tile(mana_bar: ProgressBar, tile: Control) -> void:
	# Legacy HUD bars removed; no-op
	return

func _ensure_player_mana_bar() -> void:
	# Legacy HUD bars removed; no-op
	return

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

func _rebuild_enemy_views() -> void:
	enemy_views.clear()
	if not manager:
		return
	Trace.step("CombatView._rebuild_enemy_views: begin")
	if enemy_grid_helper:
		enemy_grid_helper.clear()
	var summary: Array[String] = []
	for i in range(min(manager.enemy_team.size(), enemy_tiles.size())):
		var tile_idx: int = i
		if tile_idx >= enemy_tiles.size():
			continue
		var u: Unit = manager.enemy_team[i]
		var uv: UnitView = UnitViewClass.new()
		uv.set_unit(u)
		if enemy_grid_helper:
			enemy_grid_helper.attach(uv, tile_idx)
		else:
			_attach_unit_to_tile(uv, null, enemy_tiles[tile_idx])
		var slot := UnitSlotView.new()
		slot.unit = u
		slot.view = uv
		slot.tile_idx = tile_idx
		enemy_views.append(slot)
		var placement: String = "%d:tile%d" % [i, tile_idx]
		if enemy_grid_helper and tile_idx >= 0:
			placement = "%d:%s" % [i, enemy_grid_helper.get_center(tile_idx)]
		summary.append(placement)
	if not summary.is_empty():
		Debug.log("Plan", "Enemy positions %s" % [_join_strings(summary, ", ")])
	Trace.step("CombatView._rebuild_enemy_views: done")

func _rebuild_player_views() -> void:
	player_views.clear()
	if not manager:
		return
	Trace.step("CombatView._rebuild_player_views: begin")
	if manager.player_team.size() == 0:
		return
	if player_grid_helper:
		player_grid_helper.clear()
	if is_instance_valid(player_sprite):
		player_sprite.visible = false
	# Legacy HUD bars already hidden in _ready
	if player_indices.size() != manager.player_team.size():
		player_indices.clear()
		for i in range(manager.player_team.size()):
			player_indices.append(min(player_tiles.size() - 1, (player_tile_idx + i) % player_tiles.size()))
	var summary: Array[String] = []
	for i in range(min(manager.player_team.size(), player_tiles.size())):
		var pu: Unit = manager.player_team[i]
		var tile_idx := player_indices[i]
		if tile_idx < 0:
			tile_idx = i % player_tiles.size()
		var uv: UnitView = UnitViewClass.new()
		uv.set_unit(pu)
		var allow_drag := (GameState.phase != GameState.GamePhase.COMBAT)
		if allow_drag:
			uv.enable_drag(player_grid_helper)
		uv.dropped_on_tile.connect(func(idx): _on_player_unit_dropped(i, idx))
		if player_grid_helper:
			player_grid_helper.attach(uv, tile_idx)
		else:
			_attach_unit_to_tile(uv, null, player_tiles[tile_idx])
		var slot := UnitSlotView.new()
		slot.unit = pu
		slot.view = uv
		slot.tile_idx = tile_idx
		player_views.append(slot)
		var placement: String = "%d:tile%d" % [i, tile_idx]
		if player_grid_helper and tile_idx >= 0:
			placement = "%d:%s" % [i, player_grid_helper.get_center(tile_idx)]
		summary.append(placement)
	if not summary.is_empty():
		Debug.log("Plan", "Player positions %s" % [_join_strings(summary, ", ")])
	Trace.step("CombatView._rebuild_player_views: done")

func _on_player_unit_dropped(i: int, idx: int) -> void:
	if idx < 0 or idx >= player_tiles.size():
		return
	# Guard against stale indices if views were rebuilt during drag
	if i < 0 or i >= player_views.size():
		return
	# If another unit occupies target, swap
	var j := -1
	for k in range(player_indices.size()):
		if k != i and player_indices[k] == idx:
			j = k
			break
	var old_idx := player_indices[i]
	player_indices[i] = idx
	if j != -1:
		if j < 0 or j >= player_views.size():
			return
		player_indices[j] = old_idx
		# Swap occupants visually
		var ctrl_i: Control = player_views[i].view
		var ctrl_j: Control = player_views[j].view
		if player_grid_helper:
			player_grid_helper.attach(ctrl_i, idx)
			player_grid_helper.attach(ctrl_j, old_idx)
		# Keep view metadata in sync
		player_views[i].tile_idx = idx
		player_views[j].tile_idx = old_idx
	else:
		var ctrl: Control = player_views[i].view
		if player_grid_helper and ctrl:
			player_grid_helper.attach(ctrl, idx)
		player_views[i].tile_idx = idx

func _on_team_stats_updated(_pteam, _eteam) -> void:
	# Apply selective refresh for bars
	_refresh_hud()

func _on_unit_stat_changed(team: String, index: int, fields: Dictionary) -> void:
	var views: Array[UnitSlotView] = (player_views if team == "player" else enemy_views)
	if index < 0 or index >= views.size():
		return
	var v: UnitSlotView = views[index]
	var u: Unit = v.unit
	if v.view and v.view.hp_bar and fields.has("hp") and u:
		v.view.hp_bar.max_value = max(1, u.max_hp)
		v.view.hp_bar.value = clamp(int(fields["hp"]), 0, u.max_hp)
	if v.view and v.view.mana_bar and fields.has("mana") and u:
		v.view.mana_bar.max_value = max(0, u.mana_max)
		v.view.mana_bar.value = clamp(int(fields["mana"]), 0, u.mana_max)
	# Also update active arena actors immediately to avoid relying solely on snapshot refreshes
	if team == "player":
		if index >= 0 and index < player_actors.size():
			var actor: UnitActor = player_actors[index]
			if actor and is_instance_valid(actor):
				actor.update_bars(u)
		# No HUD bars to update
	else:
		if index >= 0 and index < enemy_actors.size():
			var eactor: UnitActor = enemy_actors[index]
			if eactor and is_instance_valid(eactor):
				eactor.update_bars(u)
		# No HUD bars to update

# --- Allies (modular unit UI for player side) ---
func _spawn_ally(id: String) -> void:
	# Deprecated: allies are provided by CombatManager.player_team
	pass

func _choose_nearest_enemy_index() -> int:
	# Prefer enemies that are alive
	var indices: Array[int] = []
	for i in range(manager.enemy_team.size()):
		var e: Unit = manager.enemy_team[i]
		if e and e.is_alive():
			indices.append(i)
	if indices.is_empty():
		return 0
	# If sprites are available, compute distances
	var pctrl := _get_player_sprite_by_index(0)
	var ppos := (pctrl.get_global_rect().get_center() if pctrl else Vector2.ZERO)
	var best_idx: int = indices[0]
	var best_d2: float = INF
	var any_pos := false
	for i in indices:
		var spr := _get_enemy_sprite_by_index(i)
		if spr:
			any_pos = true
			var d2: float = spr.get_global_rect().get_center().distance_squared_to(ppos)
			if d2 < best_d2:
				best_d2 = d2
				best_idx = i
	if any_pos:
		return best_idx
	# Fallback to first alive if positions unavailable
	return indices[0]

func select_closest_target(my_team: String, my_index: int, enemy_team: String) -> int:
	# Returns enemy index or -1 by closest straight-line distance.
	# Prefer engine arena positions (authoritative), then arena actors, then static UnitView sprites.
	if manager == null:
		return -1
	var enemy_arr: Array[Unit] = manager.enemy_team if enemy_team == "enemy" else manager.player_team
	var alive_indices: Array[int] = []
	for i in range(enemy_arr.size()):
		var u: Unit = enemy_arr[i]
		if u and u.is_alive():
			alive_indices.append(i)
	if alive_indices.is_empty():
		return -1

	# 1) Engine positions (kept in sync with movement and range gating)
	var ppos: Array = manager.get_player_positions()
	var epos: Array = manager.get_enemy_positions()
	var src_pos: Vector2 = Vector2.ZERO
	var have_engine_positions := false
	if (my_team == "player" and my_index >= 0 and my_index < ppos.size() and typeof(ppos[my_index]) == TYPE_VECTOR2):
		src_pos = ppos[my_index]
		have_engine_positions = true
	elif (my_team != "player" and my_index >= 0 and my_index < epos.size() and typeof(epos[my_index]) == TYPE_VECTOR2):
		src_pos = epos[my_index]
		have_engine_positions = true
	if have_engine_positions:
		var best_idx := alive_indices[0]
		var best_d2: float = INF
		for idx in alive_indices:
			var tgt_pos: Vector2 = Vector2.ZERO
			if enemy_team == "enemy":
				if idx >= 0 and idx < epos.size() and typeof(epos[idx]) == TYPE_VECTOR2:
					tgt_pos = epos[idx]
			else:
				if idx >= 0 and idx < ppos.size() and typeof(ppos[idx]) == TYPE_VECTOR2:
					tgt_pos = ppos[idx]
			if tgt_pos != Vector2.ZERO:
				var d2 := tgt_pos.distance_squared_to(src_pos)
				if d2 < best_d2:
					best_d2 = d2
					best_idx = idx
		return best_idx

	# 2) Arena actors (visuals following engine state)
	var src_ctrl: Control = null
	if my_team == "player":
		var a: UnitActor = (arena.get_player_actor(my_index) if arena else null)
		src_ctrl = (a as Control) if a else _get_player_sprite_by_index(my_index)
	else:
		var ea: UnitActor = (arena.get_enemy_actor(my_index) if arena else null)
		src_ctrl = (ea as Control) if ea else _get_enemy_sprite_by_index(my_index)
	if not src_ctrl:
		return alive_indices[0]
	var src_center: Vector2 = (src_ctrl as Control).get_global_rect().get_center()
	var best_idx2: int = alive_indices[0]
	var best_d22: float = INF
	for idx2 in alive_indices:
		var tgt_ctrl: Control = null
		if enemy_team == "enemy":
			var ta: UnitActor = (arena.get_enemy_actor(idx2) if arena else null)
			tgt_ctrl = (ta as Control) if ta else _get_enemy_sprite_by_index(idx2)
		else:
			var pa: UnitActor = (arena.get_player_actor(idx2) if arena else null)
			tgt_ctrl = (pa as Control) if pa else _get_player_sprite_by_index(idx2)
		if not tgt_ctrl:
			continue
		var d22: float = tgt_ctrl.get_global_rect().get_center().distance_squared_to(src_center)
		if d22 < best_d22:
			best_d22 = d22
			best_idx2 = idx2
	return best_idx2

func _enter_combat_arena() -> void:
	if not arena_container:
		return
	Trace.step("CombatView._enter_combat_arena: calling enter_arena")
	arena.call("enter_arena", player_views, enemy_views)
	arena_container.visible = true
	if planning_area:
		_planning_area_prev_mouse_filter = planning_area.mouse_filter
		planning_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		planning_area.modulate.a = 0.0
	# Configure engine arena after engine is created inside CombatManager.start_stage
	Trace.step("CombatView._enter_combat_arena: defer configure engine arena")
	call_deferred("_configure_engine_arena")

func _place_actor(actor: UnitActor, global_pos: Vector2) -> void:
	# Deprecated in favor of ArenaController
	if actor and is_instance_valid(actor):
		actor.set_screen_position(global_pos)

func _sync_arena_units() -> void:
	if manager:
		var ppos: Array = manager.get_player_positions()
		var epos: Array = manager.get_enemy_positions()
		if ppos.size() > 0 or epos.size() > 0:
			arena.call("sync_arena_with_positions", player_views, enemy_views, ppos, epos)
			return
	arena.call("sync_arena", player_views, enemy_views)

func _exit_combat_arena() -> void:
	arena.call("exit_arena")
	if arena_container:
		arena_container.visible = false
	if planning_area:
		planning_area.modulate.a = 1.0
		planning_area.mouse_filter = _planning_area_prev_mouse_filter

func _clear_arena_units() -> void:
	# Deprecated in favor of ArenaController
	if arena_units:
		for child in arena_units.get_children():
			child.queue_free()

func _configure_engine_arena() -> void:
	if not manager:
		return
	Trace.step("CombatView._configure_engine_arena: begin")
	var tile_size := TILE_SIZE
	# Bounds from the arena background area (global coordinates)
	var bounds: Rect2 = Rect2()
	if is_instance_valid(arena_background):
		var r: Rect2 = arena_background.get_global_rect()
		bounds = Rect2(r.position, r.size)
	# Initial positions from current tile centers
	var ppos: Array[Vector2] = []
	var epos: Array[Vector2] = []
	for i in range(player_views.size()):
		var pv: UnitSlotView = player_views[i]
		var idx: int = pv.tile_idx
		var pos: Vector2 = player_grid_helper.get_center(idx) if player_grid_helper and idx >= 0 else Vector2.ZERO
		ppos.append(pos)
	for j in range(enemy_views.size()):
		var ev: UnitSlotView = enemy_views[j]
		var idx2: int = ev.tile_idx
		var pos2: Vector2 = enemy_grid_helper.get_center(idx2) if enemy_grid_helper and idx2 >= 0 else Vector2.ZERO
		epos.append(pos2)
	# If the background produced a degenerate bounds (e.g., height 0),
	# compute a fallback from the grid tile centers with a margin.
	if bounds.size.y <= 1.0 or bounds.size.x <= 1.0:
		var all_pts: Array[Vector2] = []
		for v in ppos:
			if typeof(v) == TYPE_VECTOR2:
				all_pts.append(v)
		for v2 in epos:
			if typeof(v2) == TYPE_VECTOR2:
				all_pts.append(v2)
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
			var margin: float = float(tile_size)
			var pos := Vector2(min_x - margin, min_y - margin)
			var size := Vector2(max(1.0, (max_x - min_x) + margin * 2.0), max(1.0, (max_y - min_y) + margin * 2.0))
			bounds = Rect2(pos, size)
			print("[ArenaFix] Fallback bounds from tiles -> ", bounds)
		else:
			# Last resort: use viewport size
			var vp := get_viewport()
			var vs := (vp.get_visible_rect() if vp else Rect2(Vector2.ZERO, Vector2(1920, 1080)))
			bounds = Rect2(vs.position, vs.size)
			print("[ArenaFix] Fallback bounds from viewport -> ", bounds)

	manager.set_arena(float(tile_size), ppos, epos, bounds)
	Trace.step("CombatView._configure_engine_arena: done")
	print("[Arena] tile=", tile_size, " bounds=", bounds)
	# After arena is configured, log starting positions and initial targets for all units
	_log_start_positions_and_targets()
	# Enable per-frame movement logs briefly to diagnose movement issues
	if manager and manager.has_method("enable_movement_debug"):
		manager.enable_movement_debug(60)

func _log_start_positions_and_targets() -> void:
	if not manager:
		return
	var ppos: Array = manager.get_player_positions()
	var epos: Array = manager.get_enemy_positions()
	# Player team
	for i in range(manager.player_team.size()):
		var u: Unit = manager.player_team[i]
		if not u or not u.is_alive():
			continue
		var my_pos: Vector2 = Vector2.ZERO
		if i >= 0 and i < ppos.size() and typeof(ppos[i]) == TYPE_VECTOR2:
			my_pos = ppos[i]
		var tgt_idx: int = select_closest_target("player", i, "enemy")
		var tgt_pos: Vector2 = Vector2.ZERO
		if tgt_idx >= 0 and tgt_idx < epos.size() and typeof(epos[tgt_idx]) == TYPE_VECTOR2:
			tgt_pos = epos[tgt_idx]
		print("[Start] player ", i, " pos=", my_pos, " -> target ", tgt_idx, " tpos=", tgt_pos)
	# Enemy team
	for j in range(manager.enemy_team.size()):
		var e: Unit = manager.enemy_team[j]
		if not e or not e.is_alive():
			continue
		var e_my_pos: Vector2 = Vector2.ZERO
		if j >= 0 and j < epos.size() and typeof(epos[j]) == TYPE_VECTOR2:
			e_my_pos = epos[j]
		var e_tgt_idx: int = select_closest_target("enemy", j, "player")
		var e_tgt_pos: Vector2 = Vector2.ZERO
		if e_tgt_idx >= 0 and e_tgt_idx < ppos.size() and typeof(ppos[e_tgt_idx]) == TYPE_VECTOR2:
			e_tgt_pos = ppos[e_tgt_idx]
		print("[Start] enemy  ", j, " pos=", e_my_pos, " -> target ", e_tgt_idx, " tpos=", e_tgt_pos)

func set_player_team_ids(ids: Array) -> void:
	if not manager:
		return
	manager.player_team.clear()
	var uf = load("res://scripts/unit_factory.gd")
	for id in ids:
		var u: Unit = uf.spawn(String(id))
		if u:
			manager.player_team.append(u)
