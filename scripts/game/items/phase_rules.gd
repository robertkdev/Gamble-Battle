extends Object
class_name PhaseRules

# Centralized phase gating for item interactions.

static func _is_combat() -> bool:
    var game_state: Node = _autoload_node("/root/GameState")
    if game_state == null:
        return false
    return int(game_state.get("phase")) == int(GameState.GamePhase.COMBAT)

static func _autoload_node(path: String) -> Node:
    var loop: MainLoop = Engine.get_main_loop()
    if loop == null or not loop.has_method("get_root"):
        return null
    var root: Window = loop.get_root()
    if root == null:
        return null
    return root.get_node_or_null(path)

static func can_equip() -> bool:
    # Equipping items is always allowed (including during combat)
    return true

static func can_remove() -> bool:
    # Removing items is not allowed during combat
    return not _is_combat()

static func can_combine() -> bool:
    # Auto-combining is allowed in all phases
    return true
