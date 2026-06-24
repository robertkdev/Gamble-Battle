extends RefCounted

# Zone Exposure Kernel
# Records direct evidence that a unit projected a lingering zone/hazard or area
# control effect onto enemy units. Positioning occupancy remains a fallback, but
# this kernel is the subject-owned signal for "creates persistent areas that
# control positioning."

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

var _engine: Object = null
var _player_is_team_a: bool = true
var _supported: bool = false
var _per_unit: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _counts: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _index_to_uid: Dictionary = {SIDE_A: {}, SIDE_B: {}}

func attach(engine: Object, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_player_is_team_a = player_is_team_a
	_per_unit = {SIDE_A: {}, SIDE_B: {}}
	_counts = {
		SIDE_A: _empty_counts(),
		SIDE_B: _empty_counts()
	}
	_index_to_uid = _extract_index_map(context_tags)
	_supported = _connect()

func detach() -> void:
	if _engine != null:
		if _engine.has_signal("zone_exposure_applied") and _engine.is_connected("zone_exposure_applied", Callable(self, "_on_zone_exposure_applied")):
			_engine.zone_exposure_applied.disconnect(_on_zone_exposure_applied)
	_engine = null
	_supported = false

func tick(_delta_s: float) -> void:
	pass

func finalize(_total_time_s: float) -> void:
	pass

func result() -> Dictionary:
	return {
		"zone_exposure": {
			"supported": _supported,
			SIDE_A: _counts_out(SIDE_A),
			SIDE_B: _counts_out(SIDE_B),
			"per_unit": {
				SIDE_A: _per_unit_out(SIDE_A),
				SIDE_B: _per_unit_out(SIDE_B)
			}
		}
	}

func register(_aggregator: Variant) -> RefCounted:
	return self

func _connect() -> bool:
	if _engine == null:
		return false
	if _engine.has_signal("zone_exposure_applied") and not _engine.is_connected("zone_exposure_applied", Callable(self, "_on_zone_exposure_applied")):
		_engine.zone_exposure_applied.connect(_on_zone_exposure_applied)
		return true
	return false

func _on_zone_exposure_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, damage: float, radius_tiles: float) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "" or target_side == "" or source_side == target_side:
		return
	var source_uid: String = _uid_for(source_side, int(source_index))
	var target_uid: String = _uid_for(target_side, int(target_index))
	if source_uid == "" or target_uid == "":
		return
	var duration: float = max(0.0, float(duration_s))
	var amount: float = max(0.0, float(damage))
	var radius: float = max(0.0, float(radius_tiles))
	if duration <= 0.0 and amount <= 0.0 and radius <= 0.0:
		return
	_bump_counts(source_side, _exposure_deltas(target_side, target_uid, kind, duration, amount, radius))
	_bump_unit(source_side, source_uid, _exposure_deltas(target_side, target_uid, kind, duration, amount, radius))

func _exposure_deltas(target_side: String, target_uid: String, kind: String, duration: float, amount: float, radius: float) -> Dictionary:
	return {
		"zone_exposure_events": 1,
		"zone_exposure_time_s": duration,
		"zone_exposure_damage": amount,
		"zone_radius_tiles_max": radius,
		"target_keys": {"%s:%s" % [String(target_side), String(target_uid)]: true},
		"zone_kinds": {String(kind): 1}
	}

func _bump_counts(side: String, deltas: Dictionary) -> void:
	var rec: Dictionary = _counts.get(side, _empty_counts())
	_merge_deltas(rec, deltas)
	rec["zone_exposure_targets"] = (rec.get("target_keys", {}) as Dictionary).size()
	_counts[side] = rec

func _bump_unit(side: String, uid: String, deltas: Dictionary) -> void:
	var by_side: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = by_side.get(uid, _empty_counts())
	_merge_deltas(rec, deltas)
	rec["zone_exposure_targets"] = (rec.get("target_keys", {}) as Dictionary).size()
	by_side[uid] = rec
	_per_unit[side] = by_side

func _merge_deltas(rec: Dictionary, deltas: Dictionary) -> void:
	for key_value in deltas.keys():
		var key: String = String(key_value)
		var value: Variant = deltas.get(key)
		if value is Dictionary:
			var current: Dictionary = rec.get(key, {})
			if not (current is Dictionary):
				current = {}
			for subkey in (value as Dictionary).keys():
				var subvalue: Variant = (value as Dictionary).get(subkey)
				if typeof(subvalue) == TYPE_BOOL:
					current[subkey] = bool(subvalue)
				else:
					current[subkey] = int(current.get(subkey, 0)) + int(subvalue)
			rec[key] = current
		elif typeof(value) == TYPE_FLOAT:
			if key.ends_with("_max"):
				rec[key] = max(float(rec.get(key, 0.0)), float(value))
			else:
				rec[key] = float(rec.get(key, 0.0)) + float(value)
		else:
			rec[key] = int(rec.get(key, 0)) + int(value)

func _counts_out(side: String) -> Dictionary:
	return _public_counts(_counts.get(side, _empty_counts()))

func _per_unit_out(side: String) -> Dictionary:
	var source: Dictionary = _per_unit.get(side, {})
	var out: Dictionary = {}
	for uid_value in source.keys():
		var uid: String = String(uid_value)
		var rec: Dictionary = source.get(uid, {})
		out[uid] = _public_counts(rec)
	return out

func _public_counts(rec: Dictionary) -> Dictionary:
	var out: Dictionary = rec.duplicate(true)
	out.erase("target_keys")
	return out

func _team_to_side(team_str: String) -> String:
	var team: String = String(team_str)
	if team == "":
		return ""
	if _player_is_team_a:
		return SIDE_A if team == TEAM_PLAYER else SIDE_B
	return SIDE_A if team == TEAM_ENEMY else SIDE_B

func _uid_for(side: String, index: int) -> String:
	var uid_map: Dictionary = _index_to_uid.get(side, {})
	return String(uid_map.get(int(index), ""))

func _extract_index_map(context_tags: Dictionary) -> Dictionary:
	var out: Dictionary = {SIDE_A: {}, SIDE_B: {}}
	if not (context_tags is Dictionary):
		return out
	var timelines_root: Dictionary = context_tags.get("unit_timelines", {})
	if not (timelines_root is Dictionary):
		return out
	for side in [SIDE_A, SIDE_B]:
		var arr: Array = timelines_root.get(side, [])
		if not (arr is Array):
			continue
		var index_map: Dictionary = {}
		for entry in arr:
			if not (entry is Dictionary):
				continue
			var idx_value: Variant = (entry as Dictionary).get("unit_index", null)
			if typeof(idx_value) != TYPE_INT:
				continue
			var uid: String = String((entry as Dictionary).get("unit_id", ""))
			if uid == "":
				continue
			index_map[int(idx_value)] = uid
		out[side] = index_map
	return out

func _empty_counts() -> Dictionary:
	return {
		"zone_exposure_events": 0,
		"zone_exposure_targets": 0,
		"zone_exposure_time_s": 0.0,
		"zone_exposure_damage": 0.0,
		"zone_radius_tiles_max": 0.0,
		"target_keys": {},
		"zone_kinds": {}
	}
