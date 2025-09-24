extends RefCounted
class_name RollResult

var damage: int = 0
var crit: bool = false

func _init(_damage: int = 0, _crit: bool = false) -> void:
    damage = int(_damage)
    crit = bool(_crit)

