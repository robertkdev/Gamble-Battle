extends RefCounted

# Throughput Kernel
# Computes windowed damage shares and sustained damage rate.
# Keys under kernels:
#   throughput: {
#     supported: bool,
#     a: { early_0_3s_share, sustained_3_10s_share, sustained_damage_rate, window_start_s, window_end_s, window_duration_s },
#     b: { ... },
#     peers: { a: float[], b: float[], all: float[], window_start_s, window_end_s }
#   }

const SIDE_A := "a"
const SIDE_B := "b"
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var _engine = null
var _connected := false
var _player_is_team_a: bool = true
var _time_s: float = 0.0
var _total_time_s: float = 0.0

var _hits: Dictionary = { SIDE_A: [], SIDE_B: [] } # side -> Array[{t: float, d: float, sidx: int}]
var _unit_hits: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> idx -> Array[{t: float, d: float}]

func attach(engine, player_is_team_a: bool = true) -> void:
    detach()
    _engine = engine
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _total_time_s = 0.0
    _hits = { SIDE_A: [], SIDE_B: [] }
    _unit_hits = { SIDE_A: {}, SIDE_B: {} }
    _connected = _connect()

func detach() -> void:
    if _engine != null and _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
        _engine.hit_applied.disconnect(_on_hit_applied)
    _engine = null
    _connected = false

func tick(delta_s: float) -> void:
    _time_s += max(0.0, float(delta_s))

func finalize(total_time_s: float) -> void:
    _total_time_s = max(_time_s, float(total_time_s))

func result() -> Dictionary:
    var start_s: float = 3.0
    var end_s: float = _resolve_window_end()
    var dur_s: float = max(0.0, end_s - start_s)
    var out_a := _summarize_side(SIDE_A, start_s, end_s, dur_s)
    var out_b := _summarize_side(SIDE_B, start_s, end_s, dur_s)
    var peers_all: Array = []
    var peers_a: Array = _peer_rates(SIDE_A, start_s, end_s, dur_s)
    var peers_b: Array = _peer_rates(SIDE_B, start_s, end_s, dur_s)
    var peers_idx_a: Dictionary = _peer_rates_by_index(SIDE_A, start_s, end_s, dur_s)
    var peers_idx_b: Dictionary = _peer_rates_by_index(SIDE_B, start_s, end_s, dur_s)
    for v in peers_a: peers_all.append(float(v))
    for w in peers_b: peers_all.append(float(w))
    return {
        "throughput": {
            "supported": _connected,
            SIDE_A: out_a,
            SIDE_B: out_b,
            "peers": {
                "a": peers_a,
                "b": peers_b,
                "all": peers_all,
                "window_start_s": start_s,
                "window_end_s": end_s
            },
            "peers_by_index": {
                "a": peers_idx_a,
                "b": peers_idx_b,
                "window_start_s": start_s,
                "window_end_s": end_s
            }
        }
    }

func register(_aggregator) -> RefCounted:
    return self

# --- internals ---

func _connect() -> bool:
    if _engine == null:
        return false
    if _engine.has_signal("hit_applied"):
        _engine.connect("hit_applied", Callable(self, "_on_hit_applied"))
    return true

func _source_side(team_str: String) -> String:
    var t := String(team_str)
    if _player_is_team_a:
        return (SIDE_A if t == TEAM_PLAYER else SIDE_B)
    return (SIDE_A if t == TEAM_ENEMY else SIDE_B)

func _on_hit_applied(team: String, source_index: int, _target_index: int, _rolled: int, dealt: int, _crit: bool, _before_hp: int, _after_hp: int, _pcd: float, _ecd: float) -> void:
    var side := _source_side(team)
    var dmg: float = float(max(0, int(dealt)))
    if dmg <= 0.0:
        return
    var sidx: int = int(source_index)
    # Record side-level
    var arr: Array = _hits.get(side, [])
    arr.append({"t": _time_s, "d": dmg, "sidx": sidx})
    _hits[side] = arr
    # Record per-unit
    var side_map: Dictionary = _unit_hits.get(side, {})
    var uh: Array = side_map.get(sidx, [])
    if not (uh is Array):
        uh = []
    uh.append({"t": _time_s, "d": dmg})
    side_map[sidx] = uh
    _unit_hits[side] = side_map

func _resolve_window_end() -> float:
    var cap: float = 10.0
    if _total_time_s <= 0.0:
        return cap
    return min(cap, _total_time_s)

func _sum_in_window(events: Array, t0: float, t1: float) -> float:
    if events == null or not (events is Array):
        return 0.0
    var s: float = 0.0
    for e in events:
        if not (e is Dictionary):
            continue
        var t: float = float((e as Dictionary).get("t", 0.0))
        if t < t0 or t > t1:
            continue
        s += float((e as Dictionary).get("d", 0.0))
    return s

func _total_damage(events: Array) -> float:
    var s: float = 0.0
    if events is Array:
        for e in events:
            if e is Dictionary:
                s += float((e as Dictionary).get("d", 0.0))
    return s

func _summarize_side(side: String, start_s: float, end_s: float, dur_s: float) -> Dictionary:
    var arr: Array = _hits.get(side, [])
    var total: float = _total_damage(arr)
    var early: float = _sum_in_window(arr, 0.0, 3.0)
    var sustained: float = _sum_in_window(arr, start_s, end_s)
    var early_share: float = (early / max(1.0, total)) if total > 0.0 else 0.0
    var sustained_share: float = (sustained / max(1.0, total)) if total > 0.0 else 0.0
    var sustained_rate: float = (sustained / max(0.001, dur_s)) if dur_s > 0.0 else 0.0
    return {
        "early_0_3s_share": early_share,
        "sustained_3_10s_share": sustained_share,
        "sustained_damage_rate": sustained_rate,
        "window_start_s": start_s,
        "window_end_s": end_s,
        "window_duration_s": dur_s
    }

func _peer_rates(side: String, start_s: float, end_s: float, dur_s: float) -> Array:
    var out: Array = []
    if dur_s <= 0.0:
        return out
    var side_map: Dictionary = _unit_hits.get(side, {})
    if not (side_map is Dictionary):
        return out
    # Sort indices for deterministic order matching team index when consumed alongside aggregates
    var keys: Array = []
    for k in side_map.keys(): keys.append(int(k))
    keys.sort()
    for idx in keys:
        var ev: Array = side_map.get(idx, [])
        var dmg: float = _sum_in_window(ev, start_s, end_s)
        var rate: float = dmg / max(0.001, dur_s)
        out.append(rate)
    return out

func _peer_rates_by_index(side: String, start_s: float, end_s: float, dur_s: float) -> Dictionary:
    var out: Dictionary = {}
    if dur_s <= 0.0:
        return out
    var side_map: Dictionary = _unit_hits.get(side, {})
    if not (side_map is Dictionary):
        return out
    for idx in side_map.keys():
        var ev: Array = side_map.get(idx, [])
        var dmg: float = _sum_in_window(ev, start_s, end_s)
        var rate: float = dmg / max(0.001, dur_s)
        out[int(idx)] = rate
    return out
