extends Object
class_name UnitFactory

static var _cache: Dictionary = {}

const RoleLibrary = preload("res://scripts/game/units/role_library.gd")
const UnitScaler := preload("res://scripts/game/units/unit_scaler.gd")
const Trace := preload("res://scripts/util/trace.gd")

# Validation toggle for BalanceRunner and tools
static var role_invariant_fail_fast: bool = false

# Role clusters for analytics/validation
static func cluster_for_roles(roles: Array) -> String:
	# Normalize to lower strings
	var rset: Dictionary = {}
	for r in roles:
		var k := String(r).strip_edges().to_lower()
		if k != "":
			rset[k] = true
	# Priority order: assassin > marksman/mage > tank/bruiser
	if rset.has("assassin") or rset.has("mage_assassin"):
		return "assassin"
	if rset.has("marksman"):
		return "marksman"
	if rset.has("mage"):
		return "mage"
	if rset.has("tank") or rset.has("hybrid_tank") or rset.has("brawler_tank"):
		return "tank"
	if rset.has("brawler") or rset.has("hybrid_brawler"):
		return "bruiser"
	return "other"

# Quick role identity sanity checks (post role modifiers, pre-abilities)
# Returns an array of human-readable violations
static func validate_role_invariants(u: Unit) -> Array[String]:
	var out: Array[String] = []
	if u == null:
		return out
	var cluster := cluster_for_roles(u.roles)
	# Tunable bands (very broad; adjust as you tune)
	match cluster:
		"marksman":
			if int(u.attack_range) < 3:
				out.append("marksman: attack_range < 3")
			if int(u.max_hp) > 900:
				out.append("marksman: max_hp > 900 (too tanky)")
			if float(u.attack_damage) < 40.0 or float(u.attack_damage) > 90.0:
				out.append("marksman: attack_damage outside 40..90")
		"mage":
			if int(u.attack_range) < 2:
				out.append("mage: attack_range < 2")
			if float(u.spell_power) < 30.0:
				out.append("mage: spell_power < 30")
		"assassin":
			if int(u.max_hp) > 850:
				out.append("assassin: max_hp > 850 (too durable)")
			if int(u.attack_range) > 2:
				out.append("assassin: attack_range > 2 (should be short)")
			if (float(u.attack_damage) + 0.5 * float(u.spell_power)) < 60.0:
				out.append("assassin: burst proxy < 60")
		"tank", "bruiser":
			if int(u.max_hp) < 800:
				out.append(cluster + ": max_hp < 800 (too squishy)")
			if (float(u.armor) + float(u.magic_resist)) < 30.0:
				out.append(cluster + ": armor+mr < 30")
			if float(u.attack_damage) > 80.0:
				out.append(cluster + ": attack_damage > 80 (too high)")
		_:
			pass
	return out

static func _def_path(id: String) -> String:
	return "res://data/units/%s.tres" % id

static func _load_def(id: String) -> UnitDef:
	Trace.step("UnitFactory._load_def: " + id)
	var path := _def_path(id)
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		var res = load(path)
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
			# Use roles from profile (string-based)
			out_def.roles = p.roles.duplicate()
			out_def.ability_id = p.ability_id
			out_def.cost = p.cost
			out_def.level = p.level
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

	# Use UnitDef base defaults as the single source of truth for base stats.
	# Resource-specific .tres should not override math-driven base stats.
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

	# If unit has an ability, prefer its defined base_cost for mana_max (ability cost)
	if String(u.ability_id) != "":
		var AbilityCatalog = load("res://scripts/game/abilities/ability_catalog.gd")
		if AbilityCatalog and AbilityCatalog.has_method("get_def"):
			var adef = AbilityCatalog.get_def(String(u.ability_id))
			if adef and int(adef.base_cost) > 0:
				u.mana_max = int(adef.base_cost)

	# Capture base values before role deltas for scaling eligibility
	var base_vals := {
		"max_hp": int(base_def.max_hp),
		"hp_regen": float(base_def.hp_regen),
		"attack_damage": float(base_def.attack_damage),
		"spell_power": float(base_def.spell_power),
		"lifesteal": float(base_def.lifesteal),
		"armor": float(base_def.armor),
		"magic_resist": float(base_def.magic_resist),
		"true_damage": float(base_def.true_damage)
	}

	# Apply role-based stat offsets (additive before scaling)
	var role_totals := {
		"health": 0.0,
		"attack_damage": 0.0,
		"spell_power": 0.0,
		"attack_range": 0.0,
		"armor": 0.0,
		"magic_resist": 0.0,
	}
	if d.roles.size() > 0:
		for r in d.roles:
			var mod: Dictionary = RoleLibrary.get_modifier(str(r))
			if mod.is_empty():
				continue
			for key in role_totals.keys():
				if mod.has(key):
					role_totals[key] += float(mod[key])
	var health_delta := float(role_totals["health"])
	if health_delta != 0.0:
		u.max_hp = max(1, int(round(float(u.max_hp) + health_delta)))
		u.hp = min(u.max_hp, u.hp)
	var ad_delta := float(role_totals["attack_damage"])
	if ad_delta != 0.0:
		u.attack_damage = max(0.0, u.attack_damage + ad_delta)
	var sp_delta := float(role_totals["spell_power"])
	if sp_delta != 0.0:
		u.spell_power = max(0.0, u.spell_power + sp_delta)
	var range_delta := float(role_totals["attack_range"])
	if range_delta != 0.0:
		var new_range := int(round(float(u.attack_range) + range_delta))
		u.attack_range = max(1, new_range)
	var armor_delta := float(role_totals["armor"])
	if armor_delta != 0.0:
		u.armor = max(0.0, u.armor + armor_delta)
	var mr_delta := float(role_totals["magic_resist"])
	if mr_delta != 0.0:
		u.magic_resist = max(0.0, u.magic_resist + mr_delta)


	# Multiplicative scaling from cost and level (centralized)
	UnitScaler.apply_cost_level_scaling(u, base_vals)

	# Final clamps for non-scaled fields potentially changed by roles
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
	return u

static func _apply_role_generation(u: Unit, d: UnitDef) -> void:
	# Role generation removed; units use base stats directly.
	return
