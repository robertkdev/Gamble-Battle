extends RefCounted
class_name EffectRegistry

# Central registry that maps effect ids -> handler instances.
# Open/Closed: add a new effect by dropping a new handler file and registering it here.

var _handlers: Dictionary = {} # effect_id -> handler

func configure(manager: CombatManager, engine: CombatEngine, buff_system: BuffSystem) -> void:
    _handlers.clear()
    # Register known effects (handlers are tiny SRP files)
    _register("doubleblade", preload("res://scripts/game/items/effects/doubleblade.gd").new())
    _register("hyperstone", preload("res://scripts/game/items/effects/hyperstone.gd").new())
    _register("spellblade", preload("res://scripts/game/items/effects/spellblade.gd").new())
    _register("shiv", preload("res://scripts/game/items/effects/shiv.gd").new())
    _register("blood_engine", preload("res://scripts/game/items/effects/blood_engine.gd").new())
    _register("mind_siphon", preload("res://scripts/game/items/effects/mind_siphon.gd").new())
    _register("mindstone", preload("res://scripts/game/items/effects/mindstone.gd").new())
    _register("bandana", preload("res://scripts/game/items/effects/bandana.gd").new())
    _register("turbine", preload("res://scripts/game/items/effects/turbine.gd").new())
    # Optional additional effects can be added similarly when implemented.

    # Configure each handler with combat context
    for h in _handlers.values():
        if h != null and h.has_method("configure"):
            h.configure(manager, engine, buff_system)

func reconfigure(manager: CombatManager, engine: CombatEngine, buff_system: BuffSystem) -> void:
    for h in _handlers.values():
        if h != null and h.has_method("configure"):
            h.configure(manager, engine, buff_system)

func _register(effect_id: String, handler) -> void:
    if handler == null:
        return
    _handlers[String(effect_id)] = handler

func dispatch(effect_id: String, unit: Unit, event: String, data: Dictionary) -> void:
    var h = _handlers.get(String(effect_id), null)
    if h == null:
        return
    if h.has_method("on_event"):
        h.on_event(unit, String(event), (data if data != null else {}))

