extends Node

const BattleStateScript: Script = preload("res://scripts/game/combat/battle_state.gd")
const BuffSystemScript: Script = preload("res://scripts/game/abilities/buff_system.gd")
const MovementBuffAdapterScript: Script = preload("res://scripts/game/combat/movement/adapters/buff_adapter.gd")
const UnitFactoryScript: Script = preload("res://scripts/unit_factory.gd")

@export var empty_iterations: int = 240000
@export var blocked_iterations: int = 120000

const UNIT_IDS: Array[String] = [
	"bonko", "korath", "sari", "pilfer", "cashmere", "axiom",
	"brute", "repo", "hexeon", "luna", "nyxa", "morrak"
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: BattleState = _make_state()
	var buffs: BuffSystem = BuffSystemScript.new()
	var adapter: MovementBuffAdapter = MovementBuffAdapterScript.new()
	adapter.configure(buffs)

	var direct_empty: Dictionary = _run_direct_empty(adapter, state)
	var gated_empty: Dictionary = _run_gated_empty(adapter, state)

	buffs.apply_tag(state, "player", 3, "root", 60.0, {})
	var gated_blocked: Dictionary = _run_gated_blocked(adapter, state)

	var signature: int = 23
	signature = _mix(signature, int(direct_empty.get("hits", 0)))
	signature = _mix(signature, int(gated_empty.get("hits", 0)))
	signature = _mix(signature, int(gated_blocked.get("hits", 0)))
	signature = _mix(signature, 1 if buffs.has_movement_blockers() else 0)
	print("PerfMovementBlockers: empty_iterations=", empty_iterations,
		" direct_empty_ms=", int(direct_empty.get("ms", 0)),
		" gated_empty_ms=", int(gated_empty.get("ms", 0)),
		" direct_empty_hits=", int(direct_empty.get("hits", 0)),
		" gated_empty_hits=", int(gated_empty.get("hits", 0)),
		" blocked_iterations=", blocked_iterations,
		" gated_blocked_ms=", int(gated_blocked.get("ms", 0)),
		" gated_blocked_hits=", int(gated_blocked.get("hits", 0)),
		" signature=", signature)
	get_tree().quit(0)

func _run_direct_empty(adapter: MovementBuffAdapter, state: BattleState) -> Dictionary:
	var hits: int = 0
	var started_usec: int = Time.get_ticks_usec()
	for index in range(max(0, empty_iterations)):
		if adapter.is_blocked(state, "player", index % UNIT_IDS.size()):
			hits += 1
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {"ms": elapsed_ms, "hits": hits}

func _run_gated_empty(adapter: MovementBuffAdapter, state: BattleState) -> Dictionary:
	var hits: int = 0
	var blockers_active: bool = adapter.has_movement_blockers()
	var started_usec: int = Time.get_ticks_usec()
	for index in range(max(0, empty_iterations)):
		if blockers_active and adapter.is_blocked(state, "player", index % UNIT_IDS.size()):
			hits += 1
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {"ms": elapsed_ms, "hits": hits}

func _run_gated_blocked(adapter: MovementBuffAdapter, state: BattleState) -> Dictionary:
	var hits: int = 0
	var blockers_active: bool = adapter.has_movement_blockers()
	var started_usec: int = Time.get_ticks_usec()
	for index in range(max(0, blocked_iterations)):
		if blockers_active and adapter.is_blocked(state, "player", index % UNIT_IDS.size()):
			hits += 1
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {"ms": elapsed_ms, "hits": hits}

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	for index in range(UNIT_IDS.size()):
		state.player_team.append(UnitFactory.spawn(UNIT_IDS[index]))
		state.enemy_team.append(UnitFactory.spawn(UNIT_IDS[(index + 3) % UNIT_IDS.size()]))
	return state

func _mix(current: int, value: int) -> int:
	return int((current * 1315423911 + value * 2654435761 + 97) & 0x7fffffffffffffff)
