extends Node

const RosterCatalog = preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes = preload("res://scripts/game/progression/stage_types.gd")
const ChapterCatalog = preload("res://scripts/game/progression/chapter_catalog.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")
const RewardPool = preload("res://scripts/game/progression/creeps/reward_pool.gd")
const RewardEntry = preload("res://scripts/game/progression/creeps/reward_entry.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for chapter: int in range(1, 6):
		_validate_chapter(chapter, failures)
	if failures.is_empty():
		print("StageProgressionProbe: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			printerr("StageProgressionProbe: ", failure)
		get_tree().quit(1)

func _validate_chapter(chapter: int, failures: Array[String]) -> void:
	var total: int = int(ChapterCatalog.stages_in(chapter))
	_expect(total == 6, "chapter %d should have 6 rounds" % chapter, failures)
	var creep_rounds: int = 0
	var boss_rounds: int = 0
	var special_rounds: int = 0
	for round_index: int in range(1, total + 1):
		var spec: Dictionary = RosterCatalog.get_spec(chapter, round_index)
		_expect(StageTypes.validate_spec(spec), "invalid spec at chapter %d round %d" % [chapter, round_index], failures)
		var kind: String = String(spec.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL)).strip_edges().to_upper()
		if kind == StageTypes.KIND_CREEPS:
			creep_rounds += 1
			_validate_creep_round(chapter, round_index, spec, failures)
		elif kind == StageTypes.KIND_BOSS:
			boss_rounds += 1
			_expect(round_index == total, "chapter %d boss should be round %d, got round %d" % [chapter, total, round_index], failures)
		elif kind == StageTypes.KIND_ELITE or kind == StageTypes.KIND_EVENT:
			special_rounds += 1
	_expect(creep_rounds >= 2, "chapter %d should have at least two creep rounds" % chapter, failures)
	_expect(boss_rounds == 1, "chapter %d should have exactly one boss round" % chapter, failures)
	_expect(special_rounds >= 1, "chapter %d should have at least one special round" % chapter, failures)

func _validate_creep_round(chapter: int, round_index: int, spec: Dictionary, failures: Array[String]) -> void:
	var ids: Array = spec.get(StageTypes.KEY_IDS, [])
	_expect(not ids.is_empty(), "creep round should have units at chapter %d round %d" % [chapter, round_index], failures)
	for raw_id: String in ids:
		var unit_id: String = String(raw_id).strip_edges()
		_expect(UnitFactory.is_creep_id(unit_id), "non-creep id '%s' in creep round chapter %d round %d" % [unit_id, chapter, round_index], failures)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(rules.has("rewards"), "creep round missing rewards chapter %d round %d" % [chapter, round_index], failures)
	if not rules.has("rewards"):
		return
	var rewards: Dictionary = rules.get("rewards", {})
	_expect(bool(rewards.get("only_creeps", false)), "creep rewards should be creep-only chapter %d round %d" % [chapter, round_index], failures)
	_expect(String(rewards.get("source_team", "")) == "player", "creep rewards should be player-kill sourced chapter %d round %d" % [chapter, round_index], failures)
	var pool_path: String = String(rewards.get("pool_path", ""))
	var pool_stats: Dictionary = _pool_action_stats(pool_path)
	_expect(bool(pool_stats.get("has_component", false)), "creep reward pool should include component drops chapter %d round %d" % [chapter, round_index], failures)
	_expect(not bool(pool_stats.get("has_completed", false)), "creep reward pool should not include completed drops chapter %d round %d" % [chapter, round_index], failures)

func _pool_action_stats(pool_path: String) -> Dictionary:
	var stats: Dictionary = {"has_component": false, "has_completed": false}
	var seen: Dictionary = {}
	_collect_pool_action_stats(pool_path, stats, seen)
	return stats

func _collect_pool_action_stats(pool_path: String, stats: Dictionary, seen: Dictionary) -> void:
	var path: String = String(pool_path).strip_edges()
	if path == "" or seen.has(path):
		return
	seen[path] = true
	if not ResourceLoader.exists(path):
		return
	var resource: Resource = load(path)
	if not (resource is CreepRewardPool):
		return
	var pool: CreepRewardPool = resource as CreepRewardPool
	for entry: CreepRewardEntry in pool.entries:
		if entry == null:
			continue
		if String(entry.kind) == "action":
			var action_id: String = String(entry.action_id).strip_edges().to_lower()
			if action_id == "drop_component":
				stats["has_component"] = true
			elif action_id == "drop_completed":
				stats["has_completed"] = true
		elif String(entry.kind) == "pool" and entry.sub_pool is CreepRewardPool:
			var sub_path: String = String((entry.sub_pool as Resource).resource_path)
			if sub_path != "":
				_collect_pool_action_stats(sub_path, stats, seen)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
