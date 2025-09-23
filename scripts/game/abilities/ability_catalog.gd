extends Object
class_name AbilityCatalog

# Maps ability_id -> implementation script (cached) and metadata def (optional).

const AbilityDef = preload("res://scripts/game/abilities/ability_def.gd")

static var _script_cache: Dictionary = {}      # ability_id -> Script
static var _def_cache: Dictionary = {}         # ability_id -> AbilityDef
static var _override_paths: Dictionary = {}    # ability_id -> String path (runtime overrides)

static func def_path_for(ability_id: String) -> String:
	return "res://data/abilities/%s.tres" % ability_id

static func impl_path_for(ability_id: String) -> String:
	# Default convention: scripts/game/abilities/impls/<ability_id>.gd
	return "res://scripts/game/abilities/impls/%s.gd" % ability_id

static func register_override(ability_id: String, script_path: String) -> void:
	if ability_id.strip_edges() == "" or script_path.strip_edges() == "":
		return
	_override_paths[ability_id] = script_path
	# Clear cached script so next get_impl_script reflects override
	if _script_cache.has(ability_id):
		_script_cache.erase(ability_id)

static func get_def(ability_id: String) -> AbilityDef:
	if _def_cache.has(ability_id):
		return _def_cache[ability_id]
	var path := def_path_for(ability_id)
	if ResourceLoader.exists(path):
		var def: AbilityDef = load(path)
		if def != null:
			_def_cache[ability_id] = def
			return def
	return null

static func resolve_impl_path(ability_id: String) -> String:
	if _override_paths.has(ability_id):
		var p: String = String(_override_paths[ability_id])
		if ResourceLoader.exists(p):
			return p
	var def: AbilityDef = get_def(ability_id)
	if def != null:
		# Optional data-driven override: impl_path in the AbilityDef resource
		var ov_var = def.get("impl_path")
		var ov: String = ("" if ov_var == null else String(ov_var))
		if ov != "" and ResourceLoader.exists(ov):
			return ov
	var conv := impl_path_for(ability_id)
	if ResourceLoader.exists(conv):
		return conv
	return ""

static func get_impl_script(ability_id: String) -> Script:
	if _script_cache.has(ability_id):
		return _script_cache[ability_id]
	var path := resolve_impl_path(ability_id)
	if path == "":
		return null
	var scr: Script = load(path)
	if scr != null:
		_script_cache[ability_id] = scr
	return scr

static func new_instance(ability_id: String):
	var scr: Script = get_impl_script(ability_id)
	if scr == null:
		return null
	return scr.new()

static func clear_caches() -> void:
	_script_cache.clear()
	_def_cache.clear()
	_override_paths.clear()
