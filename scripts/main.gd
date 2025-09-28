extends Control

@onready var combat_view: Node = $CombatView
@onready var unit_select: Node = $UnitSelect
@onready var title_menu: Control = $TitleMenu
@onready var start_button: Button = $TitleMenu/Center/VBox/StartButton
@onready var quit_button: Button = $TitleMenu/Center/VBox/QuitButton

const Debug := preload("res://scripts/util/debug.gd")

const DEBUG_AUTO_START := false
const DEBUG_TRACE := true

func _ready() -> void:
	Debug.set_enabled(false)
	# Wire menu buttons
	var Trace = load("res://scripts/util/trace.gd")
	if Trace and Trace.has_method("set_enabled"):
		Trace.set_enabled(OS.is_debug_build() and DEBUG_TRACE)
	if start_button and not start_button.is_connected("pressed", Callable(self, "_on_start")):
		start_button.pressed.connect(_on_start)
	if quit_button and not quit_button.is_connected("pressed", Callable(self, "_on_quit")):
		quit_button.pressed.connect(_on_quit)
	# Show menu initially
	_set_menu_visible(true)
	# Wire unit select
	if unit_select and not unit_select.is_connected("unit_selected", Callable(self, "_on_unit_selected")):
		unit_select.unit_selected.connect(_on_unit_selected)
	# Optional debug auto-start (disabled by default)
	if OS.is_debug_build() and DEBUG_AUTO_START:
		if Debug.enabled:
			print("[Main] Debug auto-start enabled; starting game")
		call_deferred("_on_start")

func _set_menu_visible(show_menu: bool) -> void:
	if title_menu:
		title_menu.visible = show_menu
	if combat_view:
		combat_view.visible = false
	if unit_select:
		unit_select.visible = false
	# Update phase when toggling menu visibility
	if show_menu:
		GameState.set_phase(GameState.GamePhase.MENU)

func _on_start() -> void:
	_set_menu_visible(false)
	# Show unit selection screen instead of starting immediately
	if unit_select and unit_select.has_method("show_screen"):
		unit_select.call("show_screen")

func _on_quit() -> void:
	get_tree().quit()

# Public API for children (e.g., CombatView) to return to main menu
func go_to_menu() -> void:
	_set_menu_visible(true)

func _on_unit_selected(unit_id: String) -> void:
	# Hide selection; show combat view and start preview with chosen unit
	if unit_select and unit_select.has_method("hide_screen"):
		unit_select.call("hide_screen")
	if combat_view:
		combat_view.visible = true
		if combat_view.has_method("set_player_team_ids"):
			combat_view.call("set_player_team_ids", [unit_id])
		if combat_view.has_method("_init_game"):
			combat_view.call("_init_game")
	GameState.set_phase(GameState.GamePhase.PREVIEW)
