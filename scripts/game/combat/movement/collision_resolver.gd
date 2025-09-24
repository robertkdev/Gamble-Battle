extends RefCounted
class_name CollisionResolver

# CollisionResolver
# Simple O(n^2) circle separation working across both teams. Performs a single
# separation pass after positions have been advanced for the frame. The amount
# of correction applied to each unit is capped by that unit's own attempted step
# length for the frame, to avoid large teleports or excessive push.
#
# Units are treated as circles of radius = tile_size * unit_radius_factor. All
# alive units block each other; dead/invalid units are ignored. Results are
# clamped to arena bounds.

func resolve(
        player_positions: Array[Vector2], enemy_positions: Array[Vector2],
        player_alive: Array[bool], enemy_alive: Array[bool],
        player_step_caps: Array[float], enemy_step_caps: Array[float],
        radius: float, bounds: Rect2,
        iterations: int = 1,
        friendly_soft: bool = false,
        debug_log: bool = false) -> void:
    if radius <= 0.0:
        return
    var all_pos: Array[Vector2] = []
    var all_alive: Array[bool] = []
    var caps: Array[float] = []
    var tags: Array = [] # [team, index]
    for i in range(player_positions.size()):
        all_pos.append(player_positions[i])
        all_alive.append((player_alive[i] if i < player_alive.size() else true))
        caps.append((player_step_caps[i] if i < player_step_caps.size() else 0.0))
        tags.append(["player", i])
    var offset_enemy: int = all_pos.size()
    for j in range(enemy_positions.size()):
        all_pos.append(enemy_positions[j])
        all_alive.append((enemy_alive[j] if j < enemy_alive.size() else true))
        caps.append((enemy_step_caps[j] if j < enemy_step_caps.size() else 0.0))
        tags.append(["enemy", j])

    var min_dist: float = radius * 2.0
    var min_dist2: float = min_dist * min_dist

    var iters: int = max(1, int(iterations))
    var total_pairs: int = 0
    var resolved_pairs: int = 0
    var capped_pairs: int = 0
    var friend_pairs: int = 0
    var enemy_pairs: int = 0
    var max_overlap_seen: float = 0.0
    for _iter in range(iters):
        for a in range(all_pos.size()):
            if not all_alive[a]:
                continue
            for b in range(a + 1, all_pos.size()):
                if not all_alive[b]:
                    continue
                var pa: Vector2 = all_pos[a]
                var pb: Vector2 = all_pos[b]
                var diff: Vector2 = pb - pa
                var d2: float = diff.length_squared()
                if d2 >= min_dist2 or d2 == 0.0:
                    continue
                var d: float = sqrt(d2)
                var overlap: float = min_dist - d
                if overlap > max_overlap_seen:
                    max_overlap_seen = overlap
                var dir: Vector2 = diff / d if d > 0.0 else Vector2.RIGHT
                var half: float = overlap * 0.5

                var same_team: bool = (tags[a][0] == tags[b][0])
                var cap_a: float = max(0.0, caps[a])
                var cap_b: float = max(0.0, caps[b])

                var move_a: float
                var move_b: float
                if same_team and friendly_soft:
                    # Friendly pairs separate fully, ignoring per-step caps for a smooth yield.
                    move_a = half
                    move_b = half
                    friend_pairs += 1
                else:
                    move_a = min(half, cap_a)
                    move_b = min(half, cap_b)
                    if same_team:
                        friend_pairs += 1
                    else:
                        enemy_pairs += 1
                    if move_a < half or move_b < half:
                        capped_pairs += 1

                all_pos[a] = all_pos[a] - dir * move_a
                all_pos[b] = all_pos[b] + dir * move_b
                total_pairs += 1
                if move_a > 0.0 or move_b > 0.0:
                    resolved_pairs += 1

    # Write back and clamp
    for i2 in range(all_pos.size()):
        var t: String = tags[i2][0]
        var idx: int = int(tags[i2][1])
        var p: Vector2 = all_pos[i2]
        if bounds != Rect2():
            p.x = clampf(p.x, bounds.position.x, bounds.position.x + bounds.size.x)
            p.y = clampf(p.y, bounds.position.y, bounds.position.y + bounds.size.y)
        if t == "player":
            if idx < player_positions.size():
                player_positions[idx] = p
        else:
            if idx < enemy_positions.size():
                enemy_positions[idx] = p

    if debug_log:
        var dbg := preload("res://scripts/util/debug.gd")
        if dbg.enabled:
            print("[Coll] iters=", iters, " pairs=", total_pairs, " resolved=", resolved_pairs,
                  " max_overlap=", max_overlap_seen, " friend_pairs=", friend_pairs, " enemy_pairs=", enemy_pairs,
                  " capped_pairs=", capped_pairs, " soft=", friendly_soft)
