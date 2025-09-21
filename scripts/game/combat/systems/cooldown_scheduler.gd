extends RefCounted
class_name CooldownScheduler

var state: BattleState
var target_controller: TargetController

var process_player_first: bool = true
var alternate_order: bool = false
var simultaneous_pairs: bool = true

var max_regen_loops: int = 10
var _next_player_first: bool = true

func configure(_state: BattleState, _target_controller: TargetController) -> void:
	state = _state
	target_controller = _target_controller
	_sync_cooldowns()
	_next_player_first = process_player_first

func apply_rules(_process_player_first: bool, _alternate_order: bool, _simultaneous_pairs: bool) -> void:
	process_player_first = _process_player_first
	alternate_order = _alternate_order
	simultaneous_pairs = _simultaneous_pairs

func reset_turn() -> void:
	_sync_cooldowns()
	_next_player_first = process_player_first

func advance(delta: float) -> Dictionary:
	if not state or delta <= 0.0:
		return {"pairs": [], "ordered": [], "regen_ticks": 0}
	_sync_cooldowns()
	var regen_ticks: int = _accumulate_regen(delta)
	var player_events: Array[AttackEvent] = _collect_events("player", state.player_team, state.player_cds, delta)
	var enemy_events: Array[AttackEvent] = _collect_events("enemy", state.enemy_team, state.enemy_cds, delta)
	var result: Dictionary = {"pairs": [], "ordered": [], "regen_ticks": regen_ticks}
	var player_first: bool = _next_player_first
	if alternate_order:
		_next_player_first = not _next_player_first
	else:
		_next_player_first = process_player_first
	if simultaneous_pairs:
		var pair_count: int = min(player_events.size(), enemy_events.size())
		for i in range(pair_count):
			result["pairs"].append([player_events[i], enemy_events[i]])
		return result
	var pi: int = 0
	var ei: int = 0
	var ordered: Array[AttackEvent] = []
	while pi < player_events.size() or ei < enemy_events.size():
		if player_first:
			if pi < player_events.size():
				ordered.append(player_events[pi])
				pi += 1
				player_first = false
				continue
			player_first = false
		else:
			if ei < enemy_events.size():
				ordered.append(enemy_events[ei])
				ei += 1
				player_first = true
				continue
			player_first = true
		if pi < player_events.size():
			ordered.append(player_events[pi])
			pi += 1
		if ei < enemy_events.size():
			ordered.append(enemy_events[ei])
			ei += 1
	result["ordered"] = ordered
	return result

func _accumulate_regen(delta: float) -> int:
	var ticks: int = 0
	state.regen_tick_accum += delta
	while state.regen_tick_accum >= 1.0 and ticks < max_regen_loops:
		state.regen_tick_accum -= 1.0
		ticks += 1
	return ticks

func _collect_events(team: String, units: Array[Unit], cds: Array[float], delta: float) -> Array[AttackEvent]:
	var events: Array[AttackEvent] = []
	for i in range(units.size()):
		if i >= cds.size():
			cds.append(0.0)
		cds[i] -= delta
		var unit: Unit = units[i]
		if not unit or not unit.is_alive():
			continue
		var cooldown: float = _compute_cooldown(unit)
		var max_shots: int = clamp(int(ceil(delta / max(0.01, cooldown))) + 2, 1, 100)
		var shots: int = 0
		while cds[i] <= 0.0 and shots < max_shots:
			var target_idx: int = target_controller.current_target(team, i)
			var evt: AttackEvent = AttackEvent.new(team, i, target_idx, 0, false, 0.0)
			cds[i] += cooldown
			evt.pending_cooldown = cds[i]
			events.append(evt)
			shots += 1
	return events

func _compute_cooldown(unit: Unit) -> float:
	var atk_speed: float = max(0.01, unit.attack_speed)
	return 1.0 / atk_speed

func _sync_cooldowns() -> void:
	if not state:
		return
	state.player_cds = _resize_float_array(state.player_cds, state.player_team.size())
	state.enemy_cds = _resize_float_array(state.enemy_cds, state.enemy_team.size())

func _resize_float_array(existing: Array, desired: int) -> Array[float]:
	var out: Array[float] = []
	if desired < 0:
		desired = 0
	var count: int = min(existing.size(), desired)
	for i in range(count):
		out.append(float(existing[i]))
	while out.size() < desired:
		out.append(0.0)
	return out

