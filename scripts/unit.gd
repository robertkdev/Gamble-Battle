extends RefCounted
class_name Unit

# Identity
var id: String = ""
var name: String = ""
var sprite_path: String = ""
var ability_id: String = ""
var traits: Array[String] = []
var roles: Array[String] = []
var cost: int = 1
var level: int = 1

# Health
var max_hp: int = 1
var hp: int = 1
var hp_regen: float = 0.0

# Offense
var attack_damage: float = 0.0 # AD
var spell_power: float = 0.0   # SP
var attack_speed: float = 1.0 # AS attacks/second (rate of fire)
var crit_chance: float = 0.05 # 0..1
var crit_damage: float = 2.0  # 1.0 = no bonus, 2.0 = double
var true_damage: float = 0.0  # flat true damage
var lifesteal: float = 0.0    # 0..1
var attack_range: int = 1
var move_speed: float = 120.0

# Defense
var armor: float = 0.0
var magic_resist: float = 0.0
var block_chance: float = 0.0     # 0..1
var damage_reduction: float = 0.0 # 0..1 (reserved)
var armor_pen_flat: float = 0.0
var armor_pen_pct: float = 0.0
var mr_pen_flat: float = 0.0
var mr_pen_pct: float = 0.0

# Mana
var mana: int = 0
var mana_max: int = 0      # ability cost
var mana_start: int = 0
var mana_regen: float = 0.0
var cast_speed: float = 1.0
var mana_gain_per_attack: int = 1

func _init() -> void:
	pass

func is_alive() -> bool:
	return hp > 0

func heal_to_full() -> void:
	hp = max_hp

func take_damage(amount: int) -> int:
	var dmg: int = int(max(0, amount))
	# Armor/damage_reduction could reduce damage in the future.
	hp = max(0, hp - dmg)
	return dmg

func attack_roll(rng: RandomNumberGenerator) -> Dictionary:
	# returns { damage:int, crit:bool }
	var crit := rng.randf() < crit_chance
	var dmg_f := float(attack_damage) * (crit_damage if crit else 1.0) + true_damage
	return { "damage": int(round(dmg_f)), "crit": crit }

func end_of_turn() -> void:
	if hp_regen > 0 and is_alive():
		hp = min(max_hp, hp + hp_regen)
	# Basic mana regen support (future abilities will use mana)
	if mana_regen > 0:
		mana = min(mana_max, mana + mana_regen)

func summary() -> String:
	return "HP %d/%d  AD %d  CRIT %d%%  LS %d%%  BLOCK %d%%  REGEN %d" % [
		hp, max_hp, attack_damage, int(crit_chance * 100.0), int(lifesteal * 100.0),
		int(block_chance * 100.0), hp_regen
	]
