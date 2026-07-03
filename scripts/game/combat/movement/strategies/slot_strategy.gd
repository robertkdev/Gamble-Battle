extends RefCounted
class_name SlotStrategy
const Debug := preload("res://scripts/util/debug.gd")

const TAU := PI * 2.0
const HYST_STICKINESS := 0.05
const HYST_SWITCH_COST := 0.1
const SINGLE_CORRIDOR_EPS_FACTOR := 0.12
const FACTORIAL_ASSIGNMENT_LIMIT: int = 7
const DP_ASSIGNMENT_LIMIT: int = 12

# Computes per-attacker slot destinations around their chosen targets.
# Five evenly spaced slots per target, order-preserving assignment to avoid
# crossing. Attackers map to consecutive slots chosen to minimize total
# angular error.

static func _angle_to(from: Vector2, to: Vector2) -> float:
	var ang: float = atan2(to.y - from.y, to.x - from.x)
	if ang < 0.0:
		ang += TAU
	return ang

static func _circ_dist(a: float, b: float) -> float:
	var d: float = abs(a - b)
	if d > PI:
		d = TAU - d
	return d

static func _slot_angles(count: int) -> Array[float]:
	var out: Array[float] = []
	if count <= 0:
		return out
	var step: float = TAU / float(count)
	for i in range(count):
		out.append(step * float(i))
	return out

static func _wrap_angle(a: float) -> float:
	var r: float = fmod(a, TAU)
	if r < 0.0:
		r += TAU
	return r

static func _evaluate_assignment(pairs: Array, ring_angles: Array[float], prev_slot_assignments: Dictionary, hysteresis_frames: int) -> Dictionary:
	var rows: int = pairs.size()
	var cols: int = ring_angles.size()
	var costs: Array = []
	for i in range(rows):
		var row_cost: Array[float] = []
		var entry: Dictionary = pairs[i]
		var idx: int = int(entry["idx"])
		var prev: Dictionary = prev_slot_assignments.get(idx, {})
		var prev_slot: int = int(prev.get("slot", -1))
		var prev_frames: int = int(prev.get("frames", 0))
		var frame_factor: float = 1.0
		if hysteresis_frames > 0:
			frame_factor = clampf(float(prev_frames) / float(hysteresis_frames), 0.0, 1.0)
		for j in range(cols):
			var base_cost: float = _circ_dist(float(entry["angle"]), ring_angles[j])
			if prev_slot == j and prev_frames > 0:
				base_cost = max(0.0, base_cost - HYST_STICKINESS * frame_factor)
			elif prev_slot != -1 and prev_slot != j and prev_frames > 0:
				base_cost += HYST_SWITCH_COST * frame_factor
			row_cost.append(base_cost)
		costs.append(row_cost)
	return _best_assignment(costs)

static func _best_assignment(costs: Array) -> Dictionary:
	var n: int = costs.size()
	if n == 0:
		return {"assignment": [], "cost": 0.0}
	if n <= FACTORIAL_ASSIGNMENT_LIMIT:
		return _best_assignment_permuted(costs)
	if n <= DP_ASSIGNMENT_LIMIT:
		return _best_assignment_dp(costs)
	return _best_assignment_greedy(costs)

static func _best_assignment_permuted(costs: Array) -> Dictionary:
	var n: int = costs.size()
	var indices: Array[int] = []
	for i in range(n):
		indices.append(i)
	var best: Array = [1e30, []]
	_permute_assign(indices, 0, costs, best)
	return {"assignment": (best[1] as Array).duplicate(), "cost": float(best[0])}

static func _best_assignment_dp(costs: Array) -> Dictionary:
	var n: int = costs.size()
	var mask_count: int = 1 << n
	var best_costs: Array[float] = []
	var prev_cols: Array[int] = []
	var prev_masks: Array[int] = []
	for _i in range(mask_count):
		best_costs.append(1e30)
		prev_cols.append(-1)
		prev_masks.append(-1)
	best_costs[0] = 0.0
	for mask in range(mask_count):
		var row: int = _bit_count(mask)
		if row >= n:
			continue
		var base_cost: float = best_costs[mask]
		if base_cost >= 1e29:
			continue
		var row_costs: Array = costs[row]
		for col in range(n):
			var bit: int = 1 << col
			if (mask & bit) != 0:
				continue
			var next_mask: int = mask | bit
			var candidate_cost: float = base_cost + float(row_costs[col])
			if candidate_cost < best_costs[next_mask]:
				best_costs[next_mask] = candidate_cost
				prev_cols[next_mask] = col
				prev_masks[next_mask] = mask
	var final_mask: int = mask_count - 1
	var assignment: Array[int] = []
	assignment.resize(n)
	var walk_mask: int = final_mask
	var write_row: int = n - 1
	while write_row >= 0:
		var picked_col: int = prev_cols[walk_mask]
		if picked_col < 0:
			return _best_assignment_greedy(costs)
		assignment[write_row] = picked_col
		walk_mask = prev_masks[walk_mask]
		write_row -= 1
	return {"assignment": assignment, "cost": best_costs[final_mask]}

static func _best_assignment_greedy(costs: Array) -> Dictionary:
	var n: int = costs.size()
	var used: Array[bool] = []
	var assignment: Array[int] = []
	for _i in range(n):
		used.append(false)
	var total_cost: float = 0.0
	for row in range(n):
		var row_costs: Array = costs[row]
		var best_col: int = -1
		var best_cost: float = 1e30
		for col in range(n):
			if used[col]:
				continue
			var candidate_cost: float = float(row_costs[col])
			if candidate_cost < best_cost:
				best_cost = candidate_cost
				best_col = col
		if best_col < 0:
			best_col = 0
			best_cost = 0.0
		assignment.append(best_col)
		if best_col >= 0 and best_col < used.size():
			used[best_col] = true
		total_cost += best_cost
	return {"assignment": assignment, "cost": total_cost}

static func _bit_count(value: int) -> int:
	var count: int = 0
	var bits: int = value
	while bits > 0:
		bits = bits & (bits - 1)
		count += 1
	return count

static func _permute_assign(indices: Array[int], start: int, costs: Array, best: Array) -> void:
	var n: int = indices.size()
	if start >= n:
		var current_cost: float = 0.0
		for r in range(n):
			current_cost += float((costs[r] as Array)[indices[r]])
			if current_cost >= float(best[0]):
				break
		if current_cost < float(best[0]):
			best[0] = current_cost
			best[1] = indices.duplicate()
		return
	for i in range(start, n):
		var tmp: int = indices[start]
		indices[start] = indices[i]
		indices[i] = tmp
		_permute_assign(indices, start + 1, costs, best)
		tmp = indices[start]
		indices[start] = indices[i]
		indices[i] = tmp

# Assigns slots for a single target; attackers is an Array[int] of indices into
# attacker_positions and attacker_ranges_world (Dictionary idx->float).
static func assign_for_target(_team: String, _target_idx: int, target_pos: Vector2, attackers: Array, attacker_positions: Array[Vector2], attacker_ranges_world: Dictionary, tile_size: float, prev_slot_assignments: Dictionary, hysteresis_frames: int) -> Dictionary:
	var res: Dictionary = {}
	if attackers == null or attackers.size() == 0:
		return res

	var pairs: Array = [] # [{"idx":int,"angle":float,"pos":Vector2}]
	for attacker_idx in attackers:
		var pos: Vector2 = attacker_positions[attacker_idx]
		var ang: float = _angle_to(target_pos, pos)
		pairs.append({
			"idx": int(attacker_idx),
			"angle": ang,
			"pos": pos
		})
	pairs.sort_custom(func(a, b): return a["angle"] < b["angle"])

	var min_spacing_world: float = max(0.0, tile_size) * 0.7

	if pairs.size() == 1:
		var single: Dictionary = pairs[0]
		var idx_single: int = int(single["idx"])
		var dir_single: Vector2 = (single["pos"] - target_pos).normalized()
		if dir_single == Vector2.ZERO:
			dir_single = Vector2.UP
		var desired_single: float = float(attacker_ranges_world.get(idx_single, 0.0))
		if desired_single <= 0.0:
			desired_single = min_spacing_world
		var slot_pos_single: Vector2 = target_pos + dir_single * desired_single
		res[idx_single] = {
			"position": slot_pos_single,
			"slot_index": 0,
			"angle": float(single["angle"]),
			"mode": "los_arrive",
			"slow_radius": max(desired_single * 1.5, tile_size),
			"corridor_radius": max(desired_single, tile_size * 0.9),
			"corridor_eps": max(tile_size * SINGLE_CORRIDOR_EPS_FACTOR, 1.0)
		}
		return res

	var count: int = pairs.size()
	var step: float = TAU / float(count)
	var candidates: Array[float] = []
	for entry in pairs:
		candidates.append(float(entry["angle"]))

	var best_assignment: Array[int] = []
	var best_ring_angles: Array[float] = []
	var best_cost: float = 1e30

	for base in candidates:
		var ring_angles: Array[float] = []
		for s in range(count):
			ring_angles.append(_wrap_angle(base + step * float(s)))
		var assignment_eval: Dictionary = _evaluate_assignment(pairs, ring_angles, prev_slot_assignments, hysteresis_frames)
		var current_cost: float = float(assignment_eval.get("cost", 1e30))
		if current_cost < best_cost:
			best_cost = current_cost
			best_assignment = assignment_eval.get("assignment", []).duplicate()
			best_ring_angles = ring_angles.duplicate()
	if best_assignment.is_empty():
		return res

	var chord_factor: float = 2.0 * sin(PI / float(count))
	var min_required_radius: float = 0.0
	if chord_factor > 0.0:
		min_required_radius = min_spacing_world / chord_factor

	for i in range(count):
		var entry2: Dictionary = pairs[i]
		var attacker_index: int = int(entry2["idx"])
		var slot_index: int = int(best_assignment[i])
		var slot_angle: float = best_ring_angles[slot_index]
		var desired_r: float = float(attacker_ranges_world.get(attacker_index, 0.0))
		var radius_world: float = max(desired_r, min_required_radius)
		var dir_slot: Vector2 = Vector2(cos(slot_angle), sin(slot_angle))
		if dir_slot == Vector2.ZERO:
			dir_slot = Vector2.UP
		var slot_position: Vector2 = target_pos + dir_slot * radius_world
		res[attacker_index] = {
			"position": slot_position,
			"slot_index": slot_index,
			"angle": slot_angle,
			"mode": "ring",
			"slow_radius": max(radius_world * 1.5, tile_size),
			"corridor_radius": max(radius_world, tile_size),
			"corridor_eps": max(tile_size * SINGLE_CORRIDOR_EPS_FACTOR, 1.0)
		}
	return res

# Public: compute slot world positions for all attackers of a team.
func assign_slots_for_team(team: String,
		attackers_units: Array,            # Array[Unit]
		attacker_positions: Array[Vector2],
		_attackers_alive: Array,
		_attackers_targets: Array[int],
		target_positions: Array[Vector2],
		_targets_alive: Array,
		groups: Dictionary,                # target_idx -> Array[int] of attacker indices
		profiles: Array,                   # Array[MovementProfile]
		tile_size: float,
		debug_frames_left: int = 0,
		watch_indices: Array = [],
		prev_slot_assignments: Dictionary = {},
		hysteresis_frames: int = 0) -> Dictionary:
	var ranges_world: Dictionary = {} # idx -> float
	for i in range(attackers_units.size()):
		var u: Unit = attackers_units[i]
		var band: float = 1.0
		if i < profiles.size() and profiles[i] != null:
			band = max(0.0, float(profiles[i].band_max))
		var desired: float = 0.0
		if u != null:
			desired = max(0.0, float(u.attack_range)) * max(0.0, tile_size) * band
		ranges_world[i] = desired

	var slot_map: Dictionary = {}
	for t_idx in groups.keys():
		var attackers: Array = groups[t_idx]
		if attackers == null or attackers.size() == 0:
			continue
		if t_idx < 0 or t_idx >= target_positions.size():
			continue
		var tgt_pos: Vector2 = target_positions[t_idx]
		var m: Dictionary = assign_for_target(team, int(t_idx), tgt_pos, attackers, attacker_positions, ranges_world, tile_size, prev_slot_assignments, hysteresis_frames)
		# Debug: print assignment summary when enabled. If watch_indices is non-empty,
		# only print for groups that include any watched attacker.
		if Debug.enabled and debug_frames_left > 0:
			var should_print: bool = true
			if watch_indices != null and watch_indices.size() > 0:
				should_print = false
				for wi in watch_indices:
					if attackers.has(int(wi)):
						should_print = true
						break
			if should_print:
				# Build attacker angle list for context
				var pairs_dbg: Array = []
				for idx in attackers:
					var p_dbg: Vector2 = attacker_positions[idx]
					pairs_dbg.append([idx, _angle_to(tgt_pos, p_dbg)])
				pairs_dbg.sort_custom(func(a, b): return a[1] < b[1])
				var idxs: Array = []
				var angs: Array = []
				for pr in pairs_dbg:
					idxs.append(int(pr[0]))
					angs.append(float(pr[1]))
				print("[Slots] team=", team, " target=", t_idx, " idxs=", idxs, " angles=", angs)
				for k in m.keys():
					var slot_data: Dictionary = m[k]
					var pos_k: Vector2 = slot_data.get("position", tgt_pos)
					var ang_k: float = float(slot_data.get("angle", 0.0))
					print("[Slots] team=", team, " target=", t_idx, " idx=", k, " -> slot_ang=", ang_k, " pos=", pos_k)
		for k in m.keys():
			slot_map[k] = m[k]
	return slot_map
