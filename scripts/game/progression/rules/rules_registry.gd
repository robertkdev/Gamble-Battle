extends Object
class_name RulesRegistry

const RuleProvider := preload("res://scripts/game/progression/rules/rule_provider.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")

static var _registry: Dictionary = {}
static var _builtins_registered: bool = false

static func register(id: String, provider: Variant) -> void:
    var key: String = String(id).strip_edges().to_upper()
    if key == "" or provider == null:
        return
    _registry[key] = provider

static func resolve(id: String) -> Variant:
    ensure_builtins()
    var key: String = String(id).strip_edges().to_upper()
    if key == "":
        return null
    return _registry.get(key, null)

static func ensure_builtins() -> void:
    if _builtins_registered:
        return
    _builtins_registered = true
    # Attempt to load built-in provider implementations; fall back to no-op RuleProvider
    _register_builtin(StageTypes.KIND_NORMAL, "res://scripts/game/progression/rules/providers/normal_rule.gd")
    _register_builtin(StageTypes.KIND_CREEPS, "res://scripts/game/progression/rules/providers/creeps_rule.gd")
    _register_builtin(StageTypes.KIND_ELITE, "res://scripts/game/progression/rules/providers/elite_rule.gd")
    _register_builtin(StageTypes.KIND_EVENT, "res://scripts/game/progression/rules/providers/elite_rule.gd")
    _register_builtin(StageTypes.KIND_BOSS, "res://scripts/game/progression/rules/providers/boss_rule.gd")
    _register_builtin(StageTypes.KIND_MIRROR, "res://scripts/game/progression/rules/providers/mirror_rule.gd")

static func clear_runtime() -> void:
    for provider: Variant in _registry.values():
        if provider != null and provider.has_method("teardown"):
            provider.teardown()
    _registry.clear()
    _builtins_registered = false

static func _register_builtin(kind: String, path: String) -> void:
    var inst: Variant = _try_new(path)
    if inst == null:
        inst = RuleProvider.new()
    register(kind, inst)

static func _try_new(path: String) -> Variant:
    if ResourceLoader.exists(path):
        var scr: Script = load(path)
        if scr != null:
            return scr.new()
    return null
