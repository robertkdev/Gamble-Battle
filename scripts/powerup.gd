extends RefCounted
class_name Powerup

var name: String
var description: String = ""
var apply_func: Callable

func _init(name_: String, apply_: Callable, description_: String = "") -> void:
	name = name_
	apply_func = apply_
	description = description_

func apply_to(u: Unit) -> void:
	apply_func.call(u)

static func catalog() -> Array[Powerup]:
	# lambdas are Callables to pure functions below
	return [
		Powerup.new("+20% Attack", Callable(Powerup, "pu_atk_20"), "Increase AD by 20%."),
		Powerup.new("+25% Max HP (heal to full)", Callable(Powerup, "pu_hp_25_full"), "Raise max HP by 25% and fully heal."),
		Powerup.new("+5% Crit Chance", Callable(Powerup, "pu_crit_5"), "Increase critical hit chance by 5%."),
		Powerup.new("+4% Lifesteal", Callable(Powerup, "pu_ls_4"), "Heal 4% of damage dealt each hit."),
		Powerup.new("+5% Block Chance", Callable(Powerup, "pu_block_5"), "Gain 5% chance to block enemy attacks."),
		Powerup.new("+1 Regen per turn", Callable(Powerup, "pu_regen_1"), "Regenerate 1 HP at end of each turn."),
		Powerup.new("+10 Flat Attack", Callable(Powerup, "pu_atk_flat_10"), "Gain +10 permanent AD."),
		Powerup.new("+30 Max HP (heal 30)", Callable(Powerup, "pu_hp30_heal30"), "Increase max HP by 30 and heal 30 now."),
		Powerup.new("+10% Attack Speed", Callable(Powerup, "pu_as_10"), "Attack 10% faster."),
		Powerup.new("+10 Mana Max", Callable(Powerup, "pu_mana_max_10"), "Increase maximum mana by 10."),
		Powerup.new("+1 Mana On Attack", Callable(Powerup, "pu_mana_gain_plus1"), "Gain +1 additional mana per attack."),
	]

# --- Pure powerup implementations ---

static func pu_atk_20(u: Unit) -> void:
	u.attack_damage = max(1, int(round(float(u.attack_damage) * 1.2)))

static func pu_hp_25_full(u: Unit) -> void:
	u.max_hp = max(1, int(round(float(u.max_hp) * 1.25)))
	u.heal_to_full()

static func pu_crit_5(u: Unit) -> void:
	u.crit_chance = clampf(u.crit_chance + 0.05, 0.0, 0.95)

static func pu_ls_4(u: Unit) -> void:
	u.lifesteal = clampf(u.lifesteal + 0.04, 0.0, 0.9)

static func pu_block_5(u: Unit) -> void:
	u.block_chance = clampf(u.block_chance + 0.05, 0.0, 0.8)

static func pu_regen_1(u: Unit) -> void:
	u.hp_regen += 1

static func pu_atk_flat_10(u: Unit) -> void:
	u.attack_damage += 10

static func pu_hp30_heal30(u: Unit) -> void:
	u.max_hp += 30
	u.hp = min(u.max_hp, u.hp + 30)

static func pu_as_10(u: Unit) -> void:
	u.attack_speed = max(0.01, u.attack_speed * 1.1)

static func pu_mana_max_10(u: Unit) -> void:
	u.mana_max += 10
	u.mana = min(u.mana_max, u.mana)

static func pu_mana_gain_plus1(u: Unit) -> void:
	u.mana_gain_per_attack = max(0, u.mana_gain_per_attack + 1)
