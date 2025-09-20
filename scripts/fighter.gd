extends RefCounted
class_name Fighter

var name: String
var max_hp: int
var atk: int
var crit_chance: float = 0.05      # 0..1
var lifesteal: float = 0.0         # 0..1
var block_chance: float = 0.0      # 0..1
var regen: int = 0                 # per turn
var hp: int

func _init(
		name_: String,
		max_hp_: int,
		atk_: int,
		crit_chance_: float = 0.05,
		lifesteal_: float = 0.0,
		block_chance_: float = 0.0,
		regen_: int = 0
	) -> void:
	name = name_
	max_hp = max(1, max_hp_)
	atk = max(0, atk_)
	crit_chance = clampf(crit_chance_, 0.0, 0.95)
	lifesteal = clampf(lifesteal_, 0.0, 0.9)
	block_chance = clampf(block_chance_, 0.0, 0.8)
	regen = max(0, regen_)
	hp = max_hp

func is_alive() -> bool:
	return hp > 0

func heal_to_full() -> void:
	hp = max_hp

func take_damage(amount: int) -> int:
	var dmg: int = int(max(0, amount))
	hp = max(0, hp - dmg)
	return dmg

func attack_roll(rng: RandomNumberGenerator) -> Dictionary:
	# returns { damage:int, crit:bool }
	var crit := rng.randf() < crit_chance
	var dmg := atk * (2 if crit else 1)
	return { "damage": int(dmg), "crit": crit }

func end_of_turn() -> void:
	if regen > 0 and is_alive():
		hp = min(max_hp, hp + regen)

func summary() -> String:
	return "HP %d/%d  ATK %d  CRIT %d%%  LS %d%%  BLOCK %d%%  REGEN %d" % [
		hp, max_hp, atk, int(crit_chance * 100.0), int(lifesteal * 100.0),
		int(block_chance * 100.0), regen
	]
