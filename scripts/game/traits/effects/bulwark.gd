extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")
const CCUtils := preload("res://scripts/game/traits/runtime/cc_utils.gd")

const TRAIT_ID := "Bulwark"

const TENACITY_MEMBER := 0.50
const TENACITY_ALLY := 0.25
const SHIELD_PCT_MAXHP := 0.20
const BATTLE_LONG := 9999.0

var _ctx = null
var _connected: bool = false
var _used: Dictionary = {} # key "team|index" -> true

func on_battle_start(ctx):
    assert(ctx != null and ctx.state != null)
    assert(ctx.buff_system != null)
    _ctx = ctx
    _used.clear()
    _apply_start(ctx, "player")
    _apply_start(ctx, "enemy")
    if not _connected:
        if ctx.buff_system.has_signal("cc_applied_first"):
            ctx.buff_system.cc_applied_first.connect(_on_cc_applied_first)
            _connected = true

func on_battle_end(ctx):
    if _connected and ctx != null and ctx.buff_system != null and ctx.buff_system.has_signal("cc_applied_first"):
        if ctx.buff_system.is_connected("cc_applied_first", Callable(self, "_on_cc_applied_first")):
            ctx.buff_system.cc_applied_first.disconnect(_on_cc_applied_first)
    _connected = false
    _ctx = null
    _used.clear()

func _apply_start(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var mem_indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if mem_indices.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, {"tenacity": TENACITY_MEMBER}, BATTLE_LONG)
    # Allies +25% at T2 (and retained at T4)
    if t >= 0:
        var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
        var mem_set: Dictionary = {}
        for i in mem_indices:
            mem_set[int(i)] = true
        var nonmem: Array[int] = []
        for i in range(arr.size()):
            if arr[i] == null:
                continue
            if not mem_set.has(i):
                nonmem.append(i)
        if nonmem.size() > 0:
            GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"tenacity": TENACITY_ALLY}, BATTLE_LONG)

func _on_cc_applied_first(team: String, index: int, kind: String) -> void:
    if _ctx == null or _ctx.buff_system == null or _ctx.state == null:
        return
    # Only at T4 and only for Bulwark members
    var t: int = StackUtils.tier(_ctx, team, TRAIT_ID)
    if t < 1:
        return
    if not CCUtils.is_cc_tag(kind):
        return
    var members: Array[int] = StackUtils.members(_ctx, team, TRAIT_ID)
    if members.find(int(index)) < 0:
        return
    var key := team + "|" + str(int(index))
    if _used.has(key):
        return
    var u: Unit = _ctx.unit_at(team, index)
    if u == null or not u.is_alive():
        return
    # Cleanse debuffs and grant a shield equal to 20% Max HP (battle-long)
    _ctx.buff_system.cleanse(_ctx.state, team, index)
    var shield_amt: int = int(max(0.0, floor(float(u.max_hp) * SHIELD_PCT_MAXHP)))
    if shield_amt > 0:
        _ctx.buff_system.apply_shield(_ctx.state, team, index, shield_amt, BATTLE_LONG)
    _used[key] = true

