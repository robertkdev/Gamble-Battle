extends Resource
class_name UnitIdentity

@export var primary_role: String = ""
@export var primary_goal: String = ""
@export var approaches: Array[String] = []
@export var alt_goals: Array[String] = []

func approaches_packed() -> PackedStringArray:
    var arr := PackedStringArray()
    for a in approaches:
        arr.append(String(a))
    return arr

func alt_goals_packed() -> PackedStringArray:
    var arr := PackedStringArray()
    for g in alt_goals:
        arr.append(String(g))
    return arr