extends Object
class_name RoleLibrary
const Unit := preload("res://scripts/unit.gd")
const PrimaryRole := preload("res://scripts/game/identity/primary_role.gd")
const PrimaryRoleProfile := preload("res://scripts/game/identity/primary_role_profile.gd")

static var _loaded: bool = false
static var _profiles: Dictionary = {}

static func reload() -> void:
	_profiles.clear()
	for role_id in PrimaryRole.ALL:
		var key := _normalize(role_id)
		var path := PrimaryRole.default_profile_path(role_id)
		if path == "":
			push_warning("RoleLibrary: missing default profile path for role '%s'" % role_id)
			continue
		if not ResourceLoader.exists(path):
			push_warning("RoleLibrary: profile resource not found at %s" % path)
			continue
		var res := ResourceLoader.load(path)
		if res is PrimaryRoleProfile:
			_profiles[key] = res
		else:
			push_warning("RoleLibrary: resource at %s is not a PrimaryRoleProfile" % path)
	_loaded = true

static func get_profile(role_id: String) -> PrimaryRoleProfile:
	_ensure_loaded()
	var key := _normalize(role_id)
	return _profiles.get(key, null)

static func base_stats(role_id: String) -> Dictionary:
	var profile := get_profile(role_id)
	if profile == null:
		return {}
	return profile.base_stats.duplicate(true)

static func default_goals(role_id: String) -> Array[String]:
	var profile := get_profile(role_id)
	if profile == null:
		return []
	var out: Array[String] = []
	for g in profile.default_goals:
		out.append(String(g))
	return out

static func default_approaches(role_id: String) -> Array[String]:
	var profile := get_profile(role_id)
	if profile == null:
		return []
	var out: Array[String] = []
	for a in profile.default_approaches:
		out.append(String(a))
	return out

static func validate_unit(role_id: String, unit: Unit) -> Array[String]:
	var profile := get_profile(role_id)
	if profile == null:
		return []
	return profile.validate_unit(unit)

static func list_roles() -> PackedStringArray:
	_ensure_loaded()
	var arr := PackedStringArray()
	for k in _profiles.keys():
		arr.append(String(k))
	arr.sort()
	return arr

static func _ensure_loaded() -> void:
	if not _loaded:
		reload()

static func _normalize(role: String) -> String:
	var s := role.strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

static func _resolve_role_key(role: String, fallback_filename: String) -> String:
	var name := role if role.strip_edges() != "" else fallback_filename.get_basename()
	return _normalize(name)
