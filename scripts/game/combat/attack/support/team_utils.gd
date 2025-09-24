extends Object
class_name TeamUtils

# Team and unit helpers consolidated to avoid duplication.

static func unit_array(state: BattleState, team: String) -> Array[Unit]:
    if state == null:
        return []
    return state.player_team if team == "player" else state.enemy_team

static func unit_at(state: BattleState, team: String, idx: int) -> Unit:
    var arr: Array[Unit] = unit_array(state, team)
    if idx < 0 or idx >= arr.size():
        return null
    return arr[idx]

static func other_team(team: String) -> String:
    return "enemy" if team == "player" else "player"

static func enemy_team_array(state: BattleState, team: String) -> Array[Unit]:
    return unit_array(state, other_team(team))

