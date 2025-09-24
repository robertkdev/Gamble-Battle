extends RefCounted
class_name SlotStrategy
const Debug := preload("res://scripts/util/debug.gd")

const TAU := PI * 2.0

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

# Assigns slots for a single target; attackers is an Array[int] of indices into
# attacker_positions and attacker_ranges_world (Dictionary idx->float).
static func assign_for_target(target_pos: Vector2, attackers: Array, attacker_positions: Array[Vector2], attacker_ranges_world: Dictionary, slot_count: int, tile_size: float) -> Dictionary:
    var res: Dictionary = {}
    if attackers == null or attackers.size() == 0:
        return res
    var pairs: Array = [] # [idx, angle]
    for idx in attackers:
        var p: Vector2 = attacker_positions[idx]
        var ang: float = _angle_to(target_pos, p)
        pairs.append([idx, ang])
    pairs.sort_custom(func(a, b): return a[1] < b[1])

    # Use as many slots as attackers to avoid stacking duplicates on the same angle.
    var slots_needed: int = max(1, max(slot_count, attackers.size()))
    var base: Array[float] = _slot_angles(slots_needed)
    var best_offset: int = 0
    var best_cost: float = 1e30
    for off in range(base.size()):
        var cost: float = 0.0
        for i in range(pairs.size()):
            var ang_a: float = float(pairs[i][1])
            var ang_s: float = base[(off + i) % base.size()]
            cost += _circ_dist(ang_a, ang_s)
        if cost < best_cost:
            best_cost = cost
            best_offset = off

    # Ensure adjacent slots have at least one unit diameter spacing around the ring
    # Unit diameter ~= 2 * (tile_size * 0.35) = 0.7 * tile_size
    var min_spacing_world: float = max(0.0, tile_size) * 0.7
    var min_required_radius: float = 0.0
    if slots_needed >= 2:
        var chord_factor: float = 2.0 * sin(PI / float(slots_needed))
        if chord_factor > 0.0:
            min_required_radius = min_spacing_world / chord_factor

    for i2 in range(pairs.size()):
        var idx2: int = int(pairs[i2][0])
        var ang_s2: float = base[(best_offset + i2) % base.size()]
        var r_base: float = float(attacker_ranges_world.get(idx2, 0.0))
        var r: float = max(r_base, min_required_radius)
        var dir := Vector2(cos(ang_s2), sin(ang_s2))
        res[idx2] = target_pos + dir * r
    return res

# Public: compute slot world positions for all attackers of a team.
func assign_slots_for_team(team: String,
        attackers_units: Array,            # Array[Unit]
        attacker_positions: Array[Vector2],
        attackers_alive: Array,
        attackers_targets: Array[int],
        target_positions: Array[Vector2],
        targets_alive: Array,
        groups: Dictionary,                # target_idx -> Array[int] of attacker indices
        profiles: Array,                   # Array[MovementProfile]
        tile_size: float,
        debug_frames_left: int = 0,
        watch_indices: Array = []) -> Dictionary:
    var ranges_world: Dictionary = {} # idx -> float
    for i in range(attackers_units.size()):
        var u = attackers_units[i]
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
        var m: Dictionary = assign_for_target(tgt_pos, attackers, attacker_positions, ranges_world, 5, tile_size)
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
                var base_dbg := _slot_angles(max(5, attackers.size()))
                # Try all offsets to compute the one we used
                var best_off: int = 0
                var best_cost: float = 1e30
                for off in range(base_dbg.size()):
                    var cost: float = 0.0
                    for i in range(pairs_dbg.size()):
                        cost += _circ_dist(float(pairs_dbg[i][1]), base_dbg[(off + i) % base_dbg.size()])
                    if cost < best_cost:
                        best_cost = cost
                        best_off = off
                var idxs: Array = []
                var angs: Array = []
                for pr in pairs_dbg:
                    idxs.append(int(pr[0]))
                    angs.append(float(pr[1]))
                print("[Slots] team=", team, " target=", t_idx, " idxs=", idxs, " angles=", angs,
                      " slot_angles=", base_dbg, " offset=", best_off, " cost=", best_cost)
                for k in m.keys():
                    var pos_k: Vector2 = m[k]
                    var ang_k: float = _angle_to(tgt_pos, pos_k)
                    print("[Slots] team=", team, " target=", t_idx, " idx=", k, " -> slot_ang=", ang_k, " pos=", pos_k)
        for k in m.keys():
            slot_map[k] = m[k]
    return slot_map
