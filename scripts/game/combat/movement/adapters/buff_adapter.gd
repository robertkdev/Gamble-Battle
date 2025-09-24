extends RefCounted
class_name MovementBuffAdapter

# MovementBuffAdapter
# Lightweight shim so Movement can query status from BuffSystem without taking
# a hard dependency on engine internals. Treats the presence of a stun or a
# generic root tag as blocking movement for that unit.

var buff_system: BuffSystem = null

func configure(_buff_system: BuffSystem) -> void:
    buff_system = _buff_system

func is_blocked(state: BattleState, team: String, idx: int) -> bool:
    if buff_system == null or state == null:
        return false
    var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
    if idx < 0 or idx >= arr.size():
        return false
    var u: Unit = arr[idx]
    if u == null:
        return false
    if buff_system.is_stunned(u):
        return true
    # Interpret presence of a generic "root" tag (or "rooted") as movement block.
    if buff_system.has_tag(state, team, idx, "root"):
        return true
    if buff_system.has_tag(state, team, idx, "rooted"):
        return true
    return false
