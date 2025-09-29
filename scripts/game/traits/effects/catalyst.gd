extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const CombineRules := preload("res://scripts/game/items/combine_rules.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")

const TRAIT_ID := "Catalyst"

# Per-tier cap on automatic combines per carrier each battle
# Tier is 0-based: thresholds[0] -> tier 0 -> 1 combine, etc.
const COMBINES_PER_TIER := [1, 2, 3]

func on_battle_end(ctx):
    if ctx == null or ctx.state == null:
        return
    # Resolve Items autoload safely
    var items = _items_singleton(ctx)
    if items == null:
        return
    var members: Array[int] = StackUtils.members(ctx, "player", TRAIT_ID)
    if members.is_empty():
        return
    var t: int = StackUtils.tier(ctx, "player", TRAIT_ID)
    var combines_per_unit: int = int(COMBINES_PER_TIER[min(max(0, t), COMBINES_PER_TIER.size() - 1)]) if t >= 0 else 0
    if combines_per_unit <= 0:
        return
    var total_combined: int = 0
    for i in members:
        var idx: int = int(i)
        var u: Unit = ctx.unit_at("player", idx)
        if u == null:
            continue
        total_combined += _try_auto_combine_for_unit(items, u, combines_per_unit)
    if total_combined > 0 and ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
        ctx.engine._resolver_emit_log("[Catalyst] evolved %d item(s) across carriers" % total_combined)

func _items_singleton(_ctx) -> Node:
    if Engine.has_singleton("Items"):
        return Items
    var root := (_ctx.engine.get_tree().root if _ctx and _ctx.engine else null)
    if root:
        return root.get_node_or_null("/root/Items")
    return null

func _try_auto_combine_for_unit(items, unit: Unit, max_combines: int) -> int:
    if items == null or unit == null or max_combines <= 0:
        return 0
    var equipped: Array = []
    if items.has_method("get_equipped"):
        equipped = items.get_equipped(unit)
    if equipped == null or equipped.is_empty():
        return 0
    # Gather component indices by id
    var components: Array[String] = []
    for raw in equipped:
        var id := String(raw)
        if ItemCatalog.is_component(id):
            components.append(id)
    if components.size() < 2:
        return 0
    var combined_count: int = 0
    # Greedy: attempt up to max_combines valid pairs using CombineRules
    # Work on a multiset-like list and remove on use
    while combined_count < max_combines and components.size() >= 2:
        var pair := _find_any_valid_pair(components)
        if pair.size() != 2:
            break
        var a := String(pair[0])
        var b := String(pair[1])
        var cid := CombineRules.completed_for(a, b)
        if cid == "":
            break
        # Consume the two components from the unit, then grant the completed item back to the unit
        if items.has_method("consume_components"):
            items.consume_components(unit, [a, b])
        # Route through inventory+equip to leverage existing flows and hooks
        if items.has_method("add_to_inventory"):
            items.add_to_inventory(cid, 1)
        if items.has_method("equip"):
            var res = items.equip(unit, cid)
            if not bool(res.get("ok", false)):
                # If equipping failed (e.g., no slot), refund to inventory and stop further combines
                if items.has_method("add_to_inventory"):
                    # Item already added; leave it there as a reward
                    pass
                break
        combined_count += 1
        # Remove used components (one instance each) from our working list
        _remove_first(components, a)
        _remove_first(components, b)
    return combined_count

func _find_any_valid_pair(components: Array[String]) -> Array[String]:
    # Scan for any pair that has a valid recipe
    for i in range(components.size()):
        for j in range(i, components.size()):
            var a := String(components[i])
            var b := String(components[j])
            if CombineRules.has_combo(a, b):
                return [a, b]
    return []

func _remove_first(arr: Array[String], value: String) -> void:
    var idx := arr.find(String(value))
    if idx != -1:
        arr.remove_at(idx)
