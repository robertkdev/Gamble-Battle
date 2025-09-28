extends RefCounted
class_name ShopOffer

# Pure data for a single shop offer.
# Keep minimal and UI-agnostic.

var id: String = ""
var name: String = ""
var cost: int = 0
var sprite_path: String = ""

func _init(_id: String = "", _name: String = "", _cost: int = 0, _sprite_path: String = "") -> void:
    id = _id
    name = _name
    cost = int(_cost)
    sprite_path = _sprite_path

