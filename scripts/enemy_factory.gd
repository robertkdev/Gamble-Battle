extends Node
class_name EnemyFactory

var rng := RandomNumberGenerator.new()
const NAMES: Array[String] = [
	"Bandit", "Cultist", "Warg", "Golem", "Shade",
	"Brute", "Assassin", "Mage", "Sentinel", "Vermin"
]

func spawn_enemy(stage: int) -> Fighter:
	# Base scales with stage. Small randomness for variety.
	var base_hp := 35
	var base_atk := 6
	var hp_f := float(base_hp) * pow(1.25, max(0, stage - 1)) * rng.randf_range(0.95, 1.10)
	var atk_f := float(base_atk) * pow(1.18, max(0, stage - 1)) * rng.randf_range(0.95, 1.10)
	var crit := clampf(0.03 + 0.002 * float(stage), 0.0, 0.30)
	var block := clampf(0.01 * float(stage), 0.0, 0.15)
	var base_name: String = NAMES[(stage - 1) % NAMES.size()]
	var enemy := Fighter.new("%s %d" % [base_name, stage], int(hp_f), int(max(1.0, atk_f)), crit, 0.0, block, 0)
	return enemy
