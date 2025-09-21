extends RefCounted
class_name TargetController

const Targeting := preload("res://scripts/game/combat/targeting.gd")

var state: BattleState
var selector: Callable = Callable()
var _arena_resolver: Callable

func _init() -> void:
	_arena_resolver = Callable(self, "_resolve_for_arena")

func configure(_state: BattleState, _selector: Callable = Callable()) -> void:
	state = _state
	selector = _selector if _selector.is_valid() else Callable()
	_sync_arrays()
	_prime_targets()

func current_target(team: String, shooter_index: int) -> int:
	_sync_arrays()
	if shooter_index < 0:
		return -1
	var targets: Array[int] = _targets_for(team)
	if shooter_index >= targets.size():
		return -1
	var idx: int = int(targets[shooter_index])
	if _is_target_alive(team, idx):
		return idx
	return refresh_target(team, shooter_index)

func refresh_target(team: String, shooter_index: int) -> int:
	_sync_arrays()
	if shooter_index < 0:
		return -1
	var targets: Array[int] = _targets_for(team)
	if shooter_index >= targets.size():
		return -1
	var selection: int = _select_target(team, shooter_index)
	targets[shooter_index] = selection
	return selection

func resolver_for_arena() -> Callable:
	return _arena_resolver

func target_array(team: String) -> Array[int]:
	_sync_arrays()
	return _targets_for(team)

func _resolve_for_arena(team: String, shooter_index: int) -> int:
	return current_target(team, shooter_index)

func _sync_arrays() -> void:
	if not state:
		return
	state.player_targets = _resized(state.player_targets, state.player_team.size())
	state.enemy_targets = _resized(state.enemy_targets, state.enemy_team.size())

func _targets_for(team: String) -> Array[int]:
	return state.player_targets if team == "player" else state.enemy_targets

func _enemy_team_for(team: String) -> Array[Unit]:
	return state.enemy_team if team == "player" else state.player_team

func _enemy_team_name(team: String) -> String:
	return "enemy" if team == "player" else "player"

func _is_target_alive(team: String, idx: int) -> bool:
	var enemy_team: Array[Unit] = _enemy_team_for(team)
	return BattleState.is_target_alive(enemy_team, idx)

func _select_target(team: String, shooter_index: int) -> int:
	var enemy_team: Array[Unit] = _enemy_team_for(team)
	var enemy_team_name: String = _enemy_team_name(team)
	if selector.is_valid():
		var result = selector.call(team, shooter_index, enemy_team_name)
		if typeof(result) == TYPE_INT:
			var idx: int = int(result)
			if BattleState.is_target_alive(enemy_team, idx):
				return idx
	return Targeting.pick_first_alive(enemy_team)

func _prime_targets() -> void:
	if not state:
		return
	for i in range(state.player_team.size()):
		refresh_target("player", i)
	for j in range(state.enemy_team.size()):
		refresh_target("enemy", j)

func _resized(existing: Array, desired: int) -> Array[int]:
	var out: Array[int] = []
	if desired < 0:
		desired = 0
	var count: int = min(existing.size(), desired)
	for i in range(count):
		out.append(int(existing[i]))
	while out.size() < desired:
		out.append(-1)
	return out

