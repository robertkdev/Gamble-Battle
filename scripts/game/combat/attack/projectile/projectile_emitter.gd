extends RefCounted
class_name ProjectileEmitter

var events: CombatEvents = null

func configure(_events: CombatEvents) -> void:
    events = _events

func fire(team: String, shooter_index: int, target_index: int, damage: int, crit: bool) -> void:
    if events != null:
        events.projectile_fired(team, shooter_index, target_index, damage, crit)

