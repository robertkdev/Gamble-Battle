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

var tuning: MovementTuning = MovementTuning.new()
var data: MovementState = MovementState.new()
var forced: ForcedMovement = ForcedMovement.new()
var collider: CollisionResolver = CollisionResolver.new()
var buff_adapter: MovementBuffAdapter = MovementBuffAdapter.new()
var slots: SlotStrategy = SlotStrategy.new()

var _profiles_player: Array = []
var _profiles_enemy: Array = []

# Debug helpers (optional)
var _debug_watch_players: Array = []
var _debug_watch_enemies: Array = []

func configure(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	var p: Array[Vector2] = []
	for v in player_pos:
		if typeof(v) == TYPE_VECTOR2:
			p.append(v)
	var e: Array[Vector2] = []
	for v2 in enemy_pos:
		if typeof(v2) == TYPE_VECTOR2:
			e.append(v2)
	data.configure(tile_size, p, e, bounds)
	_ensure_profiles()

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
	ensure_capacity(state.player_team.size(), state.enemy_team.size())

	var ts: float = data.tile_size_px
	var eps: float = tuning.range_epsilon
	var radius: float = ts * max(0.0, tuning.unit_radius_factor)

	# Alive flags
	var p_alive: Array[bool] = []
	var e_alive: Array[bool] = []
	for i_alive in range(state.player_team.size()):
		var u_alive: bool = (state.player_team[i_alive] != null and state.player_team[i_alive].is_alive())
		p_alive.append(u_alive)
	for j_alive in range(state.enemy_team.size()):
		var e_u_alive: bool = (state.enemy_team[j_alive] != null and state.enemy_team[j_alive].is_alive())
		e_alive.append(e_u_alive)

	# Current targets via resolver
	var p_targets: Array[int] = []
	var e_targets: Array[int] = []
	for i_t in range(state.player_team.size()):
		var v: Variant = target_resolver.call("player", i_t)
		p_targets.append(int(v) if typeof(v) == TYPE_INT else -1)
	for j_t in range(state.enemy_team.size()):
		var v2: Variant = target_resolver.call("enemy", j_t)
		e_targets.append(int(v2) if typeof(v2) == TYPE_INT else -1)

	# Group attackers per target
	var enemy_groups: Dictionary = {}
	for i_g in range(p_targets.size()):
		var t: int = p_targets[i_g]
		if t >= 0 and t < data.enemy_positions.size() and (p_alive[i_g] if i_g < p_alive.size() else true):
			if not enemy_groups.has(t):
				enemy_groups[t] = []
			(enemy_groups[t] as Array).append(i_g)
	var player_groups: Dictionary = {}
	for j_g in range(e_targets.size()):
		var t2: int = e_targets[j_g]
		if t2 >= 0 and t2 < data.player_positions.size() and (e_alive[j_g] if j_g < e_alive.size() else true):
			if not player_groups.has(t2):
				player_groups[t2] = []
			(player_groups[t2] as Array).append(j_g)

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
		_debug_watch_players)
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
		_debug_watch_enemies)

	# Per-unit attempted step caps
	var p_caps: Array[float] = []
	var e_caps: Array[float] = []

	# Player side
	for i in range(state.player_team.size()):
		var u: Unit = state.player_team[i]
		var alive: bool = (p_alive[i] if i < p_alive.size() else (u != null and u.is_alive()))
		if not alive or i >= data.player_positions.size():
			p_caps.append(0.0)
			continue
		var cur: Vector2 = data.player_positions[i]
		var tgt_idx: int = (p_targets[i] if i < p_targets.size() else -1)
		var tpos: Vector2 = (data.enemy_positions[tgt_idx] if tgt_idx >= 0 and tgt_idx < data.enemy_positions.size() else cur)

		var step: Vector2 = Vector2.ZERO
		var slot_v: Variant = p_slot_map.get(i, tpos)
		var slot_pos: Vector2 = slot_v if typeof(slot_v) == TYPE_VECTOR2 else tpos

		if forced.has_active("player", i):
			step = forced.consume_step("player", i, delta)
		elif buff_adapter.is_blocked(state, "player", i):
			step = Vector2.ZERO
		else:
			var prof: MovementProfile = _profile_for("player", i)
			var within_enemy: bool = MovementMath.within_range(u, cur, tpos, ts, eps, prof.band_max)
			if within_enemy:
				step = Vector2.ZERO
			else:
				var dir_seek: Vector2 = MovementMath.radial(cur, slot_pos)

				# Local separation from allies
				var sep_r: float = max(0.0, radius) * max(0.0, tuning.separation_radius_factor)
				var sep: Vector2 = Vector2.ZERO
				var neigh_count: int = 0
				if sep_r > 0.0:
					for k in range(data.player_positions.size()):
						if k == i:
							continue
						var alive_k: bool = (p_alive[k] if k < p_alive.size() else true)
						if not alive_k:
							continue
						var pk: Vector2 = data.player_positions[k]
						var diff: Vector2 = cur - pk
						var d: float = diff.length()
						if d > 0.0 and d < sep_r:
							var w: float = 1.0 - (d / sep_r)
							sep += (diff / d) * w
							neigh_count += 1

				# Blend seek+separation with forward guard
				var w_seek: float = max(0.0, tuning.seek_weight)
				var w_sep: float = max(0.0, tuning.separation_weight)
				var sep_dir: Vector2 = sep.normalized() if sep != Vector2.ZERO else Vector2.ZERO
				var sep_strength: float = clampf(sep.length(), 0.0, 1.0)
				var steer: Vector2 = dir_seek * w_seek + sep_dir * (w_sep * sep_strength)
				var blended: Vector2 = (steer if steer != Vector2.ZERO else dir_seek).normalized()
				var min_dot: float = clampf(tuning.min_forward_dot, -1.0, 0.25)
				if blended.dot(dir_seek) < min_dot:
					steer = dir_seek * w_seek + sep_dir * (w_sep * sep_strength * 0.25)
					blended = (steer if steer != Vector2.ZERO else dir_seek).normalized()

				# Constant-speed movement; no arrival smoothing
				var dist_to_slot: float = cur.distance_to(slot_pos)
				var move_dist: float = max(0.0, u.move_speed) * max(0.0, tuning.speed_scale) * max(0.0, delta)
				var step_cap: float = min(move_dist, dist_to_slot)
				step = blended * step_cap

		var new_pos: Vector2 = cur + step
		new_pos = MovementMath.clamp_to_rect(new_pos, data.arena_bounds)
		data.player_positions[i] = new_pos
		p_caps.append(step.length())

	# Enemy side
	for j in range(state.enemy_team.size()):
		var e: Unit = state.enemy_team[j]
		var alive_e: bool = (e_alive[j] if j < e_alive.size() else (e != null and e.is_alive()))
		if not alive_e or j >= data.enemy_positions.size():
			e_caps.append(0.0)
			continue
		var cur_e: Vector2 = data.enemy_positions[j]
		var tgt_idx2: int = (e_targets[j] if j < e_targets.size() else -1)
		var tpos2: Vector2 = (data.player_positions[tgt_idx2] if tgt_idx2 >= 0 and tgt_idx2 < data.player_positions.size() else cur_e)

		var step2: Vector2 = Vector2.ZERO
		var slot_v2: Variant = e_slot_map.get(j, tpos2)
		var slot_pos2: Vector2 = slot_v2 if typeof(slot_v2) == TYPE_VECTOR2 else tpos2

		if forced.has_active("enemy", j):
			step2 = forced.consume_step("enemy", j, delta)
		elif buff_adapter.is_blocked(state, "enemy", j):
			step2 = Vector2.ZERO
		else:
			var prof2: MovementProfile = _profile_for("enemy", j)
			var within_enemy2: bool = MovementMath.within_range(e, cur_e, tpos2, ts, eps, prof2.band_max)
			if within_enemy2:
				step2 = Vector2.ZERO
			else:
				var dir_seek2: Vector2 = MovementMath.radial(cur_e, slot_pos2)

				var sep_r2: float = max(0.0, radius) * max(0.0, tuning.separation_radius_factor)
				var sep2: Vector2 = Vector2.ZERO
				var neigh_count2: int = 0
				if sep_r2 > 0.0:
					for k2 in range(data.enemy_positions.size()):
						if k2 == j:
							continue
						var alive_k2: bool = (e_alive[k2] if k2 < e_alive.size() else true)
						if not alive_k2:
							continue
						var pk2: Vector2 = data.enemy_positions[k2]
						var diff2: Vector2 = cur_e - pk2
						var d2: float = diff2.length()
						if d2 > 0.0 and d2 < sep_r2:
							var w2: float = 1.0 - (d2 / sep_r2)
							sep2 += (diff2 / d2) * w2
							neigh_count2 += 1

				var w_seek2: float = max(0.0, tuning.seek_weight)
				var w_sep2: float = max(0.0, tuning.separation_weight)
				var sep_dir2: Vector2 = sep2.normalized() if sep2 != Vector2.ZERO else Vector2.ZERO
				var sep_strength2: float = clampf(sep2.length(), 0.0, 1.0)
				var steer2: Vector2 = dir_seek2 * w_seek2 + sep_dir2 * (w_sep2 * sep_strength2)
				var blended2: Vector2 = (steer2 if steer2 != Vector2.ZERO else dir_seek2).normalized()
				var min_dot2: float = clampf(tuning.min_forward_dot, -1.0, 0.25)
				if blended2.dot(dir_seek2) < min_dot2:
					steer2 = dir_seek2 * w_seek2 + sep_dir2 * (w_sep2 * sep_strength2 * 0.25)
					blended2 = (steer2 if steer2 != Vector2.ZERO else dir_seek2).normalized()

				var dist_to_slot2: float = cur_e.distance_to(slot_pos2)
				var move_dist2: float = max(0.0, e.move_speed) * max(0.0, tuning.speed_scale) * max(0.0, delta)
				var step_cap2: float = min(move_dist2, dist_to_slot2)
				step2 = blended2 * step_cap2

		var new_pos_e: Vector2 = cur_e + step2
		new_pos_e = MovementMath.clamp_to_rect(new_pos_e, data.arena_bounds)
		data.enemy_positions[j] = new_pos_e
		e_caps.append(step2.length())

	# Resolve collisions (post-step)
	collider.resolve(
		data.player_positions, data.enemy_positions,
		p_alive, e_alive,
		p_caps, e_caps,
		radius, data.arena_bounds,
		max(1, tuning.collision_iterations),
		tuning.friendly_soft_separation,
		Debug.enabled and data.debug_log_frames > 0)

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
