extends RefCounted
class_name RGAUnitIdentityUtils

# Normalizes role identifiers to the canonical lowercase-with-underscores form used by BalanceRunner.
static func normalize_role_id(value) -> String:
    return _normalize_role_id(value)

# Normalizes goal identifiers to lowercase (no underscore replacement).
static func normalize_goal_id(value) -> String:
    return _normalize_goal_id(value)

# Normalizes an array of approaches (strings) and returns a deduplicated Array[String].
static func normalize_approaches(values) -> Array[String]:
    return _normalized_identity_list(values)

# Splits an approach string (e.g., "burst;zone") into an array, normalizing each entry.
static func split_approaches(text: String, delimiter: String = ";") -> Array[String]:
    if String(text).strip_edges() == "":
        return []
    return normalize_approaches(String(text).split(delimiter))

# Joins an array/PackedStringArray of approaches into a canonical semicolon-delimited string.
static func join_approaches(values, delimiter: String = ";") -> String:
    var arr := normalize_approaches(values)
    return PackedStringArray(arr).join(delimiter)

static func _normalize_role_id(value) -> String:
    var s := String(value).strip_edges().to_lower()
    s = s.replace(" ", "_")
    s = s.replace("-", "_")
    while s.find("__") != -1:
        s = s.replace("__", "_")
    return s

static func _normalize_goal_id(value) -> String:
    return String(value).strip_edges().to_lower()

static func _normalized_identity_list(values) -> Array[String]:
    return _merge_normalized_lists([], values)

static func _merge_normalized_lists(base: Array[String], extra) -> Array[String]:
    var out: Array[String] = []
    var seen: Dictionary = {}
    if base != null:
        for entry in base:
            var norm := _normalize_goal_id(entry)
            if norm != "" and not seen.has(norm):
                seen[norm] = true
                out.append(norm)
    if extra == null:
        return out
    if extra is Array or extra is PackedStringArray:
        for entry2 in extra:
            var norm2 := _normalize_goal_id(entry2)
            if norm2 != "" and not seen.has(norm2):
                seen[norm2] = true
                out.append(norm2)
    else:
        var norm_single := _normalize_goal_id(extra)
        if norm_single != "" and not seen.has(norm_single):
            seen[norm_single] = true
            out.append(norm_single)
    out.sort()
    return out
