extends Control

const CombatController := preload("res://scripts/ui/combat/controller/combat_controller.gd")

@onready var log_label: RichTextLabel = get_node_or_null("MarginContainer/VBoxContainer/Log") as RichTextLabel
@onready var player_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/PlayerStatsLabel"
@onready var enemy_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/EnemyStatsLabel"
@onready var stage_label: Label = $"MarginContainer/VBoxContainer/StageLabel"
@onready var player_sprite: TextureRect = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerUnitHolder/PlayerSprite"
@onready var enemy_sprite: TextureRect = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyUnitHolder/EnemySprite"
@onready var player_grid: GridContainer = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid"
@onready var bench_grid: GridContainer = $"MarginContainer/VBoxContainer/BenchArea/BenchGrid"
@onready var shop_grid: GridContainer = $"MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid"
@onready var arena_container: Control = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer"
@onready var arena_background: ColorRect = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground"
@onready var arena_units: Control = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits"
@onready var planning_area: Control = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea"
@onready var enemy_grid: GridContainer = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid"
@onready var stats_panel: Control = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel"
@onready var attack_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/AttackButton"
@onready var continue_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/ContinueButton"
@onready var menu_button: Button = $"TopBar/MenuButton"
@onready var gold_label: Label = $"MarginContainer/VBoxContainer/ActionsRow/GoldLabel"
@onready var bet_slider: HSlider = $"MarginContainer/VBoxContainer/ActionsRow/BetRow/BetSlider"
@onready var bet_value: Label = $"MarginContainer/VBoxContainer/ActionsRow/BetRow/BetValue"
## Title screen removed

var manager: CombatManager
var controller: CombatController

var player_name: String = "Hero"

## Intermission orchestration handled by controller

func set_combat_manager(m: CombatManager) -> void:
	manager = m
	if controller:
		controller.configure(self, manager, _collect_nodes())
		controller.initialize()


func _update_grid_metrics() -> void:
	pass

func _ready() -> void:
	if manager == null:
		manager = load("res://scripts/combat_manager.gd").new()
		add_child(manager)
	controller = CombatController.new()
	controller.configure(self, manager, _collect_nodes())
	controller.initialize()
	call_deferred("_log_initial_layout", "CombatView snapshot (ready)")
	set_process(true)

func _init_game() -> void:
	controller._init_game()

func _on_attack_pressed() -> void:
	# No manual attacks in realtime autobattler
	pass

func _on_menu_pressed() -> void:
	controller._on_menu_pressed()

func _on_continue_pressed() -> void:
	controller._on_continue_pressed()

func _auto_start_battle() -> void:
	controller._auto_start_battle()

func _refresh_economy_ui() -> void:
	controller.economy_ui.refresh()

func _on_bet_changed(val: float) -> void:
	controller._on_bet_changed(val)

func _on_battle_started(stage: int, enemy: Unit) -> void:
	controller._on_battle_started(stage, enemy)

func _on_log_line(text: String) -> void:
	controller._on_log_line(text)

func _log_to_file(text: String) -> void:
	controller._log_to_file(text)


func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
	controller._refresh_hud()

func _refresh_hud() -> void:
	controller._refresh_hud()

func _refresh_stats() -> void:
	controller._refresh_stats()

func _on_victory(_stage: int) -> void:
	controller._on_victory(_stage)

func _on_defeat(_stage: int) -> void:
	controller._on_defeat(_stage)

func clear_log() -> void:
	controller.clear_log()

## Title overlay removed; start via Main

# --- Auto-battle helpers ---

func _start_auto_loop() -> void:
	controller._start_auto_loop()

func _auto_loop() -> void:
	controller._auto_loop()

# --- Simple procedural sprites ---

func _prepare_sprites() -> void:
	controller._prepare_sprites()

	# Connect drag handling once
	# Drag handled by UnitView; no direct sprite dragging

func _prepare_projectiles() -> void:
	controller.projectile_bridge.configure(self, controller.arena_bridge, controller.player_grid_helper, controller.enemy_grid_helper, manager, controller.view_rng)

func set_projectile_manager(pm: ProjectileManager) -> void:
	controller.set_projectile_manager(pm)

func _on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	controller._on_projectile_fired(source_team, source_index, target_index, damage, crit)

func _set_sprite_texture(rect: TextureRect, path: String, fallback_color: Color) -> void:
	controller._set_sprite_texture(rect, path, fallback_color)

## Direct sprite drag removed; UnitView handles drag-and-drop

func _process(_delta: float) -> void:
	controller.process(_delta)

## Ally sprite direct drag removed



## moved to TextureUtils.make_circle_texture

## Grid helpers moved to GridPlacement

func _get_enemy_sprite_by_index(i: int) -> Control:
	return controller._get_enemy_sprite_by_index(i)

func _get_player_sprite_by_index(i: int) -> Control:
	return controller._get_player_sprite_by_index(i)

## Rebuild methods moved to GridPlacement

func _on_team_stats_updated(_pteam, _eteam) -> void:
	controller._on_team_stats_updated(_pteam, _eteam)

func _on_unit_stat_changed(team: String, index: int, fields: Dictionary) -> void:
	controller._on_unit_stat_changed(team, index, fields)

func _on_vfx_knockup(team: String, index: int, duration: float) -> void:
	controller._on_vfx_knockup(team, index, duration)

## Allies provided by manager.player_team; legacy helpers removed

## Target selection owned by engine; no view override

func _enter_combat_arena() -> void:
	controller._enter_combat_arena()

func _sync_arena_units() -> void:
	controller._sync_arena_units()

func _exit_combat_arena() -> void:
	controller._exit_combat_arena()

func _cv_configure_engine_arena() -> void:
	controller._configure_engine_arena()

func _log_start_positions_and_targets() -> void:
	controller._log_start_positions_and_targets()

func set_player_team_ids(ids: Array) -> void:
	controller.set_player_team_ids(ids)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		call_deferred("_log_initial_layout", "CombatView snapshot (visible)")


func _log_initial_layout(tag: String = "CombatView snapshot") -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("[Layout] ===== %s =====" % tag)
	_print_control_rect("CombatView", self)
	_print_control_rect("MarginContainer", "MarginContainer")
	_print_control_rect("VBoxContainer", "MarginContainer/VBoxContainer")
	_print_control_rect("BattleArea", "MarginContainer/VBoxContainer/BattleArea")
	_print_control_rect("ContentRow", "MarginContainer/VBoxContainer/BattleArea/ContentRow")
	_print_control_rect("LeftItemArea", "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
	_print_control_rect("ItemStorageGrid", "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")
	_print_control_rect("BoardColumn", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn")
	_print_control_rect("PlanningArea", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea")
	_print_control_rect("EnemyGrid", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid")
	_print_control_rect("PlayerGrid", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid")
	_print_control_rect("ArenaContainer", "MarginContainer/VBoxContainer/BattleArea/ArenaContainer")
	_print_control_rect("ArenaUnits", "MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits")
	_print_control_rect("BenchArea", "MarginContainer/VBoxContainer/BenchArea")
	_print_control_rect("BenchGrid", "MarginContainer/VBoxContainer/BenchArea/BenchGrid")
	_print_control_rect("ActionsRow", "MarginContainer/VBoxContainer/ActionsRow")
	_print_control_rect("BottomStorageArea", "MarginContainer/VBoxContainer/BottomStorageArea")
	_print_control_rect("ShopGrid", "MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid")
	_print_control_rect("TopBar", "TopBar")
	_print_control_rect("MenuButton", "TopBar/MenuButton")
	print("[Layout] =================================")

func _print_control_rect(label: String, target) -> void:
	var control: Control = null
	if target is Control:
		control = target
	elif target is NodePath:
		control = get_node_or_null(target) as Control
	elif target is String or target is StringName:
		control = get_node_or_null(NodePath(String(target))) as Control
	if control == null:
		print("[Layout] %s: <missing>" % label)
		return
	var rect := control.get_global_rect()
	print("[Layout] %s origin=%s size=%s" % [label, rect.position, rect.size])



func _collect_nodes() -> Dictionary:
	return {
		"log_label": log_label,
		"player_stats_label": player_stats_label,
		"enemy_stats_label": enemy_stats_label,
		"stage_label": stage_label,
		"player_sprite": player_sprite,
		"enemy_sprite": enemy_sprite,
		"player_grid": player_grid,
		"bench_grid": bench_grid,
		"shop_grid": shop_grid,
		"enemy_grid": enemy_grid,
		"arena_container": arena_container,
		"arena_background": arena_background,
		"arena_units": arena_units,
		"planning_area": planning_area,
		"stats_panel": stats_panel,
		"attack_button": attack_button,
		"continue_button": continue_button,
		"menu_button": menu_button,
		"gold_label": gold_label,
		"bet_slider": bet_slider,
		"bet_value": bet_value,
	}
