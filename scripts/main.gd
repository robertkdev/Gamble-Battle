extends Node

@onready var combat_view: Node = $CombatView
@onready var title_menu: Control = $TitleMenu
@onready var start_button: Button = $TitleMenu/VBox/StartButton
@onready var quit_button: Button = $TitleMenu/VBox/QuitButton

# Global game phase tracking
enum GamePhase { MENU, PREVIEW, COMBAT, POST_COMBAT }
var game_phase: int = GamePhase.MENU

func set_phase(p: int) -> void:
	game_phase = p

func _ready() -> void:
	# Wire menu buttons
	if start_button and not start_button.is_connected("pressed", Callable(self, "_on_start")):
		start_button.pressed.connect(_on_start)
	if quit_button and not quit_button.is_connected("pressed", Callable(self, "_on_quit")):
		quit_button.pressed.connect(_on_quit)
	# Show menu initially
	_set_menu_visible(true)

func _set_menu_visible(show_menu: bool) -> void:
	if title_menu:
		title_menu.visible = show_menu
	if combat_view:
		combat_view.visible = not show_menu
	# Update phase when toggling menu visibility
	if show_menu:
		game_phase = GamePhase.MENU

func _on_start() -> void:
	_set_menu_visible(false)
	# Start the game directly
	if combat_view and combat_view.has_method("_init_game"):
		combat_view.call("_init_game")

func _on_quit() -> void:
	get_tree().quit()
