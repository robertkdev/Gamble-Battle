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

