extends Node

const SMOKE_NAME: String = "ShopPurchaseFeedbackSmoke"
const ShopPresenterLib: Script = preload("res://scripts/ui/shop/shop_presenter.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/shop_purchase_feedback_pass"

var _failures: Array[String] = []
var _presenter: ShopPresenter = null
var _host: VBoxContainer = null
var _saved_captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1600, 900)
		window.content_scale_size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if not _autoloads_ready():
		_finish()
		return

	_prepare_populated_shop()
	_host = VBoxContainer.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.offset_left = 48.0
	_host.offset_top = 48.0
	_host.offset_right = -48.0
	_host.offset_bottom = -48.0
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
	_expect(cost > 0, "first shop card should have a positive purchase cost")

	_set_gold(cost)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(card.disabled, "reserve-floor purchase card should be disabled before denied capture")
	_expect(String(card.get("_status_tip")).contains("keep at least 1 health"), "denied card should expose reserve-floor feedback")
	var denied_gold: int = int(Economy.gold)
	_press_card(card)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(int(Economy.gold) == denied_gold, "denied purchase should not spend gold")
	_expect(not _bench_contains(unit_id), "denied purchase should not put %s on the bench" % unit_id)
	_expect(_label_with_text("Need +1 gold to buy safely.") != null, "denied purchase should show explicit reserve-floor feedback")
	_capture("01_purchase_denied_reserve_feedback.png")

	_set_gold(maxi(10, cost + 2))
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not card.disabled, "affordable purchase card should re-enable before successful capture")
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
	_capture("02_purchase_success_sold_on_bench.png")
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

func _capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		_fail("framebuffer unavailable for authoritative capture %s" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_fail("viewport texture unavailable for authoritative capture %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_fail("viewport image unavailable for authoritative capture %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_fail("failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(error)])
		return
	_saved_captures += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

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
	print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	get_tree().quit(0)
