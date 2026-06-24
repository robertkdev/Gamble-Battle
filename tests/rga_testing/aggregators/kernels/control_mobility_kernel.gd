extends RefCounted

# Control Mobility Kernel
# Emits per-unit KPIs for doc-level approaches that rely on control and movement:
# disrupt, engage, and reposition.

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"
const DEFAULT_TILE_SIZE: float = 64.0
const EARLY_WINDOW_S: float = 4.0
const REPOSITION_STEP_TILES: float = 0.75
const POST_CAST_WINDOW_S: float = 1.5

var _engine: Object = null
var _player_is_team_a: bool = true
var _time_s: float = 0.0
var _total_time_s: float = 0.0
var _tile_size: float = DEFAULT_TILE_SIZE
var _id_map: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _initial_positions: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _last_positions: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _path_tiles: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _early_max_displacement: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _max_step_tiles: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _reposition_steps: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _first_target_s: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _first_hit_s: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _first_cast_s: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _first_cc_s: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _cc: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _cast_positions: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _post_cast_displacement: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _connected: bool = false

func attach(engine, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_player_is_team_a = player_is_team_a
	_time_s = 0.0
	_total_time_s = 0.0
	_tile_size = _extract_tile_size(context_tags)
	_id_map = _extract_index_map(context_tags)
	_initial_positions = {SIDE_A: {}, SIDE_B: {}}
	_last_positions = {SIDE_A: {}, SIDE_B: {}}
	_path_tiles = {SIDE_A: {}, SIDE_B: {}}
	_early_max_displacement = {SIDE_A: {}, SIDE_B: {}}
	_max_step_tiles = {SIDE_A: {}, SIDE_B: {}}
	_reposition_steps = {SIDE_A: {}, SIDE_B: {}}
	_first_target_s = {SIDE_A: {}, SIDE_B: {}}
	_first_hit_s = {SIDE_A: {}, SIDE_B: {}}
	_first_cast_s = {SIDE_A: {}, SIDE_B: {}}
	_first_cc_s = {SIDE_A: {}, SIDE_B: {}}
	_cc = {SIDE_A: {}, SIDE_B: {}}
	_cast_positions = {SIDE_A: {}, SIDE_B: {}}
	_post_cast_displacement = {SIDE_A: {}, SIDE_B: {}}
	_connected = _connect()

func detach() -> void:
	if _engine != null:
		if _engine.has_signal("position_updated") and _engine.is_connected("position_updated", Callable(self, "_on_position_updated")):
			_engine.position_updated.disconnect(_on_position_updated)
		if _engine.has_signal("target_start") and _engine.is_connected("target_start", Callable(self, "_on_target_start")):
			_engine.target_start.disconnect(_on_target_start)
		if _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
			_engine.hit_applied.disconnect(_on_hit_applied)
		if _engine.has_signal("ability_cast") and _engine.is_connected("ability_cast", Callable(self, "_on_ability_cast")):
			_engine.ability_cast.disconnect(_on_ability_cast)
		if _engine.has_signal("cc_applied") and _engine.is_connected("cc_applied", Callable(self, "_on_cc_applied")):
			_engine.cc_applied.disconnect(_on_cc_applied)
	_engine = null
	_connected = false

func tick(delta_s: float) -> void:
	_time_s += max(0.0, float(delta_s))

func finalize(total_time_s: float) -> void:
	_total_time_s = max(_time_s, float(total_time_s))

func result() -> Dictionary:
	return {
		"control_mobility": {
			"supported": _connected,
			"tile_size": _tile_size,
			"early_window_s": EARLY_WINDOW_S,
			"reposition_step_tiles": REPOSITION_STEP_TILES,
			"per_unit": {
				SIDE_A: _summarize_side(SIDE_A),
				SIDE_B: _summarize_side(SIDE_B)
			}
		}
	}

func register(_aggregator) -> RefCounted:
	return self

func _connect() -> bool:
	if _engine == null:
		return false
	var any_connected: bool = false
	if _engine.has_signal("position_updated"):
		_engine.position_updated.connect(_on_position_updated)
		any_connected = true
	if _engine.has_signal("target_start"):
		_engine.target_start.connect(_on_target_start)
		any_connected = true
	if _engine.has_signal("hit_applied"):
		_engine.hit_applied.connect(_on_hit_applied)
		any_connected = true
	if _engine.has_signal("ability_cast"):
		_engine.ability_cast.connect(_on_ability_cast)
		any_connected = true
	if _engine.has_signal("cc_applied"):
		_engine.cc_applied.connect(_on_cc_applied)
		any_connected = true
	return any_connected

func _on_position_updated(team: String, index: int, x: float, y: float) -> void:
	var side: String = _source_side(team)
	var uid: String = _uid_for(side, index)
	if side == "" or uid == "":
		return
	var pos: Vector2 = Vector2(x, y)
	var initial_by_side: Dictionary = _initial_positions.get(side, {})
	var last_by_side: Dictionary = _last_positions.get(side, {})
	if not initial_by_side.has(uid):
		initial_by_side[uid] = pos
		last_by_side[uid] = pos
		_initial_positions[side] = initial_by_side
		_last_positions[side] = last_by_side
		return
	var last_pos: Vector2 = last_by_side.get(uid, pos)
	var step_tiles: float = last_pos.distance_to(pos) / max(1.0, _tile_size)
	last_by_side[uid] = pos
	_last_positions[side] = last_by_side
	_bump_float(_path_tiles, side, uid, step_tiles)
	_set_max(_max_step_tiles, side, uid, step_tiles)
	if step_tiles >= REPOSITION_STEP_TILES:
		_bump_int(_reposition_steps, side, uid, 1)
	var initial_pos: Vector2 = initial_by_side.get(uid, pos)
	var displacement_tiles: float = initial_pos.distance_to(pos) / max(1.0, _tile_size)
	if _time_s <= EARLY_WINDOW_S:
		_set_max(_early_max_displacement, side, uid, displacement_tiles)
	_update_post_cast_displacement(side, uid, pos)

func _on_target_start(source_team: String, source_index: int, _target_team: String, _target_index: int) -> void:
	_record_first(_first_target_s, _source_side(source_team), source_index, _time_s)

func _on_hit_applied(team: String, source_index: int, _target_index: int, _rolled: int, dealt: int, _crit: bool, _before_hp: int, _after_hp: int, _player_cd: float, _enemy_cd: float) -> void:
	if int(dealt) <= 0:
		return
	_record_first(_first_hit_s, _source_side(team), source_index, _time_s)

func _on_ability_cast(source_team: String, source_index: int, _target_team: String, _target_index: int, _position: Vector2) -> void:
	var side: String = _source_side(source_team)
	var uid: String = _uid_for(side, source_index)
	if side == "" or uid == "":
		return
	_record_first_by_uid(_first_cast_s, side, uid, _time_s)
	var pos: Variant = (_last_positions.get(side, {}) as Dictionary).get(uid, null)
	if pos is Vector2:
		var casts: Dictionary = _cast_positions.get(side, {})
		casts[uid] = {"t": _time_s, "pos": pos}
		_cast_positions[side] = casts

func _on_cc_applied(source_team: String, source_index: int, _target_team: String, target_index: int, kind: String, duration: float) -> void:
	var side: String = _source_side(source_team)
	var uid: String = _uid_for(side, source_index)
	if side == "" or uid == "":
		return
	_record_first_by_uid(_first_cc_s, side, uid, _time_s)
	var by_side: Dictionary = _cc.get(side, {})
	var rec: Dictionary = by_side.get(uid, {"cc_seconds": 0.0, "cc_events": 0, "targets": {}, "kinds": {}})
	rec["cc_seconds"] = float(rec.get("cc_seconds", 0.0)) + max(0.0, float(duration))
	rec["cc_events"] = int(rec.get("cc_events", 0)) + 1
	var targets: Dictionary = rec.get("targets", {})
	targets[str(int(target_index))] = true
	rec["targets"] = targets
	var kinds: Dictionary = rec.get("kinds", {})
	var kind_id: String = String(kind).strip_edges().to_lower()
	if kind_id == "":
		kind_id = "unknown"
	kinds[kind_id] = int(kinds.get(kind_id, 0)) + 1
	rec["kinds"] = kinds
	by_side[uid] = rec
	_cc[side] = by_side

func _summarize_side(side: String) -> Dictionary:
	var out: Dictionary = {}
	var uid_keys: Dictionary = {}
	for source in [_initial_positions, _first_target_s, _first_hit_s, _first_cast_s, _first_cc_s, _cc, _path_tiles, _early_max_displacement, _post_cast_displacement]:
		var by_side: Dictionary = (source as Dictionary).get(side, {})
		for uid in by_side.keys():
			uid_keys[String(uid)] = true
	for uid_key in uid_keys.keys():
		var uid: String = String(uid_key)
		var cc_rec: Dictionary = (_cc.get(side, {}) as Dictionary).get(uid, {})
		var target_map: Dictionary = cc_rec.get("targets", {}) if (cc_rec is Dictionary) else {}
		var first_action: float = _min_non_negative([
			float((_first_hit_s.get(side, {}) as Dictionary).get(uid, -1.0)),
			float((_first_cast_s.get(side, {}) as Dictionary).get(uid, -1.0)),
			float((_first_cc_s.get(side, {}) as Dictionary).get(uid, -1.0))
		])
		var first_action_displacement: float = _displacement_at_first_action(side, uid)
		out[uid] = {
			"cc_seconds": float(cc_rec.get("cc_seconds", 0.0)),
			"cc_events": int(cc_rec.get("cc_events", 0)),
			"cc_unique_targets": target_map.size() if target_map is Dictionary else 0,
			"first_target_s": float((_first_target_s.get(side, {}) as Dictionary).get(uid, -1.0)),
			"first_hit_s": float((_first_hit_s.get(side, {}) as Dictionary).get(uid, -1.0)),
			"first_cast_s": float((_first_cast_s.get(side, {}) as Dictionary).get(uid, -1.0)),
			"first_cc_s": float((_first_cc_s.get(side, {}) as Dictionary).get(uid, -1.0)),
			"first_action_s": first_action,
			"displacement_to_first_action_tiles": first_action_displacement,
			"early_max_displacement_tiles": float((_early_max_displacement.get(side, {}) as Dictionary).get(uid, 0.0)),
			"total_path_tiles": float((_path_tiles.get(side, {}) as Dictionary).get(uid, 0.0)),
			"max_step_tiles": float((_max_step_tiles.get(side, {}) as Dictionary).get(uid, 0.0)),
			"reposition_steps": int((_reposition_steps.get(side, {}) as Dictionary).get(uid, 0)),
			"post_cast_displacement_tiles": float((_post_cast_displacement.get(side, {}) as Dictionary).get(uid, 0.0)),
			"cc_kinds": cc_rec.get("kinds", {}) if (cc_rec is Dictionary) else {}
		}
	return out

func _displacement_at_first_action(side: String, uid: String) -> float:
	var action_s: float = _min_non_negative([
		float((_first_hit_s.get(side, {}) as Dictionary).get(uid, -1.0)),
		float((_first_cast_s.get(side, {}) as Dictionary).get(uid, -1.0)),
		float((_first_cc_s.get(side, {}) as Dictionary).get(uid, -1.0))
	])
	if action_s < 0.0:
		return 0.0
	var initial_pos: Variant = (_initial_positions.get(side, {}) as Dictionary).get(uid, null)
	var last_pos: Variant = (_last_positions.get(side, {}) as Dictionary).get(uid, null)
	if not (initial_pos is Vector2) or not (last_pos is Vector2):
		return 0.0
	var initial_vec: Vector2 = initial_pos
	var last_vec: Vector2 = last_pos
	return initial_vec.distance_to(last_vec) / max(1.0, _tile_size)

func _update_post_cast_displacement(side: String, uid: String, pos: Vector2) -> void:
	var casts: Dictionary = _cast_positions.get(side, {})
	if not casts.has(uid):
		return
	var rec: Dictionary = casts.get(uid, {})
	var cast_time: float = float(rec.get("t", -999.0))
	if _time_s - cast_time > POST_CAST_WINDOW_S:
		casts.erase(uid)
		_cast_positions[side] = casts
		return
	var cast_pos: Variant = rec.get("pos", null)
	if cast_pos is Vector2:
		var cast_vec: Vector2 = cast_pos
		var displacement_tiles: float = cast_vec.distance_to(pos) / max(1.0, _tile_size)
		_set_max(_post_cast_displacement, side, uid, displacement_tiles)

func _record_first(store: Dictionary, side: String, source_index: int, t: float) -> void:
	var uid: String = _uid_for(side, source_index)
	if uid == "":
		return
	_record_first_by_uid(store, side, uid, t)

func _record_first_by_uid(store: Dictionary, side: String, uid: String, t: float) -> void:
	if side == "" or uid == "":
		return
	var by_side: Dictionary = store.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = float(t)
	store[side] = by_side

func _uid_for(side: String, index: int) -> String:
	if side == "":
		return ""
	var side_map: Dictionary = _id_map.get(side, {})
	return String(side_map.get(int(index), ""))

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

func _extract_tile_size(context_tags: Dictionary) -> float:
	var metadata: Dictionary = context_tags.get("metadata", {}) if (context_tags is Dictionary) else {}
	var tile_size: float = float(metadata.get("tile_size", DEFAULT_TILE_SIZE))
	return max(1.0, tile_size)

func _extract_index_map(context_tags: Dictionary) -> Dictionary:
	var out: Dictionary = {SIDE_A: {}, SIDE_B: {}}
	if not (context_tags is Dictionary):
		return out
	var timelines_root: Dictionary = context_tags.get("unit_timelines", {})
	if not (timelines_root is Dictionary):
		return out
	for side in [SIDE_A, SIDE_B]:
		var entries: Array = timelines_root.get(side, [])
		var side_map: Dictionary = {}
		for entry in entries:
			if not (entry is Dictionary):
				continue
			var idx_value: Variant = (entry as Dictionary).get("unit_index", null)
			if typeof(idx_value) != TYPE_INT:
				continue
			var uid: String = String((entry as Dictionary).get("unit_id", ""))
			if uid != "":
				side_map[int(idx_value)] = uid
		out[side] = side_map
	return out

func _bump_float(store: Dictionary, side: String, uid: String, value: float) -> void:
	var by_side: Dictionary = store.get(side, {})
	by_side[uid] = float(by_side.get(uid, 0.0)) + float(value)
	store[side] = by_side

func _bump_int(store: Dictionary, side: String, uid: String, value: int) -> void:
	var by_side: Dictionary = store.get(side, {})
	by_side[uid] = int(by_side.get(uid, 0)) + int(value)
	store[side] = by_side

func _set_max(store: Dictionary, side: String, uid: String, value: float) -> void:
	var by_side: Dictionary = store.get(side, {})
	by_side[uid] = max(float(by_side.get(uid, 0.0)), float(value))
	store[side] = by_side

func _min_non_negative(values: Array) -> float:
	var best: float = -1.0
	for value in values:
		var f: float = float(value)
		if f < 0.0:
			continue
		if best < 0.0 or f < best:
			best = f
	return best
