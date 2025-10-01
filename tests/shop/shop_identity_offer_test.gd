extends Node

const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")
const ShopRoller := preload("res://scripts/game/shop/shop_roller.gd")
const ShopRng := preload("res://scripts/game/shop/shop_rng.gd")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")

func _ready() -> void:
	var catalog := UnitCatalog.new()
	catalog.refresh()
	var rng := ShopRng.new()
	rng.randomize()
	var roller := ShopRoller.new()
	roller.configure(catalog, rng)
	var offers := roller.roll(1, 3)
	assert_true(offers.size() > 0)
	for offer in offers:
		if offer is ShopOffer and String(offer.id) != "":
			var role := String(offer.primary_role)
			var goal := String(offer.primary_goal)
			assert_true(role != "", "shop offer should expose primary role")
			assert_true(goal != "" or offer.approaches.size() > 0, "shop offer should expose goal or approaches")
			assert_true(offer.approaches is Array)
			break
	queue_free()

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		push_error("ASSERT FAILED: " + msg)

