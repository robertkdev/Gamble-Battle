extends RefCounted
class_name AttackResolver
const ResolverServicesLib := preload("res://scripts/game/combat/attack/orchestration/resolver_services.gd")
const AbilityUtils := preload("res://scripts/game/abilities/ability_utils.gd")
const TeamUtils := preload("res://scripts/game/combat/attack/support/team_utils.gd")

var state: BattleState
var target_controller: TargetController
var rng: RandomNumberGenerator
var player_ref: Unit
var deterministic_rolls: bool = true
var ability_system: AbilitySystem = null
var buff_system: BuffSystem = null

var frame_player_team_defeated: bool = false
var frame_enemy_team_defeated: bool = false
## double KO bookkeeping (deprecated) removed

var emitters: Dictionary = {}

# Services facade
var _services: ResolverServices = null

# Convenience references wired from services (read-only usage)
var _events
var _impact

var debug_pairs: int = 0
var debug_shots: int = 0
var debug_double_lethals: int = 0

func configure(_state: BattleState, _target_controller: TargetController, _rng: RandomNumberGenerator, _player_ref: Unit, _emitters: Dictionary, _ability_system: AbilitySystem = null, _buff_system: BuffSystem = null) -> void:
	state = _state
	target_controller = _target_controller
	rng = _rng
	player_ref = _player_ref
	emitters = _emitters.duplicate()
	ability_system = _ability_system
	buff_system = _buff_system

	_services = ResolverServicesLib.new()
	_services.configure(state, target_controller, rng, player_ref, emitters, ability_system, buff_system, deterministic_rolls)
	_events = _services.events
	_impact = _services.impact

func set_deterministic_rolls(flag: bool) -> void:
	deterministic_rolls = flag
	if _services != null and _services.roller != null:
		_services.roller.deterministic = flag

func reset_totals() -> void:
	if _services != null and _services.stats != null:
		_services.stats.reset_totals()

func begin_frame() -> void:
	if _services != null and _services.stats != null:
		_services.stats.begin_frame()
	frame_player_team_defeated = false
	frame_enemy_team_defeated = false
	# no double KO tracking
# pairs path removed

func resolve_ordered(events: Array[AttackEvent]) -> void:
	if _services == null or _services.ordered_processor == null:
		return
	var res: Dictionary = _services.ordered_processor.process(events)
	var shots: int = int(res.get("shots", 0))
	debug_shots += max(0, shots)

func apply_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool, respect_block: bool = true) -> Dictionary:
	var response: Dictionary = {"processed": false}
	if not state or not state.battle_active:
		return response
	var src: Unit = TeamUtils.unit_at(state, source_team, source_index)
	var tgt_team: String = TeamUtils.other_team(source_team)
	var tgt: Unit = TeamUtils.unit_at(state, tgt_team, target_index)
	if not src or not tgt:
		return response
	# Impact pipeline
	var impact_res: AttackResult = _impact.apply_hit(source_team, source_index, src, tgt_team, target_index, tgt, damage, crit, respect_block)
	var before_hp: int = impact_res.before_hp
	response = impact_res.to_dictionary()
	if not impact_res.processed:
		return response
	# Emit queued messages from impact in order (moved to PostHitCoordinator)
	var msgs = response.get("messages", [])
	if _services != null and _services.post_hit != null:
		_services.post_hit.emit_messages(msgs)
	# If blocked, stop here (parity with original logic)
	if bool(response.get("blocked", false)):
		return response
	var dealt: int = int(response.get("dealt", 0))
	# Delegate post-hit side effects, emits, and frame status
	if _services != null and _services.post_hit != null:
		var flags: Dictionary = _services.post_hit.apply(source_team, source_index, tgt_team, target_index, damage, dealt, crit, before_hp, int(tgt.hp))
		if bool(flags.get("player_team_defeated", false)):
			frame_player_team_defeated = true
		if bool(flags.get("enemy_team_defeated", false)):
			frame_enemy_team_defeated = true
	return response

func totals() -> Dictionary:
	if _services != null and _services.stats != null:
		return _services.stats.totals()
	return {"player": 0, "enemy": 0}

func frame_status() -> Dictionary:
	return {
		"player_team_defeated": frame_player_team_defeated,
		"enemy_team_defeated": frame_enemy_team_defeated
	}

func frame_damage_summary() -> Dictionary:
	if _services != null and _services.stats != null:
		return _services.stats.frame_damage_summary()
	return {"player": 0, "enemy": 0}

func _resolve_pair(player_event: AttackEvent, enemy_event: AttackEvent) -> Dictionary:
	# Deprecated; kept only to avoid breakage if referenced. No-op wrapper.
	return {}

func _resolve_single_event(event: AttackEvent) -> void:
	# Deprecated: kept for compatibility if referenced. Delegate to ordered processor.
	if _services == null or _services.ordered_processor == null:
		return
	var res: Dictionary = _services.ordered_processor.process([event])
	debug_shots += int(res.get("shots", 0))

func _attack_roll(u: Unit) -> Dictionary:
	if _services != null and _services.roller != null:
		return _services.roller.roll(u, rng)
	return {"damage": 0, "crit": false}

func _ability_name_for(u: Unit) -> String:
	return AbilityUtils.ability_name_for(u)


func _unit_array(team: String) -> Array[Unit]:
	return TeamUtils.unit_array(state, team)

func _unit_at(team: String, index: int) -> Unit:
	return TeamUtils.unit_at(state, team, index)

func _other_team(team: String) -> String:
	return TeamUtils.other_team(team)
