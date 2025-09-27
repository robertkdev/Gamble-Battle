extends RefCounted
class_name KillEvents

signal unit_killed(source_team: String, source_index: int, target_team: String, target_index: int, kind: String)

func reset() -> void:
    pass

# Call on resolved damage events. Emits unit_killed when after_hp <= 0 and dealt > 0.
# kind: e.g., "attack", "ability"
func on_damage(source_team: String, source_index: int, target_team: String, target_index: int, dealt: int, after_hp: int, kind: String = "attack") -> void:
    if int(dealt) > 0 and int(after_hp) <= 0:
        emit_signal("unit_killed", String(source_team), int(source_index), String(target_team), int(target_index), String(kind))

