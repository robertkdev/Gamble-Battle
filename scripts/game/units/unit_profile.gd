extends Resource
class_name UnitProfile

const RoleLibrary := preload("res://scripts/game/units/role_library.gd")
const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")

@export var id: String = ""
@export var name: String = ""
@export var sprite_path: String = ""
@export var ability_id: String = ""
@export var traits: Array[String] = []
# Legacy roles by string (kept for backward compatibility)
@export var roles: Array[String] = []
@export var cost: int = 1
@export var level: int = 1

@export var primary_role: String = ""
@export var primary_goal: String = ""
@export var approaches: Array[String] = []
@export var alt_goals: Array[String] = []
@export var identity: UnitIdentity = null

func role_names() -> PackedStringArray:
	var out := PackedStringArray()
	# Only use legacy string list now
	for s in roles:
		if String(s).strip_edges() != "":
			out.append(RoleLibrary._resolve_role_key(String(s), ""))
	return out
