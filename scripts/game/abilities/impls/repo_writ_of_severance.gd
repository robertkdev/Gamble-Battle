extends AbilityImplBase

const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")

# Repo — Writ of Severance
# Heals for 90/130/170 × SP, then slashes current target for 215/325/520 × AD physical damage.
# Damage is increased by 60% against Tank‑class enemies. On kill, immediately recasts at 75% damage.

const HEAL_SP_MULT := [0.90, 1.30, 1.70]
const AD_MULT := [2.15, 3.25, 5.20]
const BONUS_VS_TANK := 0.60
const RECAST_DMG_SCALE := 0.75

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _is_tank_identity(u: Unit) -> bool:
    if u == null:
        return false
    if u.is_primary_role(IdentityKeys.ROLE_TANK):
        return true
    # Legacy fallback while migration completes
    for r in u.roles:
        var s := String(r).to_lower()
        if s.find("tank") >= 0:
            return true
    return false

func _slash(ctx: AbilityContext, target_idx: int, base_dmg: float) -> Dictionary:
    var tgt := ctx.unit_at(ctx._other_team(ctx.caster_team), target_idx)
    var dmg: float = base_dmg
    if _is_tank_identity(tgt):
        dmg *= (1.0 + BONUS_VS_TANK)
    return ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, max(0.0, dmg), "physical")

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false
    var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
    if target_idx < 0:
        return false

    var li: int = _level_index(caster)
    # Heal
    var heal_amt: float = HEAL_SP_MULT[li] * float(caster.spell_power)
    ctx.heal_single(ctx.caster_team, ctx.caster_index, heal_amt)
    # Damage
    var raw_dmg: float = AD_MULT[li] * float(caster.attack_damage)
    var res := _slash(ctx, target_idx, raw_dmg)
    var after_hp: int = int(res.get("after_hp", 1))
    var dealt: int = int(res.get("dealt", 0))
    var killed: bool = (after_hp <= 0)
    if killed:
        # Recast at 75% damage on a new current target
        var next_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
        if next_idx >= 0 and ctx.is_alive(ctx._other_team(ctx.caster_team), next_idx):
            _slash(ctx, next_idx, raw_dmg * RECAST_DMG_SCALE)
            ctx.log("Writ of Severance: recast at 75%")
    else:
        ctx.log("Writ of Severance: dealt %d (raw %.0f)" % [dealt, raw_dmg])
    return true

