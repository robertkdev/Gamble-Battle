extends Resource
class_name ApproachDef

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var category: String = "" # offense | defense | mobility | utility
@export var conflicts_with: Array[String] = []