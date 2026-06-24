extends RefCounted

# Backline Access Kernel
# Computes per-side first backline contact time and all units entering enemy backline.
# Result keys: {
#   backline_access: {
#     a: { first_backline_contact_s, first_backline_rank, first_backline_unit_id, entered_by_unit, entries, samples },
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
var _enemy_backline: Dictionary = { SIDE_A: {}, SIDE_B: {} } # per attacker side -> opponent backline zone dict
var _entered_time: Dictionary = { SIDE_A: {}, SIDE_B: {} }  # side -> unit_index -> time first entered enemy backline
var _supported: bool = false
var _index_to_uid: Dictionary = { SIDE_A: {}, SIDE_B: {} }   # side -> unit_index -> unit_id

func attach(engine, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
    detach()
    _engine = engine
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _enemy_backline = _extract_enemy_backlines(context_tags)
    _index_to_uid = _extract_index_map(context_tags)
    _entered_time = { SIDE_A: {}, SIDE_B: {} }
    _connected = _connect()
    _supported = _connected and (not _enemy_backline.get(SIDE_A, {}).is_empty() or not _enemy_backline.get(SIDE_B, {}).is_empty())

func detach() -> void:
    if _engine != null and _engine.has_signal("position_updated") and _engine.is_connected("position_updated", Callable(self, "_on_position_updated")):
        _engine.position_updated.disconnect(_on_position_updated)
    _engine = null
    _connected = false

func tick(delta_s: float) -> void:
    _time_s += max(0.0, float(delta_s))

func finalize(_total_time_s: float) -> void:
    pass

func result() -> Dictionary:
    return {
        "backline_access": {
            "supported": _supported,
            SIDE_A: _summarize_side(SIDE_A),
            SIDE_B: _summarize_side(SIDE_B)
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

func _extract_enemy_backlines(context_tags: Dictionary) -> Dictionary:
    var out := { SIDE_A: {}, SIDE_B: {} }
    var zones = context_tags.get("zones", {})
    if not (zones is Dictionary):
        return out
    var za: Dictionary = zones.get(SIDE_A, {})
    var zb: Dictionary = zones.get(SIDE_B, {})
    # For side A (player), enemy is B => use B.backline
    out[SIDE_A] = zb.get("backline", {}) if zb is Dictionary else {}
    # For side B, enemy is A => use A.backline
    out[SIDE_B] = za.get("backline", {}) if za is Dictionary else {}
    return out

func _extract_index_map(context_tags: Dictionary) -> Dictionary:
    var out := { SIDE_A: {}, SIDE_B: {} }
    if not (context_tags is Dictionary):
        return out
    var ut: Dictionary = context_tags.get("unit_timelines", {})
    if not (ut is Dictionary):
        return out
    for side in [SIDE_A, SIDE_B]:
        var arr: Array = ut.get(side, [])
        if not (arr is Array):
            continue
        var m: Dictionary = {}
        for e in arr:
            if not (e is Dictionary):
                continue
            var idx_val = (e as Dictionary).get("unit_index", null)
            if typeof(idx_val) != TYPE_INT:
                continue
            var uid := String((e as Dictionary).get("unit_id", ""))
            m[int(idx_val)] = uid
        out[side] = m
    return out

func _on_position_updated(team: String, index: int, x: float, y: float) -> void:
    var side := _source_side(team)
    if side == "":
        return
    var bl: Dictionary = _enemy_backline.get(side, {})
    if bl.is_empty():
        return
    if (_entered_time.get(side, {}) as Dictionary).has(index):
        return
    var center: Dictionary = bl.get("center", {})
    if center.is_empty():
        return
    var cx := float(center.get("x", 0.0))
    var cy := float(center.get("y", 0.0))
    var half_len := float(bl.get("half_length", 0.0))
    var half_w := float(bl.get("half_width", 0.0))
    # Approximate axis-aligned check around center
    if abs(x - cx) <= half_len and abs(y - cy) <= half_w:
        var map_side: Dictionary = _entered_time.get(side, {})
        map_side[index] = _time_s
        _entered_time[side] = map_side

func _summarize_side(side: String) -> Dictionary:
    var times: Dictionary = _entered_time.get(side, {})
    if times.is_empty():
        return {
            "first_backline_contact_s": null,
            "first_backline_rank": null,
            "first_backline_unit_id": "",
            "entered_by_unit": {},
            "entries": [],
            "samples": 0
        }
    # Find earliest
    var arr: Array = []
    for idx in times.keys():
        arr.append({"idx": int(idx), "t": float(times[idx])})
    arr.sort_custom(func(a, b): return float(a.get("t")) < float(b.get("t")))
    var first = arr[0]
    var rank := 1
    var idx0: int = int(first.get("idx", -1))
    var uid_map: Dictionary = _index_to_uid.get(side, {})
    var uid := String(uid_map.get(idx0, ""))
    var entered_by_unit: Dictionary = {}
    var entries: Array = []
    for e in arr:
        var unit_index: int = int((e as Dictionary).get("idx", -1))
        var contact_s: float = float((e as Dictionary).get("t", -1.0))
        var unit_id: String = String(uid_map.get(unit_index, ""))
        if unit_id != "":
            if not entered_by_unit.has(unit_id) or contact_s < float(entered_by_unit.get(unit_id, INF)):
                entered_by_unit[unit_id] = contact_s
        entries.append({
            "unit_index": unit_index,
            "unit_id": unit_id,
            "first_backline_contact_s": contact_s
        })
    return {
        "first_backline_contact_s": float(first.get("t", -1.0)),
        "first_backline_rank": rank,
        "first_backline_unit_id": uid,
        "entered_by_unit": entered_by_unit,
        "entries": entries,
        "samples": arr.size()
    }
