extends RefCounted
class_name ShopPresenter

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopPanel := preload("res://scripts/ui/shop/shop_panel.gd")
const ShopButtons := preload("res://scripts/ui/shop/shop_buttons.gd")
const ShopErrors := preload("res://scripts/game/shop/shop_errors.gd")
const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")

var _parent: Node = null
var _grid: GridContainer = null
var _panel: ShopPanel = null
var _buttons: ShopButtons = null
var _message_label: Label = null
var _message_timer: SceneTreeTimer = null
var _drop_grid: BoardGrid = null

signal grid_updated
signal promotions_emitted(promotions)

func _root() -> Node:
	var tree := (_parent.get_tree() if _parent else null)
	return tree.root if tree else null

func _has_shop() -> bool:
	if Engine.has_singleton("Shop"):
		return true
	var r = _root()
	return r != null and r.get_node_or_null("Shop") != null

func _has_economy() -> bool:
	if Engine.has_singleton("Economy"):
		return true
	var r = _root()
	return r != null and r.get_node_or_null("Economy") != null

func configure(parent: Node, grid: GridContainer) -> void:
	_parent = parent
	_grid = grid
	if _grid:
		_grid.columns = ShopConfig.SLOT_COUNT
	_panel = ShopPanel.new()
	_panel.configure(_grid, ShopConfig.SLOT_COUNT)
	# Button bar mounted above grid inside the host container
	_buttons = ShopButtons.new()
	_buttons.configure(_panel.get_host_container())
	_buttons.reroll_pressed.connect(_on_reroll)
	_buttons.lock_pressed.connect(_on_lock)
	_buttons.buy_xp_pressed.connect(_on_buy_xp)
	_wire()
	_refresh_now()
	_rebuild_drop_grid()

func _wire() -> void:
	if not _has_shop():
		return
	if not Shop.is_connected("offers_changed", Callable(self, "_on_offers_changed")):
		Shop.offers_changed.connect(_on_offers_changed)
	if not Shop.is_connected("locked_changed", Callable(self, "_on_locked_changed")):
		Shop.locked_changed.connect(_on_locked_changed)
	if not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)
	# React to economy/phase changes for live affordability/tooltip updates
	if _has_economy():
		if not Economy.is_connected("gold_changed", Callable(self, "_on_economy_changed")):
			Economy.gold_changed.connect(_on_economy_changed)
		if not Economy.is_connected("bet_changed", Callable(self, "_on_economy_changed")):
			Economy.bet_changed.connect(_on_economy_changed)
	if Engine.has_singleton("GameState"):
		if not GameState.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
			GameState.phase_changed.connect(_on_phase_changed)

func _refresh_now() -> void:
	if not _has_shop():
		return
	# If Shop has current offers (after reroll), show them; else show empties
	if Shop and Shop.state and Shop.state.offers != null:
		_panel.set_offers(Shop.state.offers)
	else:
		_panel.set_offers([])
	_on_locked_changed(Shop.state.locked if Shop and Shop.state else false)
	_refresh_cards_state()
	_refresh_progress()
	
func _on_offers_changed(offers: Array) -> void:
	if _panel:
		_panel.set_offers(offers)
		_refresh_cards_state()
		_refresh_progress()
		_rebuild_drop_grid()

func _on_locked_changed(locked: bool) -> void:
	if _buttons:
		_buttons.set_locked(locked)

func _refresh_progress() -> void:
	if _buttons == null:
		return
	var lvl: int = 1
	var xp: int = 0
	var need: int = 0
	if _has_shop():
		if Shop and Shop.has_method("get_level"):
			lvl = int(Shop.get_level())
		if Shop and Shop.has_method("get_xp"):
			xp = int(Shop.get_xp())
		if Shop and Shop.has_method("get_xp_to_next"):
			need = int(Shop.get_xp_to_next())
	_buttons.set_progress(lvl, xp, need)

func _on_economy_changed(_v := 0) -> void:
	_refresh_cards_state()
	_refresh_progress()

func _on_phase_changed(_prev: int, _next: int) -> void:
	_refresh_cards_state()

func _refresh_cards_state() -> void:
	if _panel == null:
		return
	var cards: Array = _panel.get_cards()
	if cards.is_empty():
		return
	var gold: int = 0
	if _has_economy():
		gold = int(Economy.gold)
	var bench_full: bool = false
	if Engine.has_singleton("Roster"):
		bench_full = (Roster.first_empty_slot() == -1)
	var in_combat: bool = false
	if Engine.has_singleton("GameState"):
		in_combat = (GameState.phase == GameState.GamePhase.COMBAT)
	var bet: int = (int(Economy.current_bet) if _has_economy() else 0)
	var spent: int = (int(Economy.combat_spent) if _has_economy() and in_combat else 0)
	var idx: int = 0
	for c in cards:
		if c is ShopCard:
			var sc: ShopCard = c
			# affordability tint only
			var price := 0
			if Shop and Shop.state and idx < Shop.state.offers.size():
				var off = Shop.state.offers[idx]
				price = int(off.cost) if off != null else 0
			var aff := ShopAffordability.can_afford(gold, bet, price, in_combat, spent)
			sc.set_affordable(bool(aff.get("ok", false)))
			if not bool(aff.get("ok", false)):
				var need: int = int(aff.get("need_more", 0))
				var msg := "Not enough gold"
				var reason := String(aff.get("reason", ""))
				if reason == ShopAffordability.REASON_RESERVE_FLOOR:
					msg = "Must keep at least 1 health (need +%d)" % max(1, need)
				elif reason == ShopAffordability.REASON_CREDIT_LIMIT:
					msg = "Exceeds combat credit (need +%d)" % max(1, need)
				sc.tooltip_text = msg
			if bench_full:
				sc.set_shop_disabled("Bench full")
			else:
				# Re-enable if previously disabled for bench full (lightweight approach)
				sc.disabled = false
				sc.modulate = Color(1,1,1,1)
			# Connect click -> buy
			if not sc.is_connected("clicked", Callable(self, "_on_card_clicked")):
				sc.clicked.connect(_on_card_clicked)
		idx += 1

	# Buttons hints
	if _buttons:
		var r_cost: int = int(ShopConfig.REROLL_COST)
		var aff_r := ShopAffordability.can_afford(gold, bet, r_cost, in_combat, spent)
		var msg_r := ""
		if not bool(aff_r.get("ok", false)):
			var need_r: int = int(aff_r.get("need_more", 0))
			var reason_r := String(aff_r.get("reason", ""))
			if reason_r == ShopAffordability.REASON_RESERVE_FLOOR:
				msg_r = "Must keep at least 1 health (need +%d)" % max(1, need_r)
			elif reason_r == ShopAffordability.REASON_CREDIT_LIMIT:
				msg_r = "Exceeds combat credit (need +%d)" % max(1, need_r)
			else:
				msg_r = "Not enough gold"
		_buttons.set_reroll_tooltip(msg_r)

		var x_cost: int = int(ShopConfig.BUY_XP_COST)
		var aff_x := ShopAffordability.can_afford(gold, bet, x_cost, in_combat, spent)
		var msg_x := ""
		if not bool(aff_x.get("ok", false)):
			var need_x: int = int(aff_x.get("need_more", 0))
			var reason_x := String(aff_x.get("reason", ""))
			if reason_x == ShopAffordability.REASON_RESERVE_FLOOR:
				msg_x = "Must keep at least 1 health (need +%d)" % max(1, need_x)
			elif reason_x == ShopAffordability.REASON_CREDIT_LIMIT:
				msg_x = "Exceeds combat credit (need +%d)" % max(1, need_x)
			else:
				msg_x = "Not enough gold"
		_buttons.set_buy_xp_tooltip(msg_x)

func _on_card_clicked(slot_index: int) -> void:
	if not _has_shop():
		return
	var res = Shop.buy_unit(int(slot_index))
	# Emit promotions for UI effects if present
	if typeof(res) == TYPE_DICTIONARY:
		var promos = res.get("promotions", null)
		if promos is Array and promos.size() > 0:
			promotions_emitted.emit(promos)
	_refresh_progress()

func set_enabled(enabled: bool) -> void:
	if _buttons:
		_buttons.set_enabled(bool(enabled))

func _on_reroll() -> void:
	if not _has_shop():
		return
	if Shop:
		Shop.reroll()
	_refresh_progress()

func _on_lock() -> void:
	if not _has_shop():
		return
	if Shop:
		Shop.toggle_lock()
	_refresh_progress()

func _on_buy_xp() -> void:
	if not _has_shop():
		return
	if Shop:
		Shop.buy_xp()
		_refresh_progress()
		_refresh_cards_state()

func _rebuild_drop_grid() -> void:
	if _grid == null:
		return
	var tiles: Array = []
	for c in _grid.get_children():
		if c is Control:
			tiles.append(c)
	if _drop_grid == null:
		_drop_grid = load("res://scripts/board_grid.gd").new()
	_drop_grid.configure(tiles, int(ShopConfig.SLOT_COUNT), 1)
	grid_updated.emit()

func get_drop_grid() -> BoardGrid:
	return _drop_grid

func get_button_bar() -> HBoxContainer:
	return (_buttons.get_bar() if _buttons else null)

func _ensure_message_label() -> void:
	if _message_label and is_instance_valid(_message_label):
		return
	var host := (_panel.get_host_container() if _panel else null)
	if host == null:
		return
	_message_label = Label.new()
	_message_label.modulate = Color(1,0.6,0.6,0.95)
	host.add_child(_message_label)
	host.move_child(_message_label, 1) # below buttons

func _show_message(text: String, seconds: float = 2.0) -> void:
	_ensure_message_label()
	if _message_label == null:
		return
	_message_label.text = String(text)
	_message_label.visible = true
	if _message_timer and is_instance_valid(_message_timer):
		_message_timer.timeout
	var tree := (_parent.get_tree() if _parent else null)
	if tree:
		_message_timer = tree.create_timer(max(0.1, float(seconds)))
		_message_timer.timeout.connect(func():
			if _message_label:
				_message_label.visible = false
		)

func _on_shop_error(code: String, context: Dictionary) -> void:
	var msg := ShopErrors.message(code)
	_show_message(msg, 2.0)
