extends Object
class_name GroupApply

# Small helpers to apply buffs/stacks to groups. Keep handlers concise.

static func stats(buff_system, state: BattleState, team: String, indices: Array, fields: Dictionary, duration_s: float) -> int:
    if buff_system == null or state == null or indices == null or fields == null:
        return 0
    var applied: int = 0
    for i in indices:
        var idx: int = int(i)
        var r: Dictionary = buff_system.apply_stats_buff(state, team, idx, fields, max(0.0, float(duration_s)))
        if bool(r.get("processed", false)):
            applied += 1
    return applied

static func stacks(buff_system, state: BattleState, team: String, indices: Array, key: String, delta: int, per_stack_fields: Dictionary = {}) -> int:
    if buff_system == null or state == null or indices == null or String(key) == "" or delta == 0:
        return 0
    var changed: int = 0
    for i in indices:
        var idx: int = int(i)
        var r: Dictionary = buff_system.add_stack(state, team, idx, key, int(delta), (per_stack_fields if per_stack_fields != null else {}))
        if bool(r.get("processed", false)):
            changed += 1
    return changed

