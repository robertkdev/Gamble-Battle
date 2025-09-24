extends Object
class_name MovementMath

# MovementMath
# Small collection of geometry/helpers used by both Movement and Engine. Keeping
# this in one place avoids discrepancies between range checks and movement gates.

# Returns a normalized direction vector from 'from' to 'to'.
# If points coincide, returns Vector2.ZERO.
static func radial(from: Vector2, to: Vector2) -> Vector2:
    var v: Vector2 = (to - from)
    if v == Vector2.ZERO:
        return Vector2.ZERO
    return v.normalized()

# Clamps a world position to a Rect2 (inclusive). If rect is empty, returns v.
static func clamp_to_rect(v: Vector2, rect: Rect2) -> Vector2:
    if rect == Rect2():
        return v
    var nx: float = clampf(v.x, rect.position.x, rect.position.x + rect.size.x)
    var ny: float = clampf(v.y, rect.position.y, rect.position.y + rect.size.y)
    return Vector2(nx, ny)

# Returns true if 'unit' is considered in range of target based on its
# attack_range in tiles. Performs type validation and converts to world pixels
# via 'tile_size'. Adds a small 'epsilon' forgiveness to avoid sticky edges.
static func within_range(unit: Unit, my_pos: Vector2, tgt_pos: Vector2, tile_size: float, epsilon: float, band_multiplier: float = 1.0) -> bool:
    assert(unit != null)
    var t: int = typeof(unit.attack_range)
    assert(t == TYPE_INT or t == TYPE_FLOAT)
    var desired: float = max(0.0, float(unit.attack_range)) * tile_size * max(0.0, band_multiplier)
    var dist: float = my_pos.distance_to(tgt_pos)
    return dist <= (desired + max(0.0, epsilon))

# Returns true if target lies within a circle of radius (radius_tiles * tile_size)
# around center. Uses the same epsilon forgiveness as other range checks.
static func within_radius_tiles(center: Vector2, tgt_pos: Vector2, radius_tiles: float, tile_size: float, epsilon: float) -> bool:
    var world_r: float = max(0.0, float(radius_tiles)) * tile_size
    var dist: float = center.distance_to(tgt_pos)
    return dist <= (world_r + max(0.0, epsilon))

# Squared distance from point P to segment AB.
static func distance_sq_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
    var ab: Vector2 = b - a
    var ap: Vector2 = p - a
    var ab_len2: float = ab.length_squared()
    if ab_len2 <= 0.0:
        return ap.length_squared()
    var t: float = clampf(ap.dot(ab) / ab_len2, 0.0, 1.0)
    var closest: Vector2 = a + ab * t
    return (p - closest).length_squared()

# Returns true if segment AB intersects a circle centered at C with radius R.
static func segment_intersects_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
    var r2: float = max(0.0, r) * max(0.0, r)
    return distance_sq_point_to_segment(c, a, b) <= r2

# Returns true if segment AB intersects any circle from an array of centers.
static func segment_intersects_any_circle(a: Vector2, b: Vector2, centers: Array[Vector2], r: float) -> bool:
    for cc in centers:
        if segment_intersects_circle(a, b, cc, r):
            return true
    return false

# Returns true if the straight segment from A to B is clear of any circles.
static func line_clear_of_circles(a: Vector2, b: Vector2, centers: Array[Vector2], r: float) -> bool:
    return not segment_intersects_any_circle(a, b, centers, r)
