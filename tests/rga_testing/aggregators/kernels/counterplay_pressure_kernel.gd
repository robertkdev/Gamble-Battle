extends RefCounted

# Counterplay Pressure Kernel
# Attributes cleanse pressure, tenacity tax, and CC-immunity tax back to the
# source unit that created the enemy effect. This backs doc metrics such as
# Cleanse_pressure, Cleanse_bait_rate, and high-tenacity lockdown tax.

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

var _engine: Object = null
var _player_is_team_a: bool = true
var _index_to_uid: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _per_unit: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _target_unit: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _pending_by_target: Dictionary = {}
var _time_s: float = 0.0
var _supported: bool = false

func attach(engine: Object, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_player_is_team_a = player_is_team_a
	_index_to_uid = _extract_index_map(context_tags)
	_per_unit = {SIDE_A: {}, SIDE_B: {}}
	_target_unit = {SIDE_A: {}, SIDE_B: {}}
	_pending_by_target = {}
	_time_s = 0.0
	_supported = _connect()

func detach() -> void:
	if _engine != null:
		_disconnect("debuff_applied", Callable(self, "_on_debuff_applied"))
		_disconnect("cleanse_applied", Callable(self, "_on_cleanse_applied"))
		_disconnect("cc_taxed", Callable(self, "_on_cc_taxed"))
	_engine = null
	_supported = false

func tick(delta_s: float) -> void:
	_time_s += max(0.0, float(delta_s))

func finalize(_total_time_s: float) -> void:
	pass

func result() -> Dictionary:
	return {
		"counterplay_pressure": {
			"supported": _supported,
			"per_unit": {
				SIDE_A: _per_unit.get(SIDE_A, {}),
				SIDE_B: _per_unit.get(SIDE_B, {})
			},
			"target_unit": {
				SIDE_A: _target_unit.get(SIDE_A, {}),
				SIDE_B: _target_unit.get(SIDE_B, {})
			}
		}
	}

func register(_aggregator: Variant) -> RefCounted:
	return self

func _connect() -> bool:
	if _engine == null:
		return false
	var any_signal: bool = false
	any_signal = _connect_signal("debuff_applied", Callable(self, "_on_debuff_applied")) or any_signal
	any_signal = _connect_signal("cleanse_applied", Callable(self, "_on_cleanse_applied")) or any_signal
	any_signal = _connect_signal("cc_taxed", Callable(self, "_on_cc_taxed")) or any_signal
	return any_signal

func _connect_signal(signal_name: String, callable: Callable) -> bool:
	if _engine == null or not _engine.has_signal(signal_name):
		return false
	if not _engine.is_connected(signal_name, callable):
		_engine.connect(signal_name, callable)
	return true

func _disconnect(signal_name: String, callable: Callable) -> void:
	if _engine == null or not _engine.has_signal(signal_name):
		return
	if _engine.is_connected(signal_name, callable):
		_engine.disconnect(signal_name, callable)

func _on_debuff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, _fields: Dictionary, _magnitude: float, duration: float) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "" or target_side == "" or source_side == target_side:
		return
	var target_key: String = _target_key(target_side, int(target_index))
	var expires_at: float = -1.0
	if float(duration) > 0.0:
		expires_at = _time_s + float(duration)
	var pending: Array = _pending_by_target.get(target_key, [])
	pending.append({
		"source_side": source_side,
		"source_index": int(source_index),
		"target_side": target_side,
		"target_index": int(target_index),
		"kind": _safe_kind(kind),
		"expires_at": expires_at
	})
	_pending_by_target[target_key] = pending
	_bump_source(source_side, int(source_index), {
		"debuffs_applied_for_counterplay": 1
	})
	_bump_source_map(source_side, int(source_index), "counterplay_debuff_kinds", _safe_kind(kind))

func _on_cleanse_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, removed: int) -> void:
	var target_side: String = _team_to_side(target_team)
	if target_side == "":
		return
	var safe_removed: int = max(0, int(removed))
	_bump_target(target_side, int(target_index), {
		"cleanse_received": 1,
		"cleanse_removed": safe_removed
	})
	if safe_removed <= 0:
		return
	var target_key: String = _target_key(target_side, int(target_index))
	var pending: Array = _active_pending(target_key)
	var remaining: Array = []
	var attributed: int = 0
	for record_value in pending:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if attributed < safe_removed:
			var source_side: String = String(record.get("source_side", ""))
			var source_index: int = int(record.get("source_index", -1))
			var kind: String = String(record.get("kind", "unknown"))
			_bump_source(source_side, source_index, {
				"cleanse_pressure_events": 1,
				"cleanse_pressure_removed": 1,
				"cleanse_bait_events": 1,
				"cleansed_debuffs": 1
			})
			_bump_source_map(source_side, source_index, "cleansed_debuff_kinds", kind)
			attributed += 1
		else:
			remaining.append(record)
	_pending_by_target[target_key] = remaining
	_update_cleanse_rates()

func _on_cc_taxed(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, raw_duration: float, effective_duration: float, tenacity: float, prevented: bool) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "" or target_side == "" or source_side == target_side:
		return
	var raw: float = max(0.0, float(raw_duration))
	var effective: float = max(0.0, float(effective_duration))
	var tax_s: float = max(0.0, raw - effective)
	var prevented_count: int = 1 if bool(prevented) else 0
	var tax_event_count: int = 1 if tax_s > 0.0 else 0
	_bump_source(source_side, int(source_index), {
		"cc_raw_duration_s": raw,
		"cc_effective_duration_s": effective,
		"tenacity_tax_s": tax_s,
		"tenacity_tax_events": tax_event_count,
		"cc_prevented_by_immunity": prevented_count
	})
	_bump_source_max(source_side, int(source_index), "max_tenacity_seen", max(0.0, float(tenacity)))
	_bump_source_map(source_side, int(source_index), "cc_tax_kinds", _safe_kind(kind))
	_bump_target(target_side, int(target_index), {
		"cc_raw_duration_received_s": raw,
		"cc_effective_duration_received_s": effective,
		"tenacity_tax_received_s": tax_s,
		"tenacity_tax_received_events": tax_event_count,
		"cc_prevented_by_immunity_received": prevented_count
	})

func _active_pending(target_key: String) -> Array:
	var pending: Array = _pending_by_target.get(target_key, [])
	var active: Array = []
	for record_value in pending:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var expires_at: float = float(record.get("expires_at", -1.0))
		if expires_at < 0.0 or expires_at + 0.001 >= _time_s:
			active.append(record)
	_pending_by_target[target_key] = active
	return active

func _update_cleanse_rates() -> void:
	for side in [SIDE_A, SIDE_B]:
		var side_map: Dictionary = _per_unit.get(side, {})
		for uid_value in side_map.keys():
			var uid: String = String(uid_value)
			var rec: Dictionary = side_map.get(uid, {})
			var debuffs: float = max(1.0, float(rec.get("debuffs_applied_for_counterplay", 0)))
			rec["cleanse_bait_rate"] = float(rec.get("cleanse_bait_events", 0)) / debuffs
			side_map[uid] = rec
		_per_unit[side] = side_map

func _empty_source_counts() -> Dictionary:
	return {
		"debuffs_applied_for_counterplay": 0,
		"cleanse_pressure_events": 0,
		"cleanse_pressure_removed": 0,
		"cleanse_bait_events": 0,
		"cleanse_bait_rate": 0.0,
		"cleansed_debuffs": 0,
		"cc_raw_duration_s": 0.0,
		"cc_effective_duration_s": 0.0,
		"tenacity_tax_s": 0.0,
		"tenacity_tax_events": 0,
		"cc_prevented_by_immunity": 0,
		"max_tenacity_seen": 0.0,
		"counterplay_debuff_kinds": {},
		"cleansed_debuff_kinds": {},
		"cc_tax_kinds": {}
	}

func _empty_target_counts() -> Dictionary:
	return {
		"cleanse_received": 0,
		"cleanse_removed": 0,
		"cc_raw_duration_received_s": 0.0,
		"cc_effective_duration_received_s": 0.0,
		"tenacity_tax_received_s": 0.0,
		"tenacity_tax_received_events": 0,
		"cc_prevented_by_immunity_received": 0
	}

func _bump_source(side: String, source_index: int, deltas: Dictionary) -> void:
	var uid: String = _uid_for(side, source_index)
	if uid == "":
		return
	var side_map: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = side_map.get(uid, _empty_source_counts())
	_apply_deltas(rec, deltas)
	side_map[uid] = rec
	_per_unit[side] = side_map

func _bump_target(side: String, target_index: int, deltas: Dictionary) -> void:
	var uid: String = _uid_for(side, target_index)
	if uid == "":
		return
	var side_map: Dictionary = _target_unit.get(side, {})
	var rec: Dictionary = side_map.get(uid, _empty_target_counts())
	_apply_deltas(rec, deltas)
	side_map[uid] = rec
	_target_unit[side] = side_map

func _bump_source_map(side: String, source_index: int, field: String, key: String) -> void:
	var uid: String = _uid_for(side, source_index)
	if uid == "" or key == "":
		return
	var side_map: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = side_map.get(uid, _empty_source_counts())
	var map_value: Dictionary = rec.get(field, {})
	map_value[key] = int(map_value.get(key, 0)) + 1
	rec[field] = map_value
	side_map[uid] = rec
	_per_unit[side] = side_map

func _bump_source_max(side: String, source_index: int, field: String, value: float) -> void:
	var uid: String = _uid_for(side, source_index)
	if uid == "":
		return
	var side_map: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = side_map.get(uid, _empty_source_counts())
	rec[field] = max(float(rec.get(field, 0.0)), float(value))
	side_map[uid] = rec
	_per_unit[side] = side_map

func _apply_deltas(record: Dictionary, deltas: Dictionary) -> void:
	for key_value in deltas.keys():
		var key: String = String(key_value)
		var old_value: Variant = record.get(key, 0)
		var delta_value: Variant = deltas.get(key_value, 0)
		if typeof(old_value) == TYPE_FLOAT or typeof(delta_value) == TYPE_FLOAT:
			record[key] = float(old_value) + float(delta_value)
		else:
			record[key] = int(old_value) + int(delta_value)

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

func _target_key(side: String, index: int) -> String:
	return "%s:%d" % [String(side), int(index)]

func _safe_kind(value: String) -> String:
	var kind: String = String(value).strip_edges().to_lower()
	if kind == "":
		return "unknown"
	return kind

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
		for entry_value in entries:
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value
			var idx_value: Variant = entry.get("unit_index", null)
			if typeof(idx_value) != TYPE_INT:
				continue
			var uid: String = String(entry.get("unit_id", ""))
			if uid != "":
				side_map[int(idx_value)] = uid
		out[side] = side_map
	return out
