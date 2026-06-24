extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var _main: Control = null
var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	Engine.time_scale = 6.0
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle_frames(4)

	await _ensure_unit_select()
	await _select_starter("paisley")
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "combat view did not open")
	_set_planning_timer_safe()
	_set_bet_to_max()
	_press_continue(true, "forced first fight")
	var loss_seen: bool = await _wait_for_loss_overlay(24.0)
	_expect(loss_seen, "loss overlay did not appear")
	if loss_seen:
		_press_loss_new_game()
		await _settle_frames(8)
		_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "loss overlay did not clear")
		_expect(_node_visible("UnitSelect"), "New Game did not return to unit select")
	_finish()

func _finish() -> void:
	Engine.time_scale = 1.0
	var exit_code: int = 0
	if _failures.is_empty():
		print("MainOneLossQuit: PASS")
	else:
		for failure: String in _failures:
			push_error("MainOneLossQuit: " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 2), CONNECT_ONE_SHOT)

func _quit_after_cleanup(exit_code: int, frames_left: int) -> void:
	if frames_left > 0:
		get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, frames_left - 1), CONNECT_ONE_SHOT)
		return
	get_tree().quit(exit_code)

func _cleanup_runtime() -> void:
	if _main != null and is_instance_valid(_main):
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	var loss_layer: Node = get_tree().root.get_node_or_null("LossOverlayLayer")
	if loss_layer != null:
		var parent: Node = loss_layer.get_parent()
		if parent != null:
			parent.remove_child(loss_layer)
		loss_layer.free()

func _ensure_unit_select() -> void:
	if _node_visible("TitleMenu"):
		var start: Button = _main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button
		if start == null:
			_expect(false, "title start button missing")
			return
		start.pressed.emit()
		await _settle_frames(4)
	if not _node_visible("UnitSelect"):
		_expect(false, "unit select was not visible")

func _select_starter(unit_id: String) -> void:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		_expect(false, "unit select node missing")
		return
	var button: Button = select.buttons_by_id.get(unit_id, null) as Button
	if button == null:
		_expect(false, "starter button missing for %s" % unit_id)
		return
	button.pressed.emit()
	await _settle_frames(2)
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	if start == null:
		_expect(false, "unit select start button missing")
		return
	_expect(not start.disabled, "unit select start button did not enable for %s" % unit_id)
	start.pressed.emit()

func _press_continue(expect_forced: bool, label: String) -> void:
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	if button == null:
		_expect(false, "%s continue button missing" % label)
		return
	if expect_forced:
		_expect(button.text == "Start Forced Fight", "%s should show Start Forced Fight, got %s" % [label, button.text])
	else:
		_expect(button.text == "Start Battle", "%s should show Start Battle, got %s" % [label, button.text])
	_expect(not button.disabled, "%s continue button disabled" % label)
	if not button.disabled:
		button.pressed.emit()

func _set_planning_timer_safe() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 9999.0)
	combat.set("planning_time_left", 9999.0)

func _set_bet_to_max() -> void:
	var slider: HSlider = _main.find_child("BetSlider", true, false) as HSlider
	if slider == null:
		_expect(false, "bet slider missing")
		return
	slider.value = slider.max_value

func _wait_for_loss_overlay(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return true
	return false

func _press_loss_new_game() -> void:
	var button: Button = get_tree().root.find_child("NewGameButton", true, false) as Button
	if button == null:
		_expect(false, "loss New Game button missing")
		return
	button.pressed.emit()

func _node_visible(path: String) -> bool:
	if _main == null:
		return false
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame
