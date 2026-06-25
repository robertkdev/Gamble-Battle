extends Node

const SMOKE_NAME: String = "ShopPurchaseFeedbackSmoke"
const ShopPresenterLib: Script = preload("res://scripts/ui/shop/shop_presenter.gd")

var _failures: Array[String] = []
var _presenter: ShopPresenter = null
var _host: VBoxContainer = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _autoloads_ready():
		_finish()
		return

	_prepare_populated_shop()
	_host = VBoxContainer.new()
	add_child(_host)
	var grid: GridContainer = GridContainer.new()
	_host.add_child(grid)
	_presenter = ShopPresenterLib.new()
	_presenter.configure(self, grid)
	await get_tree().process_frame
	await get_tree().process_frame

	var card: ShopCard = _first_shop_card()
	_expect(card != null, "first shop card missing")
	if card == null:
		_finish()
		return
	var unit_name: String = _card_name(card)
	var unit_id: String = String(card.offer_id)
	var cost: int = _offer_cost(0)
	var starting_gold: int = int(Economy.gold)
	_press_card(card)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(int(Economy.gold) == starting_gold - cost, "purchase should spend the card cost")
	_expect(_bench_contains(unit_id), "purchase should put %s on the bench" % unit_id)
	_expect(_label_with_prefix("Bought %s. Drag it from bench to board." % unit_name) != null, "purchase should show deploy guidance message")
	_expect(_label_with_text("SOLD") != null, "purchased shop slot should show SOLD")
	_expect(_label_with_text("On bench") != null, "purchased shop slot should explain the unit moved to bench")
	_expect(_sold_placeholder() != null, "purchased shop slot should keep a disabled sold placeholder")
	_finish()

func _autoloads_ready() -> bool:
	var ok: bool = true
	if get_tree().root.get_node_or_null("/root/GameState") == null:
		_fail("GameState autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		_fail("Economy autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Shop") == null:
		_fail("Shop autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Roster") == null:
		_fail("Roster autoload missing")
		ok = false
	return ok

func _prepare_populated_shop() -> void:
	Economy.reset_run()
	Shop.reset_run()
	if Roster.has_method("reset"):
		Roster.reset()
	GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	_set_gold(10)
	Shop.reroll()

func _set_gold(value: int) -> void:
	var delta: int = int(value) - int(Economy.gold)
	if delta != 0:
		Economy.add_gold(delta)

func _first_shop_card() -> ShopCard:
	if _host == null:
		return null
	var cards: Array[Node] = _host.find_children("*", "ShopCard", true, false)
	for node: Node in cards:
		var card: ShopCard = node as ShopCard
		if card != null and not card.disabled:
			return card
	return null

func _offer_cost(slot_index: int) -> int:
	if Shop.state == null or Shop.state.offers == null:
		return 0
	if slot_index < 0 or slot_index >= Shop.state.offers.size():
		return 0
	var offer: Variant = Shop.state.offers[slot_index]
	return int(offer.cost) if offer != null else 0

func _card_name(card: ShopCard) -> String:
	var label: Label = card.get_node_or_null("Name") as Label
	if label == null:
		return String(card.offer_id).capitalize()
	return String(label.text)

func _press_card(card: ShopCard) -> void:
	if card == null:
		return
	card.emit_signal("pressed")

func _bench_contains(unit_id: String) -> bool:
	if unit_id == "":
		return false
	for unit: Variant in Roster.bench_slots:
		if unit != null and String(unit.id) == unit_id:
			return true
	return false

func _sold_placeholder() -> PanelContainer:
	if _host == null:
		return null
	var panels: Array[Node] = _host.find_children("*", "PanelContainer", true, false)
	for node: Node in panels:
		var panel: PanelContainer = node as PanelContainer
		if panel != null and String(panel.tooltip_text).contains("Unit is on your bench"):
			return panel
	return null

func _label_with_prefix(text_prefix: String) -> Label:
	if _host == null:
		return null
	var labels: Array[Node] = _host.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label != null and String(label.text).begins_with(text_prefix):
			return label
	return null

func _label_with_text(text: String) -> Label:
	if _host == null:
		return null
	var labels: Array[Node] = _host.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label != null and String(label.text) == text:
			return label
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	if _presenter != null:
		_presenter.teardown()
		_presenter = null
	if _host != null and is_instance_valid(_host):
		remove_child(_host)
		_host.free()
		_host = null
	if get_tree().root.get_node_or_null("/root/Economy") != null:
		Economy.reset_run()
	if get_tree().root.get_node_or_null("/root/Shop") != null:
		Shop.reset_run()
	if get_tree().root.get_node_or_null("/root/Roster") != null and Roster.has_method("reset"):
		Roster.reset()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		get_tree().quit(1)
		return
	print(SMOKE_NAME + ": OK")
	get_tree().quit(0)
