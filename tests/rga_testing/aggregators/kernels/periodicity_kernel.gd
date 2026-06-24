extends RefCounted

# Periodicity Kernel
# Computes per-side burst periodicity metrics from hit_applied events.
# Keys: {
#   periodicity: {
#     a: { top_2s_damage_share, peak_over_mean, supported },
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
var _hits: Dictionary = { SIDE_A: [], SIDE_B: [] } # arrays of {t, dmg}
# Magic-only decomposition (from hit_components)
var _hits_magic: Dictionary = { SIDE_A: [], SIDE_B: [] } # arrays of {t, mag}
var _total_time_s: float = 0.0

func attach(engine, player_is_team_a: bool = true) -> void:
    detach()
    _engine = engine
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _hits = { SIDE_A: [], SIDE_B: [] }
    _hits_magic = { SIDE_A: [], SIDE_B: [] }
    _connected = _connect()

func detach() -> void:
    if _engine != null and _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
        _engine.hit_applied.disconnect(_on_hit_applied)
    if _engine != null and _engine.has_signal("hit_components") and _engine.is_connected("hit_components", Callable(self, "_on_hit_components")):
        _engine.hit_components.disconnect(_on_hit_components)
    _engine = null
    _connected = false

func tick(delta_s: float) -> void:
    _time_s += max(0.0, float(delta_s))

func finalize(total_time_s: float) -> void:
    _total_time_s = max(_time_s, float(total_time_s))

func result() -> Dictionary:
    var out_a := _compute_side(_hits.get(SIDE_A, []))
    var out_b := _compute_side(_hits.get(SIDE_B, []))
    var out_a_mag := _compute_side(_hits_magic.get(SIDE_A, []))
    var out_b_mag := _compute_side(_hits_magic.get(SIDE_B, []))
    # Merge magic metrics under explicit keys for consumers
    out_a["top_2s_magic_damage_share"] = float(out_a_mag.get("top_2s_damage_share", 0.0))
    out_a["magic_peak_over_mean"] = float(out_a_mag.get("peak_over_mean", 0.0))
    out_a["magic_supported"] = bool(out_a_mag.get("supported", false))
    out_b["top_2s_magic_damage_share"] = float(out_b_mag.get("top_2s_damage_share", 0.0))
    out_b["magic_peak_over_mean"] = float(out_b_mag.get("peak_over_mean", 0.0))
    out_b["magic_supported"] = bool(out_b_mag.get("supported", false))
    return { "periodicity": { SIDE_A: out_a, SIDE_B: out_b } }

func register(_aggregator) -> RefCounted:
    return self

# --- internals ---

func _connect() -> bool:
    if _engine == null:
        return false
    if _engine.has_signal("hit_applied"):
        _engine.connect("hit_applied", Callable(self, "_on_hit_applied"))
    if _engine.has_signal("hit_components"):
        _engine.connect("hit_components", Callable(self, "_on_hit_components"))
    return true

func _source_side(team_str: String) -> String:
    var t := String(team_str)
    if _player_is_team_a:
        return (SIDE_A if t == TEAM_PLAYER else SIDE_B)
    return (SIDE_A if t == TEAM_ENEMY else SIDE_B)

func _on_hit_applied(team: String, _sidx: int, _tidx: int, _rolled: int, dealt: int, _crit: bool, _bhp: int, _ahp: int, _pcd: float, _ecd: float) -> void:
    var side := _source_side(team)
    var arr: Array = _hits.get(side, [])
    arr.append({"t": _time_s, "d": max(0, int(dealt))})
    _hits[side] = arr

func _on_hit_components(team: String, _sidx: int, _tt: String, _tidx: int, _phys: int, mag: int, _tru: int) -> void:
    var side := _source_side(team)
    var m: int = max(0, int(mag))
    if m <= 0:
        return
    var arr: Array = _hits_magic.get(side, [])
    arr.append({"t": _time_s, "d": m})
    _hits_magic[side] = arr

func _compute_side(arr: Array) -> Dictionary:
    if arr.is_empty():
        return { "top_2s_damage_share": 0.0, "peak_over_mean": 0.0, "supported": false }
    # Sliding window 2.0s
    var total := 0.0
    for e in arr:
        total += float(e.get("d", 0))
    var window := 2.0
    var max_sum := 0.0
    var i := 0
    var j := 0
    var cur := 0.0
    var times: Array = []
    for e2 in arr:
        times.append(float(e2.get("t", 0.0)))
    while i < arr.size():
        var t_i := float(arr[i].get("t", 0.0))
        while j < arr.size() and float(arr[j].get("t", 0.0)) - t_i <= window:
            cur += float(arr[j].get("d", 0))
            j += 1
        if cur > max_sum:
            max_sum = cur
        cur -= float(arr[i].get("d", 0))
        i += 1
    var share: float = (max_sum / max(1.0, total))
    var mean_dps: float = (total / max(0.001, _total_time_s))
    var peak_dps: float = (max_sum / window)
    var peak_over_mean: float = (peak_dps / max(0.001, mean_dps))
    return { "top_2s_damage_share": share, "peak_over_mean": peak_over_mean, "supported": true }
