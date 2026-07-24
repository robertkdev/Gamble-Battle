extends Node

const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")
const REQUIRED_PLAYER_COPY: Dictionary[String, String] = {
	"res://scripts/ui/combat/economy_ui.gd": "Blood Reserve:",
	"res://scripts/ui/title_menu.gd": "Blood. Wager. Consequence.",
	"res://scripts/ui/shop/shop_presenter.gd": "blood in reserve",
	"res://scripts/game/progression/creeps/creep_rewards_runtime.gd": "blood",
}
const FORBIDDEN_LIVE_REFS: Array[String] = [
	"res://assets/ui/gold icon.png",
	"Gold:",
	"Bet:",
]
const RETIRED_UNIT_IDS: Array[String] = ["cashmere", "teller", "ivara"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_validate_live_roster(failures)
	_validate_trait_retirement(failures)
	_validate_blood_wager_contract(failures)
	_validate_player_copy(failures)
	if failures.is_empty():
		print("BloodEconomyConversionSmoke: PASS roster=49 laith_traits=[Arcanist] mogul=retired")
		get_tree().quit(0)
		return
	for failure: String in failures:
		printerr("BloodEconomyConversionSmoke: ", failure)
	get_tree().quit(1)

func _validate_live_roster(failures: Array[String]) -> void:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var all_ids: Array[String] = []
	for cost: int in catalog.get_all_costs():
		all_ids.append_array(catalog.get_ids_by_cost(cost))
	_expect(all_ids.size() == 49, "expected 49 playable units, got %d" % all_ids.size(), failures)
	_expect(all_ids.has("laith"), "Laith is missing from playable catalog", failures)
	for retired_id: String in RETIRED_UNIT_IDS:
		_expect(not all_ids.has(retired_id), "%s remains in playable catalog" % retired_id, failures)

	var laith: Resource = load("res://data/units/laith.tres")
	_expect(laith != null, "Laith profile failed to load", failures)
	if laith == null:
		return
	var traits_variant: Variant = laith.get("traits")
	var traits: Array[String] = []
	if traits_variant is Array:
		for raw_trait: Variant in traits_variant:
			traits.append(String(raw_trait))
	_expect(traits == ["Arcanist"], "Laith traits must be exactly [Arcanist], got %s" % str(traits), failures)
	_expect(String(laith.get("ability_id")) == "laith_ink_expulsion", "Laith must use the non-economy Ink Expulsion bridge kit", failures)

func _validate_trait_retirement(failures: Array[String]) -> void:
	_expect(not FileAccess.file_exists("res://data/traits/Mogul.tres"), "Mogul trait resource still exists", failures)
	_expect(FileAccess.file_exists("res://data/traits/Sanguine.tres"), "Sanguine trait resource is missing", failures)
	var trait_keys_source: String = FileAccess.get_file_as_string("res://scripts/game/traits/runtime/trait_keys.gd")
	_expect(not trait_keys_source.contains("MOGUL"), "Mogul runtime key remains active", failures)
	var laith_ability_source: String = FileAccess.get_file_as_string("res://scripts/game/abilities/impls/laith_ink_expulsion.gd")
	_expect(not laith_ability_source.to_lower().contains("add_gold"), "Laith ability still awards currency", failures)
	_expect(not laith_ability_source.to_lower().contains("kill reward"), "Laith ability still describes a kill reward", failures)

func _validate_blood_wager_contract(failures: Array[String]) -> void:
	_expect(get_tree().root.get_node_or_null("/root/Economy") != null, "Economy autoload is missing", failures)
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		return
	Economy.reset_run()
	_expect(int(Economy.gold) == 3, "blood reserve should retain the tuned starting value 3", failures)
	_expect(Economy.set_bet(2), "wager 2 should be accepted from reserve 3", failures)
	Economy.start_combat()
	_expect(int(Economy.gold) == 1, "wager escrow should leave 1 blood in reserve", failures)
	Economy.resolve(true)
	_expect(int(Economy.gold) == 5, "winning wager 2 from reserve 3 should pay out to reserve 5", failures)

	Economy.reset_run()
	_expect(Economy.set_bet(2), "tie setup wager should be accepted", failures)
	Economy.start_combat()
	Economy.resolve_tie()
	_expect(int(Economy.gold) == 3, "tie should restore the pre-combat blood reserve", failures)
	Economy.reset_run()

func _validate_player_copy(failures: Array[String]) -> void:
	_expect(FileAccess.file_exists("res://assets/ui/blood_reserve.svg"), "blood reserve visual asset is missing", failures)
	for path: String in REQUIRED_PLAYER_COPY.keys():
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.contains(REQUIRED_PLAYER_COPY[path]), "%s is missing required blood copy" % path, failures)
		for forbidden: String in FORBIDDEN_LIVE_REFS:
			_expect(not source.contains(forbidden), "%s still contains player-facing legacy ref %s" % [path, forbidden], failures)
	var main_scene: String = FileAccess.get_file_as_string("res://scenes/Main.tscn")
	_expect(main_scene.contains("res://assets/ui/blood_reserve.svg"), "Main scene does not use the authored blood-reserve asset", failures)
	_expect(not main_scene.contains("res://assets/ui/gold icon.png"), "Main scene still references the gold icon", failures)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
