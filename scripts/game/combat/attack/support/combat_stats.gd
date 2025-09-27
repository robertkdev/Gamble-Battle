extends RefCounted
class_name CombatStats

# CombatStats
# Tracks total and per-frame damage; exposes summaries for engine/UI.

var total_damage_player: int = 0
var total_damage_enemy: int = 0

var frame_damage_player: int = 0
var frame_damage_enemy: int = 0

# Optional per-unit round totals (team/index keyed)
var unit_damage_player: Array[int] = []
var unit_damage_enemy: Array[int] = []

func reset_totals() -> void:
    total_damage_player = 0
    total_damage_enemy = 0
    unit_damage_player.clear()
    unit_damage_enemy.clear()

func begin_frame() -> void:
    frame_damage_player = 0
    frame_damage_enemy = 0

func add_dealt(source_team: String, dealt: int) -> void:
    var amt: int = max(0, int(dealt))
    if source_team == "player":
        total_damage_player += amt
        frame_damage_player += amt
    else:
        total_damage_enemy += amt
        frame_damage_enemy += amt

func add_dealt_for_unit(state: BattleState, source_team: String, source_index: int, dealt: int) -> void:
    var amt: int = max(0, int(dealt))
    if amt <= 0 or state == null:
        return
    if source_team == "player":
        # ensure size
        while unit_damage_player.size() < state.player_team.size(): unit_damage_player.append(0)
        if source_index >= 0 and source_index < unit_damage_player.size():
            unit_damage_player[source_index] = int(unit_damage_player[source_index]) + amt
    else:
        while unit_damage_enemy.size() < state.enemy_team.size(): unit_damage_enemy.append(0)
        if source_index >= 0 and source_index < unit_damage_enemy.size():
            unit_damage_enemy[source_index] = int(unit_damage_enemy[source_index]) + amt

func totals() -> Dictionary:
    return {"player": total_damage_player, "enemy": total_damage_enemy}

func frame_damage_summary() -> Dictionary:
    return {"player": frame_damage_player, "enemy": frame_damage_enemy}
