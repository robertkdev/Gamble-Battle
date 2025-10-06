extends Node


const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")
const ShopState := preload("res://scripts/game/shop/shop_state.gd")
const ShopErrors := preload("res://scripts/game/shop/shop_errors.gd")
const ShopRng := preload("res://scripts/game/shop/shop_rng.gd")
const ShopRoller := preload("res://scripts/game/shop/shop_roller.gd")
const ShopTransactions := preload("res://scripts/game/shop/shop_transactions.gd")
const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")
const PlayerProgress := preload("res://scripts/game/shop/player_progress.gd")

signal offers_changed(offers: Array)
signal locked_changed(locked: bool)
signal free_rerolls_changed(count: int)
signal error(code: String, context: Dictionary)

var state: ShopState = ShopState.new()

var _rng: ShopRng
var _catalog: UnitCatalog
var _roller: ShopRoller
var _tx: ShopTransactions
var _progress: PlayerProgress

func _ready() -> void:
	_rng = ShopRng.new()
	# Honor debug seed override if configured
	if int(ShopConfig.DEBUG_SEED) >= 0:
		_rng.set_seed(int(ShopConfig.DEBUG_SEED))
		if bool(ShopConfig.DEBUG_VERBOSE):
			print("[Shop] Using debug seed:", int(ShopConfig.DEBUG_SEED))
	else:
		_rng.randomize()
	_catalog = UnitCatalog.new()
	_catalog.refresh()
	_roller = ShopRoller.new()
	_roller.configure(_catalog, _rng)
	_tx = ShopTransactions.new()
	# Pass Roster to transactions for bench capacity and placement
	var roster_ref = null
	if _has_autoload("Roster"):
		roster_ref = Roster
	_tx.configure(_roller, roster_ref)
	_progress = PlayerProgress.new()
	reset_run()

func _has_autoload(name: String) -> bool:
	var n = String(name)
	var path = "/root/%s" % n
	var node = get_tree().root.get_node_or_null(path)
	return node != null

func _is_combat_phase() -> bool:
	if _has_autoload("GameState"):
		var gp = GameState
		return int(gp.phase) == int(gp.GamePhase.COMBAT)
	return false

func reset_run() -> void:
	# Clear state for a new run.
	state = ShopState.new([], false if ShopConfig.CLEAR_LOCK_ON_NEW_RUN else state.locked, 0)
	if _progress:
		_progress.reset()
	_emit_all()

func get_level() -> int:
	return int(_progress.level) if _progress else int(ShopConfig.STARTING_LEVEL)

func set_level(lv: int) -> void:
	if _progress:
		var old := _progress.level
		_progress.set_level(int(lv))
		# No signal bridging here; UI can subscribe to PlayerProgress later if needed

func add_free_rerolls(n: int) -> void:
	var add: int = max(0, int(n))
	if add == 0:
		return
	state = ShopState.new(state.offers, state.locked, state.free_rerolls + add)
	free_rerolls_changed.emit(state.free_rerolls)

func grant_free_rerolls(n: int) -> void:
	# Alias for external callers (e.g., Trader trait)
	add_free_rerolls(n)

func toggle_lock() -> void:
	var next := _tx.toggle_lock(state)
	var changed := (next.locked != state.locked)
	state = next
	if changed:
		locked_changed.emit(state.locked)

func reroll() -> Dictionary:
	# Spends gold when successful; updates internal state and emits signals.
	var lvl := get_level()
	var gold := (Economy.gold if _has_autoload("Economy") else 0)
	var res := _tx.reroll(state, lvl, gold)
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), {"op": "reroll"})
		return res
	var cost := int(res.get("gold_spent", 0))
	# Spend gold or record combat spend
	if cost > 0 and _has_autoload("Economy"):
		if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
			Economy.adjust_combat_spent(cost)
		else:
			Economy.add_gold(-cost)
	state = (res.get("state") as ShopState)
	_emit_all()
	return res

func buy_xp() -> Dictionary:
	var gold := (Economy.gold if _has_autoload("Economy") else 0)
	var res := _tx.buy_xp(_progress, gold)
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), {"op": "buy_xp"})
		return res
	var cost := int(res.get("gold_spent", 0))
	if cost > 0 and _has_autoload("Economy"):
		if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
			Economy.adjust_combat_spent(cost)
		else:
			Economy.add_gold(-cost)
	# Offers unchanged; emit reroll/free_rerolls unchanged; but UI may want progress snapshot via getters
	return res

func get_xp() -> int:
	return int(_progress.xp) if _progress else 0

func get_xp_to_next() -> int:
	return int(_progress.xp_to_next()) if _progress else 0

func buy_unit(slot_index: int) -> Dictionary:
	var lvl := get_level()
	var gold := (Economy.gold if _has_autoload("Economy") else 0)
	var res := _tx.buy_unit(state, int(slot_index), gold, lvl)
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), {"op": "buy_unit", "slot": int(slot_index)})
		return res
	var cost := int(res.get("gold_spent", 0))
	if cost > 0 and _has_autoload("Economy"):
		if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
			Economy.adjust_combat_spent(cost)
		else:
			Economy.add_gold(-cost)
	state = (res.get("state") as ShopState)
	_emit_all()
	return res

func sell_unit(u: Unit) -> Dictionary:
	var res := _tx.sell_unit(u)
	if bool(res.get("ok", false)) and _has_autoload("Economy"):
		var g := int(res.get("gold_gained", 0))
		if g > 0:
			# Selling during combat should free up credit as well
			if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
				Economy.adjust_combat_spent(-g)
		Economy.add_gold(g)
	else:
		error.emit(String(res.get("error", "UNKNOWN")), {"op": "sell_unit"})
	return res

func set_board_team_provider(cb: Callable) -> void:
	# Allows UI/controller layer to provide the current player_team for board-aware combines
	if _tx != null and cb != null:
		_tx.set_board_team_provider(cb)

func set_remove_from_board(cb: Callable) -> void:
	# Allows UI/controller to provide removal of a specific board unit when consumed by a combine
	if _tx != null and cb != null:
		_tx.set_remove_from_board(cb)

func try_combine_now() -> Array:
	# Attempts to perform bench+board combines immediately (planning phase only).
	# Returns a list of promotion dicts for UI effects.
	if _tx != null and _tx.has_method("combine_now"):
		return _tx.combine_now()
	return []

func _emit_all() -> void:
	offers_changed.emit(state.offers)
	locked_changed.emit(state.locked)
	free_rerolls_changed.emit(state.free_rerolls)
