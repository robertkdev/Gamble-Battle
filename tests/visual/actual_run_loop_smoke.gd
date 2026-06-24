extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SHOP_CONFIG := preload("res://scripts/game/shop/shop_config.gd")

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

	await _play_loss_cycle("paisley", 1)
	if _finish_if_failed():
		return
	await _play_loss_cycle("paisley", 2)
	if _finish_if_failed():
		return
	await _play_shop_cycle("bonko")
	if _finish_if_failed():
		return

	_finish()

func _finish_if_failed() -> bool:
	if _failures.is_empty():
		return false
	_finish()
	return true

func _finish() -> void:
	Engine.time_scale = 1.0
	if _failures.is_empty():
		print("ActualRunLoopSmoke: OK")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("ActualRunLoopSmoke: " + failure)
		get_tree().quit(1)

func _play_loss_cycle(unit_id: String, cycle_index: int) -> void:
	await _ensure_unit_select()
	_expect(_unit_select_reset(), "cycle %d should start with cleared unit select" % cycle_index)
	await _select_starter(unit_id)
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "cycle %d combat view did not open" % cycle_index)
	_set_planning_timer_safe()
	_set_bet_to_max()
	_press_continue(true, "cycle %d forced first fight" % cycle_index)
	var loss_seen: bool = await _wait_for_loss_overlay(24.0)
	_expect(loss_seen, "cycle %d did not reach loss overlay" % cycle_index)
	if loss_seen:
		_press_loss_new_game()
		await _settle_frames(8)
		_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "cycle %d loss overlay did not clear" % cycle_index)
		_expect(_node_visible("UnitSelect"), "cycle %d New Game did not return to unit select" % cycle_index)
		_expect(_unit_select_reset(), "cycle %d New Game did not clear unit select" % cycle_index)

func _play_shop_cycle(unit_id: String) -> void:
	await _ensure_unit_select()
	await _select_starter(unit_id)
	await _settle_frames(4)
	_set_planning_timer_safe()
	_expect(_first_fight_placeholder_visible(), "forced first fight shop placeholder was not visible")
	_press_continue(true, "shop cycle forced first fight")
	var shop_ready: bool = await _wait_for_shop_after_win(30.0)
	_expect(shop_ready, "shop cycle did not open a post-fight shop")
	if not shop_ready:
		return
	_expect(int(GameState.stage_in_chapter) >= 2, "shop cycle did not advance beyond first fight")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "post-fight shop did not have full offers")
	var bought: bool = _press_affordable_shop_card()
	_expect(bought, "could not buy an affordable post-fight shop unit")
	await _settle_frames(4)
	_expect(Roster.compact().size() >= 1, "shop buy did not place a unit on bench")
	var moved_to_board: bool = _move_first_bench_unit_to_board()
	_expect(moved_to_board, "bought bench unit did not move to board through move router")
	await _settle_frames(4)
	_press_continue(false, "shop cycle second fight")
	var outcome_seen: bool = await _wait_for_preview_or_loss(35.0)
	_expect(outcome_seen, "shop cycle second fight did not resolve")
	if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		_press_loss_new_game()
		await _settle_frames(8)
		_expect(_node_visible("UnitSelect"), "shop cycle post-loss New Game did not return to unit select")
		_expect(_unit_select_reset(), "shop cycle post-loss New Game did not clear unit select")

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
		_expect(false, "bet slider missing for all-in loss cycle")
		return
	slider.value = slider.max_value

func _wait_for_loss_overlay(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return true
	return false

func _wait_for_shop_after_win(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			if Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT):
				return true
	return false

func _wait_for_preview_or_loss(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return true
		if GameState.phase == GameState.GamePhase.PREVIEW and not Economy.combat_active:
			return true
	return false

func _press_loss_new_game() -> void:
	var button: Button = get_tree().root.find_child("NewGameButton", true, false) as Button
	if button == null:
		_expect(false, "loss New Game button missing")
		return
	button.pressed.emit()

func _press_affordable_shop_card() -> bool:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		_expect(false, "shop grid missing")
		return false
	for child: Node in grid.get_children():
		var card: ShopCard = child as ShopCard
		if card == null or card.disabled:
			continue
		card.pressed.emit()
		return true
	return false

func _move_first_bench_unit_to_board() -> bool:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return false
	var controller: Variant = combat.get("controller")
	if controller == null:
		return false
	var bench_grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BenchArea/BenchGrid") as GridContainer
	if bench_grid == null:
		return false
	var unit_view: UnitView = _find_first_unit_view(bench_grid)
	if unit_view == null:
		return false
	var target_tile: int = _first_empty_board_tile(controller)
	if target_tile < 0:
		return false
	controller.move_router.call("_bench_to_board", unit_view, target_tile)
	return controller.manager != null and controller.manager.player_team.size() >= 2

func _find_first_unit_view(root: Node) -> UnitView:
	for child: Node in root.get_children():
		if child is UnitView:
			return child as UnitView
		var nested: UnitView = _find_first_unit_view(child)
		if nested != null:
			return nested
	return null

func _first_empty_board_tile(controller: Variant) -> int:
	if controller == null or controller.player_grid_helper == null:
		return -1
	for index: int in range(24):
		if not controller.player_grid_helper.is_occupied(index):
			return index
	return -1

func _first_fight_placeholder_visible() -> bool:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		return false
	for child: Node in grid.get_children():
		var label: Label = _find_label_with_text(child, "FIRST FIGHT")
		if label != null:
			return true
	return false

func _find_label_with_text(root: Node, text: String) -> Label:
	if root is Label and String((root as Label).text) == text:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null

func _unit_select_reset() -> bool:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		return false
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	return select.selected_id == "" and start != null and start.disabled

func _node_visible(path: String) -> bool:
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame
