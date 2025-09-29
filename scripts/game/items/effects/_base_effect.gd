extends RefCounted
class_name ItemEffectBase

var manager: CombatManager = null
var engine: CombatEngine = null
var buff_system: BuffSystem = null

func configure(_manager: CombatManager, _engine: CombatEngine, _buff_system: BuffSystem) -> void:
    manager = _manager
    engine = _engine
    buff_system = _buff_system

# Unified event entrypoint: override in concrete effects.
func on_event(_unit: Unit, _event: String, _data: Dictionary) -> void:
    pass

func _team_index_of(u: Unit) -> Dictionary:
    var res := {"team": "", "index": -1}
    if manager == null or u == null:
        return res
    for i in range(manager.player_team.size()):
        if manager.player_team[i] == u:
            res.team = "player"
            res.index = i
            return res
    for j in range(manager.enemy_team.size()):
        if manager.enemy_team[j] == u:
            res.team = "enemy"
            res.index = j
            return res
    return res

func _state() -> BattleState:
    return (engine.state if engine != null else null)

func _other_team(team: String) -> String:
    return "enemy" if team == "player" else "player"

