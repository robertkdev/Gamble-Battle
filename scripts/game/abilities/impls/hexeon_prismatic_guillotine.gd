extends AbilityImplBase

# Hexeon — Prismatic Guillotine (simplified core)
# Blinks to the lowest‑HP enemy (retargets) and strikes for
# 260/390/900 + 0.9×SP + 12×Kaleidoscope stacks magic damage.
# If target HP% is at/under Executioner threshold (12% + 2% × stacks, up to 40%), execute it.
# On execute, retarget lowest‑HP enemy and recast at 70% power.

const BASE := [260, 390, 900]
const SP_MULT := 0.90
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")
const KALEI_KEY := "kaleidoscope_stacks" # Legacy fallback; TODO remove after validation
const EXEC_KEY := "executioner_stacks"    # Legacy fallback; TODO remove after validation
const RECAST_SCALE := 0.70
const BLINK_OFFSET_TILES: float = 0.55

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _stack(bs, state: BattleState, team: String, index: int, key: String) -> int:
    if bs == null:
        return 0
    var trait_key: String = key
    if key == EXEC_KEY:
        trait_key = TraitKeys.EXECUTIONER
    elif key == KALEI_KEY:
        trait_key = TraitKeys.KALEIDOSCOPE
    var v: int = int(bs.get_stack(state, team, index, trait_key))
    if v > 0:
        return v
    return int(bs.get_stack(state, team, index, key))

func _exec_threshold(exec_stacks: int) -> float:
    var base_t: float = 0.12
    var inc: float = 0.02 * float(max(0, exec_stacks))
    return clamp(base_t + inc, 0.0, 0.40)

func _strike(ctx: AbilityContext, target_idx: int, power_scale: float) -> Dictionary:
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null:
        return {}
    var bs: Variant = ctx.buff_system
    var li: int = _level_index(caster)
    var kalei: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, KALEI_KEY)
    var execs: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, EXEC_KEY)
    var target_team: String = ctx._other_team(ctx.caster_team)
    var threshold: float = _exec_threshold(execs)
    var target_before: Unit = ctx.unit_at(target_team, target_idx)
    if target_before != null and target_before.is_alive():
        var before_hp_pct: float = float(target_before.hp) / max(1.0, float(target_before.max_hp))
        if before_hp_pct <= threshold:
            var execute_damage: float = float(target_before.hp)
            var execute_res: Dictionary = {}
            if execute_damage > 0.0:
                ctx.emit_execute_bonus(target_team, target_idx, 0.0, execute_damage, threshold, before_hp_pct, "hexeon_prismatic_guillotine")
                execute_res = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, execute_damage, "true")
            execute_res["executed"] = true
            return execute_res
    var dmg_f: float = float(BASE[li]) + SP_MULT * float(caster.spell_power) + 12.0 * float(max(0, kalei))
    dmg_f = max(0.0, dmg_f * max(0.0, power_scale))
    var res: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, dmg_f, "magic")
    var base_dealt: float = float(res.get("dealt", dmg_f))
    # Execute check (post-hit HP%)
    var tgt: Unit = ctx.unit_at(target_team, target_idx)
    if tgt != null and tgt.is_alive():
        var hp_pct: float = float(tgt.hp) / max(1.0, float(tgt.max_hp))
        if hp_pct <= threshold:
            var to_kill: float = float(tgt.hp)
            if to_kill > 0.0:
                ctx.emit_execute_bonus(target_team, target_idx, base_dealt, to_kill, threshold, hp_pct, "hexeon_prismatic_guillotine")
                ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, to_kill, "true")
            res["executed"] = true
    else:
        res["killed"] = true
    return res

func _priority_backline_enemy(ctx: AbilityContext) -> int:
    var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
    var target_team: String = ctx._other_team(ctx.caster_team)
    var side_sign: float = 1.0 if ctx.caster_team == "player" else -1.0
    var candidates: Array[Dictionary] = []
    for i in range(enemies.size()):
        var enemy: Unit = enemies[i]
        if enemy == null or not enemy.is_alive():
            continue
        var pos: Vector2 = ctx.position_of(target_team, i)
        candidates.append({
            "idx": i,
            "depth": pos.x * side_sign,
            "hp": int(enemy.hp)
        })
    if candidates.is_empty():
        return -1
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var da: float = float(a.get("depth", 0.0))
        var db: float = float(b.get("depth", 0.0))
        if not is_equal_approx(da, db):
            return da > db
        return int(a.get("hp", 0)) < int(b.get("hp", 0))
    )
    var backline_count: int = max(1, int(ceil(float(candidates.size()) * 0.5)))
    var best_idx: int = -1
    var best_hp: int = 1 << 30
    for k in range(backline_count):
        var candidate: Dictionary = candidates[k]
        var hp: int = int(candidate.get("hp", best_hp))
        if hp < best_hp:
            best_hp = hp
            best_idx = int(candidate.get("idx", -1))
    return best_idx

func _set_current_target(ctx: AbilityContext, target_idx: int) -> void:
    if ctx == null or ctx.state == null:
        return
    if ctx.caster_team == "player":
        if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.player_targets.size():
            ctx.state.player_targets[ctx.caster_index] = target_idx
    else:
        if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.enemy_targets.size():
            ctx.state.enemy_targets[ctx.caster_index] = target_idx

func _blink_near_target(ctx: AbilityContext, target_idx: int) -> void:
    if ctx == null or ctx.engine == null or ctx.engine.arena_state == null:
        return
    var target_team: String = ctx._other_team(ctx.caster_team)
    var target_pos: Vector2 = ctx.position_of(target_team, target_idx)
    var caster_pos: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var away_from_target: Vector2 = caster_pos - target_pos
    if away_from_target.length_squared() <= 0.0001:
        away_from_target = Vector2(-1.0 if ctx.caster_team == "player" else 1.0, 0.0)
    var dest: Vector2 = target_pos + away_from_target.normalized() * BLINK_OFFSET_TILES * ctx.tile_size()
    if ctx.engine.arena_state.data != null:
        dest = MovementMath.clamp_to_rect(dest, ctx.engine.arena_state.data.arena_bounds)
        if ctx.caster_team == "player":
            if ctx.caster_index >= 0 and ctx.caster_index < ctx.engine.arena_state.data.player_positions.size():
                ctx.engine.arena_state.data.player_positions[ctx.caster_index] = dest
        else:
            if ctx.caster_index >= 0 and ctx.caster_index < ctx.engine.arena_state.data.enemy_positions.size():
                ctx.engine.arena_state.data.enemy_positions[ctx.caster_index] = dest
        ctx.engine.emit_signal("position_updated", ctx.caster_team, ctx.caster_index, dest.x, dest.y)

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false
    # First strike at lowest‑HP enemy
    var t0: int = _priority_backline_enemy(ctx)
    if t0 < 0:
        t0 = ctx.lowest_hp_enemy(ctx.caster_team)
    if t0 < 0:
        return false
    _set_current_target(ctx, t0)
    _blink_near_target(ctx, t0)
    var r0: Dictionary = _strike(ctx, t0, 1.0)
    var executed0: bool = bool(r0.get("executed", false))
    if executed0:
        # Recast at 70% power on new lowest‑HP enemy
        var t1: int = ctx.lowest_hp_enemy(ctx.caster_team)
        if t1 >= 0 and ctx.is_alive(ctx._other_team(ctx.caster_team), t1):
            var r1: Dictionary = _strike(ctx, t1, RECAST_SCALE)
            if bool(r1.get("processed", false)) and ctx.engine.has_method("_resolver_emit_reset_triggered"):
                ctx.engine._resolver_emit_reset_triggered(ctx.caster_team, ctx.caster_index, ctx._other_team(ctx.caster_team), t1, "hexeon_execute_recast", 1, 0.0, RECAST_SCALE)
            ctx.log("Prismatic Guillotine: executed and recast at 70% power")
    else:
        ctx.log("Prismatic Guillotine: struck lowest‑HP enemy")
    return true
