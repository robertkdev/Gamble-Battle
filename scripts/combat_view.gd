extends Control

@onready var log_label: RichTextLabel = $"MarginContainer/VBoxContainer/Log"
@onready var player_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/PlayerStatsLabel"
@onready var enemy_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/EnemyStatsLabel"
@onready var stage_label: Label = $"MarginContainer/VBoxContainer/StageLabel"
@onready var player_sprite: TextureRect = $"MarginContainer/VBoxContainer/BottomArea/PlayerUnitHolder/PlayerSprite"
@onready var enemy_sprite: TextureRect = $"MarginContainer/VBoxContainer/TopArea/EnemyUnitHolder/EnemySprite"
@onready var player_hp_bar: ProgressBar = $"MarginContainer/VBoxContainer/BottomArea/PlayerUnitHolder/PlayerHPBar"
@onready var enemy_hp_bar: ProgressBar = $"MarginContainer/VBoxContainer/TopArea/EnemyUnitHolder/EnemyHPBar"
@onready var player_grid: GridContainer = $"MarginContainer/VBoxContainer/BottomArea/PlayerGrid"
@onready var enemy_grid: GridContainer = $"MarginContainer/VBoxContainer/TopArea/EnemyGrid"
@onready var attack_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/AttackButton"
@onready var continue_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/ContinueButton"
@onready var powerup_panel: VBoxContainer = $"MarginContainer/VBoxContainer/PowerupPanel"
@onready var pbtn1: Button = $"MarginContainer/VBoxContainer/PowerupPanel/PowerupBtn1"
@onready var pbtn2: Button = $"MarginContainer/VBoxContainer/PowerupPanel/PowerupBtn2"
@onready var pbtn3: Button = $"MarginContainer/VBoxContainer/PowerupPanel/PowerupBtn3"
@onready var title_overlay: Panel = $"TitleOverlay"
@onready var name_input: LineEdit = $"TitleOverlay/TitleVBox/NameRow/NameInput"
@onready var start_button: Button = $"TitleOverlay/TitleVBox/StartButton"

var manager: CombatManager
var offered_powerups: Array[Powerup] = []
var player_name: String = "Hero"
var projectile_manager: ProjectileManager

# Auto-battle settings
var auto_combat: bool = true
var _auto_loop_running: bool = false
var turn_delay: float = 0.6

# Grid settings
const GRID_W := 8
const GRID_H := 3
const TILE_SIZE := 72
const GRID_TILE_GAP := 8
const GRID_BETWEEN_GAP := 24
var player_tiles: Array[Button] = []
var enemy_tiles: Array[Button] = []
var player_tile_idx: int = -1
var enemy_tile_idx: int = -1
var enemy2_tile_idx: int = -1
var ally_tile_idx: int = -1
var view_rng := RandomNumberGenerator.new()

# Extra UI created dynamically to support multi-enemy + mana
var enemy_sprite2: TextureRect
var enemy2_hp_bar: ProgressBar
var player_mana_bar: ProgressBar
var enemy_mana_bar: ProgressBar
var enemy2_mana_bar: ProgressBar
var enemy_views: Array = [] # each: { unit: Unit, sprite: TextureRect, hp_bar: ProgressBar, mana_bar: ProgressBar, tile_idx: int }
var player_views: Array = [] # each: { unit: Unit, sprite: TextureRect, hp_bar: ProgressBar, mana_bar: ProgressBar, tile_idx: int }
var ally_sprite: TextureRect
var ally_hp_bar: ProgressBar
var ally_mana_bar: ProgressBar

# Cached styleboxes for bars
var _pb_bg_style: StyleBox = null
var _pb_hp_fill: StyleBox = null
var _pb_mana_fill: StyleBox = null

func _ready() -> void:
	manager = load("res://scripts/combat_manager.gd").new()
	add_child(manager)

	# Connect signals
	manager.battle_started.connect(_on_battle_started)
	manager.log_line.connect(_on_log_line)
	manager.stats_updated.connect(_on_stats_updated)
	manager.victory.connect(_on_victory)
	manager.defeat.connect(_on_defeat)
	manager.powerup_choices.connect(_on_powerup_choices)
	manager.powerup_applied.connect(_on_powerup_applied)
	manager.prompt_continue.connect(_on_prompt_continue)
	manager.projectile_fired.connect(_on_projectile_fired)
	# Provide closest-target helper to the manager
	manager.select_closest_target = Callable(self, "select_closest_target")

	# Wire buttons
	attack_button.pressed.connect(_on_attack_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	start_button.pressed.connect(_on_start_pressed)
	pbtn1.pressed.connect(func(): _on_powerup_pressed_idx(0))
	pbtn2.pressed.connect(func(): _on_powerup_pressed_idx(1))
	pbtn3.pressed.connect(func(): _on_powerup_pressed_idx(2))

	# Fade-in and show title overlay
	self.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

	# Build grids and prepare sprites
	view_rng.randomize()
	_build_grids()
	_prepare_sprites()
	_prepare_projectiles()
	# Set default player position (center row, column 1)
	var default_idx := int(floor(float(GRID_H) / 2.0)) * GRID_W + 1
	_set_player_tile(default_idx)

	# Attack button is hidden for autobattler gameplay
	attack_button.visible = false
	attack_button.disabled = true

	_show_title()

	# Prefer HUD over verbose text to keep buttons visible
	log_label.visible = false
	player_stats_label.visible = false
	enemy_stats_label.visible = false

func _init_game() -> void:
	clear_log()
	disable_powerup_panel()
	continue_button.disabled = false
	continue_button.visible = true
	continue_button.text = "Start Battle"
	attack_button.disabled = true
	manager.stage = 1
	manager.new_player(player_name)
	# Set player sprite from Unit sprite path
	if manager.player and is_instance_valid(player_sprite):
		_set_sprite_texture(player_sprite, manager.player.sprite_path, Color(0.2, 0.6, 1.0, 1.0))
	# Apply bar styles
	_apply_bar_style(player_hp_bar, false)
	_on_log_line("Gamble Battle")
	_on_log_line("Player: " + player_name)
	_on_log_line(manager.player.summary())
	# Build teams for preview so both player and ally are visible before battle
	manager.setup_stage_preview()
	# Deterministic enemy preview placement
	if enemy_tiles.size() == GRID_W * GRID_H:
		enemy_tile_idx = 0
		_set_enemy_tile(enemy_tile_idx)
		if manager.enemy_team.size() > 1:
			enemy2_tile_idx = 1
			_set_enemy2_tile(enemy2_tile_idx)
	_rebuild_enemy_views()
	_rebuild_player_views()
	# Player ally will be provided by manager.start_stage via player_team; views built on battle_started

func _on_attack_pressed() -> void:
	# No manual attacks in realtime autobattler
	pass

func _on_continue_pressed() -> void:
	if continue_button.text == "Start Battle":
		continue_button.disabled = true
		disable_powerup_panel()
		manager.start_stage()
		return
	if continue_button.text == "Restart":
		_init_game()
		return
	# Post-victory continue to next stage
	continue_button.disabled = true
	attack_button.disabled = false
	disable_powerup_panel()
	manager.continue_to_next_stage()

func _on_battle_started(stage: int, enemy: Unit) -> void:
	_on_log_line("Prepare to fight.")
	_refresh_hud()
	stage_label.text = "Stage " + str(stage)
	# Deterministic enemy placement: fill tiles linearly
	if enemy_tiles.size() == GRID_W * GRID_H:
		enemy_tile_idx = 0
		_set_enemy_tile(enemy_tile_idx)
		if manager.enemy_team.size() > 1:
			enemy2_tile_idx = 1
			_set_enemy2_tile(enemy2_tile_idx)
	# Set enemy sprites from templates
	if manager.enemy_team.size() >= 1 and is_instance_valid(enemy_sprite):
		_set_sprite_texture(enemy_sprite, manager.enemy_team[0].sprite_path, Color(1.0, 0.25, 0.25, 1.0))
	if manager.enemy_team.size() >= 2:
		if not enemy_sprite2:
			enemy_sprite2 = TextureRect.new()
			enemy_sprite2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			enemy_sprite2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			enemy_sprite2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_sprite_texture(enemy_sprite2, manager.enemy_team[1].sprite_path, Color(1.0, 0.25, 0.25, 1.0))
		if enemy2_tile_idx >= 0:
			_attach_unit_to_tile(enemy_sprite2, null, enemy_tiles[enemy2_tile_idx])
	# Build/attach views for both teams
	_rebuild_enemy_views()
	_rebuild_player_views()
	# Realtime combat handled by CombatManager; no manual loop needed.

func _on_log_line(text: String) -> void:
	print(text)
	log_label.append_text(text + "\n")
	log_label.scroll_to_line(log_label.get_line_count() - 1)
	_log_to_file(text)

func _log_to_file(text: String) -> void:
	var path := "user://gameplay.log"
	var fa := FileAccess.open(path, FileAccess.READ_WRITE)
	if fa:
		fa.seek_end()
		fa.store_line(text)
		fa.close()


func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
	_refresh_hud()

func _refresh_hud() -> void:
	# Update health bars instead of verbose labels
	if manager and manager.player and is_instance_valid(player_hp_bar):
		player_hp_bar.max_value = max(1, manager.player.max_hp)
		player_hp_bar.value = clamp(manager.player.hp, 0, manager.player.max_hp)
		# Player mana
		if not player_mana_bar:
			_ensure_player_mana_bar()
		if player_mana_bar:
			player_mana_bar.max_value = max(0, manager.player.mana_max)
			player_mana_bar.value = clamp(manager.player.mana, 0, manager.player.mana_max)
	# Generic enemy bars
	if not enemy_views.is_empty():
		for v in enemy_views:
			var u: Unit = v["unit"]
			var hp: ProgressBar = v["hp_bar"]
			var mb: ProgressBar = v["mana_bar"]
			if hp:
				hp.max_value = max(1, u.max_hp)
				hp.value = clamp(u.hp, 0, u.max_hp)
			if mb:
				mb.max_value = max(0, u.mana_max)
				mb.value = clamp(u.mana, 0, u.mana_max)

	# Player team bars
	if not player_views.is_empty():
		for pv in player_views:
			var pu: Unit = pv["unit"]
			var php: ProgressBar = pv["hp_bar"]
			var pmb: ProgressBar = pv["mana_bar"]
			if php:
				php.max_value = max(1, pu.max_hp)
				php.value = clamp(pu.hp, 0, pu.max_hp)
			if pmb:
				pmb.max_value = max(0, pu.mana_max)
				pmb.value = clamp(pu.mana, 0, pu.mana_max)

func _refresh_stats() -> void:
	player_stats_label.text = "Player: " + manager.player.summary()
	if manager.enemy:
		enemy_stats_label.text = "Enemy:  " + manager.enemy.summary()
	else:
		enemy_stats_label.text = "Enemy:  —"

func _on_victory(_stage: int) -> void:
	attack_button.disabled = true
	_auto_loop_running = false
	if projectile_manager:
		projectile_manager.clear()
	# Offer continue to next stage after powerups get applied
	continue_button.text = "Continue"
	continue_button.disabled = false
	continue_button.visible = true

func _on_defeat(_stage: int) -> void:
	attack_button.disabled = true
	disable_powerup_panel()
	_on_log_line("Game Over. Press Restart to try again.")
	continue_button.text = "Restart"
	continue_button.disabled = false
	continue_button.visible = true
	continue_button.grab_focus()

	_auto_loop_running = false
	if projectile_manager:
		projectile_manager.clear()

func _on_powerup_choices(options: Array[Powerup]) -> void:
	offered_powerups = options.duplicate()
	powerup_panel.visible = true
	pbtn1.text = options[0].name
	pbtn2.text = options[1].name
	pbtn3.text = options[2].name
	pbtn1.tooltip_text = options[0].description
	pbtn2.tooltip_text = options[1].description
	pbtn3.tooltip_text = options[2].description
	pbtn1.disabled = false
	pbtn2.disabled = false
	pbtn3.disabled = false

func _on_powerup_pressed_idx(i: int) -> void:
	if i < 0 or i >= offered_powerups.size():
		return
	# prevent multiple clicks
	pbtn1.disabled = true
	pbtn2.disabled = true
	pbtn3.disabled = true
	manager.apply_powerup(offered_powerups[i])

func _on_powerup_applied(_name: String) -> void:
	disable_powerup_panel()

func _on_prompt_continue() -> void:
	continue_button.text = "Continue"
	continue_button.disabled = false
	continue_button.visible = true
	continue_button.grab_focus()

func clear_log() -> void:
	log_label.clear()

func disable_powerup_panel() -> void:
	powerup_panel.visible = false

func _show_title() -> void:
	title_overlay.visible = true
	attack_button.disabled = true
	continue_button.visible = false
	powerup_panel.visible = false
	name_input.text = ""
	name_input.grab_focus()

func _on_start_pressed() -> void:
	player_name = name_input.text.strip_edges()
	if player_name == "":
		player_name = "Hero"
	title_overlay.hide()
	_init_game()

# --- Auto-battle helpers ---

func _start_auto_loop() -> void:
	if not auto_combat:
		return
	if _auto_loop_running:
		return
	_auto_loop_running = true
	call_deferred("_auto_loop")

func _auto_loop() -> void:
	# Run until someone falls or we enter a selection state
	while _auto_loop_running and auto_combat:
		if not manager or not manager.player or not manager.enemy:
			break
		if not manager.player.is_alive() or not manager.enemy.is_alive():
			break
		if powerup_panel.visible:
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
	if player_sprite and not player_sprite.is_connected("gui_input", Callable(self, "_on_player_sprite_gui_input")):
		player_sprite.gui_input.connect(_on_player_sprite_gui_input)
	# Ensure ally sprite (when present) also connects for drag
	if ally_sprite and not ally_sprite.is_connected("gui_input", Callable(self, "_on_ally_sprite_gui_input")):
		ally_sprite.gui_input.connect(_on_ally_sprite_gui_input)

func _prepare_projectiles() -> void:
	projectile_manager = load("res://scripts/projectile_manager.gd").new()
	add_child(projectile_manager)
	projectile_manager.configure(player_sprite, enemy_sprite)

func _on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not projectile_manager:
		return
	var start_pos: Vector2
	var end_pos: Vector2
	var tgt_control: Control = null
	var color: Color
	if source_team == "player":
		# Source is on player team
		var psrc := _get_player_sprite_by_index(source_index)
		start_pos = psrc.get_global_rect().get_center() if psrc else player_sprite.get_global_rect().get_center()
		var spr: TextureRect = _get_enemy_sprite_by_index(target_index)
		if spr:
			tgt_control = spr
			end_pos = spr.get_global_rect().get_center()
		else:
			end_pos = enemy_sprite.get_global_rect().get_center()
		color = Color(0.2, 0.8, 1.0)
	else:
		# Source is on enemy team
		var esrc := _get_enemy_sprite_by_index(source_index)
		start_pos = esrc.get_global_rect().get_center() if esrc else enemy_sprite.get_global_rect().get_center()
		tgt_control = _get_player_sprite_by_index(target_index)
		end_pos = (tgt_control as TextureRect).get_global_rect().get_center() if tgt_control else player_sprite.get_global_rect().get_center()
		color = Color(1.0, 0.4, 0.2)
	var speed := 800.0
	var radius := 6.0
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
		(_get_player_sprite_by_index(source_index) if source_team == "player" else _get_enemy_sprite_by_index(source_index))
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

# Drag state
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _on_player_sprite_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			# Ensure fixed size while dragging to avoid stretching
			player_sprite.anchor_left = 0.0
			player_sprite.anchor_top = 0.0
			player_sprite.anchor_right = 0.0
			player_sprite.anchor_bottom = 0.0
			player_sprite.offset_left = 0.0
			player_sprite.offset_top = 0.0
			player_sprite.offset_right = 0.0
			player_sprite.offset_bottom = 0.0
			player_sprite.size = Vector2(TILE_SIZE, TILE_SIZE)
			# Temporarily make sprite a direct child of root to move freely
			var parent := player_sprite.get_parent()
			if parent:
				parent.remove_child(player_sprite)
			get_tree().root.add_child(player_sprite)
			player_sprite.z_index = 1000
			# keep the cursor near the center of the sprite
			_drag_offset = -player_sprite.size * 0.5
		else:
			# release: snap to nearest valid player tile
			_dragging = false
			player_sprite.z_index = 0
			_snap_player_to_mouse_tile()
	elif event is InputEventMouseMotion and _dragging:
		player_sprite.global_position = get_viewport().get_mouse_position() + _drag_offset

func _input(event: InputEvent) -> void:
	# Fallback to stop dragging even if sprite misses the release event
	if _dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		player_sprite.z_index = 0
		_snap_player_to_mouse_tile()
	if _ally_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_ally_dragging = false
		if ally_sprite:
			ally_sprite.z_index = 0
			_snap_ally_to_mouse_tile()

func _process(_delta: float) -> void:
	if _dragging:
		player_sprite.global_position = get_viewport().get_mouse_position() + _drag_offset
	if _ally_dragging and ally_sprite:
		ally_sprite.global_position = get_viewport().get_mouse_position() + _ally_drag_offset

# --- Ally drag ---
var _ally_dragging: bool = false
var _ally_drag_offset: Vector2 = Vector2.ZERO

func _on_ally_sprite_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ally_dragging = true
			ally_sprite.anchor_left = 0.0
			ally_sprite.anchor_top = 0.0
			ally_sprite.anchor_right = 0.0
			ally_sprite.anchor_bottom = 0.0
			ally_sprite.offset_left = 0.0
			ally_sprite.offset_top = 0.0
			ally_sprite.offset_right = 0.0
			ally_sprite.offset_bottom = 0.0
			ally_sprite.size = Vector2(TILE_SIZE, TILE_SIZE)
			var parent := ally_sprite.get_parent()
			if parent:
				parent.remove_child(ally_sprite)
			get_tree().root.add_child(ally_sprite)
			ally_sprite.z_index = 1000
			_ally_drag_offset = -ally_sprite.size * 0.5
		else:
			_ally_dragging = false
			ally_sprite.z_index = 0
			_snap_ally_to_mouse_tile()
	elif event is InputEventMouseMotion and _ally_dragging:
		ally_sprite.global_position = get_viewport().get_mouse_position() + _ally_drag_offset

func _snap_ally_to_mouse_tile() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var picked_idx := _player_tile_index_from_global(mouse_pos)
	if picked_idx != -1:
		ally_tile_idx = picked_idx
		_attach_unit_to_tile(ally_sprite, ally_hp_bar, player_tiles[picked_idx])
		if ally_mana_bar:
			_attach_mana_bar_to_tile(ally_mana_bar, player_tiles[picked_idx])

func _snap_player_to_mouse_tile() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	# Find tile under mouse in player_grid
	var picked_idx := _player_tile_index_from_global(mouse_pos)
	if picked_idx != -1:
		_set_player_tile(picked_idx)
		return
	# If not over any tile, reattach to current tile
	if player_tile_idx != -1:
		_attach_unit_to_tile(player_sprite, player_hp_bar, player_tiles[player_tile_idx])

func _player_tile_index_from_global(gpos: Vector2) -> int:
	# Iterate children and hit-test
	for i in range(player_tiles.size()):
		var tile := player_tiles[i]
		if not is_instance_valid(tile):
			continue
		if tile.get_global_rect().has_point(gpos):
			return i
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
			var d2 := dx * dx + dy * dy
			if d2 <= r2:
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	return tex

# --- Grid helpers ---

func _build_grids() -> void:
	# Clear existing children if any
	for c in player_grid.get_children():
		c.queue_free()
	for c in enemy_grid.get_children():
		c.queue_free()
	player_tiles.clear()
	enemy_tiles.clear()
	player_grid.columns = GRID_W
	enemy_grid.columns = GRID_W
	# Intra-grid spacing
	player_grid.add_theme_constant_override("h_separation", GRID_TILE_GAP)
	player_grid.add_theme_constant_override("v_separation", GRID_TILE_GAP)
	enemy_grid.add_theme_constant_override("h_separation", GRID_TILE_GAP)
	enemy_grid.add_theme_constant_override("v_separation", GRID_TILE_GAP)
	# Inter-grid spacing (vertical gap between the two grids)
	var root_vbox := $"MarginContainer/VBoxContainer"
	if root_vbox:
		root_vbox.add_theme_constant_override("separation", GRID_BETWEEN_GAP)
	for i in range(GRID_W * GRID_H):
		# Player tile (non-clickable; drag-and-drop only)
		var pb := Button.new()
		pb.text = ""
		pb.toggle_mode = false
		pb.focus_mode = Control.FOCUS_NONE
		pb.disabled = true
		pb.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		player_grid.add_child(pb)
		player_tiles.append(pb)
		# Enemy tile (not clickable)
		var eb := Button.new()
		eb.text = ""
		eb.disabled = true
		eb.focus_mode = Control.FOCUS_NONE
		eb.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		enemy_grid.add_child(eb)
		enemy_tiles.append(eb)

# Click-to-place disabled entirely; placement is drag-only
func _on_player_tile_pressed(idx: int) -> void:
	pass

func _set_player_tile(idx: int) -> void:
	if idx < 0 or idx >= player_tiles.size():
		return
	player_tile_idx = idx
	for i in range(player_tiles.size()):
		player_tiles[i].button_pressed = (i == idx)
	_attach_unit_to_tile(player_sprite, player_hp_bar, player_tiles[idx])
	_ensure_player_mana_bar()
	_attach_mana_bar_to_tile(player_mana_bar, player_tiles[idx])

func _set_enemy_tile(idx: int) -> void:
	if idx < 0 or idx >= enemy_tiles.size():
		return
	enemy_tile_idx = idx
	_attach_unit_to_tile(enemy_sprite, enemy_hp_bar, enemy_tiles[idx])
	# Attach or create enemy1 mana bar
	if not enemy_mana_bar:
		enemy_mana_bar = _make_mana_bar()
	_attach_mana_bar_to_tile(enemy_mana_bar, enemy_tiles[idx])

func _set_enemy2_tile(idx: int) -> void:
	if idx < 0 or idx >= enemy_tiles.size():
		return
	enemy2_tile_idx = idx
	if not enemy_sprite2:
		enemy_sprite2 = TextureRect.new()
		enemy_sprite2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_sprite2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		enemy_sprite2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not enemy2_hp_bar:
		enemy2_hp_bar = ProgressBar.new()
		enemy2_hp_bar.show_percentage = false
	_attach_unit_to_tile(enemy_sprite2, enemy2_hp_bar, enemy_tiles[idx])
	if not enemy2_mana_bar:
		enemy2_mana_bar = _make_mana_bar()
	_attach_mana_bar_to_tile(enemy2_mana_bar, enemy_tiles[idx])

func _attach_unit_to_tile(sprite: TextureRect, hp_bar: ProgressBar, tile: Control) -> void:
	if not sprite or not tile:
		return
	var parent := sprite.get_parent()
	if parent:
		parent.remove_child(sprite)
	tile.add_child(sprite)
	# Fill tile and keep aspect centered
	sprite.anchor_left = 0.0
	sprite.anchor_top = 0.0
	sprite.anchor_right = 1.0
	sprite.anchor_bottom = 1.0
	sprite.offset_left = 0.0
	sprite.offset_top = 0.0
	sprite.offset_right = 0.0
	sprite.offset_bottom = 0.0
	# Attach HP bar to same tile, top-aligned, 8px height
	if hp_bar:
		var bpar := hp_bar.get_parent()
		if bpar:
			bpar.remove_child(hp_bar)
		tile.add_child(hp_bar)
		hp_bar.anchor_left = 0.0
		hp_bar.anchor_top = 0.0
		hp_bar.anchor_right = 1.0
		hp_bar.anchor_bottom = 0.0
		hp_bar.offset_left = 0.0
		hp_bar.offset_top = 0.0
		hp_bar.offset_right = 0.0
		hp_bar.offset_bottom = 8.0

func _attach_mana_bar_to_tile(mana_bar: ProgressBar, tile: Control) -> void:
	if not mana_bar or not tile:
		return
	var bpar := mana_bar.get_parent()
	if bpar:
		bpar.remove_child(mana_bar)
	tile.add_child(mana_bar)
	mana_bar.anchor_left = 0.0
	mana_bar.anchor_top = 0.0
	mana_bar.anchor_right = 1.0
	mana_bar.anchor_bottom = 0.0
	mana_bar.offset_left = 0.0
	mana_bar.offset_top = 10.0
	mana_bar.offset_right = 0.0
	mana_bar.offset_bottom = 18.0

func _make_mana_bar() -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = 0
	pb.value = 0
	pb.custom_minimum_size = Vector2(0, 6)
	pb.show_percentage = false
	_apply_bar_style(pb, true)
	return pb

func _apply_bar_style(pb: ProgressBar, is_mana: bool) -> void:
	if pb == null:
		return
	if _pb_bg_style == null:
		_pb_bg_style = load("res://themes/pb_bg.tres")
	if _pb_hp_fill == null:
		_pb_hp_fill = load("res://themes/pb_hp_fill.tres")
	if _pb_mana_fill == null:
		_pb_mana_fill = load("res://themes/pb_mana_fill.tres")
	pb.add_theme_stylebox_override("background", _pb_bg_style)
	pb.add_theme_stylebox_override("fill", (_pb_mana_fill if is_mana else _pb_hp_fill))

func _ensure_player_mana_bar() -> void:
	if not player_mana_bar:
		player_mana_bar = _make_mana_bar()
		if player_tile_idx >= 0:
			_attach_mana_bar_to_tile(player_mana_bar, player_tiles[player_tile_idx])

func _get_enemy_sprite_by_index(i: int) -> TextureRect:
	if i >= 0 and i < enemy_views.size():
		var v = enemy_views[i]
		if v.has("sprite"):
			return v["sprite"]
	if i == 0:
		return enemy_sprite
	if i == 1:
		return enemy_sprite2
	return null

func _get_player_sprite_by_index(i: int) -> TextureRect:
	if i >= 0 and i < player_views.size():
		var v = player_views[i]
		if v.has("sprite"):
			return v["sprite"]
	if i == 0:
		return player_sprite
	if i == 1:
		return ally_sprite
	return null

func _rebuild_enemy_views() -> void:
	enemy_views.clear()
	# Prepare view for each enemy using shared builder
	for i in range(min(manager.enemy_team.size(), enemy_tiles.size())):
		var tile_idx: int = (enemy_tile_idx if i == 0 else (enemy2_tile_idx if i == 1 else -1))
		if tile_idx < 0:
			continue
		var u: Unit = manager.enemy_team[i]
		var spr: TextureRect = (enemy_sprite if i == 0 else enemy_sprite2)
		if i > 1 and spr == null:
			spr = TextureRect.new()
			spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hp: ProgressBar = (enemy_hp_bar if i == 0 else enemy2_hp_bar)
		if hp == null:
			hp = ProgressBar.new()
			hp.show_percentage = false
			_apply_bar_style(hp, false)
		var mb: ProgressBar = (enemy_mana_bar if i == 0 else enemy2_mana_bar)
		if mb == null:
			mb = _make_mana_bar()
			if i == 0:
				enemy_mana_bar = mb
			elif i == 1:
				enemy2_mana_bar = mb
		# Apply styles for bars that already existed from scene as well
		_apply_bar_style(hp, false)
		_apply_bar_style(mb, true)
		_attach_unit_to_tile(spr, hp, enemy_tiles[tile_idx])
		_attach_mana_bar_to_tile(mb, enemy_tiles[tile_idx])
		_set_sprite_texture(spr, u.sprite_path, Color(1.0, 0.25, 0.25, 1.0))
		enemy_views.append({
			"unit": u,
			"sprite": spr,
			"hp_bar": hp,
			"mana_bar": mb,
			"tile_idx": tile_idx,
		})

func _rebuild_player_views() -> void:
	player_views.clear()
	# Player 0 is the main player sprite placed at player_tile_idx
	if manager.player_team.size() == 0:
		return
	var p0: Unit = manager.player_team[0]
	var p0_hp := player_hp_bar
	_ensure_player_mana_bar()
	var p0_mb := player_mana_bar
	# Ensure styles on player bars
	_apply_bar_style(p0_hp, false)
	_apply_bar_style(p0_mb, true)
	if player_tile_idx >= 0:
		_attach_unit_to_tile(player_sprite, p0_hp, player_tiles[player_tile_idx])
		_attach_mana_bar_to_tile(p0_mb, player_tiles[player_tile_idx])
	_set_sprite_texture(player_sprite, p0.sprite_path, Color(0.2, 0.6, 1.0, 1.0))
	player_views.append({
		"unit": p0,
		"sprite": player_sprite,
		"hp_bar": p0_hp,
		"mana_bar": p0_mb,
		"tile_idx": player_tile_idx,
	})
	# Player 1 (ally) if present
	if manager.player_team.size() > 1:
		var p1: Unit = manager.player_team[1]
		if not ally_sprite:
			ally_sprite = TextureRect.new()
			ally_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ally_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ally_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
		if not ally_hp_bar:
			ally_hp_bar = ProgressBar.new()
			ally_hp_bar.show_percentage = false
			_apply_bar_style(ally_hp_bar, false)
		if not ally_mana_bar:
			ally_mana_bar = _make_mana_bar()
		# Use persisted ally_tile_idx if set; otherwise choose initial near player
		if ally_tile_idx < 0:
			ally_tile_idx = clamp(player_tile_idx + 1, 0, player_tiles.size() - 1)
			if ally_tile_idx == player_tile_idx:
				ally_tile_idx = (player_tile_idx + 2) % player_tiles.size()
		_attach_unit_to_tile(ally_sprite, ally_hp_bar, player_tiles[ally_tile_idx])
		_attach_mana_bar_to_tile(ally_mana_bar, player_tiles[ally_tile_idx])
		_set_sprite_texture(ally_sprite, p1.sprite_path, Color(0.6, 1.0, 0.6))
		# Connect ally drag handler
		if not ally_sprite.is_connected("gui_input", Callable(self, "_on_ally_sprite_gui_input")):
			ally_sprite.gui_input.connect(_on_ally_sprite_gui_input)
		player_views.append({
			"unit": p1,
			"sprite": ally_sprite,
			"hp_bar": ally_hp_bar,
			"mana_bar": ally_mana_bar,
			"tile_idx": ally_tile_idx,
		})

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
	var ppos := player_sprite.get_global_rect().get_center()
	var best_idx: int = indices[0]
	var best_d2 := INF
	var any_pos := false
	for i in indices:
		var spr := _get_enemy_sprite_by_index(i)
		if spr:
			any_pos = true
			var d2 := spr.get_global_rect().get_center().distance_squared_to(ppos)
			if d2 < best_d2:
				best_d2 = d2
				best_idx = i
	if any_pos:
		return best_idx
	# Fallback to first alive if positions unavailable
	return indices[0]

func select_closest_target(my_team: String, my_index: int, enemy_team: String) -> int:
	# Returns enemy index or -1 by closest straight-line distance between sprite centers.
	# Teams: "player" or "enemy".
	var enemy_count := manager.enemy_team.size() if enemy_team == "enemy" else manager.player_team.size()
	var alive_indices: Array[int] = []
	for i in range(enemy_count):
		var u: Unit = (manager.enemy_team[i] if enemy_team == "enemy" else manager.player_team[i])
		if u and u.is_alive():
			alive_indices.append(i)
	if alive_indices.is_empty():
		return -1
	# Get source center
	var src_rect: TextureRect = (_get_player_sprite_by_index(my_index) if my_team == "player" else _get_enemy_sprite_by_index(my_index))
	if not src_rect:
		return alive_indices[0]
	var src_pos := src_rect.get_global_rect().get_center()
	var best_idx := alive_indices[0]
	var best_d2 := INF
	for idx in alive_indices:
		var spr: TextureRect = (_get_enemy_sprite_by_index(idx) if enemy_team == "enemy" else _get_player_sprite_by_index(idx))
		if not spr:
			continue
		var d2 := spr.get_global_rect().get_center().distance_squared_to(src_pos)
		if d2 < best_d2:
			best_d2 = d2
			best_idx = idx
	return best_idx
