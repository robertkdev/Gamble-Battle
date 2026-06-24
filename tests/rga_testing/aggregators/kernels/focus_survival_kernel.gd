extends RefCounted

# Focus Survival Kernel
# Emits per-side averages for time under focus until death and hits survived while focused.
# Keys: {
#   focus_survival: { a: { avg_s, samples }, b: { avg_s, samples } },
#   hits_survived:  { a: { avg, samples },   b: { avg, samples } }
# }

const SIDE_A := "a"
const SIDE_B := "b"
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var _engine = null
var _connected := false
var _time_s: float = 0.0
var _player_is_team_a: bool = true
var _priority: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _focus_map: Dictionary = { SIDE_A: {}, SIDE_B: {} } # defender side -> target_index -> {start, hits}
var _survival_samples: Dictionary = {
    SIDE_A: [],
    SIDE_B: []
}
var _hits_samples: Dictionary = {
    SIDE_A: [],
    SIDE_B: []
}
var _id_map: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> idx -> unit_id
var _per_unit_survival: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> uid -> {sum_s: float, n: int}
var _supported: bool = false

func attach(engine, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
    detach()
    _engine = engine
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _priority = _extract_priority_targets(context_tags)
    _id_map = _extract_id_map(context_tags)
    _focus_map = { SIDE_A: {}, SIDE_B: {} }
    _survival_samples = { SIDE_A: [], SIDE_B: [] }
    _hits_samples = { SIDE_A: [], SIDE_B: [] }
    _per_unit_survival = { SIDE_A: {}, SIDE_B: {} }
    _connected = _connect()
    # Supported if targeting signals are present and any priority targets exist
    var has_priorities := false
    for s in [SIDE_A, SIDE_B]:
        var d: Dictionary = _priority.get(s, {})
        if d != null and d.size() > 0:
            has_priorities = true
            break
    _supported = _connected and has_priorities

func detach() -> void:
    if _engine != null:
        if _engine.has_signal("target_start") and _engine.is_connected("target_start", Callable(self, "_on_target_start")):
            _engine.target_start.disconnect(_on_target_start)
        if _engine.has_signal("target_end") and _engine.is_connected("target_end", Callable(self, "_on_target_end")):
            _engine.target_end.disconnect(_on_target_end)
        if _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
            _engine.hit_applied.disconnect(_on_hit_applied)
    _engine = null
    _connected = false

func tick(delta_s: float) -> void:
    _time_s += max(0.0, float(delta_s))

func finalize(_total_time_s: float) -> void:
    pass

func result() -> Dictionary:
    var per_unit_block := {
        SIDE_A: _summarize_per_unit(SIDE_A),
        SIDE_B: _summarize_per_unit(SIDE_B)
    }
    return {
        "focus_survival": {
            "supported": _supported,
            SIDE_A: _avg_s(_survival_samples[SIDE_A]),
            SIDE_B: _avg_s(_survival_samples[SIDE_B]),
            "focus_survival_per_unit": per_unit_block
        },
        "hits_survived": {
            "supported": _supported,
            SIDE_A: _avg_i(_hits_samples[SIDE_A]),
            SIDE_B: _avg_i(_hits_samples[SIDE_B])
        }
    }

func register(_aggregator) -> RefCounted:
    # DIP: return an instance; aggregator may choose to attach() it.
    return self

# --- internals ---

func _connect() -> bool:
    if _engine == null:
        return false
    if _engine.has_signal("target_start"):
        _engine.connect("target_start", Callable(self, "_on_target_start"))
    if _engine.has_signal("target_end"):
        _engine.connect("target_end", Callable(self, "_on_target_end"))
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

func _extract_priority_targets(context_tags: Dictionary) -> Dictionary:
    var out := { SIDE_A: {}, SIDE_B: {} }
    var unit_tl: Dictionary = context_tags.get("unit_timelines", {})
    if not (unit_tl is Dictionary):
        return out
    for side in [SIDE_A, SIDE_B]:
        var arr = unit_tl.get(side, [])
        var timelines: Array = arr if arr is Array else []
        for entry in timelines:
            if not (entry is Dictionary):
                continue
            var idx := int(entry.get("unit_index", -1))
            var entries: Array = entry.get("entries", [])
            for e in entries:
                if e is Dictionary and String(e.get("tag", "")).to_lower() == "priority_target":
                    out[side][idx] = true
                    break
    return out

func _extract_id_map(context_tags: Dictionary) -> Dictionary:
    var out := { SIDE_A: {}, SIDE_B: {} }
    var unit_tl: Dictionary = context_tags.get("unit_timelines", {})
    if not (unit_tl is Dictionary):
        return out
    for side in [SIDE_A, SIDE_B]:
        var arr = unit_tl.get(side, [])
        var timelines: Array = arr if arr is Array else []
        for entry in timelines:
            if not (entry is Dictionary):
                continue
            var idx := int(entry.get("unit_index", -1))
            if idx < 0:
                continue
            var uid := String(entry.get("unit_id", ""))
            if uid == "":
                uid = "%s_%d" % [side, idx]
            out[side][idx] = uid
    return out

func _on_target_start(_source_team: String, _source_index: int, target_team: String, target_index: int) -> void:
    var defender_side := _source_side(target_team)
    if defender_side == "":
        return
    if not bool(_priority.get(defender_side, {}).get(target_index, false)):
        return
    var m: Dictionary = _focus_map.get(defender_side, {})
    m[target_index] = {"start": _time_s, "hits": 0}
    _focus_map[defender_side] = m

func _on_target_end(_source_team: String, _source_index: int, target_team: String, target_index: int) -> void:
    var defender_side := _source_side(target_team)
    if defender_side == "":
        return
    # If focus ended without death, drop the sample (we track only until death)
    var m: Dictionary = _focus_map.get(defender_side, {})
    if m.has(target_index):
        m.erase(target_index)
        _focus_map[defender_side] = m

func _on_hit_applied(team: String, _sidx: int, tidx: int, _rolled: int, _dealt: int, _crit: bool, _bhp: int, ahp: int, _pcd: float, _ecd: float) -> void:
    var attacker_side := _source_side(team)
    var defender_side := _opponent_side(attacker_side)
    var m: Dictionary = _focus_map.get(defender_side, {})
    if m.has(tidx):
        var entry: Dictionary = m[tidx]
        entry["hits"] = int(entry.get("hits", 0)) + 1
        m[tidx] = entry
        _focus_map[defender_side] = m
    if ahp <= 0 and m.has(tidx):
        var e2: Dictionary = m[tidx]
        var start: float = float(e2.get("start", _time_s))
        var surv: float = max(0.0, _time_s - start)
        (_survival_samples[defender_side] as Array).append(surv)
        (_hits_samples[defender_side] as Array).append(int(e2.get("hits", 0)))
        # Aggregate per-unit (by unit_id) on defender side
        var side_map: Dictionary = _id_map.get(defender_side, {})
        var uid := String(side_map.get(tidx, ""))
        if uid != "":
            var agg: Dictionary = _per_unit_survival.get(defender_side, {})
            var cur: Dictionary = agg.get(uid, {"sum_s": 0.0, "n": 0})
            cur["sum_s"] = float(cur.get("sum_s", 0.0)) + surv
            cur["n"] = int(cur.get("n", 0)) + 1
            agg[uid] = cur
            _per_unit_survival[defender_side] = agg
        m.erase(tidx)
        _focus_map[defender_side] = m

func _avg_s(arr: Array) -> Dictionary:
    var n: int = max(0, arr.size())
    if n <= 0:
        return {"avg_s": null, "samples": 0}
    var sum: float = 0.0
    for v in arr:
        sum += float(v)
    return {"avg_s": (sum / float(n)), "samples": n}

func _avg_i(arr: Array) -> Dictionary:
    var n: int = max(0, arr.size())
    if n <= 0:
        return {"avg": null, "samples": 0}
    var sum: float = 0.0
    for v in arr:
        sum += float(v)
    return {"avg": (sum / float(n)), "samples": n}

func _summarize_per_unit(side: String) -> Dictionary:
    var src: Dictionary = _per_unit_survival.get(side, {})
    var out: Dictionary = {}
    if not (src is Dictionary):
        return out
    for uid in src.keys():
        var e: Dictionary = src.get(uid, {})
        var n: int = int(e.get("n", 0))
        if n <= 0:
            continue
        var s: float = float(e.get("sum_s", 0.0))
        out[String(uid)] = {"avg_s": (s / float(n)), "samples": n}
    return out
