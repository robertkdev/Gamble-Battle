extends RefCounted

# Frontline Window Kernel
# Computes, for the first N seconds (default 4s), the share of damage dealt
# to frontline vs backline targets per side.
# Emits under key:
#   frontline_window: {
#     supported: bool,
#     a: { frontline_share_0_4s, backline_share_0_4s, window_s, observed_s },
#     b: { ... }
#   }

const SIDE_A := "a"
const SIDE_B := "b"
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var _engine = null
var _connected: bool = false
var _player_is_team_a: bool = true
var _time_s: float = 0.0

var _window_s: float = 4.0

# side -> idx(frontline=true)
var _frontline_targets: Dictionary = { SIDE_A: {}, SIDE_B: {} }

# side -> { f: float, b: float, total: float, observed: float }
var _acc: Dictionary = {
    SIDE_A: {"f": 0.0, "b": 0.0, "total": 0.0, "observed": 0.0},
    SIDE_B: {"f": 0.0, "b": 0.0, "total": 0.0, "observed": 0.0}
}

func attach(engine, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
    detach()
    _engine = engine
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _frontline_targets = _extract_frontline_map(context_tags)
    _acc = {
        SIDE_A: {"f": 0.0, "b": 0.0, "total": 0.0, "observed": 0.0},
        SIDE_B: {"f": 0.0, "b": 0.0, "total": 0.0, "observed": 0.0}
    }
    _connected = _connect()

func detach() -> void:
    if _engine != null and _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
        _engine.hit_applied.disconnect(_on_hit_applied)
    _engine = null
    _connected = false

func tick(delta_s: float) -> void:
    var dt: float = max(0.0, float(delta_s))
    if _time_s < _window_s:
        # count observed window time per side
        for side in [SIDE_A, SIDE_B]:
            _acc[side]["observed"] = float(_acc[side].get("observed", 0.0)) + dt
    _time_s += dt

func finalize(_total_time_s: float) -> void:
    pass

func result() -> Dictionary:
    var a_total: float = float(_acc[SIDE_A].get("total", 0.0))
    var a_f: float = float(_acc[SIDE_A].get("f", 0.0))
    var a_b: float = float(_acc[SIDE_A].get("b", 0.0))
    var b_total: float = float(_acc[SIDE_B].get("total", 0.0))
    var b_f: float = float(_acc[SIDE_B].get("f", 0.0))
    var b_b: float = float(_acc[SIDE_B].get("b", 0.0))
    var a_front_share: float = (a_f / max(1.0, a_total)) if a_total > 0.0 else 0.0
    var b_front_share: float = (b_f / max(1.0, b_total)) if b_total > 0.0 else 0.0
    var a_back_share: float = (a_b / max(1.0, a_total)) if a_total > 0.0 else 0.0
    var b_back_share: float = (b_b / max(1.0, b_total)) if b_total > 0.0 else 0.0
    var supported := _connected
    return {
        "frontline_window": {
            "supported": supported,
            SIDE_A: {
                "frontline_share_0_4s": a_front_share,
                "backline_share_0_4s": a_back_share,
                "window_s": _window_s,
                "observed_s": float(_acc[SIDE_A].get("observed", 0.0))
            },
            SIDE_B: {
                "frontline_share_0_4s": b_front_share,
                "backline_share_0_4s": b_back_share,
                "window_s": _window_s,
                "observed_s": float(_acc[SIDE_B].get("observed", 0.0))
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

func _opponent_side(side: String) -> String:
    return (SIDE_B if side == SIDE_A else SIDE_A)

func _extract_frontline_map(context_tags: Dictionary) -> Dictionary:
    var out := { SIDE_A: {}, SIDE_B: {} }
    var timelines = context_tags.get("unit_timelines", {})
    if not (timelines is Dictionary):
        return out
    for side in [SIDE_A, SIDE_B]:
        var arr = timelines.get(side, [])
        if not (arr is Array):
            continue
        for entry in arr:
            if not (entry is Dictionary):
                continue
            var idx := int(entry.get("unit_index", -1))
            if idx < 0:
                continue
            var entries: Array = entry.get("entries", [])
            var is_front := false
            for e in entries:
                if e is Dictionary and String(e.get("tag", "")).to_lower() == "frontline":
                    is_front = true
                    break
            if is_front:
                out[side][idx] = true
    return out

func _on_hit_applied(team: String, _sidx: int, tidx: int, _rolled: int, dealt: int, _crit: bool, _bhp: int, _ahp: int, _pcd: float, _ecd: float) -> void:
    if _time_s > _window_s:
        return
    var attacker_side := _source_side(team)
    var defender_side := _opponent_side(attacker_side)
    var dmg: float = float(max(0, int(dealt)))
    if dmg <= 0.0:
        return
    _acc[attacker_side]["total"] = float(_acc[attacker_side].get("total", 0.0)) + dmg
    var is_front := bool(_frontline_targets.get(defender_side, {}).get(int(tidx), false))
    if is_front:
        _acc[attacker_side]["f"] = float(_acc[attacker_side].get("f", 0.0)) + dmg
    else:
        _acc[attacker_side]["b"] = float(_acc[attacker_side].get("b", 0.0)) + dmg
