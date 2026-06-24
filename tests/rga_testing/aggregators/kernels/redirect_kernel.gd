extends RefCounted

# Redirect Kernel
# Counts direct target/threat manipulation evidence. Current engine support emits
# damage_redirected when an active absorb/redirect mechanic prevents damage.
# target_start/target_end are also consumed to record enemy focus and swaps onto
# a redirect subject, matching the design-doc "taunts/body blocks/threat swaps"
# definition without changing combat behavior.

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

var _engine: Object = null
var _player_is_team_a: bool = true
var _supported: bool = false
var _time_s: float = 0.0
var _per_unit: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _counts: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _index_to_uid: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _active_focus: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _attacker_active_targets: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _attacker_last_targets: Dictionary = {SIDE_A: {}, SIDE_B: {}}

func attach(engine: Object, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_player_is_team_a = player_is_team_a
	_supported = false
	_time_s = 0.0
	_per_unit = {SIDE_A: {}, SIDE_B: {}}
	_counts = {
		SIDE_A: _empty_side_counts(),
		SIDE_B: _empty_side_counts()
	}
	_index_to_uid = _extract_index_map(context_tags)
	_active_focus = {SIDE_A: {}, SIDE_B: {}}
	_attacker_active_targets = {SIDE_A: {}, SIDE_B: {}}
	_attacker_last_targets = {SIDE_A: {}, SIDE_B: {}}
	_supported = _connect()

func detach() -> void:
	if _engine != null:
		if _engine.has_signal("damage_redirected") and _engine.is_connected("damage_redirected", Callable(self, "_on_damage_redirected")):
			_engine.damage_redirected.disconnect(_on_damage_redirected)
		if _engine.has_signal("redirect_semantic_applied") and _engine.is_connected("redirect_semantic_applied", Callable(self, "_on_redirect_semantic_applied")):
			_engine.redirect_semantic_applied.disconnect(_on_redirect_semantic_applied)
		if _engine.has_signal("target_start") and _engine.is_connected("target_start", Callable(self, "_on_target_start")):
			_engine.target_start.disconnect(_on_target_start)
		if _engine.has_signal("target_end") and _engine.is_connected("target_end", Callable(self, "_on_target_end")):
			_engine.target_end.disconnect(_on_target_end)
	_engine = null
	_supported = false

func tick(delta_s: float) -> void:
	_time_s += max(0.0, float(delta_s))

func finalize(_total_time_s: float) -> void:
	_close_all_focus()

func result() -> Dictionary:
	return {
		"redirect": {
			"supported": _supported,
			SIDE_A: _counts.get(SIDE_A, _empty_side_counts()),
			SIDE_B: _counts.get(SIDE_B, _empty_side_counts()),
			"per_unit": {
				SIDE_A: _per_unit.get(SIDE_A, {}),
				SIDE_B: _per_unit.get(SIDE_B, {})
			}
		}
	}

func register(_aggregator: Variant) -> RefCounted:
	return self

func _connect() -> bool:
	if _engine == null:
		return false
	var connected: bool = false
	if _engine.has_signal("damage_redirected") and not _engine.is_connected("damage_redirected", Callable(self, "_on_damage_redirected")):
		_engine.damage_redirected.connect(_on_damage_redirected)
		connected = true
	if _engine.has_signal("redirect_semantic_applied") and not _engine.is_connected("redirect_semantic_applied", Callable(self, "_on_redirect_semantic_applied")):
		_engine.redirect_semantic_applied.connect(_on_redirect_semantic_applied)
		connected = true
	if _engine.has_signal("target_start") and not _engine.is_connected("target_start", Callable(self, "_on_target_start")):
		_engine.target_start.connect(_on_target_start)
		connected = true
	if _engine.has_signal("target_end") and not _engine.is_connected("target_end", Callable(self, "_on_target_end")):
		_engine.target_end.connect(_on_target_end)
		connected = true
	return connected

func _on_damage_redirected(source_team: String, source_index: int, original_target_team: String, original_target_index: int, redirect_team: String, redirect_index: int, amount: int, kind: String) -> void:
	var redirect_side: String = _team_to_side(redirect_team)
	var original_side: String = _team_to_side(original_target_team)
	if redirect_side == "":
		return
	var amt: int = max(0, int(amount))
	if amt <= 0:
		return
	var ally_prevented: int = 0
	if original_side == redirect_side and int(original_target_index) != int(redirect_index):
		ally_prevented = amt
	_bump_side(redirect_side, "redirect_events", 1)
	_bump_side(redirect_side, "redirected_damage_prevented", amt)
	_bump_side(redirect_side, "ally_damage_prevented", ally_prevented)
	_bump_unit(redirect_side, int(redirect_index), {
		"redirect_events": 1,
		"redirected_damage_prevented": amt,
		"ally_damage_prevented": ally_prevented,
		"source_attackers": {"%s:%d" % [String(source_team), int(source_index)]: true},
		"kinds": {String(kind): 1}
	})

func _on_redirect_semantic_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, amount: float, risk_s: float) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "" or target_side == "" or source_side == target_side:
		return
	var target_uid: String = _uid_for(target_side, int(target_index))
	if target_uid == "":
		return
	var normalized_kind: String = _normalize_kind(kind)
	var duration: float = max(0.0, float(duration_s))
	var value: float = max(0.0, float(amount))
	var risk: float = max(0.0, float(risk_s))
	if normalized_kind == "" or (duration <= 0.0 and value <= 0.0 and risk <= 0.0):
		return
	var deltas: Dictionary = _semantic_deltas(target_side, target_uid, normalized_kind, duration, value, risk)
	_bump_semantic_side(source_side, deltas)
	_bump_unit(source_side, int(source_index), deltas)

func _on_target_start(source_team: String, source_index: int, target_team: String, target_index: int) -> void:
	var attacker_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if attacker_side == "" or target_side == "" or attacker_side == target_side:
		return
	var target_uid: String = _uid_for(target_side, int(target_index))
	if target_uid == "":
		return
	var attacker_key: String = _attacker_key(attacker_side, int(source_index))
	var previous_uid: String = _last_target_uid(attacker_side, attacker_key)
	_end_active_focus_for_attacker(attacker_side, attacker_key, target_uid)
	_start_focus(target_side, int(target_index), attacker_key)
	_set_active_target(attacker_side, attacker_key, target_side, target_uid)
	_set_last_target_uid(attacker_side, attacker_key, target_uid)
	_bump_side(target_side, "focus_start_events", 1)
	_bump_unit(target_side, int(target_index), {
		"focus_start_events": 1,
		"source_attackers": {attacker_key: true}
	})
	if previous_uid != "" and previous_uid != target_uid:
		_bump_side(target_side, "target_swap_to_subject_events", 1)
		_bump_unit(target_side, int(target_index), {
			"target_swap_to_subject_events": 1,
			"source_attackers": {attacker_key: true}
		})

func _on_target_end(source_team: String, source_index: int, target_team: String, target_index: int) -> void:
	var attacker_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if attacker_side == "" or target_side == "" or attacker_side == target_side:
		return
	var attacker_key: String = _attacker_key(attacker_side, int(source_index))
	_end_focus(target_side, int(target_index), attacker_key)
	_clear_active_target(attacker_side, attacker_key, target_side, int(target_index))

func _team_to_side(team_str: String) -> String:
	var team: String = String(team_str)
	if team == "":
		return ""
	if _player_is_team_a:
		return SIDE_A if team == TEAM_PLAYER else SIDE_B
	return SIDE_A if team == TEAM_ENEMY else SIDE_B

func _bump_side(side: String, key: String, amount: int) -> void:
	if side == "":
		return
	var data: Dictionary = _counts.get(side, _empty_side_counts())
	data[key] = int(data.get(key, 0)) + int(amount)
	_counts[side] = data

func _bump_side_float(side: String, key: String, amount: float) -> void:
	if side == "":
		return
	var data: Dictionary = _counts.get(side, _empty_side_counts())
	data[key] = float(data.get(key, 0.0)) + float(amount)
	_counts[side] = data

func _bump_semantic_side(side: String, deltas: Dictionary) -> void:
	if side == "":
		return
	var data: Dictionary = _counts.get(side, _empty_side_counts())
	_merge_deltas(data, deltas)
	data["redirect_semantic_targets"] = _dict_size(data.get("target_keys", {}))
	_counts[side] = data

func _bump_unit(side: String, index: int, deltas: Dictionary) -> void:
	var uid: String = _uid_for(side, index)
	if uid == "":
		return
	var by_side: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = by_side.get(uid, _empty_unit_counts())
	_merge_deltas(rec, deltas)
	rec["redirect_semantic_targets"] = _dict_size(rec.get("target_keys", {}))
	by_side[uid] = rec
	_per_unit[side] = by_side

func _merge_deltas(rec: Dictionary, deltas: Dictionary) -> void:
	for key in deltas.keys():
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
			rec[key] = float(rec.get(key, 0.0)) + float(value)
		else:
			rec[key] = int(rec.get(key, 0)) + int(value)

func _semantic_deltas(target_side: String, target_uid: String, kind: String, duration: float, amount: float, risk: float) -> Dictionary:
	var deltas: Dictionary = {
		"redirect_semantic_events": 1,
		"redirect_semantic_duration_s": duration,
		"redirect_semantic_amount": amount,
		"redirect_semantic_risk_s": risk,
		"target_keys": {"%s:%s" % [String(target_side), String(target_uid)]: true},
		"kinds": {String(kind): 1}
	}
	if kind.find("taunt") >= 0:
		deltas["taunt_events"] = 1
		deltas["taunt_duration_s"] = duration
	if kind.find("body_block") >= 0 or kind.find("bodyblock") >= 0 or kind.find("block") >= 0:
		deltas["body_block_events"] = 1
		deltas["body_block_duration_s"] = duration
		deltas["body_block_damage_prevented"] = amount
	if kind.find("threat_swap") >= 0 or kind.find("threatswap") >= 0:
		deltas["explicit_threat_swap_events"] = 1
	if kind.find("risk") >= 0 or risk > 0.0:
		deltas["redirect_end_risk_events"] = 1
		deltas["redirect_end_risk_s"] = risk
	return deltas

func _normalize_kind(kind: String) -> String:
	var text: String = String(kind).strip_edges().to_lower()
	text = text.replace(" ", "_")
	text = text.replace("-", "_")
	return text

func _dict_size(value: Variant) -> int:
	if value is Dictionary:
		return (value as Dictionary).size()
	return 0

func _start_focus(side: String, index: int, attacker_key: String) -> void:
	var uid: String = _uid_for(side, index)
	if uid == "" or attacker_key == "":
		return
	var by_side: Dictionary = _active_focus.get(side, {})
	var by_unit: Dictionary = by_side.get(uid, {})
	if by_unit.has(attacker_key):
		return
	by_unit[attacker_key] = _time_s
	by_side[uid] = by_unit
	_active_focus[side] = by_side

func _end_focus(side: String, index: int, attacker_key: String) -> void:
	var uid: String = _uid_for(side, index)
	if uid == "" or attacker_key == "":
		return
	var by_side: Dictionary = _active_focus.get(side, {})
	var by_unit: Dictionary = by_side.get(uid, {})
	if not by_unit.has(attacker_key):
		return
	var started_s: float = float(by_unit.get(attacker_key, _time_s))
	var duration_s: float = max(0.0, _time_s - started_s)
	_bump_side_float(side, "enemy_focus_time_s", duration_s)
	_bump_unit(side, index, {
		"enemy_focus_time_s": duration_s,
		"source_attackers": {attacker_key: true}
	})
	by_unit.erase(attacker_key)
	if by_unit.is_empty():
		by_side.erase(uid)
	else:
		by_side[uid] = by_unit
	_active_focus[side] = by_side

func _end_active_focus_for_attacker(attacker_side: String, attacker_key: String, next_target_uid: String) -> void:
	var by_attacker: Dictionary = _attacker_active_targets.get(attacker_side, {})
	var current: Dictionary = by_attacker.get(attacker_key, {})
	if current.is_empty():
		return
	var current_uid: String = String(current.get("uid", ""))
	if current_uid == "" or current_uid == next_target_uid:
		return
	var target_side: String = String(current.get("target_side", ""))
	var index: int = _index_for_uid(target_side, current_uid)
	if index >= 0:
		_end_focus(target_side, index, attacker_key)

func _close_all_focus() -> void:
	for side in [SIDE_A, SIDE_B]:
		var by_side: Dictionary = _active_focus.get(side, {})
		var uids: Array = by_side.keys()
		for uid_value in uids:
			var uid: String = String(uid_value)
			var index: int = _index_for_uid(side, uid)
			if index < 0:
				continue
			var by_unit: Dictionary = by_side.get(uid, {})
			var attacker_keys: Array = by_unit.keys()
			for attacker_value in attacker_keys:
				_end_focus(side, index, String(attacker_value))
	_active_focus = {SIDE_A: {}, SIDE_B: {}}

func _set_active_target(attacker_side: String, attacker_key: String, target_side: String, target_uid: String) -> void:
	var by_attacker: Dictionary = _attacker_active_targets.get(attacker_side, {})
	by_attacker[attacker_key] = {
		"target_side": target_side,
		"uid": target_uid
	}
	_attacker_active_targets[attacker_side] = by_attacker

func _clear_active_target(attacker_side: String, attacker_key: String, target_side: String, target_index: int) -> void:
	var uid: String = _uid_for(target_side, target_index)
	var by_attacker: Dictionary = _attacker_active_targets.get(attacker_side, {})
	var current: Dictionary = by_attacker.get(attacker_key, {})
	if String(current.get("uid", "")) == uid:
		by_attacker.erase(attacker_key)
		_attacker_active_targets[attacker_side] = by_attacker

func _last_target_uid(attacker_side: String, attacker_key: String) -> String:
	var by_attacker: Dictionary = _attacker_last_targets.get(attacker_side, {})
	return String(by_attacker.get(attacker_key, ""))

func _set_last_target_uid(attacker_side: String, attacker_key: String, target_uid: String) -> void:
	var by_attacker: Dictionary = _attacker_last_targets.get(attacker_side, {})
	by_attacker[attacker_key] = target_uid
	_attacker_last_targets[attacker_side] = by_attacker

func _attacker_key(side: String, index: int) -> String:
	return "%s:%d" % [String(side), int(index)]

func _uid_for(side: String, index: int) -> String:
	var uid_map: Dictionary = _index_to_uid.get(side, {})
	return String(uid_map.get(int(index), ""))

func _index_for_uid(side: String, uid: String) -> int:
	var uid_map: Dictionary = _index_to_uid.get(side, {})
	for index_value in uid_map.keys():
		if String(uid_map.get(index_value, "")) == uid:
			return int(index_value)
	return -1

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

func _empty_side_counts() -> Dictionary:
	return {
		"redirect_events": 0,
		"redirected_damage_prevented": 0,
		"ally_damage_prevented": 0,
		"focus_start_events": 0,
		"target_swap_to_subject_events": 0,
		"enemy_focus_time_s": 0.0,
		"redirect_semantic_events": 0,
		"redirect_semantic_targets": 0,
		"redirect_semantic_duration_s": 0.0,
		"redirect_semantic_amount": 0.0,
		"redirect_semantic_risk_s": 0.0,
		"taunt_events": 0,
		"taunt_duration_s": 0.0,
		"body_block_events": 0,
		"body_block_duration_s": 0.0,
		"body_block_damage_prevented": 0.0,
		"explicit_threat_swap_events": 0,
		"redirect_end_risk_events": 0,
		"redirect_end_risk_s": 0.0,
		"target_keys": {},
		"kinds": {}
	}

func _empty_unit_counts() -> Dictionary:
	return {
		"redirect_events": 0,
		"redirected_damage_prevented": 0,
		"ally_damage_prevented": 0,
		"focus_start_events": 0,
		"target_swap_to_subject_events": 0,
		"enemy_focus_time_s": 0.0,
		"redirect_semantic_events": 0,
		"redirect_semantic_targets": 0,
		"redirect_semantic_duration_s": 0.0,
		"redirect_semantic_amount": 0.0,
		"redirect_semantic_risk_s": 0.0,
		"taunt_events": 0,
		"taunt_duration_s": 0.0,
		"body_block_events": 0,
		"body_block_duration_s": 0.0,
		"body_block_damage_prevented": 0.0,
		"explicit_threat_swap_events": 0,
		"redirect_end_risk_events": 0,
		"redirect_end_risk_s": 0.0,
		"target_keys": {},
		"source_attackers": {},
		"kinds": {}
	}
