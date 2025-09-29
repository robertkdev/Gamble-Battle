extends ItemEffectBase

const STACK_KEY := "doubleblade_ad"
const MAX_STACKS := 15
const PCT_PER_STACK := 0.02

func on_event(u: Unit, ev: String, _data: Dictionary) -> void:
    if buff_system == null or engine == null:
        return
    if ev != "hit_dealt" and ev != "hit_taken":
        return
    var st := _state()
    if st == null:
        return
    var ctx := _team_index_of(u)
    var team: String = String(ctx.team)
    var index: int = int(ctx.index)
    if team == "" or index < 0:
        return
    var cur: int = buff_system.get_stack(st, team, index, STACK_KEY)
    if cur >= MAX_STACKS:
        return
    # +2% AD as a flat add based on current AD (per stack)
    var inc: float = float(u.attack_damage) * PCT_PER_STACK
    if inc <= 0.0:
        return
    buff_system.add_stack(st, team, index, STACK_KEY, 1, {"attack_damage": inc})
