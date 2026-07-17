extends Node

const ChapterContractService := preload("res://scripts/game/progression/chapter_contract_service.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const TeamOddsEstimator := preload("res://scripts/game/combat/team_odds_estimator.gd")
const EconomyScript := preload("res://scripts/game/economy/economy.gd")

var _failures: Array[String] = []

func _ready() -> void:
	var service: ChapterContractService = ChapterContractService.new()
	var offers: Array[Dictionary] = service.begin_chapter(1, 10, 1234)
	_expect(offers.size() == 3, "chapter market should contain exactly three offers")
	_expect(String(offers[0].get("family", "")) == "champion", "first offer should be Champion")
	_expect(String(offers[1].get("family", "")) == "stable", "second offer should be Stable")
	_expect(String(offers[2].get("family", "")) == "pit", "third offer should be Pit")
	_expect(int(offers[0].get("price", -1)) == 0, "first chapter Champion tutorial should be free")
	var chosen: Dictionary = service.choose(1, 1000)
	_expect(bool(chosen.get("ok", false)), "affordable contract should be selectable")
	_expect(service.stable_board_bonus == 1, "Stable contract should add one board slot")
	_expect(not service.has_pending_choice(), "one choice should expire the other offers")
	var duplicate: Dictionary = service.choose(0, 1000)
	_expect(not bool(duplicate.get("ok", false)), "contract must not double-apply")
	service.begin_chapter(2, 10, 1234)
	var snapshot: Dictionary = service.snapshot()
	var restored: ChapterContractService = ChapterContractService.new()
	restored.restore(snapshot)
	_expect(restored.pending_offers.size() == 3, "pending contract offers should round-trip")
	_expect(restored.stable_board_bonus == 1, "chosen Stable effect should round-trip")
	var pit_choice: Dictionary = restored.choose(2, 1000)
	_expect(bool(pit_choice.get("ok", false)), "Pit contract should be selectable")
	_expect(is_equal_approx(restored.pit_enemy_multiplier, 1.25), "Pit contract should increase enemy strength")
	_expect(is_equal_approx(restored.pit_payout_multiplier, 1.0), "Pit should rely on odds-based payout rather than a second multiplier")
	var enemy: Unit = Unit.new()
	enemy.max_hp = 100
	enemy.hp = 100
	enemy.attack_damage = 40.0
	var player: Unit = Unit.new()
	player.max_hp = 100
	player.hp = 100
	player.attack_damage = 40.0
	var odds_before: int = TeamOddsEstimator.estimate_win_percent([player], [enemy])
	StageRuleRunner.apply_enemy_multiplier([enemy], restored.pit_enemy_multiplier)
	_expect(enemy.max_hp == 125, "Pit multiplier should affect spawned enemy health")
	_expect(is_equal_approx(enemy.attack_damage, 50.0), "Pit multiplier should affect spawned enemy damage")
	var odds_after: int = TeamOddsEstimator.estimate_win_percent([player], [enemy])
	_expect(odds_after < odds_before, "Pit enemy strength should lower projected player odds")
	var economy: Node = EconomyScript.new()
	add_child(economy)
	economy.reset_run()
	var quote_before: float = economy.gross_payout_multiplier(float(odds_before) / 100.0)
	var quote_after: float = economy.gross_payout_multiplier(float(odds_after) / 100.0)
	_expect(quote_after > quote_before, "harder Pit odds should naturally create a richer payout quote")
	_expect(is_equal_approx(restored.pit_payout_multiplier, 1.0), "Pit must not double-compensate difficulty with a second multiplier")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("CHAPTER_CONTRACT_MARKET_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("CHAPTER_CONTRACT_MARKET_PROBE: %s" % failure)
	get_tree().quit(1)
