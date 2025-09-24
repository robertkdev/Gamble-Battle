extends RefCounted
class_name ManaOnAttack

const Mana := preload("res://scripts/game/stats/mana.gd")

var state: BattleState
var ability_system: AbilitySystem = null
var buff_system: BuffSystem = null

func configure(_state: BattleState, _ability_system: AbilitySystem, _buff_system: BuffSystem) -> void:
    state = _state
    ability_system = _ability_system
    buff_system = _buff_system

func gain(team: String, index: int, src: Unit) -> Dictionary:
    if src == null:
        return {"gained": 0, "cast": false, "mana": 0}
    return Mana.gain_on_attack(state, team, index, src, ability_system, buff_system)

