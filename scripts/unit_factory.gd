extends Object
class_name UnitFactory

class UnitTemplate:
	var id: String
	var name: String
	var sprite_path: String

	var max_hp: int = 1
	var hp_regen: int = 0

	var attack_damage: int = 0
	var spell_power: int = 0
	var attack_speed: float = 1.0
	var crit_chance: float = 0.05
	var crit_damage: float = 2.0
	var lifesteal: float = 0.0
	var attack_range: int = 1

	var armor: int = 0
	var magic_resist: int = 0
	var block_chance: float = 0.0
	var damage_reduction: float = 0.0

	var mana_start: int = 0
	var mana_max: int = 0
	var mana_regen: int = 0

static var _builtins_registered := false
static var _templates: Dictionary = {}

static func register(template: UnitTemplate) -> void:
	if template == null or not template.id:
		return
	_templates[template.id] = template

static func get_template(id: String) -> UnitTemplate:
	ensure_builtins()
	if _templates.has(id):
		return _templates[id]
	return null

static func ensure_builtins() -> void:
	if _builtins_registered:
		return
	_builtins_registered = true

	# Sari (starter melee baseline)
	var sari := UnitTemplate.new()
	sari.id = "sari"
	sari.name = "Sari"
	sari.sprite_path = "res://assets/units/sari (3).png"
	sari.max_hp = 100
	sari.hp_regen = 0
	sari.attack_damage = 12
	sari.spell_power = 0
	sari.attack_speed = 1.0
	sari.crit_chance = 0.05
	sari.crit_damage = 2.0
	sari.lifesteal = 0.0
	sari.attack_range = 1
	sari.armor = 0
	sari.magic_resist = 0
	sari.block_chance = 0.0
	sari.damage_reduction = 0.0
	sari.mana_start = 0
	sari.mana_max = 60
	sari.mana_regen = 0
	register(sari)

	# Nyxa (ranged)
	var nyxa := UnitTemplate.new()
	nyxa.id = "nyxa"
	nyxa.name = "Nyxa"
	nyxa.sprite_path = "res://assets/units/nyxa.png"
	nyxa.max_hp = 90
	nyxa.hp_regen = 0
	nyxa.attack_damage = 14
	nyxa.spell_power = 0
	nyxa.attack_speed = 0.9
	nyxa.crit_chance = 0.10
	nyxa.crit_damage = 2.0
	nyxa.lifesteal = 0.0
	nyxa.attack_range = 4
	nyxa.armor = 0
	nyxa.magic_resist = 0
	nyxa.block_chance = 0.0
	nyxa.damage_reduction = 0.0
	nyxa.mana_start = 10
	nyxa.mana_max = 50
	nyxa.mana_regen = 0
	register(nyxa)

	# Volt (ranged, higher speed, lower damage)
	var volt := UnitTemplate.new()
	volt.id = "volt"
	volt.name = "Volt"
	volt.sprite_path = "res://assets/units/volt.png"
	volt.max_hp = 80
	volt.hp_regen = 0
	volt.attack_damage = 10
	volt.spell_power = 0
	volt.attack_speed = 1.6
	volt.crit_chance = 0.08
	volt.crit_damage = 2.0
	volt.lifesteal = 0.0
	volt.attack_range = 4
	volt.armor = 0
	volt.magic_resist = 0
	volt.block_chance = 0.0
	volt.damage_reduction = 0.0
	volt.mana_start = 0
	volt.mana_max = 40
	volt.mana_regen = 0
	register(volt)

	# Paisley (ally/support baseline)
	var paisley := UnitTemplate.new()
	paisley.id = "paisley"
	paisley.name = "Paisley"
	paisley.sprite_path = "res://assets/units/paisley.png"
	paisley.max_hp = 85
	paisley.hp_regen = 1
	paisley.attack_damage = 8
	paisley.spell_power = 0
	paisley.attack_speed = 1.2
	paisley.crit_chance = 0.06
	paisley.crit_damage = 2.0
	paisley.lifesteal = 0.0
	paisley.attack_range = 2
	paisley.armor = 0
	paisley.magic_resist = 0
	paisley.block_chance = 0.02
	paisley.damage_reduction = 0.0
	paisley.mana_start = 0
	paisley.mana_max = 50
	paisley.mana_regen = 1
	register(paisley)

static func spawn(id: String) -> Unit:
	ensure_builtins()
	var t: UnitTemplate = get_template(id)
	if t == null:
		push_warning("UnitFactory.spawn: unknown id '%s'" % id)
		return null
	var u := Unit.new()
	u.id = t.id
	u.name = t.name
	u.sprite_path = t.sprite_path

	u.max_hp = max(1, t.max_hp)
	u.hp_regen = max(0, t.hp_regen)
	u.hp = u.max_hp

	u.attack_damage = max(0, t.attack_damage)
	u.spell_power = max(0, t.spell_power)
	u.attack_speed = max(0.01, t.attack_speed)
	u.crit_chance = clampf(t.crit_chance, 0.0, 0.95)
	u.crit_damage = max(1.0, t.crit_damage)
	u.lifesteal = clampf(t.lifesteal, 0.0, 0.9)
	u.attack_range = max(1, t.attack_range)

	u.armor = max(0, t.armor)
	u.magic_resist = max(0, t.magic_resist)
	u.block_chance = clampf(t.block_chance, 0.0, 0.8)
	u.damage_reduction = clampf(t.damage_reduction, 0.0, 0.9)

	u.mana_max = max(0, t.mana_max)
	u.mana_start = clamp(t.mana_start, 0, u.mana_max)
	u.mana_regen = max(0, t.mana_regen)
	u.mana = u.mana_start

	return u
