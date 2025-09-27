extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const TRAIT_ID := "Catalyst"
const BATTLE_LONG := 9999.0

func on_battle_end(ctx):
    # Stub: emit progress markers for Catalyst carriers on player team.
    if ctx == null or ctx.state == null:
        return
    var members: Array[int] = StackUtils.members(ctx, "player", TRAIT_ID)
    if members.is_empty():
        return
    # If an Item/Inventory system exists, try to bump progress; otherwise tag and log.
    var progressed: int = 0
    for i in members:
        var idx: int = int(i)
        var u: Unit = ctx.unit_at("player", idx)
        if u == null:
            continue
        progressed += 1
        if ctx.buff_system != null:
            ctx.buff_system.apply_tag(ctx.state, "player", idx, BuffTags.TAG_CATALYST_META, BATTLE_LONG, {"progress_stub": true})
    if progressed > 0 and ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
        ctx.engine._resolver_emit_log("[Catalyst] progression +1 for %d carrier(s) (stub)" % progressed)

