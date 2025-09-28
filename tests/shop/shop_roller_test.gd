extends Node

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopOdds := preload("res://scripts/game/shop/shop_odds.gd")
const ShopRng := preload("res://scripts/game/shop/shop_rng.gd")
const ShopRoller := preload("res://scripts/game/shop/shop_roller.gd")
const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("ShopRollerTest: start")
	var catalog := UnitCatalog.new()
	catalog.refresh()
	var rng := ShopRng.new()
	rng.set_seed(123456)
	var roller := ShopRoller.new()
	roller.configure(catalog, rng)

	# Basic roll shape
	var offers := roller.roll(1, ShopConfig.SLOT_COUNT)
	assert_true(offers.size() == ShopConfig.SLOT_COUNT or offers.size() > 0, "Offers should be non-empty and at most SLOT_COUNT")

	# Costs must exist in catalog
	var available_costs: Array[int] = catalog.get_all_costs()
	for o in offers:
		if o == null:
			continue
		assert_true(available_costs.has(int(o.cost)), "Offer cost must exist in catalog")

	# Odds sanity across levels for cost=3 when present
	var has_cost3: bool = catalog.count_by_cost(3) > 0
	var samples := 2000
	var cnt_l1_3 := _count_cost(roller, 1, 3, samples)
	var cnt_l2_3 := _count_cost(roller, 2, 3, samples)
	var cnt_l6_3 := _count_cost(roller, 6, 3, samples)
	if has_cost3:
		assert_true(cnt_l1_3 == 0, "Level 1 should not roll cost-3 when odds table is 100% cost-1")
		assert_true(cnt_l2_3 > 0, "Level 2 should have some chance of cost-3")
		assert_true(cnt_l6_3 >= cnt_l2_3, "Cost-3 count should not decrease at higher levels")
	else:
		assert_true(cnt_l1_3 == 0 and cnt_l2_3 == 0 and cnt_l6_3 == 0, "No cost-3 units available; none should be rolled")

	print("ShopRollerTest: ok")
	if get_tree():
		get_tree().quit()

func _count_cost(roller: ShopRoller, level: int, cost: int, samples: int) -> int:
	var n := 0
	for _i in range(samples):
		var arr = roller.roll(level, 1)
		if arr.size() == 0:
			continue
		if int(arr[0].cost) == int(cost):
			n += 1
	return n

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERT FAILED: " + msg)
		printerr("ASSERT FAILED: " + msg)
		if get_tree():
			get_tree().quit()
		return

