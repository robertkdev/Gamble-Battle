extends Resource
class_name TraitDef

@export var id: String = ""
@export var name: String = ""
# Ordered thresholds for activation (e.g., [2,4,6,8])
@export var thresholds: Array[int] = []
@export var description: String = ""

