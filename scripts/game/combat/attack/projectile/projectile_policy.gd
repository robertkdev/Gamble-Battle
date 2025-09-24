extends RefCounted
class_name ProjectilePolicy

# ProjectilePolicy
# Emits base and multishot projectiles using MultishotSelector and CombatEvents-driven ProjectileEmitter.

var state: BattleState
var multishot: MultishotSelector
var emitter: ProjectileEmitter

func configure(_state: BattleState, _multishot: MultishotSelector, _emitter: ProjectileEmitter) -> void:
    state = _state
    multishot = _multishot
    emitter = _emitter

# Fires base and extra shots according to multishot rules.
# Returns the number of projectiles emitted.
func emit_shots(team: String, shooter_index: int, default_target: int, rolled_damage: int, crit: bool) -> int:
    if emitter == null:
        return 0
    var base_tgt: int = default_target
    if multishot != null:
        base_tgt = multishot.pick_base_target(state, team, shooter_index, default_target)
    emitter.fire(team, shooter_index, base_tgt, rolled_damage, crit)
    var shots: int = 1
    if multishot != null:
        var extras: Array[int] = multishot.extra_targets(state, team, shooter_index)
        for t in extras:
            emitter.fire(team, shooter_index, int(t), rolled_damage, crit)
            shots += 1
    return shots
