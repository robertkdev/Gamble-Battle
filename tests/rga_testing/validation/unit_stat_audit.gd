extends Node

const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitDefaults := preload("res://scripts/game/units/unit_defaults.gd")
const UnitScaler := preload("res://scripts/game/units/unit_scaler.gd")
const RoleLibrary := preload("res://scripts/game/units/role_library.gd")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")

const MAX_ATTACK_SPEED := 4.0

func _ready() -> void:
	var issues: Array[String] = _audit_units()
	if issues.is_empty():
		print("UnitStatAudit: OK")
		get_tree().quit(0)
		return
	for issue in issues:
		push_error(issue)
	get_tree().quit(1)

func _audit_units() -> Array[String]:
	var issues: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/units")
	if dir == null:
		issues.append("UnitStatAudit: unable to open res://data/units")
		return issues
	dir.list_dir_begin()
	var seen: Dictionary = {}
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir():
			continue
		if not entry.ends_with(".tres"):
			continue
		var path: String = "res://data/units/%s" % entry
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null or not (res is UnitProfile):
			continue
		var profile: UnitProfile = res
		var id: String = String(profile.id)
		if id == "":
			continue
		if seen.has(id):
			continue
		seen[id] = true
		issues.append_array(_evaluate_unit(id))
	dir.list_dir_end()
	return issues

func _evaluate_unit(id: String) -> Array[String]:
	var issues: Array[String] = []
	var prev_suppress: bool = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	var actual: Unit = UnitFactory.spawn(id)
	UnitFactory.suppress_validation_warnings = prev_suppress
	if actual == null:
		issues.append("UnitStatAudit: failed to spawn unit '%s'" % id)
		return issues
	var expected: Unit = _build_expected(actual)
	issues.append_array(_diff_stats(id, actual, expected))
	return issues

func _build_expected(actual: Unit) -> Unit:
	var expected: Unit = Unit.new()
	expected.id = actual.id
	expected.cost = actual.cost
	expected.level = actual.level
	expected.ability_id = actual.ability_id
	UnitFactory._apply_stats_from_dict(expected, UnitDefaults.BASELINE_STATS)
	var primary_role: String = UnitFactory._primary_role_from_unit(actual)
	if primary_role != "":
		var role_stats: Dictionary = RoleLibrary.base_stats(primary_role)
		if not role_stats.is_empty():
			UnitFactory._apply_stats_from_dict(expected, role_stats)
	if String(actual.ability_id) != "":
		var ability_def: AbilityDef = AbilityCatalog.get_def(String(actual.ability_id))
		if ability_def and int(ability_def.base_cost) > 0:
			expected.mana_max = int(ability_def.base_cost)
	expected.mana_start = clampi(int(expected.mana_start), 0, int(expected.mana_max))
	expected.mana = expected.mana_start
	var base_vals: Dictionary = UnitFactory._collect_scaler_base_values(expected)
	UnitScaler.apply_cost_level_scaling(expected, base_vals)
	expected.crit_chance = clampf(expected.crit_chance, 0.0, 0.95)
	expected.crit_damage = max(1.0, expected.crit_damage)
	expected.attack_speed = clamp(expected.attack_speed, 0.01, MAX_ATTACK_SPEED)
	expected.mana_regen = max(0.0, expected.mana_regen)
	expected.cast_speed = max(0.1, expected.cast_speed)
	expected.armor_pen_flat = max(0.0, expected.armor_pen_flat)
	expected.armor_pen_pct = clampf(expected.armor_pen_pct, 0.0, 1.0)
	expected.mr_pen_flat = max(0.0, expected.mr_pen_flat)
	expected.mr_pen_pct = clampf(expected.mr_pen_pct, 0.0, 1.0)
	expected.hp = expected.max_hp
	expected.mana = min(int(expected.mana_max), expected.mana_start)
	return expected

func _diff_stats(unit_id: String, actual: Unit, expected: Unit) -> Array[String]:
	var issues: Array[String] = []
	var int_fields: Dictionary = {
		"max_hp": true,
		"hp": true,
		"attack_range": true,
		"mana": true,
		"mana_max": true,
		"mana_start": true,
		"mana_gain_per_attack": true,
	}
	var keys: Array[String] = [
		"max_hp",
		"hp",
		"hp_regen",
		"attack_damage",
		"spell_power",
		"attack_speed",
		"crit_chance",
		"crit_damage",
		"true_damage",
		"lifesteal",
		"attack_range",
		"armor",
		"magic_resist",
		"armor_pen_flat",
		"armor_pen_pct",
		"mr_pen_flat",
		"mr_pen_pct",
		"mana",
		"mana_max",
		"mana_regen",
		"mana_start",
		"cast_speed",
		"mana_gain_per_attack",
	]
	for key in keys:
		var expected_val: Variant = expected.get(key)
		var actual_val: Variant = actual.get(key)
		if typeof(expected_val) == TYPE_NIL or typeof(actual_val) == TYPE_NIL:
			continue
		if int_fields.has(key):
			if int(actual_val) != int(expected_val):
				issues.append("%s: %s expected %d got %d" % [unit_id, key, int(expected_val), int(actual_val)])
		else:
			var diff: float = abs(float(actual_val) - float(expected_val))
			if diff > 0.01:
				issues.append("%s: %s expected %.3f got %.3f" % [unit_id, key, float(expected_val), float(actual_val)])
	return issues
