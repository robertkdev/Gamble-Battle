extends Node

const MainScene: PackedScene = preload("res://scenes/Main.tscn")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/exit_menu_pass"

var _main: Control
var _failures: Array[String] = []
var _previous_suppress_validation_warnings: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true

	_main = MainScene.instantiate() as Control
	add_child(_main)
	await _settle_frames(2)

	_expect(_node_visible("TitleMenu"), "title menu should be visible on boot")
	_expect(not _button_visible("SystemMenuButton"), "system menu button should be hidden on title")

	_press_title_start()
	await _settle_frames(2)
	_expect(_node_visible("UnitSelect"), "unit select should be visible after start")
	_expect(_button_visible("SystemMenuButton"), "system menu button should be visible during unit select")

	_press_button("SystemMenuButton")
	await _settle_frames(1)
	_expect(get_tree().paused, "opening system menu should pause the game")
	_expect(_overlay_visible(), "system menu overlay should be visible during unit select")
	_expect(_button_exists("ResumeButton"), "resume button missing")
	_expect(_button_exists("NewRunButton"), "new run button missing")
	_expect(_button_exists("ReturnTitleButton"), "return to title button missing")
	_expect(_button_exists("QuitGameButton"), "quit game button missing")
	_save_capture("01_unit_select_system_menu.png")
	_press_button("ResumeButton")
	await _settle_frames(2)
	_expect(not get_tree().paused, "resume should unpause the game")
	_expect(not _overlay_visible(), "resume should hide the system menu")

	_press_button("SystemMenuButton")
	_press_button("NewRunButton")
	await _settle_frames(3)
	_expect(not get_tree().paused, "new run should unpause the game")
	_expect(_node_visible("UnitSelect"), "new run should land on unit select")
	_expect(int(GameState.stage) == 1, "new run should reset stage to 1")
	_expect(int(Economy.gold) == 2, "new run should reset gold to starting value")
	_expect(_unit_select_reset(), "new run should clear unit select choice")

	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	await _settle_frames(6)
	_expect(_node_visible("CombatView"), "combat view should be visible after selecting a unit")
	_expect(_button_visible("SystemMenuButton"), "system menu button should be visible during combat")
	_expect(not _embedded_combat_menu_visible(), "embedded combat menu button should be hidden")

	_press_button("SystemMenuButton")
	await _settle_frames(1)
	_expect(get_tree().paused, "opening system menu in combat should pause")
	_expect(_overlay_visible(), "system menu overlay should be visible during combat")
	_save_capture("02_combat_system_menu.png")
	_press_button("ReturnTitleButton")
	await _settle_frames(3)
	_expect(not get_tree().paused, "return to title should unpause")
	_expect(_node_visible("TitleMenu"), "return to title should show title menu")
	_expect(not _node_visible("CombatView"), "return to title should hide combat")
	_expect(not _button_visible("SystemMenuButton"), "system menu button should hide on title")
	_expect(GameState.phase == GameState.GamePhase.MENU, "return to title should set menu phase")

	var fake_loss_layer: CanvasLayer = CanvasLayer.new()
	fake_loss_layer.name = "LossOverlayLayer"
	fake_loss_layer.layer = 100
	get_tree().root.add_child(fake_loss_layer)
	_press_title_start()
	await _settle_frames(2)
	_press_button("SystemMenuButton")
	_press_button("NewRunButton")
	await _settle_frames(4)
	_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "new run should clear defeat overlay layer")
	_expect(_node_visible("UnitSelect"), "new run from overlay state should land on unit select")
	_expect(not get_tree().paused, "new run from overlay state should unpause")
	_expect(_unit_select_reset(), "new run from overlay state should clear unit select choice")

	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	if _failures.is_empty():
		print("ExitFlowSmoke: OK")
	else:
		for failure: String in _failures:
			push_error("ExitFlowSmoke: " + failure)
	get_tree().quit()

func _press_title_start() -> void:
	var button: Button = _main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button
	if button == null:
		_expect(false, "title start button missing")
		return
	button.pressed.emit()

func _press_button(button_name: String) -> void:
	var button: Button = _main.find_child(button_name, true, false) as Button
	if button == null:
		_expect(false, "%s missing" % button_name)
		return
	button.pressed.emit()

func _button_exists(button_name: String) -> bool:
	return _main.find_child(button_name, true, false) is Button

func _button_visible(button_name: String) -> bool:
	var button: Button = _main.find_child(button_name, true, false) as Button
	return button != null and button.visible

func _overlay_visible() -> bool:
	var overlay: Control = _main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay") as Control
	return overlay != null and overlay.visible

func _node_visible(path: String) -> bool:
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _embedded_combat_menu_visible() -> bool:
	var button: Button = _main.get_node_or_null("CombatView/TopBar/MenuButton") as Button
	return button != null and button.visible

func _unit_select_reset() -> bool:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		return false
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	return select.selected_id == "" and start != null and start.disabled

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy":
		print("ExitFlowSmoke: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		print("ExitFlowSmoke: skipped %s because viewport texture is unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("ExitFlowSmoke: skipped %s because viewport image is unavailable" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		print("ExitFlowSmoke: failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(err)])
		return
	print("ExitFlowSmoke: saved %s" % ProjectSettings.globalize_path(path))
