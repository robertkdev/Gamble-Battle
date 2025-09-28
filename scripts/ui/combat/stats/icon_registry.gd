extends Object
class_name StatsIconRegistry

const TextureUtils := preload("res://scripts/util/texture_utils.gd")

var _map: Dictionary = {}
var _colors: Dictionary = {
    "damage": Color(0.95, 0.55, 0.20),
    "taken": Color(0.85, 0.25, 0.25),
    "dps": Color(0.25, 0.6, 1.0),
    "healing": Color(0.25, 0.8, 0.35),
    "shield": Color(0.2, 0.85, 0.85),
    "cc": Color(0.95, 0.85, 0.35),
    # stats
    "hp": Color(0.9, 0.3, 0.35),
    "ad": Color(0.95, 0.55, 0.2),
    "ap": Color(0.45, 0.55, 1.0),
    "as": Color(0.75, 0.55, 0.95),
    "crit": Color(1.0, 0.85, 0.3),
    "range": Color(0.7, 0.7, 0.8),
    "armor": Color(0.6, 0.75, 0.85),
    "mr": Color(0.55, 0.75, 0.95),
    "move": Color(0.6, 0.9, 0.9),
    "mana": Color(0.4, 0.7, 1.0),
}

func register_icon(key: String, path: String) -> void:
    if String(key) == "" or String(path) == "":
        return
    _map[String(key)] = String(path)

func get_icon(key: String, size: int = 24) -> Texture2D:
    var k := String(key)
    # Path mapping (assets/icons/stats/<key>.png by convention)
    var path: String = _map.get(k, "")
    if path == "":
        var candidate := "res://assets/icons/stats/%s.png" % k
        # Defer to loader; if it fails, produce fallback
        var tex := load(candidate)
        if tex != null:
            return tex
    else:
        var tex2 := load(path)
        if tex2 != null:
            return tex2
    # Fallback: colored circle
    var color: Color = _colors.get(k, Color(0.6, 0.65, 0.75))
    return TextureUtils.make_circle_texture(color, max(8, size))

