extends RefCounted
class_name BuffHooks

func nyxa_extra_shots(state: BattleState, team: String, index: int) -> int:
	return 0

func nyxa_per_shot_bonus(state: BattleState, team: String, index: int) -> int:
	return 0

func korath_absorb_pct(state: BattleState, team: String, index: int) -> float:
	return 0.0

func korath_accumulate_pool(state: BattleState, team: String, index: int, amount: int) -> void:
	pass

func unstable_pre_phys_bonus(state: BattleState, team: String, index: int, tgt_team: String, target_index: int) -> float:
	return 0.0

# Executioner specials
func exec_ignore_shields_on_crit(state: BattleState, team: String, index: int) -> bool:
	return false

func exec_true_bonus_pct(state: BattleState, team: String, index: int) -> float:
	return 0.0
