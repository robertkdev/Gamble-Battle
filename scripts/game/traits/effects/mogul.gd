extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")

const TRAIT_ID := "Mogul"

# Payout by activation tier (2/4/6 -> +1/+2/+3)
const PAYOUT_BY_TIER := [1, 2, 3]

var _pending_player: int = 0

func on_battle_start(ctx):
    _pending_player = 0
    # Snapshot player payout at start based on current tier
    var t: int = StackUtils.tier(ctx, "player", TRAIT_ID)
    if t >= 0:
        _pending_player = int(PAYOUT_BY_TIER[min(t, PAYOUT_BY_TIER.size() - 1)])

func on_battle_end(ctx):
    if _pending_player <= 0:
        return
    # Guard: only award if player would survive without the payout.
    # If an Economy singleton exists and gold is already 0, skip (fatal round).
    var can_award: bool = true
    if Engine.has_singleton("Economy"):
        var econ = Engine.get_singleton("Economy")
        if econ != null and econ.has_method("get"):
            var g = 0
            # Try common access patterns
            if econ.has_property("gold"):
                g = int(econ.get("gold"))
            elif econ.has_method("gold"):
                g = int(econ.gold())
            can_award = (g > 0)
        elif econ != null and econ.has_property("gold"):
            can_award = int(econ.gold) > 0
    if not can_award:
        _pending_player = 0
        return
    # Award via Economy if available; else emit a log (and rely on UI to reconcile).
    var amt: int = _pending_player
    _pending_player = 0
    if Engine.has_singleton("Economy"):
        var E = Engine.get_singleton("Economy")
        if E != null and E.has_method("add_gold"):
            E.add_gold(amt)
            if ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
                ctx.engine._resolver_emit_log("Mogul payout: +%d gold" % amt)
            return
    # Fallback: try to bubble to UI via log (UI can listen and award).
    if ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
        ctx.engine._resolver_emit_log("[Mogul] gold_awarded(%d)" % amt)

