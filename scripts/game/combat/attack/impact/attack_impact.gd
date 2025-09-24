extends RefCounted
class_name AttackImpact

const Health := preload("res://scripts/game/stats/health.gd")

var state: BattleState
var rng: RandomNumberGenerator
var hooks

var blocking: BlockingService
var dmgcalc: DamageCalculator
var shields: ShieldService
var redirect: AbsorbRedirector
var lifesteal: LifestealService

func configure(_state: BattleState, _rng: RandomNumberGenerator, _hooks, _shield_service: ShieldService) -> void:
    state = _state
    rng = _rng
    hooks = _hooks
    blocking = load("res://scripts/game/combat/attack/impact/blocking_service.gd").new()
    dmgcalc = load("res://scripts/game/combat/attack/impact/damage_calculator.gd").new()
    lifesteal = load("res://scripts/game/combat/attack/impact/lifesteal_service.gd").new()
    redirect = load("res://scripts/game/combat/attack/impact/absorb_redirector.gd").new()
    redirect.configure(hooks)
    shields = _shield_service

func apply_hit(source_team: String, source_index: int, src: Unit, tgt_team: String, target_index: int, tgt: Unit, rolled_damage: int, crit: bool, respect_block: bool) -> AttackResult:
    var result: AttackResult = load("res://scripts/game/combat/attack/models/attack_result.gd").new()
    if state == null or src == null or tgt == null or not tgt.is_alive():
        return result
    result.processed = true
    result.before_hp = int(tgt.hp)

    # Block
    if blocking.is_blocked(rng, tgt, respect_block):
        result.blocked = true
        var msg: String = ""
        if source_team == "enemy":
            msg = "You blocked the enemy attack."
        else:
            msg = "%s blocked your attack." % (tgt.name)
        result.before_hp = int(tgt.hp)
        result.after_hp = int(tgt.hp)
        result.messages = [msg]
        return result

    # Base damage components
    var phys_base: float = max(0.0, float(src.attack_damage))
    var magic_base: float = max(0.0, float(src.spell_power))
    if crit:
        phys_base *= max(1.0, float(src.crit_damage))
    var true_base: float = max(0.0, float(src.true_damage))

    # Total after mitigation
    var total: float = dmgcalc.from_components(phys_base, magic_base, true_base, src, tgt)

    # Nyxa per-shot bonus
    var bonus: int = 0
    if hooks != null and hooks.has_method("nyxa_per_shot_bonus"):
        bonus = int(hooks.nyxa_per_shot_bonus(state, source_team, source_index))
    if bonus > 0:
        total += float(bonus)

    var dealt_pre: int = int(max(0.0, round(total)))

    # Shields
    var sres: Dictionary = shields.absorb(tgt, dealt_pre)
    var absorbed: int = int(sres.get("absorbed", 0))
    var dealt_left: int = int(sres.get("leftover", dealt_pre))
    result.absorbed = absorbed
    if absorbed > 0:
        result.messages.append("%s's shield absorbed %d damage." % [tgt.name, absorbed])

    # Korath absorb & redirect to pool
    if dealt_left > 0 and hooks != null and hooks.has_method("korath_absorb_pct"):
        var r: Dictionary = redirect.divert(state, tgt_team, target_index, dealt_left)
        var div: int = int(r.get("diverted", 0))
        if div > 0:
            dealt_left = int(r.get("leftover", dealt_left))

    # Apply damage
    var hres := Health.apply_damage(tgt, max(0, dealt_left))
    var dealt: int = int(hres.dealt)
    result.dealt = dealt
    result.after_hp = int(tgt.hp)

    # Lifesteal
    var heal_amt: int = lifesteal.apply(src, dealt)
    result.heal = heal_amt

    # Final log
    var crit_str: String = (" (CRIT)" if crit else "")
    if source_team == "player":
        result.messages.append("You hit %s for %d%s. Lifesteal +%d." % [tgt.name, dealt, crit_str, heal_amt])
    else:
        result.messages.append("%s hits you for %d%s." % [src.name, dealt, crit_str])

    return result
