extends RefCounted
class_name RGAConfigLoader

# Load JSON/TRES configs and deep-merge: base -> profile -> CLI.
# Keep pure dictionary outputs to feed into RGASettings.from_dict().

# Public API
static func load_config(path: String) -> Dictionary:
    var p := String(path).strip_edges()
    if p == "":
        return {}
    if p.ends_with(".json"):
        return _load_json(p)
    if p.ends_with(".tres") or p.ends_with(".res"):
        return _load_tres(p)
    # Fallback: try JSON first, then TRES
    var as_json := _load_json(p)
    if not as_json.is_empty():
        return as_json
    return _load_tres(p)

static func merge_dict(base: Dictionary, override: Dictionary) -> Dictionary:
    # Deep-merge dictionaries (override wins). Arrays and scalars are replaced.
    if base == null:
        base = {}
    if override == null:
        return base
    var out := {}
    # Copy base
    for k in base.keys():
        out[k] = base[k]
    # Apply override
    for k2 in override.keys():
        var bv = out.get(k2)
        var ov = override[k2]
        if (bv is Dictionary) and (ov is Dictionary):
            out[k2] = merge_dict(bv, ov)
        else:
            out[k2] = ov
    return out

static func merge_all(base_cfg: Dictionary, profile_cfg: Dictionary, cli_cfg: Dictionary) -> Dictionary:
    return merge_dict(merge_dict(base_cfg, profile_cfg), cli_cfg)

static func load_and_merge(base_path: String, profile_path: String, cli_cfg: Dictionary) -> Dictionary:
    var base_cfg := load_config(base_path)
    var prof_cfg := load_config(profile_path)
    return merge_all(base_cfg, prof_cfg, (cli_cfg if cli_cfg != null else {}))

# --- Internal helpers ---

static func _load_json(path: String) -> Dictionary:
    var fa := FileAccess.open(path, FileAccess.READ)
    if fa == null:
        return {}
    var txt := fa.get_as_text()
    fa.close()
    if String(txt).strip_edges() == "":
        return {}
    var parsed = JSON.parse_string(txt)
    if typeof(parsed) == TYPE_DICTIONARY:
        return parsed
    return {}

static func _load_tres(path: String) -> Dictionary:
    if not ResourceLoader.exists(path):
        # Try FileAccess existence in case path is user:// or absolute
        if not FileAccess.file_exists(path):
            return {}
    var res = load(path)
    if res == null:
        return {}
    # Prefer common property names holding a Dictionary
    if res.has_method("to_dict"):
        var d = res.to_dict()
        return (d if d is Dictionary else {})
    for key in ["data", "config", "settings"]:
        if res.has_method("get") and res.get(key) is Dictionary:
            return res.get(key)
    # Generic: export properties into a dictionary, excluding engine internals
    var out := {}
    if res.has_method("get_property_list"):
        var props: Array = res.get_property_list()
        for p in props:
            var n := String(p.get("name", ""))
            if n == "" or n == "script" or n.begins_with("resource_") or n.begins_with("_"):
                continue
            out[n] = res.get(n)
    return out

