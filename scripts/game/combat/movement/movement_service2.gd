extends RefCounted
class_name MovementService2

const MovementState := preload("res://scripts/game/combat/movement/movement_state.gd")
const MovementTuning := preload("res://scripts/game/combat/movement/tuning.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")
const ForcedMovement := preload("res://scripts/game/combat/movement/forced_movement.gd")
const CollisionResolver := preload("res://scripts/game/combat/movement/collision_resolver.gd")
const MovementBuffAdapter := preload("res://scripts/game/combat/movement/adapters/buff_adapter.gd")
const SlotStrategy := preload("res://scripts/game/combat/movement/strategies/slot_strategy.gd")
const Debug := preload("res://scripts/util/debug.gd")
const MovementProfile := preload("res://scripts/game/combat/movement/movement_profile.gd")
const TAU := PI * 2.0

const SLOT_HYSTERESIS_FRAMES := 6
const ARRIVE_STOP_EPS := 0.5
const IN_BAND_BOUNDS_BUFFER := 12.0

var tuning: MovementTuning = MovementTuning.new()
var data: MovementState = MovementState.new()
var forced: ForcedMovement = ForcedMovement.new()
var collider: CollisionResolver = CollisionResolver.new()
var buff_adapter: MovementBuffAdapter = MovementBuffAdapter.new()
var slots: SlotStrategy = SlotStrategy.new()

var _profiles_player: Array = []
var _profiles_enemy: Array = []
var _p_alive_scratch: Array[bool] = []
var _e_alive_scratch: Array[bool] = []
var _p_targets_scratch: Array[int] = []
var _e_targets_scratch: Array[int] = []
var _p_caps_scratch: Array[float] = []
var _e_caps_scratch: Array[float] = []
var _enemy_groups_scratch: Dictionary = {}
var _player_groups_scratch: Dictionary = {}
var _prev_player_slots_scratch: Dictionary = {}
var _prev_enemy_slots_scratch: Dictionary = {}

# Debug helpers (optional)
var _debug_watch_players: Array = []
var _debug_watch_enemies: Array = []

var diagnostics_enabled: bool = false
var _diag_phase_usec: Dictionary[String, int] = {}
var _diag_frames: int = 0
var _diag_total_usec: int = 0
var _diag_target_calls: int = 0
var _diag_target_skips: int = 0

func configure(config_tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	var p: Array[Vector2] = []
	for v in player_pos:
		if typeof(v) == TYPE_VECTOR2:
			p.append(v)
	var e: Array[Vector2] = []
	for v2 in enemy_pos:
		if typeof(v2) == TYPE_VECTOR2:
			e.append(v2)
	data.configure(config_tile_size, p, e, bounds)
	_ensure_profiles()

func set_bounds(bounds: Rect2) -> void:
	data.set_bounds(bounds)

func set_buff_system(buff_system) -> void:
	if buff_system != null:
		buff_adapter.configure(buff_system)

func set_profiles(team: String, arr: Array) -> void:
	var out: Array = []
	for v in arr:
		if v is MovementProfile:
			out.append(v)
	if team == "player":
		_profiles_player = out
	else:
		_profiles_enemy = out

func get_profile(team: String, idx: int) -> MovementProfile:
	return _profile_for(team, idx)

func notify_forced_movement(team: String, idx: int, vec: Vector2, dur: float) -> void:
	forced.add(team, idx, vec, dur)

func set_debug_log_frames(n: int) -> void:
	data.set_debug_log_frames(n)

func set_debug_watch(team: String, indices: Array) -> void:
	var out: Array = []
	for v in indices:
		if typeof(v) == TYPE_INT:
			out.append(int(v))
	if team == "player":
		_debug_watch_players = out
	else:
		_debug_watch_enemies = out

func set_diagnostics_enabled(enabled: bool) -> void:
	diagnostics_enabled = bool(enabled)
	reset_diagnostics()

func reset_diagnostics() -> void:
	_diag_phase_usec.clear()
	_diag_frames = 0
	_diag_total_usec = 0
	_diag_target_calls = 0
	_diag_target_skips = 0

func diagnostics_snapshot() -> Dictionary:
	var phases: Dictionary[String, int] = {}
	for key in _diag_phase_usec.keys():
		var phase_key: String = String(key)
		phases[phase_key] = int(_diag_phase_usec.get(phase_key, 0))
	return {
		"frames": int(_diag_frames),
		"total_usec": int(_diag_total_usec),
		"phases_usec": phases,
		"target_calls": int(_diag_target_calls),
		"target_skips": int(_diag_target_skips)
	}

func ensure_capacity(player_count: int, enemy_count: int) -> void:
	data.ensure_capacity(player_count, enemy_count)
	_ensure_profiles()

func player_positions_copy() -> Array:
	return data.player_positions_copy()

func enemy_positions_copy() -> Array:
	return data.enemy_positions_copy()

func get_player_position(idx: int) -> Vector2:
	return data.get_player_position(idx)

func get_enemy_position(idx: int) -> Vector2:
	return data.get_enemy_position(idx)

func bounds_copy() -> Rect2:
	return data.bounds_copy()

func tile_size() -> float:
	return data.tile_size()

func update_movement(state, delta: float, target_resolver: Callable) -> void:
	_update_impl(state, delta, target_resolver)

func update(delta: float, state, target_resolver: Callable) -> void:
	_update_impl(state, delta, target_resolver)

func _update_impl(state, delta: float, target_resolver: Callable) -> void:
	if delta <= 0.0:
		return
	if data.arena_bounds == Rect2():
		return
	if state == null:
		return
	var diag_enabled: bool = bool(diagnostics_enabled)
	var diag_total_start: int = 0
	var diag_phase_start: int = 0
	if diag_enabled:
		diag_total_start = Time.get_ticks_usec()
		diag_phase_start = diag_total_start
	ensure_capacity(state.player_team.size(), state.enemy_team.size())
	data.tick_slot_memory()
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("setup", diag_phase_start)

	# Snapshot remaining debug frames for this update; will decrement once per call
	var _dbg_frames_left: int = int(data.debug_log_frames)

	var ts: float = data.tile_size_px
	var eps: float = tuning.range_epsilon
	var radius: float = ts * max(0.0, tuning.unit_radius_factor)

	# Alive flags
	_resize_bool_scratch(_p_alive_scratch, state.player_team.size(), false)
	_resize_bool_scratch(_e_alive_scratch, state.enemy_team.size(), false)
	var p_alive: Array[bool] = _p_alive_scratch
	var e_alive: Array[bool] = _e_alive_scratch
	for i_alive in range(state.player_team.size()):
		var u_alive: bool = (state.player_team[i_alive] != null and state.player_team[i_alive].is_alive())
		p_alive[i_alive] = u_alive
	for j_alive in range(state.enemy_team.size()):
		var e_u_alive: bool = (state.enemy_team[j_alive] != null and state.enemy_team[j_alive].is_alive())
		e_alive[j_alive] = e_u_alive
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("alive", diag_phase_start)

	# Current targets via resolver
	_resize_int_scratch(_p_targets_scratch, state.player_team.size(), -1)
	_resize_int_scratch(_e_targets_scratch, state.enemy_team.size(), -1)
	var p_targets: Array[int] = _p_targets_scratch
	var e_targets: Array[int] = _e_targets_scratch
	for i_t in range(state.player_team.size()):
		if i_t < p_alive.size() and not p_alive[i_t]:
			p_targets[i_t] = -1
			if diag_enabled:
				_diag_target_skips += 1
			continue
		if diag_enabled:
			_diag_target_calls += 1
		var v: Variant = target_resolver.call("player", i_t)
		p_targets[i_t] = int(v) if typeof(v) == TYPE_INT else -1
	for j_t in range(state.enemy_team.size()):
		if j_t < e_alive.size() and not e_alive[j_t]:
			e_targets[j_t] = -1
			if diag_enabled:
				_diag_target_skips += 1
			continue
		if diag_enabled:
			_diag_target_calls += 1
		var v2: Variant = target_resolver.call("enemy", j_t)
		e_targets[j_t] = int(v2) if typeof(v2) == TYPE_INT else -1
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("targets", diag_phase_start)

	# Group attackers per target
	_enemy_groups_scratch.clear()
	var enemy_groups: Dictionary = _enemy_groups_scratch
	for i_g in range(p_targets.size()):
		var t: int = p_targets[i_g]
		if t >= 0 and t < data.enemy_positions.size() and (p_alive[i_g] if i_g < p_alive.size() else true):
			if not enemy_groups.has(t):
				enemy_groups[t] = []
			(enemy_groups[t] as Array).append(i_g)
	_player_groups_scratch.clear()
	var player_groups: Dictionary = _player_groups_scratch
	for j_g in range(e_targets.size()):
		var t2: int = e_targets[j_g]
		if t2 >= 0 and t2 < data.player_positions.size() and (e_alive[j_g] if j_g < e_alive.size() else true):
			if not player_groups.has(t2):
				player_groups[t2] = []
			(player_groups[t2] as Array).append(j_g)
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("groups", diag_phase_start)

	var prev_player_slots: Dictionary = _prev_player_slots_scratch
	var prev_enemy_slots: Dictionary = _prev_enemy_slots_scratch
	_sync_prev_slots(prev_player_slots, "player", state.player_team.size())
	_sync_prev_slots(prev_enemy_slots, "enemy", state.enemy_team.size())
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("prev_slots", diag_phase_start)

	# Slot destinations
	var p_slot_map: Dictionary = slots.assign_slots_for_team(
		"player",
		state.player_team,
		data.player_positions,
		p_alive,
		p_targets,
		data.enemy_positions,
		e_alive,
		enemy_groups,
		_profiles_player,
		ts,
		data.debug_log_frames,
		_debug_watch_players,
		prev_player_slots,
		SLOT_HYSTERESIS_FRAMES)
	var e_slot_map: Dictionary = slots.assign_slots_for_team(
		"enemy",
		state.enemy_team,
		data.enemy_positions,
		e_alive,
		e_targets,
		data.player_positions,
		p_alive,
		player_groups,
		_profiles_enemy,
		ts,
		data.debug_log_frames,
		_debug_watch_enemies,
		prev_enemy_slots,
		SLOT_HYSTERESIS_FRAMES)
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("slot_assign", diag_phase_start)

	# Per-unit attempted step caps
	_resize_float_scratch(_p_caps_scratch, state.player_team.size(), 0.0)
	_resize_float_scratch(_e_caps_scratch, state.enemy_team.size(), 0.0)
	var p_caps: Array[float] = _p_caps_scratch
	var e_caps: Array[float] = _e_caps_scratch
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("caps", diag_phase_start)

	# (Potential fast path for 1v1 removed pending further validation)

	# Player side
	for i in range(state.player_team.size()):
		var u: Unit = state.player_team[i]
		var alive: bool = (p_alive[i] if i < p_alive.size() else (u != null and u.is_alive()))
		if not alive or i >= data.player_positions.size():
			p_caps[i] = 0.0
			data.set_slot_memory("player", i, -1, 0)
			continue
		var cur: Vector2 = data.player_positions[i]
		var tgt_idx: int = (p_targets[i] if i < p_targets.size() else -1)
		var tpos: Vector2 = (data.enemy_positions[tgt_idx] if tgt_idx >= 0 and tgt_idx < data.enemy_positions.size() else cur)

		var slot_info: Variant = p_slot_map.get(i)
		var slot_pos: Vector2 = tpos
		var slot_mode: String = "ring"
		var slot_idx: int = -1
		var slow_radius: float = ts * tuning.arrival_slow_radius_factor
		var corridor_radius: float = slow_radius * tuning.corridor_decay_radius_factor
		var corridor_eps: float = ts * tuning.corridor_epsilon_factor
		if slot_info is Dictionary:
			slot_pos = slot_info.get("position", tpos)
			slot_mode = String(slot_info.get("mode", "ring"))
			slot_idx = int(slot_info.get("slot_index", -1))
			slow_radius = float(slot_info.get("slow_radius", slow_radius))
			corridor_radius = float(slot_info.get("corridor_radius", corridor_radius))
			corridor_eps = float(slot_info.get("corridor_eps", corridor_eps))
		if slot_idx >= 0:
			data.set_slot_memory("player", i, slot_idx, SLOT_HYSTERESIS_FRAMES)
		else:
			data.set_slot_memory("player", i, -1, 0)

		var step: Vector2 = Vector2.ZERO

		if forced.has_active("player", i):
			step = forced.consume_step("player", i, delta)
		elif buff_adapter.is_blocked(state, "player", i):
			step = Vector2.ZERO
		else:
			var prof: MovementProfile = _profile_for("player", i)
			var within_enemy: bool = MovementMath.within_range(u, cur, tpos, ts, eps, prof.band_max)
			if within_enemy:
				step = _compute_in_band_step(
					"player",
					i,
					cur,
					tpos,
					u,
					delta,
					radius,
					data.player_positions,
					data.enemy_positions,
					p_alive,
					e_alive,
					prof)
			else:
				if slot_mode == "los_arrive":
					step = _compute_arrive_step(cur, slot_pos, tpos, u, delta, slow_radius, corridor_radius, corridor_eps)
				else:
					step = _compute_slot_step(
						"player",
						i,
						cur,
						slot_pos,
						tpos,
						u,
						prof,
						delta,
						slow_radius,
						corridor_radius,
						radius,
						data.player_positions,
						data.enemy_positions,
						p_alive,
						e_alive,
						_dbg_frames_left)

		var new_pos: Vector2 = cur + step
		new_pos = MovementMath.clamp_to_rect(new_pos, data.arena_bounds)
		data.player_positions[i] = new_pos
		step = new_pos - cur
		p_caps[i] = step.length()
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("player_steps", diag_phase_start)

	# Enemy side
	for j in range(state.enemy_team.size()):
		var e: Unit = state.enemy_team[j]
		var alive_e: bool = (e_alive[j] if j < e_alive.size() else (e != null and e.is_alive()))
		if not alive_e or j >= data.enemy_positions.size():
			e_caps[j] = 0.0
			data.set_slot_memory("enemy", j, -1, 0)
			continue
		var cur_e: Vector2 = data.enemy_positions[j]
		var tgt_idx2: int = (e_targets[j] if j < e_targets.size() else -1)
		var tpos2: Vector2 = (data.player_positions[tgt_idx2] if tgt_idx2 >= 0 and tgt_idx2 < data.player_positions.size() else cur_e)

		var slot_info2: Variant = e_slot_map.get(j)
		var slot_pos2: Vector2 = tpos2
		var slot_mode2: String = "ring"
		var slot_idx2: int = -1
		var slow_radius2: float = ts * tuning.arrival_slow_radius_factor
		var corridor_radius2: float = slow_radius2 * tuning.corridor_decay_radius_factor
		var corridor_eps2: float = ts * tuning.corridor_epsilon_factor
		if slot_info2 is Dictionary:
			slot_pos2 = slot_info2.get("position", tpos2)
			slot_mode2 = String(slot_info2.get("mode", "ring"))
			slot_idx2 = int(slot_info2.get("slot_index", -1))
			slow_radius2 = float(slot_info2.get("slow_radius", slow_radius2))
			corridor_radius2 = float(slot_info2.get("corridor_radius", corridor_radius2))
			corridor_eps2 = float(slot_info2.get("corridor_eps", corridor_eps2))
		if slot_idx2 >= 0:
			data.set_slot_memory("enemy", j, slot_idx2, SLOT_HYSTERESIS_FRAMES)
		else:
			data.set_slot_memory("enemy", j, -1, 0)

		var step2: Vector2 = Vector2.ZERO

		if forced.has_active("enemy", j):
			step2 = forced.consume_step("enemy", j, delta)
		elif buff_adapter.is_blocked(state, "enemy", j):
			step2 = Vector2.ZERO
		else:
			var prof2: MovementProfile = _profile_for("enemy", j)
			var within_enemy2: bool = MovementMath.within_range(e, cur_e, tpos2, ts, eps, prof2.band_max)
			if within_enemy2:
				step2 = _compute_in_band_step(
					"enemy",
					j,
					cur_e,
					tpos2,
					e,
					delta,
					radius,
					data.enemy_positions,
					data.player_positions,
					e_alive,
					p_alive,
					prof2)
			else:
				if slot_mode2 == "los_arrive":
					step2 = _compute_arrive_step(cur_e, slot_pos2, tpos2, e, delta, slow_radius2, corridor_radius2, corridor_eps2)
				else:
					step2 = _compute_slot_step(
						"enemy",
						j,
						cur_e,
						slot_pos2,
						tpos2,
						e,
						prof2,
						delta,
						slow_radius2,
						corridor_radius2,
						radius,
						data.enemy_positions,
						data.player_positions,
						e_alive,
						p_alive,
						_dbg_frames_left)

		var new_pos_e: Vector2 = cur_e + step2
		new_pos_e = MovementMath.clamp_to_rect(new_pos_e, data.arena_bounds)
		data.enemy_positions[j] = new_pos_e
		step2 = new_pos_e - cur_e
		e_caps[j] = step2.length()
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("enemy_steps", diag_phase_start)

	# Resolve collisions (post-step)
	collider.resolve(
		data.player_positions, data.enemy_positions,
		p_alive, e_alive,
		p_caps, e_caps,
		radius, data.arena_bounds,
		max(1, tuning.collision_iterations),
		tuning.friendly_soft_separation,
		Debug.enabled and data.debug_log_frames > 0)
	if diag_enabled:
		diag_phase_start = _diag_mark_phase("collision", diag_phase_start)
		_diag_frames += 1
		_diag_total_usec += max(0, Time.get_ticks_usec() - diag_total_start)

	# Decrement debug frames to limit verbose logging to the requested window
	if _dbg_frames_left > 0:
		data.debug_log_frames = max(0, _dbg_frames_left - 1)

func _compute_arrive_step(cur: Vector2, slot_pos: Vector2, _target_pos: Vector2, unit: Unit, delta: float, _slow_radius: float, _corridor_radius: float, _corridor_eps: float) -> Vector2:
	# Constant-speed LOS approach: move along the ray to the slot at move_speed, clamped by remaining distance.
	var to_slot: Vector2 = slot_pos - cur
	var dist: float = to_slot.length()
	if dist <= ARRIVE_STOP_EPS:
		return Vector2.ZERO
	var dir_los: Vector2 = to_slot / dist
	var max_speed: float = max(0.0, unit.move_speed) * max(0.0, tuning.speed_scale)
	var move_dist: float = max_speed * max(0.0, delta)
	if move_dist > dist:
		move_dist = dist
	return dir_los * move_dist

func _compute_slot_step(team: String, idx: int, cur: Vector2, slot_pos: Vector2, target_pos: Vector2, unit: Unit, prof: MovementProfile, delta: float, _slow_radius: float, corridor_radius: float, radius: float, self_positions: Array[Vector2], other_positions: Array[Vector2], self_alive: Array, other_alive: Array, debug_frames_left: int) -> Vector2:
	var to_slot: Vector2 = slot_pos - cur
	var dist_to_slot: float = to_slot.length()
	if dist_to_slot <= ARRIVE_STOP_EPS:
		return Vector2.ZERO
	var dir_seek: Vector2 = to_slot / dist_to_slot
	if debug_frames_left > 0:
		print("[Vec] ", team, " ", idx, " cur=", cur, " tgt=", target_pos, " slot=", slot_pos, " raw=", to_slot)
	var corridor_factor: float = _corridor_factor(dist_to_slot, corridor_radius)
	var max_speed: float = max(0.0, unit.move_speed) * max(0.0, tuning.speed_scale)
	var move_dist: float = max_speed * max(0.0, delta)
	var sep: Vector2 = Vector2.ZERO
	var sep_r: float = max(0.0, radius) * max(0.0, tuning.separation_radius_factor)
	if sep_r > 0.0:
		for k in range(self_positions.size()):
			if k == idx:
				continue
			if k < self_alive.size() and not self_alive[k]:
				continue
			var other: Vector2 = self_positions[k]
			var diff: Vector2 = cur - other
			var d: float = diff.length()
			if d > 0.0 and d < sep_r:
				var w: float = 1.0 - (d / sep_r)
				sep += (diff / d) * w
	var sep_dir: Vector2 = sep.normalized() if sep != Vector2.ZERO else Vector2.ZERO
	var sep_strength: float = clampf(sep.length(), 0.0, 1.0) * corridor_factor
	var avoidance_vec: Vector2 = _compute_avoidance_vector(cur, idx, self_positions, other_positions, self_alive, other_alive, radius, corridor_factor)
	var avoidance_dir: Vector2 = avoidance_vec.normalized() if avoidance_vec != Vector2.ZERO else Vector2.ZERO
	var avoidance_strength: float = clampf(avoidance_vec.length(), 0.0, 1.0)
	var w_seek: float = max(0.0, tuning.seek_weight)
	var w_sep: float = max(0.0, tuning.separation_weight)
	var w_avoid: float = max(0.0, tuning.avoidance_weight) * avoidance_strength
	var steer: Vector2 = dir_seek * w_seek + sep_dir * (w_sep * sep_strength) + avoidance_dir * w_avoid
	var blended: Vector2 = (steer if steer != Vector2.ZERO else dir_seek).normalized()
	var min_dot: float = clampf(tuning.min_forward_dot, -1.0, 0.25)
	if blended.dot(dir_seek) < min_dot:
		steer = dir_seek * w_seek + sep_dir * (w_sep * sep_strength * 0.25)
		steer += avoidance_dir * (w_avoid * 0.5)
		blended = (steer if steer != Vector2.ZERO else dir_seek).normalized()
	var step_cap: float = min(move_dist, dist_to_slot)
	var step: Vector2 = blended * step_cap
	return _apply_anchor_step(cur, step, move_dist, prof, self_positions)

func _compute_in_band_step(_team: String, idx: int, cur: Vector2, target_pos: Vector2, unit: Unit, delta: float, radius: float, self_positions: Array[Vector2], other_positions: Array[Vector2], self_alive: Array, other_alive: Array, prof: MovementProfile) -> Vector2:
	if unit == null or prof == null:
		return Vector2.ZERO
	var to_target: Vector2 = target_pos - cur
	var dist: float = to_target.length()
	if dist <= ARRIVE_STOP_EPS:
		return Vector2.ZERO
	var desired_range: float = max(0.0, float(unit.attack_range)) * max(0.0, data.tile_size_px)
	if desired_range <= ARRIVE_STOP_EPS:
		return Vector2.ZERO
	var max_speed: float = max(0.0, unit.move_speed) * max(0.0, tuning.speed_scale)
	var move_dist: float = max_speed * max(0.0, delta)
	if move_dist <= 0.0:
		return Vector2.ZERO

	var min_range: float = desired_range * max(0.0, prof.band_min)
	var max_range: float = desired_range * max(max(0.1, prof.band_max), prof.band_min)
	var range_eps: float = max(0.0, tuning.range_epsilon)
	if prof.kite_strength > 0.0 and dist < min_range:
		var away_dir: Vector2 = (cur - target_pos) / dist
		var room: float = max(0.0, max_range - dist)
		var kite_step: float = min(move_dist * clampf(prof.kite_strength, 0.0, 1.0), room)
		if kite_step > 0.0:
			var anchored_kite: Vector2 = _apply_anchor_step(cur, away_dir * kite_step, move_dist, prof, self_positions)
			return _bounded_band_step(cur, anchored_kite, target_pos, min_range, max_range, range_eps, prof.side_bias)

	if prof.strafe_strength <= 0.0:
		return Vector2.ZERO
	var radial_dir: Vector2 = to_target / dist
	var side: float = -1.0 if prof.side_bias < 0.0 else 1.0
	var tangent: Vector2 = Vector2(-radial_dir.y, radial_dir.x) * side
	var strafe_step: float = move_dist * clampf(prof.strafe_strength, 0.0, 1.0)
	if strafe_step <= 0.0:
		return Vector2.ZERO
	var candidate_step: Vector2 = tangent * strafe_step
	var candidate_pos: Vector2 = cur + candidate_step
	var candidate_dist: float = candidate_pos.distance_to(target_pos)
	if candidate_dist > max_range + range_eps:
		return Vector2.ZERO
	if candidate_dist < min_range * 0.80 and prof.kite_strength > 0.0:
		return Vector2.ZERO
	var avoidance_vec: Vector2 = _compute_avoidance_vector(cur, idx, self_positions, other_positions, self_alive, other_alive, radius, 0.35)
	if avoidance_vec != Vector2.ZERO:
		var avoid_dir: Vector2 = avoidance_vec.normalized()
		var blended: Vector2 = (tangent + avoid_dir * 0.35).normalized()
		var anchored_blend: Vector2 = _apply_anchor_step(cur, blended * strafe_step, move_dist, prof, self_positions)
		return _bounded_band_step(cur, anchored_blend, target_pos, min_range, max_range, range_eps, prof.side_bias)
	var anchored_strafe: Vector2 = _apply_anchor_step(cur, candidate_step, move_dist, prof, self_positions)
	return _bounded_band_step(cur, anchored_strafe, target_pos, min_range, max_range, range_eps, prof.side_bias)

func _apply_anchor_step(cur: Vector2, step: Vector2, max_step: float, prof: MovementProfile, self_positions: Array[Vector2]) -> Vector2:
	if prof == null or prof.anchor_strength <= 0.0:
		return step
	var anchor_idx: int = prof.anchor_index
	if anchor_idx < 0 or anchor_idx >= self_positions.size():
		return step
	var anchor_pos: Vector2 = self_positions[anchor_idx]
	var min_dist: float = max(0.0, prof.anchor_min_tiles) * max(1.0, data.tile_size_px)
	var max_dist: float = max(min_dist, prof.anchor_max_tiles * max(1.0, data.tile_size_px))
	if max_dist <= 0.0 or max_step <= 0.0:
		return step
	var predicted: Vector2 = cur + step
	var to_anchor: Vector2 = anchor_pos - predicted
	var dist: float = to_anchor.length()
	var correction_dir: Vector2 = Vector2.ZERO
	var pressure: float = 0.0
	if dist > max_dist and dist > 0.0001:
		correction_dir = to_anchor / dist
		pressure = clampf((dist - max_dist) / max_dist, 0.25, 1.0)
	elif dist < min_dist and dist > 0.0001:
		correction_dir = -to_anchor / dist
		pressure = clampf((min_dist - dist) / max(1.0, min_dist), 0.15, 0.6)
	if correction_dir == Vector2.ZERO:
		return step
	var adjusted: Vector2 = step + correction_dir * max_step * clampf(prof.anchor_strength, 0.0, 1.0) * pressure
	var adjusted_len: float = adjusted.length()
	if adjusted_len > max_step and adjusted_len > 0.0001:
		adjusted = (adjusted / adjusted_len) * max_step
	return adjusted

func _bounded_band_step(cur: Vector2, desired_step: Vector2, target_pos: Vector2, min_range: float, max_range: float, range_eps: float, side_bias: float) -> Vector2:
	if desired_step == Vector2.ZERO:
		return Vector2.ZERO
	var desired_pos: Vector2 = cur + desired_step
	if _inside_bounds(desired_pos):
		return desired_step
	var step_len: float = desired_step.length()
	var to_target: Vector2 = target_pos - cur
	var dist: float = to_target.length()
	if step_len <= 0.0 or dist <= ARRIVE_STOP_EPS:
		return Vector2.ZERO
	var radial_dir: Vector2 = to_target / dist
	var side: float = -1.0 if side_bias < 0.0 else 1.0
	var tangent: Vector2 = Vector2(-radial_dir.y, radial_dir.x) * side
	var candidates: Array[Vector2] = [
		tangent * step_len,
		-tangent * step_len,
		(desired_step * 0.35 + tangent * step_len).normalized() * step_len,
		(desired_step * 0.35 - tangent * step_len).normalized() * step_len
	]
	for candidate_step in candidates:
		var candidate_pos: Vector2 = cur + candidate_step
		if not _inside_bounds(candidate_pos):
			continue
		var candidate_dist: float = candidate_pos.distance_to(target_pos)
		if candidate_dist >= min_range * 0.70 and candidate_dist <= max_range + range_eps:
			return candidate_step
	var clamped_pos: Vector2 = _clamp_to_inner_bounds(desired_pos)
	var clamped_step: Vector2 = clamped_pos - cur
	if clamped_step.length_squared() > 0.01:
		var clamped_dist: float = clamped_pos.distance_to(target_pos)
		if clamped_dist >= min_range * 0.70 and clamped_dist <= max_range + range_eps:
			return clamped_step
	return Vector2.ZERO

func _inside_bounds(pos: Vector2) -> bool:
	if data.arena_bounds == Rect2():
		return true
	var min_x: float = data.arena_bounds.position.x + IN_BAND_BOUNDS_BUFFER
	var min_y: float = data.arena_bounds.position.y + IN_BAND_BOUNDS_BUFFER
	var max_x: float = data.arena_bounds.position.x + data.arena_bounds.size.x - IN_BAND_BOUNDS_BUFFER
	var max_y: float = data.arena_bounds.position.y + data.arena_bounds.size.y - IN_BAND_BOUNDS_BUFFER
	return pos.x >= min_x and pos.x <= max_x and pos.y >= min_y and pos.y <= max_y

func _clamp_to_inner_bounds(pos: Vector2) -> Vector2:
	if data.arena_bounds == Rect2():
		return pos
	var min_x: float = data.arena_bounds.position.x + IN_BAND_BOUNDS_BUFFER
	var min_y: float = data.arena_bounds.position.y + IN_BAND_BOUNDS_BUFFER
	var max_x: float = data.arena_bounds.position.x + data.arena_bounds.size.x - IN_BAND_BOUNDS_BUFFER
	var max_y: float = data.arena_bounds.position.y + data.arena_bounds.size.y - IN_BAND_BOUNDS_BUFFER
	return Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))

func _compute_avoidance_vector(cur: Vector2, idx: int, self_positions: Array[Vector2], other_positions: Array[Vector2], self_alive: Array, other_alive: Array, radius: float, corridor_factor: float) -> Vector2:
	var avoid_radius: float = radius * max(1.0, tuning.avoidance_radius_factor)
	if avoid_radius <= 0.0:
		return Vector2.ZERO
	var accum: Vector2 = Vector2.ZERO
	for s in range(self_positions.size()):
		if s == idx:
			continue
		if s < self_alive.size() and not self_alive[s]:
			continue
		accum += _avoid_from(cur, self_positions[s], avoid_radius)
	for o in range(other_positions.size()):
		if o < other_alive.size() and not other_alive[o]:
			continue
		accum += _avoid_from(cur, other_positions[o], avoid_radius)
	return accum * corridor_factor

func _avoid_from(cur: Vector2, other: Vector2, avoid_radius: float) -> Vector2:
	var diff: Vector2 = cur - other
	var dist: float = diff.length()
	if dist <= 0.0001 or dist >= avoid_radius:
		return Vector2.ZERO
	var weight: float = 1.0 - (dist / avoid_radius)
	return (diff / dist) * weight

func _corridor_factor(dist_to_slot: float, corridor_radius: float) -> float:
	if corridor_radius <= ARRIVE_STOP_EPS:
		return 1.0
	return clampf(dist_to_slot / corridor_radius, 0.0, 1.0)

func _diag_mark_phase(phase_name: String, phase_start_usec: int) -> int:
	var now_usec: int = Time.get_ticks_usec()
	var elapsed_usec: int = max(0, now_usec - phase_start_usec)
	_diag_phase_usec[phase_name] = int(_diag_phase_usec.get(phase_name, 0)) + elapsed_usec
	return now_usec

func _resize_bool_scratch(arr: Array[bool], length: int, fill: bool) -> void:
	if length < 0:
		length = 0
	var current: int = arr.size()
	if current < length:
		for _i in range(length - current):
			arr.append(fill)
	elif current > length:
		arr.resize(length)

func _resize_int_scratch(arr: Array[int], length: int, fill: int) -> void:
	if length < 0:
		length = 0
	var current: int = arr.size()
	if current < length:
		for _i in range(length - current):
			arr.append(fill)
	elif current > length:
		arr.resize(length)

func _resize_float_scratch(arr: Array[float], length: int, fill: float) -> void:
	if length < 0:
		length = 0
	var current: int = arr.size()
	if current < length:
		for _i in range(length - current):
			arr.append(fill)
	elif current > length:
		arr.resize(length)

func _sync_prev_slots(out: Dictionary, team: String, count: int) -> void:
	for i in range(max(0, count)):
		var entry_value: Variant = out.get(i, null)
		var entry: Dictionary = entry_value if entry_value is Dictionary else {}
		entry["slot"] = data.get_slot_id(team, i)
		entry["frames"] = data.get_slot_timer(team, i)
		out[i] = entry

func _ensure_profiles() -> void:
	if _profiles_player.size() < data.player_positions.size():
		while _profiles_player.size() < data.player_positions.size():
			_profiles_player.append(MovementProfile.new())
	elif _profiles_player.size() > data.player_positions.size():
		_profiles_player.resize(data.player_positions.size())
	if _profiles_enemy.size() < data.enemy_positions.size():
		while _profiles_enemy.size() < data.enemy_positions.size():
			_profiles_enemy.append(MovementProfile.new())
	elif _profiles_enemy.size() > data.enemy_positions.size():
		_profiles_enemy.resize(data.enemy_positions.size())

func _profile_for(team: String, idx: int) -> MovementProfile:
	if team == "player":
		if idx >= 0 and idx < _profiles_player.size():
			return _profiles_player[idx]
	else:
		if idx >= 0 and idx < _profiles_enemy.size():
			return _profiles_enemy[idx]
	return MovementProfile.new()
