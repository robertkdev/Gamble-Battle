extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")

const TRAIT_ID := "Vindicator"

const SHRED_PCT := [0.30, 0.50, 0.70] # per tier (2/4/6)
const DURATION_S := 3.0
const LABEL := "vindicator_shred"

func on_hit_applied(ctx, event: Dictionary):
    if ctx == null or ctx.state == null or ctx.buff_system == null:
        return
    var team: String = String(event.get("team", "player"))
    var src_idx: int = int(event.get("source_index", -1))
    var tgt_idx: int = int(event.get("target_index", -1))
    var dealt: int = int(event.get("dealt", 0))
    if src_idx < 0 or tgt_idx < 0 or dealt <= 0:
        return
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    # Skip ability hits: only apply on basic attacks
    var pcd: float = float(event.get("player_cd", 0.0))
    var ecd: float = float(event.get("enemy_cd", 0.0))
    var is_ability: bool = (pcd == 0.0 and ecd == 0.0)
    if is_ability:
        return
    # Source must be a Vindicator member
    var members: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if members.find(src_idx) < 0:
        return
    var other: String = ("enemy" if team == "player" else "player")
    var tgt: Unit = ctx.unit_at(other, tgt_idx)
    if tgt == null or not tgt.is_alive():
        return
    var pct: float = StackUtils.value_by_tier(t, SHRED_PCT)
    pct = clamp(pct, 0.0, 0.95)
    # Snapshot deltas based on current Armor/MR
    var d_armor: float = -float(tgt.armor) * pct
    var d_mr: float = -float(tgt.magic_resist) * pct
    # Avoid no-op
    if abs(d_armor) < 0.5 and abs(d_mr) < 0.5:
        return
    # Apply or refresh labeled stats buff (refresh-not-stack)
    ctx.buff_system.apply_stats_labeled(ctx.state, other, tgt_idx, LABEL, {
        "armor": d_armor,
        "magic_resist": d_mr,
    }, DURATION_S)

