extends RefCounted
class_name OrderedAttackProcessor

# OrderedAttackProcessor
# Processes ordered attack events: assigns targets, rolls damage, and emits projectiles.

var state: BattleState
var target_controller: TargetController
var roller: AttackRoller
var projectile_policy: ProjectilePolicy
var rng: RandomNumberGenerator
var target_assigner: TargetAssigner

func configure(_state: BattleState, _target_controller: TargetController, _roller: AttackRoller, _proj_policy: ProjectilePolicy, _rng: RandomNumberGenerator, _target_assigner: TargetAssigner) -> void:
	state = _state
	target_controller = _target_controller
	roller = _roller
	projectile_policy = _proj_policy
	rng = _rng
	target_assigner = _target_assigner

# Processes a batch of ordered events.
# Returns a summary: { shots: int }
func process(events: Array[AttackEvent]) -> Dictionary:
	var shot_count: int = 0
	if events == null:
		return {"shots": 0}
	for event in events:
		shot_count += _process_single(event)
	return {"shots": shot_count}

func _process_single(event: AttackEvent) -> int:
	if state == null or event == null:
		return 0
	var team: String = event.team
	var shooter_index: int = event.shooter_index
	var shooter: Unit = (state.player_team[shooter_index] if team == "player" and shooter_index >= 0 and shooter_index < state.player_team.size() else (state.enemy_team[shooter_index] if shooter_index >= 0 and shooter_index < state.enemy_team.size() else null))
	if shooter == null or not shooter.is_alive():
		return 0
	# Assign target via coordinator
	if target_assigner != null:
		target_assigner.assign_for_event(event, target_controller)
	# Validate target
	var target_team: Array[Unit] = (state.enemy_team if team == "player" else state.player_team)
	var tgt_idx: int = int(event.target_index)
	if tgt_idx < 0 or tgt_idx >= target_team.size() or target_team[tgt_idx] == null or not target_team[tgt_idx].is_alive():
		return 0
	# Roll attack
	if roller != null:
		var roll: Dictionary = roller.roll(shooter, rng)
		event.rolled_damage = int(roll.get("damage", 0))
		event.crit = bool(roll.get("crit", false))
	# Emit projectiles (base + extras)
	if projectile_policy != null:
		var emitted: int = projectile_policy.emit_shots(team, shooter_index, tgt_idx, event.rolled_damage, event.crit)
		return max(0, emitted)
	return 0
