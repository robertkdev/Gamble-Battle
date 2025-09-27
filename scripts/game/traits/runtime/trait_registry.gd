extends RefCounted
class_name TraitRegistry

# TraitRegistry maps trait id -> handler script and instantiates them on demand.
# Convention-first: scripts/game/traits/effects/<trait_id_lower>.gd
# Small override map supports exceptions without growing a central list.

var _overrides: Dictionary = {}   # trait_id -> script path

func register(trait_id: String, script_path: String) -> void:
	if String(trait_id).strip_edges() == "" or String(script_path).strip_edges() == "":
		return
	_overrides[String(trait_id)] = String(script_path)

func unregister(trait_id: String) -> void:
	_overrides.erase(String(trait_id))

func has_override(trait_id: String) -> bool:
	return _overrides.has(String(trait_id))

func _default_path_for(trait_id: String) -> String:
	var id_lower: String = String(trait_id).to_lower()
	return "res://scripts/game/traits/effects/%s.gd" % id_lower

func instantiate(trait_id: String):
	var key := String(trait_id)
	var path: String = ""
	if _overrides.has(key):
		path = String(_overrides[key])
	else:
		var conv := _default_path_for(key)
		if ResourceLoader.exists(conv):
			path = conv
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scr: Script = load(path)
	return (scr.new() if scr != null else null)

func instantiate_for_all(trait_ids: Array) -> Dictionary:
	var out: Dictionary = {} # trait_id -> handler
	if trait_ids == null:
		return out
	for t in trait_ids:
		var id := String(t)
		var h = instantiate(id)
		if h != null:
			out[id] = h
	return out
