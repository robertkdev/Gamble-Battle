extends RefCounted
class_name ShopOffer

# Pure data for a single shop offer.
# Keep minimal and UI-agnostic.

var id: String = ""
var name: String = ""
var cost: int = 0
var sprite_path: String = ""
var roles: Array[String] = []
var traits: Array[String] = []

func _init(_id: String = "", _name: String = "", _cost: int = 0, _sprite_path: String = "", _roles = null, _traits = null) -> void:
	id = _id
	name = _name
	cost = int(_cost)
	sprite_path = _sprite_path
	roles = _to_string_array(_roles)
	traits = _to_string_array(_traits)

static func _to_string_array(values) -> Array[String]:
	var out: Array[String] = []
	if values == null:
		return out
	if values is Array or values is PackedStringArray:
		for v in values:
			out.append(String(v))
	else:
		out.append(String(values))
	return out
