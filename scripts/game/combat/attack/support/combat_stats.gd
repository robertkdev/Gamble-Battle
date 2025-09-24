extends RefCounted
class_name CombatStats

# CombatStats
# Tracks total and per-frame damage; exposes summaries for engine/UI.

var total_damage_player: int = 0
var total_damage_enemy: int = 0

var frame_damage_player: int = 0
var frame_damage_enemy: int = 0

func reset_totals() -> void:
    total_damage_player = 0
    total_damage_enemy = 0

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

func totals() -> Dictionary:
    return {"player": total_damage_player, "enemy": total_damage_enemy}

func frame_damage_summary() -> Dictionary:
    return {"player": frame_damage_player, "enemy": frame_damage_enemy}
