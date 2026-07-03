extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")

const TRAIT_ID := "Trader"

# Free rerolls by tier (2/4/6 -> 1/2/3)
const REROLLS_BY_TIER := [1, 2, 3]

var _pending_rerolls: int = 0

func on_battle_start(ctx):
    # Compute pending rerolls for player based on current tier; awarded after combat
    _pending_rerolls = 0
    var t: int = StackUtils.tier(ctx, "player", TRAIT_ID)
    if t >= 0:
        _pending_rerolls = int(REROLLS_BY_TIER[min(t, REROLLS_BY_TIER.size() - 1)])

func on_battle_end(ctx):
    if _pending_rerolls <= 0:
        return
    var n: int = _pending_rerolls
    _pending_rerolls = 0
    # Attempt to grant rerolls via a Shop singleton if available; otherwise emit a log marker
    var shop: Node = _autoload_node("/root/Shop")
    if shop != null:
        if shop.has_method("grant_free_rerolls"):
            shop.grant_free_rerolls(n)
        elif shop.has_method("add_free_rerolls"):
            shop.add_free_rerolls(n)
        # Log for visibility
        if ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
            ctx.engine._resolver_emit_log("Trader: granted %d free reroll(s)" % n)
        return
    # Fallback log marker for UI/Integration to consume later
    if ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
        ctx.engine._resolver_emit_log("[Trader] free_rerolls_granted(%d)" % n)

func _autoload_node(path: String) -> Node:
    var loop: MainLoop = Engine.get_main_loop()
    if loop == null or not loop.has_method("get_root"):
        return null
    var root: Window = loop.get_root()
    if root == null:
        return null
    return root.get_node_or_null(path)
