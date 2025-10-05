extends RefCounted
class_name DerivedStatsAggregator

const BattleState := preload("res://scripts/game/combat/battle_state.gd")
const ContextTagger := preload("res://tests/rga_testing/core/context_tagger.gd")

# Phase 2 derived telemetry aggregator.
# Consumes live engine signals to compute second-pass metrics that depend on
# spatial occupancy, control coverage, and threat-response timings.
# Metrics exposed per-team ("a" == player, "b" == enemy unless overridden):
#   - ttk_on_carry_s: Average time to eliminate opposing carries once focused.
#   - lockdown_seconds_on_priority: Aggregate CC duration applied to priority targets.
#   - lockdown_coverage_pct: Portion of priority uptime spent locked down.
#   - frontline_zone_time_s / frontline_zone_uptime_pct: Occupancy inside owned frontline zone.
#   - peel_saves: Count of timely CC responses against threats on our priority units.
#
# The aggregator expects the engine to emit: hit_applied, cc_applied,
# position_updated, target_start, target_end. Absent signals degrade gracefully.

const SIDE_A := "a"
const SIDE_B := "b"
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"
const PEEL_WINDOW_S := 2.0
const POSITION_EPS := 0.0001

var _engine = null
var _state: BattleState = null
var _context_tags: ContextTagger.ContextTags = null
var _player_is_team_a: bool = true

var _time_s: float = 0.0
var _total_time_s: float = 0.0

var _team_metrics: Dictionary = {}
var _zone_observation: Dictionary = {}
var _priority_observation: Dictionary = {}
var _carry_track: Dictionary = {}
var _unit_alive: Dictionary = {}
var _unit_positions: Dictionary = {}
var _priority_units: Dictionary = {}
var _carry_units: Dictionary = {}
var _frontline_zones: Dictionary = {}
var _threat_track: Dictionary = {}

var _connected := false

func attach(engine, state: BattleState, context_tags: ContextTagger.ContextTags = null, player_is_team_a: bool = true) -> void:
    detach()
    _engine = engine
    _state = state
    _context_tags = context_tags
    _player_is_team_a = player_is_team_a
    _reset_state()
    _connected = _connect_signals()

func detach() -> void:
    if _engine != null:
        if _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
            _engine.hit_applied.disconnect(_on_hit_applied)
        if _engine.has_signal("cc_applied") and _engine.is_connected("cc_applied", Callable(self, "_on_cc_applied")):
            _engine.cc_applied.disconnect(_on_cc_applied)
        if _engine.has_signal("position_updated") and _engine.is_connected("position_updated", Callable(self, "_on_position_updated")):
            _engine.position_updated.disconnect(_on_position_updated)
        if _engine.has_signal("target_start") and _engine.is_connected("target_start", Callable(self, "_on_target_start")):
            _engine.target_start.disconnect(_on_target_start)
        if _engine.has_signal("target_end") and _engine.is_connected("target_end", Callable(self, "_on_target_end")):
            _engine.target_end.disconnect(_on_target_end)
    _engine = null
    _state = null
    _context_tags = null
    _connected = false

func tick(delta_s: float) -> void:
    if not _connected:
        return
    var dt := max(0.0, float(delta_s))
    _time_s += dt
    _update_priority_observation(dt)
    _update_frontline_occupancy(dt)
    _expire_threats()

func finalize(total_time_s: float) -> void:
    _total_time_s = max(_time_s, float(total_time_s))

func result() -> Dictionary:
    return {
        "derived": {
            SIDE_A: _build_side_result(SIDE_A),
            SIDE_B: _build_side_result(SIDE_B)
        },
        "kernels": {
            "frontline_zone": {
                SIDE_A: _zone_observation.get(SIDE_A, {}),
                SIDE_B: _zone_observation.get(SIDE_B, {})
            },
            "lockdown": {
                SIDE_A: {
                    "seconds_on_priority": _team_metrics[SIDE_A]["lockdown_seconds"],
                    "observed_s": _priority_observation[SIDE_A],
                    "coverage_pct": _coverage_pct(SIDE_A)
                },
                SIDE_B: {
                    "seconds_on_priority": _team_metrics[SIDE_B]["lockdown_seconds"],
                    "observed_s": _priority_observation[SIDE_B],
                    "coverage_pct": _coverage_pct(SIDE_B)
                }
            },
            "peel_kernel": {
                "window_s": PEEL_WINDOW_S
            }
        }
    }

# --- internal helpers ----------------------------------------------------

func _reset_state() -> void:
    _time_s = 0.0
    _total_time_s = 0.0
    _team_metrics = {
        SIDE_A: {
            "ttk_samples": [],
            "lockdown_seconds": 0.0,
            "peel_saves": 0
        },
        SIDE_B: {
            "ttk_samples": [],
            "lockdown_seconds": 0.0,
            "peel_saves": 0
        }
    }
    _zone_observation = {
        SIDE_A: {"time_inside_s": 0.0, "observed_s": 0.0},
        SIDE_B: {"time_inside_s": 0.0, "observed_s": 0.0}
    }
    _priority_observation = {
        SIDE_A: 0.0,
        SIDE_B: 0.0
    }
    _carry_track = {
        SIDE_A: {},
        SIDE_B: {}
    }
    _unit_alive = {
        SIDE_A: _init_alive_array(_state.player_team if _state != null else []),
        SIDE_B: _init_alive_array(_state.enemy_team if _state != null else [])
    }
    _unit_positions = {
        SIDE_A: _init_position_array(_state.player_team if _state != null else []),
        SIDE_B: _init_position_array(_state.enemy_team if _state != null else [])
    }
    _priority_units = _extract_unit_tags("priority_target")
    _carry_units = _extract_unit_tags("carry")
    _frontline_zones = _extract_frontline_zones()
    _threat_track = {
        SIDE_A: {},
        SIDE_B: {}
    }

func _connect_signals() -> bool:
    if _engine == null:
        return false
    if _engine.has_signal("hit_applied"):
        if not _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
            _engine.hit_applied.connect(_on_hit_applied)
    if _engine.has_signal("cc_applied"):
        if not _engine.is_connected("cc_applied", Callable(self, "_on_cc_applied")):
            _engine.cc_applied.connect(_on_cc_applied)
    if _engine.has_signal("position_updated"):
        if not _engine.is_connected("position_updated", Callable(self, "_on_position_updated")):
            _engine.position_updated.connect(_on_position_updated)
    if _engine.has_signal("target_start"):
        if not _engine.is_connected("target_start", Callable(self, "_on_target_start")):
            _engine.target_start.connect(_on_target_start)
    if _engine.has_signal("target_end"):
        if not _engine.is_connected("target_end", Callable(self, "_on_target_end")):
            _engine.target_end.connect(_on_target_end)
    return true

func _init_alive_array(team_array: Array) -> Array:
    var out: Array = []
    if team_array is Array:
        for _u in team_array:
            out.append(true)
    return out

func _init_position_array(team_array: Array) -> Array:
    var out: Array = []
    if team_array is Array:
        for _u in team_array:
            out.append(null)
    return out

func _extract_unit_tags(tag_id: String) -> Dictionary:
    var out := {
        SIDE_A: {},
        SIDE_B: {}
    }
    if _context_tags == null:
        return out
    var tagger := _context_tags
    var timelines_root := tagger.unit_timelines if tagger.unit_timelines is Dictionary else {}
    var raw_a = timelines_root.get(SIDE_A, [])
    var raw_b = timelines_root.get(SIDE_B, [])
    var timelines_a: Array = raw_a if raw_a is Array else []
    var timelines_b: Array = raw_b if raw_b is Array else []
    _extract_tags_for_side(out[SIDE_A], timelines_a, tag_id)
    _extract_tags_for_side(out[SIDE_B], timelines_b, tag_id)
    return out

func _extract_tags_for_side(store: Dictionary, timelines: Array, tag_id: String) -> void:
    for entry in timelines:
        if not (entry is Dictionary):
            continue
        var idx: int = int(entry.get("unit_index", -1))
        if idx < 0:
            continue
        var entries: Array = entry.get("entries", [])
        for e in entries:
            if e is Dictionary and String(e.get("tag", "")).to_lower() == tag_id:
                store[idx] = true
                break

func _extract_frontline_zones() -> Dictionary:
    var out := {
        SIDE_A: {},
        SIDE_B: {}
    }
    if _context_tags == null:
        return out
    var zones_dict := _context_tags.zones if _context_tags.zones is Dictionary else {}
    out[SIDE_A] = zones_dict.get(SIDE_A, {})
    out[SIDE_B] = zones_dict.get(SIDE_B, {})
    return out

func _build_side_result(side: String) -> Dictionary:
    var metrics: Dictionary = _team_metrics.get(side, {})
    var ttk_samples: Array = metrics.get("ttk_samples", [])
    var sum_ttk: float = 0.0
    for v in ttk_samples:
        sum_ttk += float(v)
    var avg_ttk := -1.0
    if ttk_samples.size() > 0:
        avg_ttk = sum_ttk / float(ttk_samples.size())
    var zone_stats: Dictionary = _zone_observation.get(side, {})
    var frontline_time: float = float(zone_stats.get("time_inside_s", 0.0))
    var zone_observed: float = float(zone_stats.get("observed_s", 0.0))
    var zone_pct: float = (frontline_time / zone_observed) if zone_observed > 0.0 else 0.0
    return {
        "ttk_on_carry_s": avg_ttk,
        "ttk_samples": ttk_samples.duplicate(),
        "lockdown_seconds_on_priority": float(metrics.get("lockdown_seconds", 0.0)),
        "lockdown_coverage_pct": _coverage_pct(side),
        "time_in_frontline_zone_s": frontline_time,
        "frontline_zone_uptime_pct": zone_pct,
        "peel_saves": int(metrics.get("peel_saves", 0))
    }

func _coverage_pct(side: String) -> float:
    var observed: float = _priority_observation.get(side, 0.0)
    if observed <= 0.0:
        return 0.0
    return float(_team_metrics.get(side, {}).get("lockdown_seconds", 0.0)) / observed

func _update_priority_observation(delta: float) -> void:
    for side in [SIDE_A, SIDE_B]:
        var alive_arr: Array = _unit_alive.get(side, [])
        if alive_arr == null:
            continue
        var priorities_obj = _priority_units.get(side, {})
        var priorities: Dictionary = priorities_obj if priorities_obj is Dictionary else {}
        for idx in priorities.keys():
            var id_int := int(idx)
            if id_int >= 0 and id_int < alive_arr.size() and bool(alive_arr[id_int]):
                _priority_observation[side] = float(_priority_observation.get(side, 0.0)) + delta

func _update_frontline_occupancy(delta: float) -> void:
    for side in [SIDE_A, SIDE_B]:
        var alive_arr: Array = _unit_alive.get(side, [])
        var pos_arr: Array = _unit_positions.get(side, [])
        var zone_parent := _frontline_zones.get(side, {})
        if alive_arr == null or pos_arr == null or zone_parent.is_empty():
            continue
        for i in range(pos_arr.size()):
            if i >= alive_arr.size() or not bool(alive_arr[i]):
                continue
            var pos = pos_arr[i]
            if not (pos is Vector2):
                continue
            _zone_observation[side]["observed_s"] = float(_zone_observation[side].get("observed_s", 0.0)) + delta
            if _is_inside_zone(pos, zone_parent):
                _zone_observation[side]["time_inside_s"] = float(_zone_observation[side].get("time_inside_s", 0.0)) + delta

func _expire_threats() -> void:
    for side in [SIDE_A, SIDE_B]:
        var threats: Dictionary = _threat_track.get(side, {})
        var to_remove: Array = []
        for key in threats.keys():
            var started: float = float(threats.get(key, -999.0))
            if _time_s - started > PEEL_WINDOW_S:
                to_remove.append(key)
        for k in to_remove:
            threats.erase(k)

func _is_inside_zone(pos: Vector2, zone_parent: Dictionary) -> bool:
    if not (pos is Vector2) or zone_parent.is_empty():
        return false
    var front: Dictionary = zone_parent.get("frontline", {})
    if front.is_empty():
        return false
    var center_dict: Dictionary = front.get("center", {})
    if center_dict.is_empty():
        return false
    var center := Vector2(float(center_dict.get("x", 0.0)), float(center_dict.get("y", 0.0)))
    var half_length: float = float(front.get("half_length", 0.0))
    var half_width: float = float(front.get("half_width", 0.0))
    var forward_dict: Dictionary = zone_parent.get("forward", {})
    var forward := Vector2.RIGHT
    if not forward_dict.is_empty():
        forward = Vector2(float(forward_dict.get("x", 1.0)), float(forward_dict.get("y", 0.0)))
    if forward.length_squared() <= POSITION_EPS:
        forward = Vector2.RIGHT
    forward = forward.normalized()
    var offset := pos - center
    var forward_proj := offset.dot(forward)
    var lateral_proj := abs(offset.dot(Vector2(-forward.y, forward.x)))
    return abs(forward_proj) <= half_length + POSITION_EPS and lateral_proj <= half_width + POSITION_EPS

# --- signal handlers -----------------------------------------------------

func _on_hit_applied(team: String, source_index: int, target_index: int, _rolled: int, _dealt: int, _crit: bool, _before_hp: int, after_hp: int, _pcd: float, _ecd: float) -> void:
    var src_side := _source_side(team)
    var dst_side := _opponent_side(src_side)
    if dst_side == "":
        return
    _track_ttk_sample(src_side, dst_side, target_index, after_hp)
    if after_hp <= 0:
        _mark_dead(dst_side, target_index)
        _clear_threats_on_death(dst_side, target_index)

func _track_ttk_sample(attacker_side: String, defender_side: String, defender_index: int, after_hp: int) -> void:
    if defender_index < 0:
        return
    var carries_obj = _carry_units.get(defender_side, {})
    var carries: Dictionary = carries_obj if carries_obj is Dictionary else {}
    if not carries.has(defender_index):
        return
    var tracker: Dictionary = _carry_track.get(attacker_side, {})
    if tracker == null:
        tracker = {}
        _carry_track[attacker_side] = tracker
    if not tracker.has(defender_index):
        tracker[defender_index] = _time_s
    if after_hp <= 0:
        var start_time: float = float(tracker.get(defender_index, _time_s))
        var elapsed := max(0.0, _time_s - start_time)
        var samples: Array = _team_metrics[attacker_side]["ttk_samples"]
        samples.append(elapsed)
        tracker.erase(defender_index)

func _on_cc_applied(source_team: String, _source_index: int, target_team: String, target_index: int, _kind: String, duration: float) -> void:
    var source_side := _source_side(source_team)
    var target_side := _source_side(target_team)
    if target_side == "":
        return
    if int(duration) < 0:
        duration = 0.0
    var priorities_obj = _priority_units.get(target_side, {})
    var priorities: Dictionary = priorities_obj if priorities_obj is Dictionary else {}
    if priorities.has(target_index):
        _team_metrics[source_side]["lockdown_seconds"] = float(_team_metrics[source_side].get("lockdown_seconds", 0.0)) + max(0.0, duration)
    # Peel detection: defenders (opponent of target) responding to threats
    var defender_side := _opponent_side(target_side)
    if defender_side == "":
        defender_side = source_side
    var attacker_side := _opponent_side(defender_side)
    if attacker_side == "":
        attacker_side = target_side
    if source_side == defender_side:
        var threats: Dictionary = _threat_track.get(defender_side, {})
        if threats != null and threats.has(target_index):
            var started: float = float(threats[target_index])
            if _time_s - started <= PEEL_WINDOW_S:
                _team_metrics[defender_side]["peel_saves"] = int(_team_metrics[defender_side].get("peel_saves", 0)) + 1
                threats.erase(target_index)

func _on_position_updated(team: String, index: int, x: float, y: float) -> void:(team: String, index: int, x: float, y: float) -> void:
    var side := _source_side(team)
    if side == "":
        return
    var positions: Array = _unit_positions.get(side, [])
    if index < 0 or index >= positions.size():
        return
    positions[index] = Vector2(x, y)

func _on_target_start(source_team: String, source_index: int, target_team: String, target_index: int) -> void:
    var defender_side := _source_side(target_team)
    var attacker_side := _source_side(source_team)
    if defender_side == "" or attacker_side == "":
        return
    var priorities: Dictionary = _priority_units.get(defender_side, {})
    if priorities == null or not priorities.has(target_index):
        return
    var threats: Dictionary = _threat_track.get(defender_side, {})
    threats[source_index] = _time_s

func _on_target_end(source_team: String, source_index: int, _target_team: String, _target_index: int) -> void:
    var defender_side := _opponent_side(_source_side(source_team))
    if defender_side == "":
        return
    var threats: Dictionary = _threat_track.get(defender_side, {})
    if threats != null:
        threats.erase(source_index)

func _mark_dead(side: String, index: int) -> void:
    var arr: Array = _unit_alive.get(side, [])
    if index >= 0 and index < arr.size():
        arr[index] = false

func _clear_threats_on_death(side: String, index: int) -> void:
    var threats: Dictionary = _threat_track.get(side, {})
    var priorities_obj = _priority_units.get(side, {})
    var priorities: Dictionary = priorities_obj if priorities_obj is Dictionary else {}
    if priorities.has(index):
        threats.clear()
    var carry_tracker: Dictionary = _carry_track.get(_opponent_side(side), {})
    if carry_tracker != null and carry_tracker.has(index):
        carry_tracker.erase(index)

func _source_side(team_str: String) -> String:
    var team := String(team_str)
    if _player_is_team_a:
        if team == TEAM_PLAYER:
            return SIDE_A
        if team == TEAM_ENEMY:
            return SIDE_B
    else:
        if team == TEAM_PLAYER:
            return SIDE_B
        if team == TEAM_ENEMY:
            return SIDE_A
    return ""

func _opponent_side(side: String) -> String:
    if side == SIDE_A:
        return SIDE_B
    if side == SIDE_B:
        return SIDE_A
    return ""
















