extends AbilityImplBase

# Bonko — Bonk (with Bonk Buddy)
# Cast: Smash current target for 160/240/380 + 1.0×AD + 15×StrikerStacks physical.
# If target already stunned: +25% damage instead of applying stun.
# Else: stun for 1.0/1.25/1.5s.
# Then: spawn Bonk Buddy (virtual) for 4.0s — Bonko gains +50% attack speed, and a clone shot is emitted on each attack for 50% damage.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

const BASE_BY_LEVEL := [120, 180, 280]
const STUN_BY_LEVEL := [1.0, 1.25, 1.5]
const STRIKER_KEY := "striker_stacks" # Legacy fallback; TODO: remove after validation
const DURATION_S := 4.0
const CLONE_PCT := 0.35
const BONUS_ON_STUNNED := 0.25

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _stacks(bs, state: BattleState, team: String, index: int, key: String) -> int:
    if bs == null:
        return 0
    # Prefer unified TraitKeys; fall back to legacy key for back-compat
    var trait_key: String = TraitKeys.STRIKER
    var v: int = int(bs.get_stack(state, team, index, trait_key))
    if v > 0:
        return v
    return int(bs.get_stack(state, team, index, key))

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Bonk] BuffSystem not available; cast aborted")
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false

    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx < 0:
        return false
    var tgt_team: String = ("enemy" if ctx.caster_team == "player" else "player")
    var tgt: Unit = ctx.unit_at(tgt_team, target_idx)
    if tgt == null or not tgt.is_alive():
        return false

    var li: int = _level_index(caster)
    var base_dmg: int = BASE_BY_LEVEL[li]
    var striker: int = _stacks(bs, ctx.state, ctx.caster_team, ctx.caster_index, STRIKER_KEY)
    var total: float = float(base_dmg) + 0.8 * float(caster.attack_damage) + 12.0 * float(max(0, striker))

    var already_stunned: bool = false
    if bs.has_method("is_stunned"):
        already_stunned = bs.is_stunned(tgt)

    if already_stunned:
        total *= (1.0 + BONUS_ON_STUNNED)
    # Apply primary damage
    ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, max(0.0, total), "physical")

    # Apply stun if not already stunned
    if not already_stunned:
        bs.apply_stun(ctx.state, tgt_team, target_idx, STUN_BY_LEVEL[li])

    # Bonk Buddy window: +50% attack speed and clone tag
    var delta_as: float = float(caster.attack_speed) * 0.3
    bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"attack_speed": delta_as}, DURATION_S)
    bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_BONKO, DURATION_S, {"pct": CLONE_PCT})

    ctx.log("Bonk: dealt %d (%s), stun %.2fs, Buddy 4s (+50%% AS, 50%% echo)" % [int(round(total)), ("+25% vs stunned" if already_stunned else "stun applied"), STUN_BY_LEVEL[li]])
    return true
