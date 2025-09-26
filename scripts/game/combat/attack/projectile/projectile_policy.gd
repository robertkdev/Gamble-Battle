extends RefCounted
class_name ProjectilePolicy

# ProjectilePolicy
# Emits base and multishot projectiles using MultishotSelector and CombatEvents-driven ProjectileEmitter.

var state: BattleState
var multishot: MultishotSelector
var emitter: ProjectileEmitter
var hooks

func configure(_state: BattleState, _multishot: MultishotSelector, _emitter: ProjectileEmitter, _hooks = null) -> void:
	state = _state
	multishot = _multishot
	emitter = _emitter
	hooks = _hooks

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
	# Bonko: emit a single clone shot to the same target with scaled damage when buddy tag is active
	if hooks != null and hooks.has_method("bonko_clone_count"):
		var clone_n: int = int(hooks.bonko_clone_count(state, team, shooter_index))
		if clone_n > 0:
			var pct: float = 0.5
			if hooks.has_method("bonko_clone_damage_pct"):
				pct = float(hooks.bonko_clone_damage_pct(state, team, shooter_index))
			var clone_damage: int = int(max(0.0, round(float(rolled_damage) * max(0.0, pct))))
			for _i in range(clone_n):
				emitter.fire(team, shooter_index, base_tgt, clone_damage, crit)
				shots += 1
	return shots
