extends RefCounted

# Positioning Kernel
# Computes per-side time share inside own frontline zone and inside enemy backline zone.
# Result keys: {
#   positioning: {
#     a: { frontline_zone_share, backline_zone_share, observed_s },
#     b: { ... }
#   }
# }

const SIDE_A := "a"
const SIDE_B := "b"
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var _engine = null
var _connected := false
var _time_s: float = 0.0
var _player_is_team_a: bool = true
var _own_frontline: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _enemy_backline: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _positions: Dictionary = { SIDE_A: [], SIDE_B: [] } # latest pos per index
var _alive: Dictionary = { SIDE_A: [], SIDE_B: [] }
var _zone_time: Dictionary = { SIDE_A: {"frontline": 0.0, "observed": 0.0}, SIDE_B: {"frontline": 0.0, "observed": 0.0} }
var _enemy_back_time: Dictionary = { SIDE_A: {"inside": 0.0, "observed": 0.0}, SIDE_B: {"inside": 0.0, "observed": 0.0} }
var _total_time_s: float = 0.0

func attach(engine, team_sizes: Dictionary, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
    # team_sizes: { a: int, b: int }
    detach()
    _engine = engine
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _own_frontline = _extract_frontlines(context_tags)
    _enemy_backline = _extract_enemy_backlines(context_tags)
    _positions = { SIDE_A: [], SIDE_B: [] }
    _alive = { SIDE_A: [], SIDE_B: [] }
    var asz := int(team_sizes.get(SIDE_A, 0))
    var bsz := int(team_sizes.get(SIDE_B, 0))
    for i in range(max(0, asz)):
        (_positions[SIDE_A] as Array).append(null)
        (_alive[SIDE_A] as Array).append(true)
    for j in range(max(0, bsz)):
        (_positions[SIDE_B] as Array).append(null)
        (_alive[SIDE_B] as Array).append(true)
    _zone_time = { SIDE_A: {"frontline": 0.0, "observed": 0.0}, SIDE_B: {"frontline": 0.0, "observed": 0.0} }
    _enemy_back_time = { SIDE_A: {"inside": 0.0, "observed": 0.0}, SIDE_B: {"inside": 0.0, "observed": 0.0} }
    _connected = _connect()

func detach() -> void:
    if _engine != null and _engine.has_signal("position_updated") and _engine.is_connected("position_updated", Callable(self, "_on_position_updated")):
        _engine.position_updated.disconnect(_on_position_updated)
    _engine = null
    _connected = false

func tick(delta_s: float) -> void:
    var dt: float = max(0.0, float(delta_s))
    _time_s += dt
    # accumulate per side using dynamic zones computed from current centroids and forward axis
    for side in [SIDE_A, SIDE_B]:
        var opp: String = _opponent_side(side)
        var zone_self: Dictionary = _compute_dynamic_zone_parent(side)
        var zone_enemy: Dictionary = _compute_dynamic_zone_parent(opp)
        var pos_arr: Array = _positions.get(side, [])
        for i in range(pos_arr.size()):
            var pos = pos_arr[i]
            if not (pos is Vector2):
                continue
            _zone_time[side]["observed"] = float(_zone_time[side].get("observed", 0.0)) + dt
            if _is_inside_zone_oriented(pos, zone_self, "frontline"):
                _zone_time[side]["frontline"] = float(_zone_time[side].get("frontline", 0.0)) + dt
            _enemy_back_time[side]["observed"] = float(_enemy_back_time[side].get("observed", 0.0)) + dt
            if _is_inside_zone_oriented(pos, zone_enemy, "backline"):
                _enemy_back_time[side]["inside"] = float(_enemy_back_time[side].get("inside", 0.0)) + dt

func finalize(total_time_s: float) -> void:
    _total_time_s = max(_time_s, float(total_time_s))

func result() -> Dictionary:
    var a_front := fraction(_zone_time[SIDE_A]["frontline"], max(0.001, _zone_time[SIDE_A]["observed"]))
    var b_front := fraction(_zone_time[SIDE_B]["frontline"], max(0.001, _zone_time[SIDE_B]["observed"]))
    var a_back := fraction(_enemy_back_time[SIDE_A]["inside"], max(0.001, _enemy_back_time[SIDE_A]["observed"]))
    var b_back := fraction(_enemy_back_time[SIDE_B]["inside"], max(0.001, _enemy_back_time[SIDE_B]["observed"]))
    return {
        "positioning": {
            SIDE_A: {
                "frontline_zone_share": a_front,
                "backline_zone_share": a_back,
                "observed_s": _zone_time[SIDE_A]["observed"],
                "observed_unit_seconds": _zone_time[SIDE_A]["observed"],
                "fight_time_seconds": _total_time_s
            },
            SIDE_B: {
                "frontline_zone_share": b_front,
                "backline_zone_share": b_back,
                "observed_s": _zone_time[SIDE_B]["observed"],
                "observed_unit_seconds": _zone_time[SIDE_B]["observed"],
                "fight_time_seconds": _total_time_s
            }
        }
    }

func register(_aggregator) -> RefCounted:
    return self

# --- internals ---

func _connect() -> bool:
    if _engine == null:
        return false
    if _engine.has_signal("position_updated"):
        _engine.connect("position_updated", Callable(self, "_on_position_updated"))
    return true

func _source_side(team_str: String) -> String:
    var t := String(team_str)
    if _player_is_team_a:
        return (SIDE_A if t == TEAM_PLAYER else SIDE_B)
    return (SIDE_A if t == TEAM_ENEMY else SIDE_B)

func _on_position_updated(team: String, index: int, x: float, y: float) -> void:
    var side := _source_side(team)
    if side == "":
        return
    var arr: Array = _positions.get(side, [])
    if index < 0:
        return
    while index >= arr.size():
        arr.append(null)
    arr[index] = Vector2(x, y)
    _positions[side] = arr

func _extract_frontlines(context_tags: Dictionary) -> Dictionary:
    var out := { SIDE_A: {}, SIDE_B: {} }
    var zones = context_tags.get("zones", {})
    if not (zones is Dictionary):
        return out
    for side in [SIDE_A, SIDE_B]:
        var zd = zones.get(side, {})
        if zd is Dictionary:
            out[side] = zd.get("frontline", {})
    return out

func _extract_enemy_backlines(context_tags: Dictionary) -> Dictionary:
    var out := { SIDE_A: {}, SIDE_B: {} }
    var zones = context_tags.get("zones", {})
    if not (zones is Dictionary):
        return out
    var za: Dictionary = zones.get(SIDE_A, {})
    var zb: Dictionary = zones.get(SIDE_B, {})
    out[SIDE_A] = (zb.get("backline", {}) if zb is Dictionary else {})
    out[SIDE_B] = (za.get("backline", {}) if za is Dictionary else {})
    return out

func _opponent_side(side: String) -> String:
    return (SIDE_B if side == SIDE_A else SIDE_A)

func _is_inside_zone_oriented(pos: Vector2, zone_parent: Dictionary, which: String) -> bool:
    if zone_parent == null or zone_parent.is_empty():
        return false
    var z: Dictionary = zone_parent.get(which, {})
    if z.is_empty():
        return false
    var center_dict: Dictionary = z.get("center", {})
    var center: Vector2 = Vector2(float(center_dict.get("x", 0.0)), float(center_dict.get("y", 0.0)))
    var half_length: float = float(z.get("half_length", 0.0))
    var half_width: float = float(z.get("half_width", 0.0))
    var fdict: Dictionary = zone_parent.get("forward", {})
    var forward: Vector2 = Vector2.RIGHT
    if not fdict.is_empty():
        forward = Vector2(float(fdict.get("x", 1.0)), float(fdict.get("y", 0.0)))
    if forward.length_squared() <= 0.0001:
        forward = Vector2.RIGHT
    forward = forward.normalized()
    var perp: Vector2 = Vector2(-forward.y, forward.x)
    var delta: Vector2 = pos - center
    var along: float = abs(delta.dot(forward))
    var lateral: float = abs(delta.dot(perp))
    return along <= (half_length + 0.0001) and lateral <= (half_width + 0.0001)

func _compute_dynamic_zone_parent(side: String) -> Dictionary:
    var self_arr: Array = _positions.get(side, [])
    var opp: String = _opponent_side(side)
    var enemy_arr: Array = _positions.get(opp, [])
    var c_self: Vector2 = _centroid(self_arr)
    var c_enemy: Vector2 = _centroid(enemy_arr)
    var forward: Vector2 = (c_enemy - c_self)
    if forward.length_squared() <= 0.0001:
        forward = Vector2.RIGHT
    forward = forward.normalized()
    var perp: Vector2 = Vector2(-forward.y, forward.x)
    var front_weight: float = 0.0
    var front_total: float = 0.0
    var front_max: float = 0.0
    var back_weight: float = 0.0
    var back_total: float = 0.0
    var back_max: float = 0.0
    var lat_weight: float = 0.0
    var lat_total: float = 0.0
    for p in self_arr:
        if not (p is Vector2):
            continue
        var offset: Vector2 = p - c_self
        var proj: float = offset.dot(forward)
        if proj >= 0.0:
            front_weight += 1.0
            front_total += proj
            if proj > front_max:
                front_max = proj
        else:
            var b: float = -proj
            back_weight += 1.0
            back_total += b
            if b > back_max:
                back_max = b
        var lat: float = abs(offset.dot(perp))
        lat_weight += 1.0
        lat_total += lat
    var front_offset: float = (front_total / front_weight) if front_weight > 0.0 else front_max
    var back_offset: float = (back_total / back_weight) if back_weight > 0.0 else back_max
    var half_width: float = (lat_total / lat_weight) if lat_weight > 0.0 else 0.0
    var front_center: Vector2 = c_self + forward * front_offset
    var back_center: Vector2 = c_self - forward * back_offset
    return {
        "forward": {"x": forward.x, "y": forward.y},
        "frontline": {
            "center": {"x": front_center.x, "y": front_center.y},
            "half_length": front_offset,
            "half_width": half_width
        },
        "backline": {
            "center": {"x": back_center.x, "y": back_center.y},
            "half_length": back_offset,
            "half_width": half_width
        }
    }

func _centroid(arr: Array) -> Vector2:
    var acc: Vector2 = Vector2.ZERO
    var n: float = 0.0
    for v in arr:
        if v is Vector2:
            acc += v
            n += 1.0
    if n <= 0.0:
        return Vector2.ZERO
    return acc / n

func fraction(n: float, d: float) -> float:
    if d <= 0.0:
        return 0.0
    return n / d
