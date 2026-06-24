extends Resource
class_name CreepRewardPool

const CreepRewardEntry := preload("res://scripts/game/progression/creeps/reward_entry.gd")

# A weighted pool of entries. The runtime rolls entries based on weights.

@export var id: String = ""
@export var rolls_per_kill: int = 1
@export var entries: Array[CreepRewardEntry] = []

func is_empty() -> bool:
	return entries.is_empty()
