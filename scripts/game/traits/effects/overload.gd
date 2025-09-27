extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const CostAdapterLib := preload("res://scripts/game/traits/runtime/cost_adapter.gd")

const TRAIT_ID := "Overload"

const REDUCE_FLAT := [10, 14, 18]
const STARTING_CASTS := [0, 1, 2]

var _adapter: CostAdapter = null

func on_battle_start(ctx):
    # Apply effective cost reductions and grant starting full casts.
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func _apply_for_team(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var reduce: int = int(StackUtils.value_by_tier(t, REDUCE_FLAT))
    var free_casts: int = int(StackUtils.value_by_tier(t, STARTING_CASTS))
    if reduce > 0:
        _ensure_resolver(ctx)
        _apply_reduction_to_team(ctx, team, reduce)
    if free_casts > 0:
        _grant_starting_casts(ctx, team, free_casts)

func _ensure_resolver(ctx) -> void:
    if _adapter == null:
        _adapter = CostAdapterLib.new()
    if ctx != null and ctx.ability_system != null and ctx.ability_system.has_method("set_cost_resolver"):
        ctx.ability_system.set_cost_resolver(_adapter)

func _apply_reduction_to_team(ctx, team: String, reduce: int) -> void:
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    for i in range(arr.size()):
        var u: Unit = arr[i]
        if u == null:
            continue
        # Only units with an ability cost benefit from reduction
        var has_ability: bool = (String(u.ability_id) != "" and int(u.mana_max) > 0)
        if not has_ability:
            continue
        _adapter.add_flat_reduction(u, reduce)

func _grant_starting_casts(ctx, team: String, count: int) -> void:
    var candidates: Array[int] = []
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    for i in range(arr.size()):
        var u: Unit = arr[i]
        if u == null or not u.is_alive():
            continue
        if String(u.ability_id) == "" or int(u.mana_max) <= 0:
            continue
        candidates.append(i)
    if candidates.is_empty():
        return
    var rng = (ctx.engine.rng if ctx != null and ctx.engine != null else null)
    var picks: Array[int] = _pick_unique(candidates, count, rng)
    for idx in picks:
        var u: Unit = arr[idx]
        if u == null:
            continue
        # Fill mana and cast immediately if possible
        u.mana = int(u.mana_max)
        if ctx.ability_system != null and ctx.ability_system.has_method("try_cast"):
            ctx.ability_system.try_cast(team, int(idx))

func _pick_unique(indices: Array[int], n: int, rng) -> Array[int]:
    var out: Array[int] = []
    if indices.is_empty() or n <= 0:
        return out
    var pool: Array[int] = []
    for i in indices:
        pool.append(int(i))
    # Fisher-Yates partial shuffle for n picks
    var R: RandomNumberGenerator = (rng if rng != null else RandomNumberGenerator.new())
    if rng == null:
        R.randomize()
    var m: int = min(n, pool.size())
    for k in range(m):
        var j: int = k + int(floor(R.randf() * float(pool.size() - k)))
        var tmp = pool[k]
        pool[k] = pool[j]
        pool[j] = tmp
        out.append(int(pool[k]))
    return out
