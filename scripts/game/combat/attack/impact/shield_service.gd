extends RefCounted
class_name ShieldService

var buff_system: BuffSystem = null

func configure(_buff_system: BuffSystem) -> void:
    buff_system = _buff_system

func absorb(u: Unit, incoming: int) -> Dictionary:
    var result := {"leftover": max(0, incoming), "absorbed": 0}
    if buff_system == null or u == null or incoming <= 0:
        return result
    var r: Dictionary = buff_system.absorb_with_shields(u, incoming)
    result.leftover = int(r.get("leftover", incoming))
    result.absorbed = int(r.get("absorbed", 0))
    return result

