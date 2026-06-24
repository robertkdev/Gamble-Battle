extends Node

const Runtime = preload("res://scripts/game/progression/creeps/creep_rewards_runtime.gd")
const RewardPool = preload("res://scripts/game/progression/creeps/reward_pool.gd")
const RewardEntry = preload("res://scripts/game/progression/creeps/reward_entry.gd")
const CombatEngineScript = preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript = preload("res://scripts/game/combat/battle_state.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")
const ItemCatalog = preload("res://scripts/game/items/item_catalog.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var previous_suppress_validation_warnings: bool = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	var items: Node = _find("/root/Items")
	if items == null or not items.has_method("reset_run"):
		UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
		printerr("RewardsKillProbe: missing Items autoload")
		get_tree().quit(1)
		return
	items.call("reset_run")

	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = BattleStateScript.new()
	engine.state = state
	engine.rng.seed = 12345

	var runtime: CreepRewardsRuntime = Runtime.new()
	var pool: CreepRewardPool = _component_only_pool()

	_set_teams(state, ["sari"], ["drubble"])
	runtime.configure(engine, pool, {"rolls_per_kill": 1, "only_creeps": true, "source_team": "player"})
	var before_creep_kill: Dictionary = _inv()
	runtime._on_hit_applied("player", 0, 0, 10, 10, false, 10, 0, 0.0, 0.0)
	var after_creep_kill: Dictionary = _inv()
	_expect(_count_inv(after_creep_kill) == _count_inv(before_creep_kill) + 1, "player kill on enemy creep should add one component", failures)
	_expect(_only_new_items_are_type(before_creep_kill, after_creep_kill, "component"), "creep kill reward should only add components", failures)

	_set_teams(state, ["sari"], ["bonko"])
	runtime.configure(engine, pool, {"rolls_per_kill": 1, "only_creeps": true, "source_team": "player"})
	var before_non_creep_kill: Dictionary = _inv()
	runtime._on_hit_applied("player", 0, 0, 10, 10, false, 10, 0, 0.0, 0.0)
	_expect(_count_inv(_inv()) == _count_inv(before_non_creep_kill), "player kill on non-creep should not add creep reward", failures)

	_set_teams(state, ["drubble"], ["bonko"])
	runtime.configure(engine, pool, {"rolls_per_kill": 1, "only_creeps": true, "source_team": "player"})
	var before_enemy_kill: Dictionary = _inv()
	runtime._on_hit_applied("enemy", 0, 0, 10, 10, false, 10, 0, 0.0, 0.0)
	_expect(_count_inv(_inv()) == _count_inv(before_enemy_kill), "enemy kill on a creep should not grant player creep reward", failures)

	items.call("reset_run")
	ItemCatalog.clear_cache()
	UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
	if failures.is_empty():
		print("RewardsKillProbe: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			printerr("RewardsKillProbe: ", failure)
		get_tree().quit(1)

func _component_only_pool() -> CreepRewardPool:
	var entry: CreepRewardEntry = RewardEntry.new()
	entry.id = "component"
	entry.kind = "action"
	entry.weight = 1.0
	entry.action_id = "drop_component"
	entry.action_params = {"count": 1}

	var pool: CreepRewardPool = RewardPool.new()
	pool.id = "component_only"
	pool.rolls_per_kill = 1
	pool.entries.clear()
	pool.entries.append(entry)
	return pool

func _set_teams(state: BattleState, player_ids: Array[String], enemy_ids: Array[String]) -> void:
	state.player_team.clear()
	state.enemy_team.clear()
	for player_id: String in player_ids:
		var player_unit: Unit = UnitFactory.spawn(player_id)
		if player_unit != null:
			state.player_team.append(player_unit)
	for enemy_id: String in enemy_ids:
		var enemy_unit: Unit = UnitFactory.spawn(enemy_id)
		if enemy_unit != null:
			state.enemy_team.append(enemy_unit)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _inv() -> Dictionary:
	var items: Node = _find("/root/Items")
	if items != null and items.has_method("get_inventory_snapshot"):
		return items.call("get_inventory_snapshot")
	return {}

func _count_inv(inv: Dictionary) -> int:
	var sum: int = 0
	for item_id: String in inv.keys():
		sum += int(inv.get(item_id, 0))
	return sum

func _only_new_items_are_type(before: Dictionary, after: Dictionary, expected_type: String) -> bool:
	for item_id: String in after.keys():
		var delta: int = int(after.get(item_id, 0)) - int(before.get(item_id, 0))
		if delta <= 0:
			continue
		var def: ItemDef = ItemCatalog.get_def(String(item_id))
		if def == null:
			return false
		if String(def.type) != expected_type:
			return false
	return true

func _find(path: String) -> Node:
	var root: Node = get_tree().get_root()
	if root != null and root.has_node(path):
		return root.get_node(path)
	return null
