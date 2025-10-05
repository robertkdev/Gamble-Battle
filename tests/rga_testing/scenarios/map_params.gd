extends RefCounted
class_name RGAMapParams

const RGARandom = preload("res://tests/rga_testing/util/random.gd")

var openness: float = 0.7
var choke_count: int = 0
var obstacle_density: float = 0.25
var artillery_range: float = 8.0
var tile_size: float = 1.0
var center: Vector2 = Vector2.ZERO
var map_id: String = "open_field_variable"
var extras: Dictionary = {}

static func from_dict(values: Dictionary) -> RGAMapParams:
    var p := RGAMapParams.new()
    p.apply(values)
    return p

func apply(values: Dictionary) -> void:
    if values == null:
        return
    if values.has("openness"):
        openness = float(values.get("openness", openness))
    if values.has("choke_count"):
        choke_count = int(values.get("choke_count", choke_count))
    if values.has("obstacle_density"):
        obstacle_density = float(values.get("obstacle_density", obstacle_density))
    if values.has("artillery_range"):
        artillery_range = float(values.get("artillery_range", artillery_range))
    if values.has("tile_size"):
        tile_size = float(values.get("tile_size", tile_size))
    if values.has("center"):
        var c := values.get("center")
        if c is Vector2:
            center = c
        elif c is Array and c.size() >= 2:
            center = Vector2(float(c[0]), float(c[1]))
    if values.has("map_id"):
        map_id = String(values.get("map_id", map_id))
    var known := {
        "openness": true,
        "choke_count": true,
        "obstacle_density": true,
        "artillery_range": true,
        "tile_size": true,
        "center": true,
        "map_id": true,
    }
    extras = {}
    for key in values.keys():
        if not known.has(key):
            extras[key] = values[key]

func to_dict(include_extras: bool = true) -> Dictionary:
    var out := {
        "openness": openness,
        "choke_count": choke_count,
        "obstacle_density": obstacle_density,
        "artillery_range": artillery_range,
        "tile_size": tile_size,
        "center": center,
        "map_id": map_id,
    }
    if include_extras and extras != null:
        for k in extras.keys():
            out[k] = extras[k]
    return out

func clone() -> RGAMapParams:
    var c := RGAMapParams.new()
    c.openness = openness
    c.choke_count = choke_count
    c.obstacle_density = obstacle_density
    c.artillery_range = artillery_range
    c.tile_size = tile_size
    c.center = center
    c.map_id = map_id
    c.extras = extras.duplicate(true)
    return c

func validate() -> bool:
    var ok := true
    if is_nan(openness) or openness < 0.1:
        openness = clamp(openness if not is_nan(openness) else 0.7, 0.1, 1.0)
        ok = false
    elif openness > 1.0:
        openness = 1.0
        ok = false

    if choke_count < 0:
        choke_count = 0
        ok = false
    elif choke_count > 8:
        choke_count = 8
        ok = false

    if is_nan(obstacle_density) or obstacle_density < 0.0:
        obstacle_density = clamp(obstacle_density if not is_nan(obstacle_density) else 0.25, 0.0, 1.0)
        ok = false
    elif obstacle_density > 1.0:
        obstacle_density = 1.0
        ok = false

    if is_nan(artillery_range) or artillery_range < 1.0:
        artillery_range = max(4.0, artillery_range if not is_nan(artillery_range) else 8.0)
        ok = false

    if is_nan(tile_size) or tile_size <= 0.0:
        tile_size = 1.0
        ok = false

    if is_nan(center.x) or is_nan(center.y):
        center = Vector2.ZERO
        ok = false

    map_id = map_id.strip_edges()
    if map_id == "":
        map_id = "open_field_variable"
        ok = false

    return ok

func hash() -> String:
    var quant := [
        _quantize(openness),
        float(choke_count),
        _quantize(obstacle_density),
        _quantize(artillery_range, 0.01),
        _quantize(tile_size, 0.001),
        _quantize(center.x, 0.01),
        _quantize(center.y, 0.01),
    ]
    var parts: Array[String] = []
    for val in quant:
        parts.append(String(val))
    parts.append(map_id)
    var extras_keys := extras.keys()
    extras_keys.sort()
    for k in extras_keys:
        parts.append(String(k) + "=" + String(extras[k]))
    var builder := ""
    for i in range(parts.size()):
        if i > 0:
            builder += "|"
        builder += parts[i]
    var h := RGARandom.hash_string64(builder)
    return "%016X" % (h & RGARandom.MASK64)

func _quantize(value: float, step: float = 0.001) -> float:
    return snapped(value, step)
