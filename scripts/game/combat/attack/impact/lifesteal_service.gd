extends RefCounted
class_name LifestealService

const HealingService := preload("res://scripts/game/traits/runtime/healing_service.gd")

var state: BattleState = null
var buff_system: BuffSystem = null

func configure(_state: BattleState, _buff_system: BuffSystem) -> void:
    state = _state
    buff_system = _buff_system

func apply(team: String, index: int, dealt: int) -> int:
    if state == null or dealt <= 0:
        return 0
    var src: Unit = _unit_at(team, index)
    if src == null or not src.is_alive():
        return 0
    var ls: float = float(src.lifesteal)
    if ls <= 0.0:
        return 0
    var base_heal: float = float(max(0, dealt)) * ls
    var hres: Dictionary = HealingService.apply_heal(state, buff_system, team, index, base_heal)
    return int(hres.get("healed", 0))

func _unit_at(team: String, idx: int) -> Unit:
    var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
    if idx < 0 or idx >= arr.size():
        return null
    return arr[idx]
