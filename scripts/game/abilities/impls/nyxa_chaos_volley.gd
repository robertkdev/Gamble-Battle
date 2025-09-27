extends AbilityImplBase

# Nyxa — Chaos Volley
# For the next four attacks, fires at random enemies.
# Gains +1 bonus arrow per cast, up to a maximum of four.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const KEY_BONUS := "nyxa_cv_bonus_arrows" # persistent: number of extra arrows per attack (0..3)
const KEY_DMG_STACKS := "nyxa_cv_damage_stacks" # persistent: number of casts beyond cap (after reaching 4 total shots)
const TAG_ACTIVE := BuffTags.TAG_NYXA # timed tag during which multishot applies

func cast(ctx: AbilityContext) -> bool:
    if ctx == null:
        return false
    var bs = ctx.buff_system
    if bs == null:
        ctx.log("[Chaos Volley] BuffSystem not available; cast aborted")
        return false

    # Increment persistent bonus arrows, capped at 3 (total shots = 1 + bonus => max 4)
    var current_bonus: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_BONUS))
    var new_bonus: int = min(3, current_bonus + 1)
    var delta_bonus: int = new_bonus - current_bonus
    if delta_bonus != 0:
        bs.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_BONUS, delta_bonus)
    # Beyond the 3rd cast, stack damage bonus that scales with AD on ability shots
    var over_cap_cast: bool = (current_bonus >= 3)
    var dmg_stacks_after: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_DMG_STACKS))
    if over_cap_cast:
        dmg_stacks_after += 1
        bs.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_DMG_STACKS, 1)

    # Duration approximates 4 attacks at current attack speed
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    var atk_spd: float = 1.0
    if caster:
        atk_spd = max(0.1, float(caster.attack_speed))
    var duration_s: float = clamp(4.0 / atk_spd, 2.0, 8.0)

    # Apply/refresh active tag with metadata for resolver and VFX
    var ad: float = 0.0
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster:
        ad = max(0.0, float(caster.attack_damage))
    var damage_bonus_per_stack: int = int(round(0.10 * ad)) # +10% AD per extra cast beyond cap
    var meta := {
        "extra": new_bonus, # number of extra shots (total = 1 + extra)
        "damage_bonus": int(max(0, dmg_stacks_after)) * damage_bonus_per_stack,
        "block_mana_gain": true
    }
    bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, TAG_ACTIVE, duration_s, meta)

    var total_shots: int = 1 + int(meta["extra"])
    var dmg_bonus_msg: String = (" (+%d per shot)" % int(meta["damage_bonus"])) if int(meta["damage_bonus"]) > 0 else ""
    ctx.log("Chaos Volley: %d shots for %.1fs%s" % [total_shots, duration_s, dmg_bonus_msg])
    return true
