extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const TRAIT_ID := "Cartel"
const BATTLE_LONG := 9999.0

# Per-cost contributions (multiplied by count of units with that cost)
const AS_PER_1C := 0.10      # +10% Attack Speed per 1-cost unit
const SP_PER_2C := 0.10      # +10% Spell Power per 2-cost unit
const AD_PER_3C := 0.10      # +10% Attack Damage per 3-cost unit
const AMP_PER_4C := 0.10     # +10% damage amp per 4-cost unit (attacks and abilities)
const DR_PER_5C := 0.10      # +10% damage reduction per 5-cost unit

func on_battle_start(ctx):
    assert(ctx != null and ctx.state != null)
    assert(ctx.buff_system != null)
    _apply_for_team(ctx, "player")
    _apply_for_team(ctx, "enemy")

func _apply_for_team(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    if arr.is_empty():
        return
    var c1: int = 0
    var c2: int = 0
    var c3: int = 0
    var c4: int = 0
    var c5: int = 0
    for u in arr:
        if u == null:
            continue
        match int(u.cost):
            1: c1 += 1
            2: c2 += 1
            3: c3 += 1
            4: c4 += 1
            5: c5 += 1
            _: pass
    # Derived team-wide percentages
    var as_pct: float = AS_PER_1C * float(c1)
    var sp_pct: float = SP_PER_2C * float(c2)
    var ad_pct: float = AD_PER_3C * float(c3)
    var amp_pct: float = AMP_PER_4C * float(c4)
    var dr_pct: float = DR_PER_5C * float(c5)

    # Apply per-unit multiplicative deltas for AS/SP/AD (as additive stat buffs)
    for i in range(arr.size()):
        var u: Unit = arr[i]
        if u == null:
            continue
        var fields: Dictionary = {}
        if as_pct > 0.0:
            var as_delta: float = float(u.attack_speed) * as_pct
            if as_delta != 0.0:
                fields["attack_speed"] = as_delta
        if sp_pct > 0.0:
            var sp_delta: float = float(u.spell_power) * sp_pct
            if sp_delta != 0.0:
                fields["spell_power"] = sp_delta
        if ad_pct > 0.0:
            var ad_delta: float = float(u.attack_damage) * ad_pct
            if ad_delta != 0.0:
                fields["attack_damage"] = ad_delta
        if not fields.is_empty():
            ctx.buff_system.apply_stats_buff(ctx.state, team, i, fields, BATTLE_LONG)

    # Apply uniform damage reduction
    if dr_pct > 0.0:
        for i in range(arr.size()):
            if arr[i] != null:
                ctx.buff_system.apply_stats_buff(ctx.state, team, i, {"damage_reduction": dr_pct}, BATTLE_LONG)

    # Apply damage amplification tags for both attacks and abilities
    if amp_pct > 0.0:
        for i in range(arr.size()):
            if arr[i] == null:
                continue
            ctx.buff_system.apply_tag(ctx.state, team, i, BuffTags.TAG_DAMAGE_AMP, BATTLE_LONG, {"damage_amp_pct": amp_pct})
            # Reuse ability amp tag for ability damage path
            ctx.buff_system.apply_tag(ctx.state, team, i, BuffTags.TAG_ABILITY_AMP, BATTLE_LONG, {"ability_damage_amp": amp_pct})

