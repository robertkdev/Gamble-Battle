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
var role_members_player: Dictionary = {}
var role_members_enemy: Dictionary = {}
var goal_members_player: Dictionary = {}
var goal_members_enemy: Dictionary = {}
var approach_members_player: Dictionary = {}
var approach_members_enemy: Dictionary = {}

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
	var identity_player := _build_identity_membership(state.player_team)
	var identity_enemy := _build_identity_membership(state.enemy_team)
	role_members_player = identity_player.get("roles", {})
	role_members_enemy = identity_enemy.get("roles", {})
	goal_members_player = identity_player.get("goals", {})
	goal_members_enemy = identity_enemy.get("goals", {})
	approach_members_player = identity_player.get("approaches", {})
	approach_members_enemy = identity_enemy.get("approaches", {})

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
	var out: Array[int] = []
	for v in arr:
		out.append(int(v))
	return out

func primary_role_counts(team: String) -> Dictionary:
	return _copy_count_map(_role_map_for(team))

func members_with_primary_role(team: String, role_id: String) -> Array[int]:
	return _copy_indices(_role_map_for(team).get(_normalize_role(role_id), []))

func members_with_primary_goal(team: String, goal_id: String) -> Array[int]:
	return _copy_indices(_goal_map_for(team).get(_normalize_key(goal_id), []))

func members_with_approach(team: String, approach_id: String) -> Array[int]:
	return _copy_indices(_approach_map_for(team).get(_normalize_key(approach_id), []))

func unit_at(team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]

func enemy_team(team: String) -> String:
	return ("enemy" if team == "player" else "player")

func _role_map_for(team: String) -> Dictionary:
	return role_members_player if team == "player" else role_members_enemy

func _goal_map_for(team: String) -> Dictionary:
	return goal_members_player if team == "player" else goal_members_enemy

func _approach_map_for(team: String) -> Dictionary:
	return approach_members_player if team == "player" else approach_members_enemy

func _copy_indices(values) -> Array[int]:
	var out: Array[int] = []
	if values is Array:
		for v in values:
			out.append(int(v))
	elif values is PackedInt32Array:
		for v in values:
			out.append(int(v))
	return out

func _copy_count_map(map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if map == null:
		return out
	for key in map.keys():
		var arr = map[key]
		var count: int = 0
		if arr is Array:
			count = arr.size()
		elif arr is PackedInt32Array:
			count = arr.size()
		out[String(key)] = count
	return out

func _normalize_role(role_id: String) -> String:
	var s := String(role_id).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

func _normalize_key(value: String) -> String:
	return String(value).strip_edges().to_lower()

func _append_index(map: Dictionary, key: String, idx: int) -> void:
	if key == "" or map == null:
		return
	if not map.has(key):
		map[key] = []
	var arr: Array = map[key]
	arr.append(int(idx))

func _build_identity_membership(arr: Array[Unit]) -> Dictionary:
	var roles: Dictionary = {}
	var goals: Dictionary = {}
	var approaches: Dictionary = {}
	if arr == null:
		return {"roles": roles, "goals": goals, "approaches": approaches}
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null:
			continue
		var role_id: String = _normalize_role(u.get_primary_role())
		if role_id == "" and u.roles.size() > 0:
			role_id = _normalize_role(String(u.roles[0]))
		if role_id != "":
			_append_index(roles, role_id, i)
		var goal_id: String = _normalize_key(u.get_primary_goal())
		if goal_id != "":
			_append_index(goals, goal_id, i)
		var seen: Dictionary = {}
		for approach in u.get_approaches():
			var aid := _normalize_key(String(approach))
			if aid == "" or seen.has(aid):
				continue
			seen[aid] = true
			_append_index(approaches, aid, i)
	return {"roles": roles, "goals": goals, "approaches": approaches}

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
