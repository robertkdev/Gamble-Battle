extends Object
class_name RoleLibrary

const SUPPORTED_KEYS := [
	"health",
	"attack_damage",
	"spell_power",
	"attack_range",
	"armor",
	"magic_resist",
]

const ROLE_DIR := "res://data/roles"
const RoleModifier = preload("res://scripts/game/units/role_modifier.gd")

static var _loaded: bool = false
static var _modifiers: Dictionary = {}
static var _resource_map: Dictionary = {}

static func reload() -> void:
	_modifiers.clear()
	_resource_map.clear()
	var dir := DirAccess.open(ROLE_DIR)
	if dir == null:
		push_warning("RoleLibrary: role directory not found: %s" % ROLE_DIR)
		_loaded = true
		return
	var file := ""
	dir.list_dir_begin()
	while true:
		file = dir.get_next()
		if file == "":
			break
		if file.begins_with("."):
			continue
		if dir.current_is_dir():
			continue
		if not file.ends_with(".tres"):
			continue
		var path := "%s/%s" % [ROLE_DIR, file]
		var res := ResourceLoader.load(path)
		if res is RoleModifier:
			var key := _resolve_role_key(res.role, file)
			_modifiers[key] = {
				"health": int(res.health),
				"attack_damage": int(res.attack_damage),
				"spell_power": int(res.spell_power),
				"attack_range": int(res.attack_range),
				"armor": int(res.armor),
				"magic_resist": int(res.magic_resist),
			}
			_resource_map[key] = path
		else:
			push_warning("RoleLibrary: skipping non RoleModifier resource: %s" % path)
	dir.list_dir_end()
	_loaded = true

static func get_modifier(role: String) -> Dictionary:
	_ensure_loaded()
	if role == null:
		return {}
	var key := _normalize(role)
	if _modifiers.has(key):
		return _modifiers[key].duplicate(true)
	return {}

static func set_modifier(role: String, modifier: Dictionary) -> void:
	var key := _normalize(role)
	_ensure_loaded()
	_modifiers[key] = _filter_supported(modifier)

static func list_roles() -> PackedStringArray:
	_ensure_loaded()
	var out := PackedStringArray()
	for k in _modifiers.keys():
		out.append(String(k))
	out.sort()
	return out

static func get_resource_path(role: String) -> String:
	_ensure_loaded()
	var key := _normalize(role)
	return String(_resource_map.get(key, ""))

static func _ensure_loaded() -> void:
	if not _loaded:
		reload()

static func _normalize(role: String) -> String:
	var s := role.strip_edges().to_lower()
	# Treat spaces and hyphens as underscores so resource Role names like
	# "Mage Assassin" match UnitProfile roles like "mage_assassin".
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	# Collapse duplicate underscores
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

static func _filter_supported(modifier: Dictionary) -> Dictionary:
	var filtered: Dictionary = {}
	if modifier == null:
		return filtered
	for key in SUPPORTED_KEYS:
		if modifier.has(key):
			filtered[key] = modifier[key]
	return filtered

static func _resolve_role_key(role: String, fallback_filename: String) -> String:
	var name := role if role.strip_edges() != "" else fallback_filename.get_basename()
	return _normalize(name)
