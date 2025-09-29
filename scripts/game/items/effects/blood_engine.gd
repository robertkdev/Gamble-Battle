extends ItemEffectBase

const TAG_KEY := "blood_engine_ad_meta"

var _applied: Dictionary = {} # Unit -> float (current applied AD from HP)

func on_event(u: Unit, ev: String, _data: Dictionary) -> void:
    if buff_system == null or engine == null or u == null:
        return
    if ev != "combat_started" and ev != "unit_stat_changed":
        return
    # Recompute AD = 0.5% of Max HP
    var inc: float = float(u.max_hp) * 0.005
    var prev: float = float(_applied.get(u, 0.0))
    var delta: float = inc - prev
    if abs(delta) < 0.001:
        return
    var ctx := _team_index_of(u)
    var team: String = String(ctx.team)
    var index: int = int(ctx.index)
    if team == "" or index < 0:
        return
    var st := _state()
    if st == null:
        return
    if delta != 0.0:
        buff_system.apply_stats_buff(st, team, index, {"attack_damage": delta}, 3600.0)
        _applied[u] = inc
