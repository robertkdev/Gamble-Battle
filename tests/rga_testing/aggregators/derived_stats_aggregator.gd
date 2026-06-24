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
const DEFAULT_TILE_SIZE: float = 64.0
const CONTROL_EFFECT_WINDOW_S: float = 2.5
const TARGET_SWAP_WINDOW_S: float = 2.5
const FOLLOW_UP_KILL_WINDOW_S: float = 3.0
const FORCED_REPOSITION_TILES: float = 0.75
const FORMATION_BREAK_DELTA_TILES: float = 0.75

var _engine: Object = null
var _state: BattleState = null
var _context_tags: ContextTagger.ContextTags = null
var _player_is_team_a: bool = true
var _tile_size: float = DEFAULT_TILE_SIZE

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
var _id_map: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> idx -> unit_id
var _healing_per_unit: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> uid -> {healed: int, overheal: int, samples: int}
var _shield_per_unit: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> uid -> {absorbed: int, samples: int}
var _lockdown_per_unit: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> uid -> {seconds_on_priority: float, events: int, samples: int}
var _disruption_per_unit: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> uid -> direct enemy-response effects after control
var _current_targets: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> uid -> target_index
var _control_windows: Array[Dictionary] = []

var _connected: bool = false

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
		if _engine.has_signal("heal_applied") and _engine.is_connected("heal_applied", Callable(self, "_on_heal_applied")):
			_engine.heal_applied.disconnect(_on_heal_applied)
		if _engine.has_signal("shield_absorbed") and _engine.is_connected("shield_absorbed", Callable(self, "_on_shield_absorbed")):
			_engine.shield_absorbed.disconnect(_on_shield_absorbed)
	_engine = null
	_state = null
	_context_tags = null
	_connected = false

func tick(delta_s: float) -> void:
	if not _connected:
		return
	var dt: float = max(0.0, float(delta_s))
	_time_s += dt
	_update_priority_observation(dt)
	_update_frontline_occupancy(dt)
	_expire_threats()
	_expire_control_windows(false)

func finalize(total_time_s: float) -> void:
	_total_time_s = max(_time_s, float(total_time_s))
	_expire_control_windows(true)

func result() -> Dictionary:
	var fl_a: Dictionary = _zone_observation.get(SIDE_A, {}).duplicate()
	var fl_b: Dictionary = _zone_observation.get(SIDE_B, {}).duplicate()
	if fl_a is Dictionary:
		fl_a["observed_unit_seconds"] = float(fl_a.get("observed_s", fl_a.get("observed", 0.0)))
		fl_a["fight_time_seconds"] = _total_time_s
	if fl_b is Dictionary:
		fl_b["observed_unit_seconds"] = float(fl_b.get("observed_s", fl_b.get("observed", 0.0)))
		fl_b["fight_time_seconds"] = _total_time_s
	return {
		"derived": {
			SIDE_A: _build_side_result(SIDE_A),
			SIDE_B: _build_side_result(SIDE_B)
		},
		"kernels": {
			"frontline_zone": {
				SIDE_A: fl_a,
				SIDE_B: fl_b
			},
			"lockdown": {
				SIDE_A: {
					"seconds_on_priority": _team_metrics[SIDE_A]["lockdown_seconds"],
					"observed_s": _priority_observation[SIDE_A],
					"observed_unit_seconds": _priority_observation[SIDE_A],
					"fight_time_seconds": _total_time_s,
					"coverage_pct": _coverage_pct(SIDE_A),
					"per_unit": _lockdown_per_unit.get(SIDE_A, {})
				},
				SIDE_B: {
					"seconds_on_priority": _team_metrics[SIDE_B]["lockdown_seconds"],
					"observed_s": _priority_observation[SIDE_B],
					"observed_unit_seconds": _priority_observation[SIDE_B],
					"fight_time_seconds": _total_time_s,
					"coverage_pct": _coverage_pct(SIDE_B),
					"per_unit": _lockdown_per_unit.get(SIDE_B, {})
				},
				"per_unit": {
					SIDE_A: _lockdown_per_unit.get(SIDE_A, {}),
					SIDE_B: _lockdown_per_unit.get(SIDE_B, {})
				}
			},
			"peel_kernel": {
				"window_s": PEEL_WINDOW_S
			},
			"support": {
				"healing_per_unit": {
					SIDE_A: _healing_per_unit.get(SIDE_A, {}),
					SIDE_B: _healing_per_unit.get(SIDE_B, {})
				},
				"shield_absorbed_per_unit": {
					SIDE_A: _shield_per_unit.get(SIDE_A, {}),
					SIDE_B: _shield_per_unit.get(SIDE_B, {})
				}
			},
			"disruption": {
				"supported": _connected,
				"control_effect_window_s": CONTROL_EFFECT_WINDOW_S,
				"target_swap_window_s": TARGET_SWAP_WINDOW_S,
				"follow_up_kill_window_s": FOLLOW_UP_KILL_WINDOW_S,
				"forced_reposition_threshold_tiles": FORCED_REPOSITION_TILES,
				"formation_break_threshold_tiles": FORMATION_BREAK_DELTA_TILES,
				"per_unit": {
					SIDE_A: _disruption_per_unit.get(SIDE_A, {}),
					SIDE_B: _disruption_per_unit.get(SIDE_B, {})
				}
			}
		}
	}

# --- internal helpers ----------------------------------------------------

func _reset_state() -> void:
	_time_s = 0.0
	_total_time_s = 0.0
	_tile_size = _extract_tile_size()
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
	_id_map = _extract_id_map()
	_healing_per_unit = { SIDE_A: {}, SIDE_B: {} }
	_shield_per_unit = { SIDE_A: {}, SIDE_B: {} }
	_lockdown_per_unit = { SIDE_A: {}, SIDE_B: {} }
	_disruption_per_unit = { SIDE_A: {}, SIDE_B: {} }
	_current_targets = { SIDE_A: {}, SIDE_B: {} }
	_control_windows = []

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
	if _engine.has_signal("heal_applied"):
		if not _engine.is_connected("heal_applied", Callable(self, "_on_heal_applied")):
			_engine.heal_applied.connect(_on_heal_applied)
	if _engine.has_signal("shield_absorbed"):
		if not _engine.is_connected("shield_absorbed", Callable(self, "_on_shield_absorbed")):
			_engine.shield_absorbed.connect(_on_shield_absorbed)
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
	var out: Dictionary = {
		SIDE_A: {},
		SIDE_B: {}
	}
	if _context_tags == null:
		return out
	var tagger: ContextTagger.ContextTags = _context_tags
	var timelines_root: Dictionary = tagger.unit_timelines if tagger.unit_timelines is Dictionary else {}
	var raw_a: Variant = timelines_root.get(SIDE_A, [])
	var raw_b: Variant = timelines_root.get(SIDE_B, [])
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
	var out: Dictionary = {
		SIDE_A: {},
		SIDE_B: {}
	}
	if _context_tags == null:
		return out
	var zones_dict: Dictionary = _context_tags.zones if _context_tags.zones is Dictionary else {}
	out[SIDE_A] = zones_dict.get(SIDE_A, {})
	out[SIDE_B] = zones_dict.get(SIDE_B, {})
	return out

func _extract_id_map() -> Dictionary:
	var out: Dictionary = { SIDE_A: {}, SIDE_B: {} }
	if _context_tags == null:
		return out
	var tagger: ContextTagger.ContextTags = _context_tags
	var timelines_root: Dictionary = tagger.unit_timelines if tagger.unit_timelines is Dictionary else {}
	for side in [SIDE_A, SIDE_B]:
		var arr: Variant = timelines_root.get(side, [])
		var timelines: Array = arr if arr is Array else []
		var m: Dictionary = {}
		for e in timelines:
			if not (e is Dictionary):
				continue
			var idx_val: Variant = (e as Dictionary).get("unit_index", null)
			if typeof(idx_val) != TYPE_INT:
				continue
			var uid: String = String((e as Dictionary).get("unit_id", ""))
			m[int(idx_val)] = uid
		out[side] = m
	return out

func _build_side_result(side: String) -> Dictionary:
	var metrics: Dictionary = _team_metrics.get(side, {})
	var disruption: Dictionary = _sum_disruption_side(side)
	var ttk_samples: Array = metrics.get("ttk_samples", [])
	var sum_ttk: float = 0.0
	for v in ttk_samples:
		sum_ttk += float(v)
	var avg_ttk: Variant = null
	if ttk_samples.size() > 0:
		avg_ttk = sum_ttk / float(ttk_samples.size())
	var zone_stats: Dictionary = _zone_observation.get(side, {})
	var frontline_time: float = float(zone_stats.get("time_inside_s", 0.0))
	var zone_observed: float = float(zone_stats.get("observed_s", 0.0))
	var zone_pct: float = (frontline_time / zone_observed) if zone_observed > 0.0 else 0.0
	var ttk_supported: bool = false
	var opp: String = _opponent_side(side)
	var carries_obj: Variant = _carry_units.get(opp, {})
	if carries_obj is Dictionary:
		ttk_supported = (carries_obj.size() > 0)
	return {
		"ttk_on_carry_s": avg_ttk,
		"ttk_samples": ttk_samples.duplicate(),
		"ttk_supported": ttk_supported,
		"lockdown_seconds_on_priority": float(metrics.get("lockdown_seconds", 0.0)),
		"lockdown_coverage_pct": _coverage_pct(side),
		"time_in_frontline_zone_s": frontline_time,
		"frontline_zone_uptime_pct": zone_pct,
		"peel_saves": int(metrics.get("peel_saves", 0)),
		"forced_reposition_events": int(disruption.get("forced_reposition_events", 0)),
		"forced_reposition_distance_tiles": float(disruption.get("forced_reposition_distance_tiles", 0.0)),
		"target_swap_events": int(disruption.get("target_swap_events", 0)),
		"formation_break_events": int(disruption.get("formation_break_events", 0)),
		"formation_spread_increase_tiles": float(disruption.get("formation_spread_increase_tiles", 0.0)),
		"follow_up_kills": int(disruption.get("follow_up_kills", 0))
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
		var priorities_obj: Variant = _priority_units.get(side, {})
		var priorities: Dictionary = priorities_obj if priorities_obj is Dictionary else {}
		for idx in priorities.keys():
			var id_int: int = int(idx)
			if id_int >= 0 and id_int < alive_arr.size() and bool(alive_arr[id_int]):
				_priority_observation[side] = float(_priority_observation.get(side, 0.0)) + delta

func _update_frontline_occupancy(delta: float) -> void:
	for side in [SIDE_A, SIDE_B]:
		var alive_arr: Array = _unit_alive.get(side, [])
		var pos_arr: Array = _unit_positions.get(side, [])
		var zone_parent: Dictionary = _frontline_zones.get(side, {})
		if alive_arr == null or pos_arr == null or zone_parent.is_empty():
			continue
		for i in range(pos_arr.size()):
			if i >= alive_arr.size() or not bool(alive_arr[i]):
				continue
			var pos: Variant = pos_arr[i]
			if not (pos is Vector2):
				continue
			var pos_vec: Vector2 = pos
			_zone_observation[side]["observed_s"] = float(_zone_observation[side].get("observed_s", 0.0)) + delta
			if _is_inside_zone(pos_vec, zone_parent):
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

func _expire_control_windows(force: bool) -> void:
	var keep: Array[Dictionary] = []
	var retention_s: float = max(CONTROL_EFFECT_WINDOW_S, max(TARGET_SWAP_WINDOW_S, FOLLOW_UP_KILL_WINDOW_S))
	for raw_rec in _control_windows:
		var rec: Dictionary = raw_rec
		var age_s: float = _time_s - float(rec.get("start_s", 0.0))
		if (force or age_s >= CONTROL_EFFECT_WINDOW_S) and not bool(rec.get("finalized", false)):
			_finalize_control_window(rec)
			rec["finalized"] = true
		if not force and age_s <= retention_s:
			keep.append(rec)
	_control_windows = keep

func _finalize_control_window(rec: Dictionary) -> void:
	var source_side: String = String(rec.get("source_side", ""))
	var source_uid: String = String(rec.get("source_uid", ""))
	if source_side == "" or source_uid == "":
		return
	var distance_tiles: float = float(rec.get("max_distance_tiles", 0.0))
	if distance_tiles >= FORCED_REPOSITION_TILES:
		_bump_disruption_int(source_side, source_uid, "forced_reposition_events", 1)
		_bump_disruption_float(source_side, source_uid, "forced_reposition_distance_tiles", distance_tiles)
	var spread_delta_tiles: float = float(rec.get("max_spread_delta_tiles", 0.0))
	if spread_delta_tiles >= FORMATION_BREAK_DELTA_TILES:
		_bump_disruption_int(source_side, source_uid, "formation_break_events", 1)
		_bump_disruption_float(source_side, source_uid, "formation_spread_increase_tiles", spread_delta_tiles)

func _is_inside_zone(pos: Vector2, zone_parent: Dictionary) -> bool:
	if not (pos is Vector2) or zone_parent.is_empty():
		return false
	var front: Dictionary = zone_parent.get("frontline", {})
	if front.is_empty():
		return false
	var center_dict: Dictionary = front.get("center", {})
	if center_dict.is_empty():
		return false
	var center: Vector2 = Vector2(float(center_dict.get("x", 0.0)), float(center_dict.get("y", 0.0)))
	var half_length: float = float(front.get("half_length", 0.0))
	var half_width: float = float(front.get("half_width", 0.0))
	var forward_dict: Dictionary = zone_parent.get("forward", {})
	var forward: Vector2 = Vector2.RIGHT
	if not forward_dict.is_empty():
		forward = Vector2(float(forward_dict.get("x", 1.0)), float(forward_dict.get("y", 0.0)))
	if forward.length_squared() <= POSITION_EPS:
		forward = Vector2.RIGHT
	forward = forward.normalized()
	var offset: Vector2 = pos - center
	var forward_proj: float = offset.dot(forward)
	var lateral_proj: float = abs(offset.dot(Vector2(-forward.y, forward.x)))
	return abs(forward_proj) <= half_length + POSITION_EPS and lateral_proj <= half_width + POSITION_EPS


# --- signal handlers -----------------------------------------------------

func _on_hit_applied(team: String, _source_index: int, target_index: int, _rolled: int, _dealt: int, _crit: bool, _before_hp: int, after_hp: int, _pcd: float, _ecd: float) -> void:
	var src_side: String = _source_side(team)
	var dst_side: String = _opponent_side(src_side)
	if dst_side == "":
		return
	_track_ttk_sample(src_side, dst_side, target_index, after_hp)
	if after_hp <= 0:
		_record_follow_up_kill(src_side, dst_side, target_index)
		_mark_dead(dst_side, target_index)
		_clear_threats_on_death(dst_side, target_index)

func _track_ttk_sample(attacker_side: String, defender_side: String, defender_index: int, after_hp: int) -> void:
	if defender_index < 0:
		return
	var carries_obj: Variant = _carry_units.get(defender_side, {})
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
		var elapsed: float = max(0.0, _time_s - start_time)
		var samples: Array = _team_metrics[attacker_side]["ttk_samples"]
		samples.append(elapsed)
		tracker.erase(defender_index)

func _on_cc_applied(source_team: String, source_index: int, target_team: String, target_index: int, _kind: String, duration: float) -> void:
	var source_side: String = _source_side(source_team)
	var target_side: String = _source_side(target_team)
	if target_side == "":
		return
	if int(duration) < 0:
		duration = 0.0
	# Resolve attacker/defender sides robustly to avoid empty-side indexing
	var defender_side: String = _opponent_side(target_side)
	if defender_side == "":
		defender_side = source_side
	var attacker_side: String = _opponent_side(defender_side)
	if attacker_side == "":
		attacker_side = target_side
	var priorities_obj: Variant = _priority_units.get(target_side, {})
	var priorities: Dictionary = priorities_obj if priorities_obj is Dictionary else {}
	if priorities.has(target_index) and attacker_side != "":
		_team_metrics[attacker_side]["lockdown_seconds"] = float(_team_metrics[attacker_side].get("lockdown_seconds", 0.0)) + max(0.0, duration)
		_record_lockdown_source((source_side if source_side != "" else attacker_side), source_index, max(0.0, duration))
	# Peel detection: defenders (opponent of target) responding to threats
	if source_side == defender_side:
		var threats: Dictionary = _threat_track.get(defender_side, {})
		if threats != null and threats.has(target_index):
			var started: float = float(threats[target_index])
			if _time_s - started <= PEEL_WINDOW_S:
				_team_metrics[defender_side]["peel_saves"] = int(_team_metrics[defender_side].get("peel_saves", 0)) + 1
				threats.erase(target_index)
	_record_control_window(source_side, source_index, target_side, target_index)

func _on_position_updated(team: String, index: int, x: float, y: float) -> void:
	var side: String = _source_side(team)
	if side == "":
		return
	var positions: Array = _unit_positions.get(side, [])
	if index < 0 or index >= positions.size():
		return
	var pos: Vector2 = Vector2(x, y)
	positions[index] = pos
	_update_control_windows_for_position(side, index, pos)
	_update_formation_windows_for_side(side)

func _record_control_window(source_side: String, source_index: int, target_side: String, target_index: int) -> void:
	if source_side == "" or target_side == "":
		return
	var source_uid: String = _unit_uid(source_side, source_index)
	if source_uid == "":
		return
	var target_uid: String = _unit_uid(target_side, target_index)
	var target_pos: Variant = _position_for(target_side, target_index)
	var rec: Dictionary = {
		"source_side": source_side,
		"source_uid": source_uid,
		"source_index": int(source_index),
		"target_side": target_side,
		"target_uid": target_uid,
		"target_index": int(target_index),
		"start_s": _time_s,
		"start_pos": target_pos,
		"start_spread_tiles": _team_spread_tiles(target_side),
		"max_distance_tiles": 0.0,
		"max_spread_delta_tiles": 0.0,
		"target_swap_counted": false,
		"follow_up_kill_counted": false,
		"finalized": false
	}
	_control_windows.append(rec)

func _update_control_windows_for_position(side: String, index: int, pos: Vector2) -> void:
	for i in range(_control_windows.size()):
		var rec: Dictionary = _control_windows[i]
		if bool(rec.get("finalized", false)):
			continue
		if String(rec.get("target_side", "")) != side or int(rec.get("target_index", -1)) != int(index):
			continue
		if _time_s - float(rec.get("start_s", 0.0)) > CONTROL_EFFECT_WINDOW_S:
			continue
		var start_pos: Variant = rec.get("start_pos", null)
		if start_pos is Vector2:
			var start_vec: Vector2 = start_pos
			var distance_tiles: float = start_vec.distance_to(pos) / max(1.0, _tile_size)
			rec["max_distance_tiles"] = max(float(rec.get("max_distance_tiles", 0.0)), distance_tiles)
			_control_windows[i] = rec

func _update_formation_windows_for_side(side: String) -> void:
	var spread_tiles: float = _team_spread_tiles(side)
	for i in range(_control_windows.size()):
		var rec: Dictionary = _control_windows[i]
		if bool(rec.get("finalized", false)):
			continue
		if String(rec.get("target_side", "")) != side:
			continue
		if _time_s - float(rec.get("start_s", 0.0)) > CONTROL_EFFECT_WINDOW_S:
			continue
		var delta_tiles: float = max(0.0, spread_tiles - float(rec.get("start_spread_tiles", spread_tiles)))
		rec["max_spread_delta_tiles"] = max(float(rec.get("max_spread_delta_tiles", 0.0)), delta_tiles)
		_control_windows[i] = rec

func _record_target_start(attacker_side: String, source_index: int, target_index: int) -> void:
	var uid: String = _unit_uid(attacker_side, source_index)
	if uid == "":
		return
	var side_targets: Dictionary = _current_targets.get(attacker_side, {})
	var previous_target: int = int(side_targets.get(uid, -1))
	side_targets[uid] = int(target_index)
	_current_targets[attacker_side] = side_targets
	if previous_target >= 0 and previous_target != int(target_index):
		_record_target_swap_after_control(attacker_side, source_index)

func _record_target_swap_after_control(controlled_side: String, controlled_index: int) -> void:
	for i in range(_control_windows.size()):
		var rec: Dictionary = _control_windows[i]
		if bool(rec.get("target_swap_counted", false)):
			continue
		if String(rec.get("target_side", "")) != controlled_side or int(rec.get("target_index", -1)) != int(controlled_index):
			continue
		if _time_s - float(rec.get("start_s", 0.0)) > TARGET_SWAP_WINDOW_S:
			continue
		var source_side: String = String(rec.get("source_side", ""))
		var source_uid: String = String(rec.get("source_uid", ""))
		_bump_disruption_int(source_side, source_uid, "target_swap_events", 1)
		rec["target_swap_counted"] = true
		_control_windows[i] = rec

func _record_follow_up_kill(attacker_side: String, target_side: String, target_index: int) -> void:
	for i in range(_control_windows.size()):
		var rec: Dictionary = _control_windows[i]
		if bool(rec.get("follow_up_kill_counted", false)):
			continue
		if String(rec.get("source_side", "")) != attacker_side:
			continue
		if String(rec.get("target_side", "")) != target_side or int(rec.get("target_index", -1)) != int(target_index):
			continue
		if _time_s - float(rec.get("start_s", 0.0)) > FOLLOW_UP_KILL_WINDOW_S:
			continue
		_bump_disruption_int(attacker_side, String(rec.get("source_uid", "")), "follow_up_kills", 1)
		rec["follow_up_kill_counted"] = true
		_control_windows[i] = rec

func _record_lockdown_source(side: String, source_index: int, duration: float) -> void:
	if side == "":
		return
	var uid_map: Dictionary = _id_map.get(side, {})
	var uid: String = String(uid_map.get(int(source_index), ""))
	if uid == "":
		return
	var per_side: Dictionary = _lockdown_per_unit.get(side, {})
	var rec: Dictionary = per_side.get(uid, {"seconds_on_priority": 0.0, "events": 0, "samples": 0})
	rec["seconds_on_priority"] = float(rec.get("seconds_on_priority", 0.0)) + max(0.0, duration)
	rec["events"] = int(rec.get("events", 0)) + 1
	rec["samples"] = int(rec.get("samples", 0)) + 1
	per_side[uid] = rec
	_lockdown_per_unit[side] = per_side

func _on_target_start(source_team: String, source_index: int, target_team: String, target_index: int) -> void:
	var defender_side: String = _source_side(target_team)
	var attacker_side: String = _source_side(source_team)
	if defender_side == "" or attacker_side == "":
		return
	_record_target_start(attacker_side, source_index, target_index)
	var priorities: Dictionary = _priority_units.get(defender_side, {})
	if priorities == null or not priorities.has(target_index):
		return
	var threats: Dictionary = _threat_track.get(defender_side, {})
	threats[source_index] = _time_s

func _on_target_end(source_team: String, source_index: int, _target_team: String, _target_index: int) -> void:
	var defender_side: String = _opponent_side(_source_side(source_team))
	if defender_side == "":
		return
	var threats: Dictionary = _threat_track.get(defender_side, {})
	if threats != null:
		threats.erase(source_index)

func _on_heal_applied(source_team: String, source_index: int, _target_team: String, _target_index: int, healed: int, overheal: int, _before_hp: int, _after_hp: int) -> void:
	var side: String = _source_side(source_team)
	if side == "":
		return
	var uid_map: Dictionary = _id_map.get(side, {})
	var uid: String = String(uid_map.get(int(source_index), ""))
	if uid == "":
		return
	var rec: Dictionary = _healing_per_unit[side].get(uid, {"healed": 0, "overheal": 0, "samples": 0})
	rec["healed"] = int(rec.get("healed", 0)) + int(healed)
	rec["overheal"] = int(rec.get("overheal", 0)) + int(overheal)
	rec["samples"] = int(rec.get("samples", 0)) + 1
	_healing_per_unit[side][uid] = rec

func _on_shield_absorbed(target_team: String, target_index: int, absorbed: int) -> void:
	# Attribute shielding to the TARGET’s side and unit (beneficiary)
	var side: String = _source_side(target_team)
	if side == "":
		return
	var uid_map: Dictionary = _id_map.get(side, {})
	var uid: String = String(uid_map.get(int(target_index), ""))
	if uid == "":
		return
	var rec: Dictionary = _shield_per_unit[side].get(uid, {"absorbed": 0, "samples": 0})
	rec["absorbed"] = int(rec.get("absorbed", 0)) + int(absorbed)
	rec["samples"] = int(rec.get("samples", 0)) + 1
	_shield_per_unit[side][uid] = rec

func _mark_dead(side: String, index: int) -> void:
	var arr: Array = _unit_alive.get(side, [])
	if index >= 0 and index < arr.size():
		arr[index] = false

func _clear_threats_on_death(side: String, index: int) -> void:
	var threats: Dictionary = _threat_track.get(side, {})
	var priorities_obj: Variant = _priority_units.get(side, {})
	var priorities: Dictionary = priorities_obj if priorities_obj is Dictionary else {}
	if priorities.has(index):
		threats.clear()
	var carry_tracker: Dictionary = _carry_track.get(_opponent_side(side), {})
	if carry_tracker != null and carry_tracker.has(index):
		carry_tracker.erase(index)

func _unit_uid(side: String, index: int) -> String:
	if side == "":
		return ""
	var uid_map: Dictionary = _id_map.get(side, {})
	return String(uid_map.get(int(index), ""))

func _position_for(side: String, index: int) -> Variant:
	var positions: Array = _unit_positions.get(side, [])
	if index < 0 or index >= positions.size():
		return null
	return positions[index]

func _team_spread_tiles(side: String) -> float:
	var alive_arr: Array = _unit_alive.get(side, [])
	var pos_arr: Array = _unit_positions.get(side, [])
	if alive_arr == null or pos_arr == null:
		return 0.0
	var valid_positions: Array[Vector2] = []
	for i in range(pos_arr.size()):
		if i >= alive_arr.size() or not bool(alive_arr[i]):
			continue
		var pos_value: Variant = pos_arr[i]
		if pos_value is Vector2:
			var pos_vec: Vector2 = pos_value
			valid_positions.append(pos_vec)
	if valid_positions.size() <= 1:
		return 0.0
	var centroid: Vector2 = Vector2.ZERO
	for pos in valid_positions:
		centroid += pos
	centroid /= float(valid_positions.size())
	var total_distance: float = 0.0
	for pos_b in valid_positions:
		total_distance += centroid.distance_to(pos_b)
	return (total_distance / float(valid_positions.size())) / max(1.0, _tile_size)

func _blank_disruption_rec() -> Dictionary:
	return {
		"forced_reposition_events": 0,
		"forced_reposition_distance_tiles": 0.0,
		"target_swap_events": 0,
		"formation_break_events": 0,
		"formation_spread_increase_tiles": 0.0,
		"follow_up_kills": 0
	}

func _bump_disruption_int(side: String, uid: String, key: String, amount: int) -> void:
	if side == "" or uid == "":
		return
	var per_side: Dictionary = _disruption_per_unit.get(side, {})
	var rec: Dictionary = per_side.get(uid, _blank_disruption_rec())
	rec[key] = int(rec.get(key, 0)) + int(amount)
	per_side[uid] = rec
	_disruption_per_unit[side] = per_side

func _bump_disruption_float(side: String, uid: String, key: String, amount: float) -> void:
	if side == "" or uid == "":
		return
	var per_side: Dictionary = _disruption_per_unit.get(side, {})
	var rec: Dictionary = per_side.get(uid, _blank_disruption_rec())
	rec[key] = float(rec.get(key, 0.0)) + float(amount)
	per_side[uid] = rec
	_disruption_per_unit[side] = per_side

func _sum_disruption_side(side: String) -> Dictionary:
	var totals: Dictionary = _blank_disruption_rec()
	var per_side: Dictionary = _disruption_per_unit.get(side, {})
	for uid in per_side.keys():
		var rec: Dictionary = per_side.get(uid, {})
		if not (rec is Dictionary):
			continue
		totals["forced_reposition_events"] = int(totals.get("forced_reposition_events", 0)) + int(rec.get("forced_reposition_events", 0))
		totals["forced_reposition_distance_tiles"] = float(totals.get("forced_reposition_distance_tiles", 0.0)) + float(rec.get("forced_reposition_distance_tiles", 0.0))
		totals["target_swap_events"] = int(totals.get("target_swap_events", 0)) + int(rec.get("target_swap_events", 0))
		totals["formation_break_events"] = int(totals.get("formation_break_events", 0)) + int(rec.get("formation_break_events", 0))
		totals["formation_spread_increase_tiles"] = float(totals.get("formation_spread_increase_tiles", 0.0)) + float(rec.get("formation_spread_increase_tiles", 0.0))
		totals["follow_up_kills"] = int(totals.get("follow_up_kills", 0)) + int(rec.get("follow_up_kills", 0))
	return totals

func _extract_tile_size() -> float:
	if _context_tags == null:
		return DEFAULT_TILE_SIZE
	var metadata: Dictionary = _context_tags.metadata if _context_tags.metadata is Dictionary else {}
	return max(1.0, float(metadata.get("tile_size", DEFAULT_TILE_SIZE)))

func _source_side(team_str: String) -> String:
	var team: String = String(team_str)
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
