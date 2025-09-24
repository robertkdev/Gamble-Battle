extends RefCounted
class_name MultishotSelector

var rng: RandomNumberGenerator = null
var hooks

func configure(_rng: RandomNumberGenerator, _hooks) -> void:
    rng = _rng
    hooks = _hooks

func _enemy_team_name(team: String) -> String:
    return "enemy" if team == "player" else "player"

func _enemy_arr(state: BattleState, team: String) -> Array[Unit]:
    return state.enemy_team if team == "player" else state.player_team

func _alive_indices(state: BattleState, team: String) -> Array[int]:
    var arr: Array[int] = []
    var enemies: Array[Unit] = _enemy_arr(state, team)
    for i in range(enemies.size()):
        var u: Unit = enemies[i]
        if u != null and u.is_alive():
            arr.append(i)
    return arr

func pick_base_target(state: BattleState, team: String, shooter_index: int, default_idx: int) -> int:
    if state == null:
        return default_idx
    var extra: int = 0
    if hooks != null and hooks.has_method("nyxa_extra_shots"):
        extra = int(hooks.nyxa_extra_shots(state, team, shooter_index))
    if extra <= 0:
        return default_idx
    var alive: Array[int] = _alive_indices(state, team)
    if alive.is_empty():
        return default_idx
    return (rng.randi_range(0, alive.size() - 1) if rng != null else alive[0])

func extra_targets(state: BattleState, team: String, shooter_index: int) -> Array[int]:
    var out: Array[int] = []
    if state == null:
        return out
    var extra: int = 0
    if hooks != null and hooks.has_method("nyxa_extra_shots"):
        extra = int(hooks.nyxa_extra_shots(state, team, shooter_index))
    if extra <= 0:
        return out
    var alive: Array[int] = _alive_indices(state, team)
    if alive.is_empty():
        return out
    for _i in range(extra):
        var pick_idx: int = (rng.randi_range(0, alive.size() - 1) if rng != null else 0)
        out.append(alive[pick_idx])
    return out

