extends RefCounted
class_name RGAIdCodec

# Tiny ID codec: maps strings to integer codes per namespace.
# Use-case: compress NDJSON by replacing repeated strings with small ints
# and writing a single dictionary block per shard.

const RESERVED_UNKNOWN: int = 0

var _ns_maps: Dictionary = {} # ns -> { "map": {str->id}, "list": Array[String] }

func clear() -> void:
    _ns_maps.clear()

func namespaces() -> Array[String]:
    var out: Array[String] = []
    for k in _ns_maps.keys():
        out.append(String(k))
    out.sort()
    return out

func encode(ns: String, value: String) -> int:
    var key := String(value).strip_edges()
    if key == "":
        return RESERVED_UNKNOWN
    var name := String(ns)
    var rec := _ensure_ns(name)
    var m: Dictionary = rec.get("map", {})
    var lst: Array = rec.get("list", [])
    if m.has(key):
        return int(m[key])
    lst.append(key)
    var assigned := lst.size() # 1-based ids; 0 is reserved unknown
    m[key] = assigned
    rec["list"] = lst
    rec["map"] = m
    _ns_maps[name] = rec
    return assigned

func decode(ns: String, id: int) -> String:
    var rec := _ensure_ns(String(ns))
    var lst: Array = rec.get("list", [])
    if id <= 0 or id > lst.size():
        return ""
    return String(lst[id - 1])

func encode_many(ns: String, values) -> PackedInt32Array:
    var out: PackedInt32Array = []
    if values == null:
        return out
    var arr: Array = []
    if values is Array:
        arr = values
    elif values is PackedStringArray:
        for v in values:
            arr.append(v)
    elif typeof(values) == TYPE_STRING:
        arr = [values]
    for v in arr:
        out.append(encode(ns, String(v)))
    return out

func export_dictionary() -> Dictionary:
    # Compact snapshot for embedding in telemetry: ns -> ["value1","value2",...]
    var out := {}
    for ns in namespaces():
        var rec := _ensure_ns(ns)
        var lst: Array = rec.get("list", [])
        out[ns] = lst.duplicate()
    return out

func import_dictionary(d: Dictionary) -> void:
    # Replace current state with the given dictionary snapshot.
    _ns_maps.clear()
    if d == null:
        return
    for k in d.keys():
        var ns := String(k)
        var lst: Array = []
        var src = d[k]
        if src is Array:
            for v in src:
                lst.append(String(v))
        elif src is PackedStringArray:
            for v2 in src:
                lst.append(String(v2))
        else:
            continue
        var m: Dictionary = {}
        for i in range(lst.size()):
            m[lst[i]] = i + 1
        _ns_maps[ns] = {"map": m, "list": lst}

func size(ns: String) -> int:
    var rec := _ensure_ns(String(ns))
    var lst: Array = rec.get("list", [])
    return lst.size()

func _ensure_ns(ns: String) -> Dictionary:
    if _ns_maps.has(ns):
        return _ns_maps[ns]
    var rec := {"map": {}, "list": []}
    _ns_maps[ns] = rec
    return rec
