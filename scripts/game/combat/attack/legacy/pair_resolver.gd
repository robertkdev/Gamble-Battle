extends RefCounted
class_name PairResolver

# Deprecated legacy pair resolution extracted from AttackResolver.
# Kept for compatibility and reference; not used in the new flow.

func resolve_pair(state: BattleState, target_controller: TargetController, player_event: AttackEvent, enemy_event: AttackEvent) -> Dictionary:
    var summary: Dictionary = {}
    if not state:
        return summary
    var p_idx: int = player_event.shooter_index
    var e_idx: int = enemy_event.shooter_index
    var player_unit: Unit = BattleState.unit_at(state.player_team, p_idx)
    var enemy_unit: Unit = BattleState.unit_at(state.enemy_team, e_idx)
    if not player_unit or not player_unit.is_alive():
        return summary
    if not enemy_unit or not enemy_unit.is_alive():
        return summary
    var p_target_idx: int = target_controller.current_target("player", p_idx)
    player_event.target_index = p_target_idx
    var e_target_idx: int = target_controller.current_target("enemy", e_idx)
    enemy_event.target_index = e_target_idx
    if not BattleState.is_target_alive(state.enemy_team, p_target_idx):
        return summary
    if not BattleState.is_target_alive(state.player_team, e_target_idx):
        return summary
    # Legacy apply elided intentionally to avoid behavior duplication.
    return summary

