extends Node

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const AccountProgressionScript: GDScript = preload("res://scripts/game/account/account_progression.gd")
const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")
const UnitSelectScene: PackedScene = preload("res://scenes/UnitSelect.tscn")

const PROFILE_PATH: String = "user://account_progression_probe_profile.json"
const JOURNAL_PATH: String = "user://account_progression_probe_journal.json"

var _failures: Array[String] = []

func _ready() -> void:
	_cleanup()
	_test_fresh_profile()
	await _test_fresh_unit_picker()
	_test_idempotent_bounty_awards()
	_test_spend_uses_balance_not_lifetime()
	_test_circle_gating()
	_cleanup()
	if _failures.is_empty():
		print("ACCOUNT_PROGRESSION_PROBE:PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("ACCOUNT_PROGRESSION_PROBE:%s" % failure)
		get_tree().quit(1)

func _test_fresh_profile() -> void:
	var current: Dictionary = AccountProgressionScript.profile(PROFILE_PATH)
	_expect(int(current.get("omens_balance", -1)) == 0, "fresh balance is zero")
	_expect(int(current.get("lifetime_omens", -1)) == 0, "fresh lifetime total is zero")
	var starters: Array[String] = _strings(current.get("unlocked_starter_ids", []))
	_expect(starters.size() == 6, "fresh profile exposes exactly six starters")
	for starter_id: String in BountyCatalogScript.STARTER_IDS:
		_expect(starters.has(starter_id), "fresh profile contains %s" % starter_id)
	_expect(not starters.has("berebell"), "locked starters do not leak into fresh picker")

func _test_idempotent_bounty_awards() -> void:
	var snapshot: Dictionary = _base_snapshot("run-a", "run-a:1:1:victory")
	snapshot["units"] = [
		{"id": "axiom", "level": 3, "alive": true, "market_package_kind": "standard"},
		{"id": "brute", "level": 1, "alive": true, "market_package_kind": "standard"},
	]
	snapshot["team_size"] = 2
	snapshot["survivor_count"] = 2
	var result: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, PROFILE_PATH, JOURNAL_PATH)
	_expect(bool(result.get("ok", false)), "first award evaluation succeeds")
	var awards: Array = result.get("awards", []) as Array
	_expect(awards.size() == 2, "one victory can deliberately satisfy two opening Bounties")
	var current: Dictionary = result.get("profile", {}) as Dictionary
	_expect(int(current.get("omens_balance", 0)) == 6, "two opening Bounties pay six Omens")
	_expect(int(current.get("lifetime_omens", 0)) == 6, "lifetime Omens tracks awards")
	var duplicate: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, PROFILE_PATH, JOURNAL_PATH)
	_expect(bool(duplicate.get("duplicate", false)), "same combat event is idempotent")
	_expect((duplicate.get("awards", []) as Array).is_empty(), "duplicate event pays nothing")
	_expect(int((duplicate.get("profile", {}) as Dictionary).get("omens_balance", 0)) == 6, "duplicate cannot inflate balance")

func _test_fresh_unit_picker() -> void:
	var picker: Control = UnitSelectScene.instantiate() as Control
	picker.set("account_profile_path", PROFILE_PATH)
	add_child(picker)
	await get_tree().process_frame
	await get_tree().process_frame
	var picker_items: Array = picker.get("items") as Array
	_expect(picker_items.size() == 6, "real starter picker renders exactly six fresh-account choices")
	var picker_ids: Array[String] = []
	for raw_item: Variant in picker_items:
		if raw_item is Dictionary:
			picker_ids.append(String((raw_item as Dictionary).get("id", "")))
	for starter_id: String in BountyCatalogScript.STARTER_IDS:
		_expect(picker_ids.has(starter_id), "real starter picker contains %s" % starter_id)
	picker.queue_free()
	await get_tree().process_frame

func _test_spend_uses_balance_not_lifetime() -> void:
	var purchase: Dictionary = AccountProgressionScript.purchase_starter("berebell", PROFILE_PATH)
	_expect(bool(purchase.get("ok", false)), "first revealed starter can be purchased")
	var current: Dictionary = purchase.get("profile", {}) as Dictionary
	_expect(int(current.get("omens_balance", -1)) == 0, "purchase spends current balance")
	_expect(int(current.get("lifetime_omens", -1)) == 6, "purchase does not reduce lifetime access")
	_expect(_strings(current.get("unlocked_starter_ids", [])).has("berebell"), "purchase permanently unlocks starter")
	var too_early: Dictionary = AccountProgressionScript.purchase_starter("knoll", PROFILE_PATH)
	_expect(String(too_early.get("error", "")) == "SEALED", "later starter stays sealed by lifetime total")

func _test_circle_gating() -> void:
	var revealed: Array[Dictionary] = BountyCatalogScript.revealed_bounties(6)
	var revealed_ids: Array[String] = []
	for definition: Dictionary in revealed:
		revealed_ids.append(String(definition.get("id", "")))
	_expect(revealed_ids.has("five_disciplines"), "second circle reveals at six lifetime Omens")
	_expect(not revealed_ids.has("pit_proven"), "third circle remains foreshadowed before 24")
	var snapshot: Dictionary = _base_snapshot("run-b", "run-b:1:2:victory")
	snapshot["primary_roles"] = ["tank", "brawler", "support", "mage", "assassin"]
	snapshot["units"] = [
		{"id": "brute", "level": 1, "alive": true, "market_package_kind": "standard"},
		{"id": "bonko", "level": 1, "alive": true, "market_package_kind": "standard"},
	]
	snapshot["team_size"] = 2
	snapshot["survivor_count"] = 2
	var result: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, PROFILE_PATH, JOURNAL_PATH)
	var award_ids: Array[String] = []
	for raw_award: Variant in result.get("awards", []) as Array:
		if raw_award is Dictionary:
			award_ids.append(String((raw_award as Dictionary).get("id", "")))
	_expect(award_ids.has("five_disciplines"), "revealed mastery Bounty pays from authoritative snapshot")

func _base_snapshot(run_id: String, event_id: String) -> Dictionary:
	return {
		"run_id": run_id,
		"event_id": event_id,
		"chapter": 1,
		"stage": 1,
		"is_boss": false,
		"multi_phase_boss": false,
		"units": [],
		"team_size": 0,
		"survivor_count": 0,
		"team_capacity": 6,
		"primary_roles": [],
		"active_trait_count": 0,
		"team_slots": ["one", "two"],
		"team_signature": "one|two",
		"top_damage_unit_id": "",
		"precombat_bankroll": 10,
		"wager": 1,
		"projected_win_probability": 0.8,
		"paid_rerolls": 1,
		"paid_xp_purchases": 0,
		"paid_command_purchases": 0,
		"command_rank": 0,
		"contract_families": [],
		"champion_fulfilled": false,
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			out.append(String(entry))
	return out

func _cleanup() -> void:
	AccountProfileStoreScript.clear(PROFILE_PATH)
	var journal_paths: Array[String] = [JOURNAL_PATH, "%s.tmp" % JOURNAL_PATH, "%s.bak" % JOURNAL_PATH]
	for path: String in journal_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
