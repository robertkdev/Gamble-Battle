extends Node

const SMOKE_NAME: String = "ItemDragSafetySmoke"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const PLAYER_TEAM: Array[String] = ["mortem"]

var _main: Control = null
var _view: Control = null
var _manager: CombatManager = null
var _controller: RefCounted = null
var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle_frames(8)
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle_frames(8)
	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	await _settle_frames(12)

	_view = _main.get_node_or_null("CombatView") as Control
	if _view == null:
		_fail("CombatView missing")
		_finish()
		return
	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", PLAYER_TEAM)
	if _view.has_method("_init_game"):
		_view.call("_init_game")
	await _settle_frames(18)

	_manager = _view.get("manager") as CombatManager
	_controller = _view.get("controller") as RefCounted
	if _manager == null or _controller == null:
		_fail("manager/controller missing")
		_finish()
		return
	if _manager.player_team.is_empty():
		_fail("player team missing")
		_finish()
		return

	Items.add_to_inventory("hammer", 1)
	await _settle_frames(6)
	var hammer_card: ItemCard = _find_item_card("hammer")
	if hammer_card == null:
		_fail("hammer card missing")
		_finish()
		return
	var unit: Unit = _manager.player_team[0] as Unit
	var target_position: Vector2 = _first_board_unit_center()
	_drag_card_to_position(hammer_card, target_position)
	await _settle_frames(6)
	var equipped: Array = Items.get_equipped(unit)
	_expect(equipped.has("hammer"), "hammer should equip when released on a board unit")

	Items.add_to_inventory("crystal", 1)
	await _settle_frames(6)
	var crystal_card: ItemCard = _find_item_card("crystal")
	if crystal_card == null:
		_fail("crystal card missing")
		_finish()
		return
	_drag_card_to_position(crystal_card, Vector2(-80.0, -80.0))
	await _settle_frames(6)
	_expect(_inventory_contains("crystal"), "invalid release should leave crystal in inventory")
	_expect(not bool(crystal_card.get("_dragging")), "invalid release should end the item drag")
	_finish()

func _find_item_card(item_id: String) -> ItemCard:
	if _view == null:
		return null
	var grid: Node = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")
	if grid == null:
		return null
	for child: Node in grid.get_children():
		var card: ItemCard = child as ItemCard
		if card != null and String(card.item_id) == item_id:
			return card
	return null

func _first_board_unit_center() -> Vector2:
	if _controller == null:
		return Vector2.ZERO
	var placement: Variant = _controller.get("grid_placement")
	var helper: BoardGrid = _controller.get("player_grid_helper") as BoardGrid
	if placement == null or helper == null or not placement.has_method("get_player_views"):
		return Vector2.ZERO
	var player_views: Variant = placement.call("get_player_views")
	if not (player_views is Array) or (player_views as Array).is_empty():
		return Vector2.ZERO
	var view_entry: Variant = (player_views as Array)[0]
	var tile_idx: int = int(view_entry.tile_idx)
	return helper.get_center(tile_idx)

func _drag_card_to_position(card: ItemCard, position: Vector2) -> void:
	card.call("_begin_drag_internal")
	card.set("_last_mouse_pos", position)
	card.call("_end_drag_internal")

func _inventory_contains(item_id: String) -> bool:
	var snapshot: Dictionary = Items.get_inventory_snapshot()
	return int(snapshot.get(item_id, 0)) > 0

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if get_tree().root.get_node_or_null("/root/Items") != null:
		Items.reset_run()
	if get_tree().root.get_node_or_null("/root/Roster") != null and Roster.has_method("reset"):
		Roster.reset()
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _main != null and is_instance_valid(_main):
		remove_child(_main)
		_main.queue_free()
		_main = null
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
