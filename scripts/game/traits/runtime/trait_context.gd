extends RefCounted
class_name TraitContext

# Read-only facade shared with trait handlers.
# Exposes engine/state/buffs/ability_system, compiled traits, and membership sets.

const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")

var engine: CombatEngine
var state: BattleState
var buff_system: BuffSystem
var ability_system: AbilitySystem

# Compiled trait data per team
var compiled_player: Dictionary = {}
var compiled_enemy: Dictionary = {}

# Membership maps: trait_id -> Array[int] (unit indices)
var members_player: Dictionary = {}
var members_enemy: Dictionary = {}

func configure(_engine: CombatEngine, _state: BattleState, _buffs: BuffSystem = null, _abilities: AbilitySystem = null) -> void:
	engine = _engine
	state = _state
	buff_system = _buffs
	ability_system = _abilities
	assert(state != null)
	refresh()

func refresh() -> void:
	compiled_player = TraitCompiler.compile(state.player_team)
	compiled_enemy = TraitCompiler.compile(state.enemy_team)
	members_player = _build_membership(state.player_team)
	members_enemy = _build_membership(state.enemy_team)

func tier(team: String, trait_id: String) -> int:
	var t: Dictionary = (compiled_player if team == "player" else compiled_enemy)
	var tiers: Dictionary = t.get("tiers", {})
	return int(tiers.get(String(trait_id), -1))

func count(team: String, trait_id: String) -> int:
	var t: Dictionary = (compiled_player if team == "player" else compiled_enemy)
	var counts: Dictionary = t.get("counts", {})
	return int(counts.get(String(trait_id), 0))

func members(team: String, trait_id: String) -> Array[int]:
	var m: Dictionary = (members_player if team == "player" else members_enemy)
	var arr: Array = m.get(String(trait_id), [])
	# Return a shallow copy to keep context read-only semantics
	var out: Array[int] = []
	for v in arr:
		out.append(int(v))
	return out

func unit_at(team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]

func enemy_team(team: String) -> String:
	return ("enemy" if team == "player" else "player")

func _build_membership(arr: Array[Unit]) -> Dictionary:
	var map: Dictionary = {} # trait_id -> Array[int]
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null:
			continue
		for t in u.traits:
			var id := String(t)
			if not map.has(id):
				map[id] = []
			map[id].append(i)
	return map
