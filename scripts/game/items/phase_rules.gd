extends Object
class_name PhaseRules

# Centralized phase gating for item interactions.

static func _is_combat() -> bool:
    if Engine.has_singleton("GameState"):
        return int(GameState.phase) == int(GameState.GamePhase.COMBAT)
    return false

static func can_equip() -> bool:
    # Equipping items is always allowed (including during combat)
    return true

static func can_remove() -> bool:
    # Removing items is not allowed during combat
    return not _is_combat()

static func can_combine() -> bool:
    # Auto-combining is allowed in all phases
    return true

