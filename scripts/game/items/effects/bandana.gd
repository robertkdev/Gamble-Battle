extends ItemEffectBase

# On crit: apply temporary armor shred to the target.
# Stacks naturally by applying multiple short stats buffs; each application refreshes its own timer.

const DURATION := 3.0
const SHRED_PCT := 0.08  # 8% of current Armor as a flat reduction (placeholder; balance later)

func on_event(u: Unit, ev: String, data: Dictionary) -> void:
    if buff_system == null or engine == null:
        return
    if ev != "hit_dealt":
        return
    var crit: bool = bool(data.get("crit", false))
    if not crit:
        return
    var st := _state()
    if st == null:
        return
    var ctx := _team_index_of(u)
    var team: String = String(ctx.team)
    var index: int = int(ctx.index)
    if team == "" or index < 0:
        return
    var ti: int = int(data.get("target_index", -1))
    if ti < 0:
        return
    var tgt_team: String = _other_team(team)
    var tgt: Unit = (engine.state.enemy_team[ti] if team == "player" else engine.state.player_team[ti])
    if tgt == null:
        return
    var amount: float = max(0.0, float(tgt.armor)) * SHRED_PCT
    if amount <= 0.0:
        return
    buff_system.apply_stats_buff(st, tgt_team, ti, {"armor": -amount}, DURATION)

