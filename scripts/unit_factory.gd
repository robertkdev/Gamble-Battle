extends Object
class_name UnitFactory

static var _cache: Dictionary = {}
static func clear_cache() -> void:
	_cache.clear()

const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")

const IdentityValidator := preload("res://scripts/game/identity/identity_validator.gd")
const RoleLibrary = preload("res://scripts/game/units/role_library.gd")
const UnitScaler := preload("res://scripts/game/units/unit_scaler.gd")
const Trace := preload("res://scripts/util/trace.gd")

# Validation toggle for BalanceRunner and tools
static var role_invariant_fail_fast: bool = false

# Role clusters for analytics/validation
static func cluster_for_roles(roles: Array) -> String:
	var rset: Dictionary = {}
	if roles != null:
		for r in roles:
			var raw := String(r)
			if raw == "":
				continue
			for part in raw.split("|", false):
				var key := _sanitize_role_id(String(part))
				if key != "":
					rset[key] = true
	if rset.has("assassin") or rset.has("mage_assassin"):
		return "assassin"
	if rset.has("marksman"):
		return "marksman"
	if rset.has("mage"):
		return "mage"
	if rset.has("support"):
		return "support"
	if rset.has("tank") or rset.has("hybrid_tank") or rset.has("brawler_tank"):
		return "tank"
	if rset.has("brawler") or rset.has("hybrid_brawler"):
		return "bruiser"
	return "other"

# Quick role identity sanity checks (post role profile, pre-abilities)
# Returns an array of human-readable violations
static func validate_role_invariants(u: Unit) -> Array[String]:
	var issues: Array[String] = []
	if u == null:
		return issues
	var role_id := _primary_role_from_unit(u)
	var goal_id := String(u.primary_goal).strip_edges()
	issues.append_array(IdentityValidator.validate(role_id, goal_id, u.get_approaches()))
	if role_id != "":
		issues.append_array(RoleLibrary.validate_unit(role_id, u))
	if role_invariant_fail_fast and not issues.is_empty():
		for issue in issues:
			push_error("UnitFactory invariant (%s): %s" % [u.id, issue])
		assert(false)
	return issues

static func _def_path(id: String) -> String:
	return "res://data/units/%s.tres" % id

static func _load_def(id: String) -> UnitDef:
	Trace.step("UnitFactory._load_def: " + id)
	var path := _def_path(id)
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var out_def: UnitDef = null
		# Support both legacy UnitDef .tres and new UnitProfile .tres
		if res is UnitDef:
			out_def = res
		elif res is UnitProfile:
			var p: UnitProfile = res
			out_def = load("res://scripts/game/units/unit_def.gd").new()
			out_def.id = p.id
			out_def.name = p.name
			out_def.sprite_path = p.sprite_path
			out_def.traits = p.traits.duplicate()
			out_def.roles = p.roles.duplicate()
			out_def.ability_id = p.ability_id
			out_def.cost = p.cost
			out_def.level = p.level
			out_def.primary_role = p.primary_role
			out_def.primary_goal = p.primary_goal
			out_def.approaches = p.approaches.duplicate()
			out_def.alt_goals = p.alt_goals.duplicate()
			out_def.identity = p.identity
		else:
			push_warning("UnitFactory: unsupported unit resource '%s'" % path)
		if out_def != null:
			_cache[path] = out_def
			return out_def
	push_warning("UnitFactory: unit def not found '%s'" % id)
	return null

static func spawn(id: String) -> Unit:
	Trace.step("UnitFactory.spawn: " + id)
	var d: UnitDef = _load_def(id)
	if d == null:
		Trace.step("UnitFactory.spawn: def missing for " + id)
		return null
	var u: Unit = _from_def(d)
	Trace.step("UnitFactory.spawn: built unit " + id)
	return u

static func _from_def(d: UnitDef) -> Unit:
	var u := Unit.new()
	u.id = d.id
	u.name = d.name
	u.sprite_path = d.sprite_path
	u.ability_id = d.ability_id
	u.traits = d.traits.duplicate()
	u.roles = d.roles.duplicate()
	u.cost = int(d.cost)
	u.level = int(d.level)

	var identity_resource: UnitIdentity = d.identity
	var primary_role_id := _resolve_primary_role(d)
	var primary_goal_id := _resolve_primary_goal(identity_resource, d, primary_role_id)
	var approaches := _resolve_approaches(identity_resource, d, primary_role_id)
	var alt_goals := _resolve_alt_goals(identity_resource, d, primary_role_id, primary_goal_id)
	u.set_identity_data(primary_role_id, primary_goal_id, approaches, alt_goals, identity_resource)

	# Use UnitDef base defaults as the starting point for stats.
	var base_def: UnitDef = d.get_script().new()

	u.max_hp = max(1, int(base_def.max_hp))
	u.hp = u.max_hp
	u.hp_regen = max(0.0, float(base_def.hp_regen))

	u.attack_damage = max(0.0, float(base_def.attack_damage))
	u.spell_power = max(0.0, float(base_def.spell_power))
	u.attack_speed = max(0.01, float(base_def.attack_speed))
	u.crit_chance = clampf(float(base_def.crit_chance), 0.0, 0.95)
	u.crit_damage = max(1.0, float(base_def.crit_damage))
	u.true_damage = max(0.0, float(base_def.true_damage))
	u.lifesteal = clampf(float(base_def.lifesteal), 0.0, 0.9)
	u.attack_range = max(1, int(base_def.attack_range))

	u.armor = max(0.0, float(base_def.armor))
	u.magic_resist = max(0.0, float(base_def.magic_resist))
	u.armor_pen_flat = max(0.0, float(base_def.armor_pen_flat))
	u.armor_pen_pct = clampf(float(base_def.armor_pen_pct), 0.0, 1.0)
	u.mr_pen_flat = max(0.0, float(base_def.mr_pen_flat))
	u.mr_pen_pct = clampf(float(base_def.mr_pen_pct), 0.0, 1.0)

	# Resource & casting
	u.mana_max = max(0, int(base_def.mana))
	u.mana_start = int(clamp(float(base_def.mana_start), 0.0, float(u.mana_max)))
	u.mana_regen = max(0.0, float(base_def.mana_regen))
	u.cast_speed = max(0.1, float(base_def.cast_speed))
	u.mana = u.mana_start

	# Override with role profile base stats when available
	if primary_role_id != "":
		var role_base := RoleLibrary.base_stats(primary_role_id)
		if not role_base.is_empty():
			_apply_base_stats(u, role_base)

	# If unit has an ability, prefer its defined base_cost for mana_max (ability cost)
	if String(u.ability_id) != "":
		var AbilityCatalog = load("res://scripts/game/abilities/ability_catalog.gd")
		if AbilityCatalog and AbilityCatalog.has_method("get_def"):
			var adef = AbilityCatalog.get_def(String(u.ability_id))
			if adef and int(adef.base_cost) > 0:
				u.mana_max = int(adef.base_cost)

	# Capture base values before scaling
	var base_vals := {
		"max_hp": float(u.max_hp),
		"hp_regen": float(u.hp_regen),
		"attack_damage": float(u.attack_damage),
		"spell_power": float(u.spell_power),
		"lifesteal": float(u.lifesteal),
		"armor": float(u.armor),
		"magic_resist": float(u.magic_resist),
		"true_damage": float(u.true_damage)
	}

	# Multiplicative scaling from cost and level (centralized)
	UnitScaler.apply_cost_level_scaling(u, base_vals)

	# Final clamps for non-scaled fields
	u.crit_chance = clampf(u.crit_chance, 0.0, 0.95)
	u.crit_damage = max(1.0, u.crit_damage)
	u.attack_speed = max(0.01, u.attack_speed)
	u.mana_regen = max(0.0, u.mana_regen)
	u.cast_speed = max(0.1, u.cast_speed)
	u.armor_pen_flat = max(0.0, u.armor_pen_flat)
	u.armor_pen_pct = clampf(u.armor_pen_pct, 0.0, 1.0)
	u.mr_pen_flat = max(0.0, u.mr_pen_flat)
	u.mr_pen_pct = clampf(u.mr_pen_pct, 0.0, 1.0)

	# Reset HP to new max after scaling
	u.hp = u.max_hp
	var identity_issues := validate_role_invariants(u)
	if identity_issues.size() > 0 and not role_invariant_fail_fast:
		for issue in identity_issues:
			push_warning("UnitFactory validation (%s): %s" % [u.id, issue])
	return u

static func _apply_role_generation(u: Unit, d: UnitDef) -> void:
	# Role generation removed; units use base stats directly.
	return

static func _apply_base_stats(u: Unit, stats: Dictionary) -> void:
	if stats.has("max_hp"):
		u.max_hp = max(1, int(round(float(stats["max_hp"]))))
		u.hp = min(u.max_hp, u.hp)
	if stats.has("attack_damage"):
		u.attack_damage = max(0.0, float(stats["attack_damage"]))
	if stats.has("spell_power"):
		u.spell_power = max(0.0, float(stats["spell_power"]))
	if stats.has("attack_range"):
		u.attack_range = max(1, int(round(float(stats["attack_range"]))))
	if stats.has("armor"):
		u.armor = max(0.0, float(stats["armor"]))
	if stats.has("magic_resist"):
		u.magic_resist = max(0.0, float(stats["magic_resist"]))

static func _resolve_primary_role(d: UnitDef) -> String:
	if d == null:
		return ""
	if d.identity != null:
		var rid_identity := String(d.identity.primary_role).strip_edges()
		if rid_identity != "":
			return _sanitize_role_id(rid_identity)
	var rid_def := String(d.primary_role).strip_edges()
	if rid_def != "":
		return _sanitize_role_id(rid_def)
	if d.roles.size() > 0:
		return _sanitize_role_id(String(d.roles[0]).strip_edges())
	return ""

static func _resolve_primary_goal(identity: UnitIdentity, d: UnitDef, primary_role_id: String) -> String:
	if identity != null:
		var goal_identity := String(identity.primary_goal).strip_edges()
		if goal_identity != "":
			return goal_identity
	var goal_def := String(d.primary_goal).strip_edges()
	if goal_def != "":
		return goal_def
	if primary_role_id != "":
		var defaults := RoleLibrary.default_goals(primary_role_id)
		if defaults.size() > 0:
			return String(defaults[0])
	return ""

static func _resolve_approaches(identity: UnitIdentity, d: UnitDef, primary_role_id: String) -> Array[String]:
	var merged: Array[String] = []
	if identity != null:
		merged.append_array(_copy_string_array(identity.approaches))
	merged.append_array(_copy_string_array(d.approaches))
	if merged.is_empty() and primary_role_id != "":
		merged.append_array(RoleLibrary.default_approaches(primary_role_id))
	return _unique_strings(merged)

static func _resolve_alt_goals(identity: UnitIdentity, d: UnitDef, primary_role_id: String, primary_goal_id: String) -> Array[String]:
	var merged: Array[String] = []
	if identity != null:
		merged.append_array(_copy_string_array(identity.alt_goals))
	merged.append_array(_copy_string_array(d.alt_goals))
	if primary_role_id != "":
		var defaults := RoleLibrary.default_goals(primary_role_id)
		for goal in defaults:
			var g := String(goal)
			if g != "" and g != primary_goal_id:
				merged.append(g)
	return _unique_strings(merged)

static func _primary_role_from_def(d: UnitDef) -> String:
	return _resolve_primary_role(d)

static func _primary_role_from_unit(u: Unit) -> String:
	if u == null:
		return ""
	var rid := String(u.primary_role).strip_edges()
	if rid != "":
		return _sanitize_role_id(rid)
	if u.roles.size() > 0:
		return _sanitize_role_id(String(u.roles[0]).strip_edges())
	return ""

static func _sanitize_role_id(value: String) -> String:
	var s := String(value).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

static func _copy_string_array(values) -> Array[String]:
	var out: Array[String] = []
	if values == null:
		return out
	if values is Array:
		for v in values:
			out.append(String(v))
	elif values is PackedStringArray:
		for v in values:
			out.append(String(v))
	elif typeof(values) == TYPE_STRING:
		out.append(String(values))
	return out

static func _unique_strings(values: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for value in values:
		var key := String(value).strip_edges()
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		out.append(key)
	return out
