extends Node

const ShopErrors := preload("res://scripts/game/shop/shop_errors.gd")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")
const ShopState := preload("res://scripts/game/shop/shop_state.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("ShopTransactionsTest: start")
	# Ensure singletons exist
	assert_true(_has_autoload("Shop"), "Shop autoload present")
	assert_true(_has_autoload("Economy"), "Economy autoload present")
	assert_true(_has_autoload("Roster"), "Roster autoload present")
	assert_true(_has_autoload("GameState"), "GameState autoload present")

	# Reset run and set PREVIEW phase
	Economy.reset_run()
	Shop.reset_run()
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	# Empty bench
	for i in range(Roster.slot_count()):
		Roster.set_slot(i, null)

	# Reroll (should spend gold if not free and produce offers)
	var g0 := Economy.gold
	print("gold before reroll:", g0)
	var res_roll := Shop.reroll()
	if not bool(res_roll.get("ok", false)):
		print("res_roll error:", String(res_roll.get("error", "?")))
	assert_true(bool(res_roll.get("ok", false)), "Reroll should succeed in PREVIEW")
	assert_true(Shop.state.offers.size() > 0, "Reroll populates offers")
	assert_true(Economy.gold == max(0, g0 - 2), "Reroll spends REROLL_COST when no free rerolls")

	# Lock toggle and reroll clears lock (per config)
	Shop.toggle_lock()
	assert_true(Shop.state.locked == true, "Lock toggles on")
	Economy.add_gold(ShopConfig.REROLL_COST)
	var res_roll2 := Shop.reroll()
	if not bool(res_roll2.get("ok", false)):
		print("res_roll2 error:", String(res_roll2.get("error", "?")))
	assert_true(bool(res_roll2.get("ok", false)), "Reroll while locked should succeed and clear lock when CLEAR_LOCK_ON_REROLL=true")
	assert_true(Shop.state.locked == false, "Lock cleared after reroll")

	# Buy XP flow
	Economy.add_gold(10)
	var g1 := Economy.gold
	var res_xp := Shop.buy_xp()
	assert_true(bool(res_xp.get("ok", false)), "Buy XP ok")
	assert_true(Economy.gold == g1 - 4, "Gold deducted by BUY_XP_COST")

	# Buy a unit from the first slot (ensure gold and bench capacity)
	Economy.add_gold(20)
	var have_offers := Shop.state.offers.size() > 0
	if not have_offers:
		Shop.reroll()
	var res_buy := Shop.buy_unit(0)
	assert_true(bool(res_buy.get("ok", false)), "Buy unit ok")
	var bench_slot: int = int(res_buy.get("bench_slot", -1))
	assert_true(bench_slot >= 0, "Bought unit placed on bench")
	var placed: Unit = Roster.get_slot(bench_slot)
	assert_true(placed != null, "Bench slot now occupied")
	assert_true(String(Shop.state.offers[0].id) == "", "Purchased slot becomes placeholder (empty id)")

	# Sell the unit we just bought
	var g2 := Economy.gold
	var res_sell := Shop.sell_unit(placed)
	assert_true(bool(res_sell.get("ok", false)), "Sell unit ok")
	assert_true(Economy.gold > g2, "Gold increased after sell")
	assert_true(Roster.get_slot(bench_slot) == null, "Bench slot cleared after sell")

	# Combine: place two copies, then buy third via custom state
	for i2 in range(Roster.slot_count()):
		Roster.set_slot(i2, null)
	var u1: Unit = UnitFactory.spawn("volt")
	var u2: Unit = UnitFactory.spawn("volt")
	assert_true(u1 != null and u2 != null, "Can spawn volt units for combine test")
	Roster.set_slot(0, u1)
	Roster.set_slot(1, u2)
	# Craft a custom state with a third copy as an offer at index 0
	var offer := ShopOffer.new("volt", "Volt", 1, "")
	Shop.state = ShopState.new([offer], false, 0)
	Economy.add_gold(10)
	var res_buy3 := Shop.buy_unit(0)
	assert_true(bool(res_buy3.get("ok", false)), "Buy third copy ok")
	# Validate only one volt remains at level 2
	var remaining: Array = []
	for i3 in range(Roster.slot_count()):
		var u: Unit = Roster.get_slot(i3)
		if u != null and String(u.id) == "volt":
			remaining.append(u)
	assert_true(remaining.size() == 1, "One unit remains after combine")
	assert_true(int(remaining[0].level) == 2, "Promoted to level 2 after combine")

	# Combat phase blocks
	GameState.set_phase(GameState.GamePhase.COMBAT)
	var res_b1 := Shop.reroll()
	assert_true(not bool(res_b1.get("ok", true)) and String(res_b1.get("error")) == ShopErrors.COMBAT_PHASE, "Reroll blocked in COMBAT phase")
	var res_b2 := Shop.buy_xp()
	assert_true(not bool(res_b2.get("ok", true)) and String(res_b2.get("error")) == ShopErrors.COMBAT_PHASE, "Buy XP blocked in COMBAT phase")
	var res_b3 := Shop.buy_unit(0)
	assert_true(not bool(res_b3.get("ok", true)) and String(res_b3.get("error")) == ShopErrors.COMBAT_PHASE, "Buy unit blocked in COMBAT phase")
	var res_b4 := Shop.sell_unit(remaining[0])
	assert_true(not bool(res_b4.get("ok", true)) and String(res_b4.get("error")) == ShopErrors.COMBAT_PHASE, "Sell unit blocked in COMBAT phase")

	print("ShopTransactionsTest: ok")
	if get_tree():
		get_tree().quit()

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERT FAILED: " + msg)
		printerr("ASSERT FAILED: " + msg)
		if get_tree():
			get_tree().quit()
		return

func _has_autoload(name: String) -> bool:
	var n = String(name)
	var path = "/root/%s" % n
	var node = get_tree().root.get_node_or_null(path)
	return node != null
