extends RefCounted
class_name ChapterContractService

const StakesMarket := preload("res://scripts/game/economy/stakes_market.gd")
const CommandResearch := preload("res://scripts/game/progression/command_research.gd")

const FAMILY_CHAMPION: String = "champion"
const FAMILY_STABLE: String = "stable"
const FAMILY_PIT: String = "pit"

var pending_chapter: int = 0
var pending_offers: Array[Dictionary] = []
var chosen_history: Array[Dictionary] = []
var stable_board_bonus: int = 0
var pit_enemy_multiplier: float = 1.0
var pit_payout_multiplier: float = 1.0
var pending_champion_contracts: int = 0
var pending_champion_doctrines: Array[String] = []

func reset() -> void:
	pending_chapter = 0
	pending_offers.clear()
	chosen_history.clear()
	stable_board_bonus = 0
	pit_enemy_multiplier = 1.0
	pit_payout_multiplier = 1.0
	pending_champion_contracts = 0
	pending_champion_doctrines.clear()

func begin_chapter(chapter: int, stake_unit: int, run_seed: int = 0) -> Array[Dictionary]:
	var next_chapter: int = max(1, int(chapter))
	if next_chapter == pending_chapter and not pending_offers.is_empty():
		return pending_offers.duplicate(true)
	pending_chapter = next_chapter
	pit_enemy_multiplier = 1.0
	pit_payout_multiplier = 1.0
	pending_offers = _build_offers(next_chapter, max(1, int(stake_unit)), int(run_seed))
	return pending_offers.duplicate(true)

func has_pending_choice() -> bool:
	return pending_chapter > 0 and not pending_offers.is_empty()

func choose(index: int, available_gold: int) -> Dictionary:
	if not has_pending_choice():
		return {"ok": false, "error": "NO_PENDING_CONTRACT"}
	var safe_index: int = int(index)
	if safe_index < 0 or safe_index >= pending_offers.size():
		return {"ok": false, "error": "INVALID_CONTRACT"}
	var offer: Dictionary = pending_offers[safe_index].duplicate(true)
	if bool(offer.get("exhausted", false)):
		return {"ok": false, "error": "CONTRACT_EXHAUSTED"}
	var price: int = max(0, int(offer.get("price", 0)))
	var spendable: int = max(0, int(available_gold) - 1)
	if price > spendable:
		return {"ok": false, "error": "INSUFFICIENT_GOLD", "need_more": price - spendable}
	_apply_offer(offer)
	chosen_history.append(offer.duplicate(true))
	pending_offers.clear()
	pending_chapter = 0
	return {
		"ok": true,
		"gold_spent": price,
		"offer": offer,
		"stable_board_bonus": stable_board_bonus,
		"pit_enemy_multiplier": pit_enemy_multiplier,
		"pit_payout_multiplier": pit_payout_multiplier,
		"pending_champion_contracts": pending_champion_contracts,
	}

func pass_choice() -> Dictionary:
	if not has_pending_choice():
		return {"ok": false, "error": "NO_PENDING_CONTRACT"}
	var chapter: int = pending_chapter
	pending_offers.clear()
	pending_chapter = 0
	return {"ok": true, "passed": true, "chapter": chapter}

func apply_champion_contract(unit: Unit, doctrine_id: String = "") -> Dictionary:
	if pending_champion_doctrines.is_empty():
		return {"ok": false, "error": "NO_CHAMPION_CONTRACT"}
	if unit == null:
		return {"ok": false, "error": "INVALID_UNIT"}
	var doctrine: String = pending_champion_doctrines[0]
	var requested: String = String(doctrine_id).strip_edges().to_lower()
	if requested != "" and requested != doctrine:
		return {"ok": false, "error": "DOCTRINE_MISMATCH", "awarded_doctrine": doctrine}
	unit.targeting_mode_override = doctrine
	pending_champion_doctrines.remove_at(0)
	pending_champion_contracts = pending_champion_doctrines.size()
	return {
		"ok": true,
		"unit_id": String(unit.id),
		"doctrine": doctrine,
		"remaining": pending_champion_contracts,
	}

func snapshot() -> Dictionary:
	return {
		"pending_chapter": pending_chapter,
		"pending_offers": pending_offers.duplicate(true),
		"chosen_history": chosen_history.duplicate(true),
		"stable_board_bonus": stable_board_bonus,
		"pit_enemy_multiplier": pit_enemy_multiplier,
		"pit_payout_multiplier": pit_payout_multiplier,
		"pending_champion_contracts": pending_champion_contracts,
		"pending_champion_doctrines": pending_champion_doctrines.duplicate(),
	}

func restore(snapshot_data: Dictionary) -> void:
	pending_chapter = max(0, int(snapshot_data.get("pending_chapter", 0)))
	pending_offers = _dictionary_array(snapshot_data.get("pending_offers", []))
	chosen_history = _dictionary_array(snapshot_data.get("chosen_history", []))
	stable_board_bonus = max(0, int(snapshot_data.get("stable_board_bonus", 0)))
	pit_enemy_multiplier = max(1.0, float(snapshot_data.get("pit_enemy_multiplier", 1.0)))
	pit_payout_multiplier = max(1.0, float(snapshot_data.get("pit_payout_multiplier", 1.0)))
	pending_champion_doctrines = _string_array(snapshot_data.get("pending_champion_doctrines", []))
	pending_champion_contracts = pending_champion_doctrines.size()

func _build_offers(chapter: int, stake_unit: int, run_seed: int) -> Array[Dictionary]:
	var doctrine_index: int = abs(hash("%d:%d:champion" % [run_seed, chapter])) % CommandResearch.DOCTRINES.size()
	var doctrine: String = CommandResearch.DOCTRINES[doctrine_index]
	var tutorial_discount: int = 0 if chapter == 1 else StakesMarket.action_price(10, stake_unit)
	return [
		{
			"id": "champion_doctrine_%s" % doctrine,
			"family": FAMILY_CHAMPION,
			"name": "Champion Contract: %s" % doctrine.replace("_", " ").capitalize(),
			"description": "Install a permanent targeting doctrine on one owned unit for this run.",
			"price": tutorial_discount,
			"doctrine": doctrine,
			"chapter": chapter,
		},
		{
			"id": "stable_formation_license",
			"family": FAMILY_STABLE,
			"name": "Stable Contract: Formation License" if stable_board_bonus < 3 else "Stable Contract: Fully Licensed",
			"description": "Gain one additional board slot for this run." if stable_board_bonus < 3 else "Your formation-license capacity is already exhausted.",
			"price": StakesMarket.action_price(12, stake_unit) if stable_board_bonus < 3 else 0,
			"board_bonus": 1 if stable_board_bonus < 3 else 0,
			"exhausted": stable_board_bonus >= 3,
			"chapter": chapter,
		},
		{
			"id": "pit_blood_odds",
			"family": FAMILY_PIT,
			"name": "Pit Contract: Blood Odds",
			"description": "Enemies become 25% stronger; their lower projected win odds naturally quote a richer payout.",
			"price": StakesMarket.action_price(16, stake_unit),
			"enemy_multiplier": 1.25,
			"payout_multiplier": 1.0,
			"chapter": chapter,
		},
	]

func _apply_offer(offer: Dictionary) -> void:
	var family: String = String(offer.get("family", ""))
	if family == FAMILY_CHAMPION:
		var doctrine: String = String(offer.get("doctrine", "")).strip_edges().to_lower()
		if CommandResearch.DOCTRINES.has(doctrine):
			pending_champion_doctrines.append(doctrine)
		pending_champion_contracts = pending_champion_doctrines.size()
	elif family == FAMILY_STABLE:
		stable_board_bonus = min(3, stable_board_bonus + max(0, int(offer.get("board_bonus", 0))))
	elif family == FAMILY_PIT:
		pit_enemy_multiplier = min(3.0, pit_enemy_multiplier * max(1.0, float(offer.get("enemy_multiplier", 1.0))))
		pit_payout_multiplier = 1.0

func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				output.append((entry as Dictionary).duplicate(true))
	return output

func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array or value is PackedStringArray:
		for entry: Variant in value:
			var text: String = String(entry).strip_edges().to_lower()
			if text != "":
				output.append(text)
	return output
