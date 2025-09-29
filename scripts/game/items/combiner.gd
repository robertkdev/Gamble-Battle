extends Object
class_name Combiner

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const CombineRules := preload("res://scripts/game/items/combine_rules.gd")

# Dependency-injected providers to avoid tight coupling.
static var _get_equipped_ids: Callable = Callable()        # (unit) -> Array[String]
static var _consume_components: Callable = Callable()       # (unit, Array[String]) -> void

static func configure(get_equipped_ids: Callable, consume_components: Callable = Callable()) -> void:
    _get_equipped_ids = get_equipped_ids
    _consume_components = consume_components

# Attempts to combine the incoming component with one on the unit.
# If a valid pair exists, consumes both components (via injected consumer when provided)
# and returns the completed item id; otherwise returns "".
static func try_combine_on_equip(unit, new_component_id: String) -> String:
    var nid := String(new_component_id).strip_edges()
    if nid == "" or not ItemCatalog.is_component(nid):
        return ""

    # Gather currently equipped item ids for this unit
    var equipped_ids: Array = _safe_get_equipped_ids(unit)
    if equipped_ids == null:
        equipped_ids = []

    # Search for a complementary component
    for it in equipped_ids:
        var cid := String(it)
        if cid == "":
            continue
        if not ItemCatalog.is_component(cid):
            continue
        var completed_id := CombineRules.completed_for(cid, nid)
        if completed_id != "":
            # Consume both components if a consumer is wired
            _safe_consume_components(unit, [cid, nid])
            return completed_id
    return ""

static func set_equipped_provider(getter: Callable) -> void:
    _get_equipped_ids = getter

static func set_consumer(consumer: Callable) -> void:
    _consume_components = consumer

# -- Internals --

static func _safe_get_equipped_ids(unit) -> Array:
    if _get_equipped_ids.is_valid():
        var out = _get_equipped_ids.call(unit)
        return (out if out is Array else [])
    # Fallback attempt: check for Items autoload conventions
    if Engine.has_singleton("Items"):
        if Items.has_method("get_equipped_ids"):
            var out2 = Items.get_equipped_ids(unit)
            return (out2 if out2 is Array else [])
        elif Items.has_method("get_equipped"):
            var out3 = Items.get_equipped(unit)
            # get_equipped may return array of ids or objects; coerce to strings
            var arr: Array = []
            if out3 is Array:
                for v in out3:
                    arr.append(String(v))
            return arr
    return []

static func _safe_consume_components(unit, ids: Array) -> void:
    if _consume_components.is_valid():
        _consume_components.call(unit, ids)
        return
    # Optional fallback to Items autoload if it exposes a consumer
    if Engine.has_singleton("Items") and Items.has_method("consume_components"):
        Items.consume_components(unit, ids)

