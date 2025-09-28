extends RefCounted
class_name ShopRoller

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopOdds := preload("res://scripts/game/shop/shop_odds.gd")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")

var _catalog: UnitCatalog
var _rng: ShopRng

func configure(catalog: UnitCatalog, rng: ShopRng) -> void:
	_catalog = catalog
	_rng = rng

func roll(level: int, count: int = ShopConfig.SLOT_COUNT) -> Array[ShopOffer]:
	# Generate up to `count` offers using odds by level and the unit catalog.
	var out: Array[ShopOffer] = []
	if _catalog == null:
		return out
	_catalog.ensure_ready()
	var probs: Dictionary = ShopOdds.get_cost_probabilities(int(level))
	# Filter to costs that have at least one unit in the catalog
	var filtered: Dictionary = {}
	for k in probs.keys():
		var c: int = int(k)
		if _catalog.count_by_cost(c) > 0:
			filtered[c] = float(probs[k])
	if filtered.is_empty():
		# As a fallback, consider any catalog cost equally
		for c in _catalog.get_all_costs():
			filtered[int(c)] = 1.0
	if filtered.is_empty():
		return out

	var used: Dictionary = {}
	var allow_dupes := bool(ShopConfig.ALLOW_DUPLICATES)
	var n: int = max(0, int(count))
	for _i in range(n):
		# Choose a cost tier per odds
		var cost = _rng.pick_weighted(filtered)
		var offer_id := _pick_id_for_cost(int(cost), allow_dupes, used)
		if offer_id == "":
			# Try other costs in order of current filtered keys
			for kc in filtered.keys():
				offer_id = _pick_id_for_cost(int(kc), allow_dupes, used)
				if offer_id != "":
					cost = int(kc)
					break
		if offer_id == "":
			break
		var name := _catalog.get_name(offer_id)
		var sprite := _catalog.get_sprite_path(offer_id)
		var offer: ShopOffer = ShopOffer.new(offer_id, name, int(cost), sprite)
		out.append(offer)
		if not allow_dupes:
			used[offer_id] = true
	return out

func _pick_id_for_cost(cost: int, allow_dupes: bool, used: Dictionary) -> String:
	var ids := _catalog.get_ids_by_cost(cost)
	if ids.is_empty():
		return ""
	if allow_dupes:
		return _catalog.pick_id_by_cost(cost, _rng)
	# No duplicates: try a few random picks to avoid bias
	var attempts: int = min(8, ids.size())
	for _a in range(attempts):
		var candidate := _catalog.pick_id_by_cost(cost, _rng)
		if candidate != "" and not used.has(candidate):
			return candidate
	# Fallback: linear scan for first unused
	for id in ids:
		var sid := String(id)
		if not used.has(sid):
			return sid
	return ""
