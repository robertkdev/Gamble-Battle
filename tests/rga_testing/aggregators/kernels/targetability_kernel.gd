extends RefCounted

# Targetability Kernel
# Captures doc-level untargetable evidence: window duration/frame share,
# key-threat dodge rate, and cooldown trade gained by dodging threats.

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

var _engine = null
var _player_is_team_a: bool = true
var _time_s: float = 0.0
var _total_time_s: float = 0.0
var _id_map: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _windows: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _threats: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _connected: bool = false
var _window_supported: bool = false
var _threat_supported: bool = false

func attach(engine, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_player_is_team_a = player_is_team_a
	_time_s = 0.0
	_total_time_s = 0.0
	_id_map = _extract_index_map(context_tags)
	_windows = {SIDE_A: {}, SIDE_B: {}}
	_threats = {SIDE_A: {}, SIDE_B: {}}
	_window_supported = false
	_threat_supported = false
	_connected = _connect()

func detach() -> void:
	if _engine != null:
		if _engine.has_signal("targetability_window") and _engine.is_connected("targetability_window", Callable(self, "_on_targetability_window")):
			_engine.targetability_window.disconnect(_on_targetability_window)
		if _engine.has_signal("targetability_threat_interaction") and _engine.is_connected("targetability_threat_interaction", Callable(self, "_on_targetability_threat_interaction")):
			_engine.targetability_threat_interaction.disconnect(_on_targetability_threat_interaction)
	_engine = null
	_connected = false
	_window_supported = false
	_threat_supported = false

func tick(delta_s: float) -> void:
	_time_s += max(0.0, float(delta_s))

func finalize(total_time_s: float) -> void:
	_total_time_s = max(_time_s, float(total_time_s))

func result() -> Dictionary:
	return {
		"targetability": {
			"supported": _window_supported or _threat_supported,
			"window_supported": _window_supported,
			"threat_interaction_supported": _threat_supported,
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
	if _engine.has_signal("targetability_window"):
		_engine.targetability_window.connect(_on_targetability_window)
		_window_supported = true
	if _engine.has_signal("targetability_threat_interaction"):
		_engine.targetability_threat_interaction.connect(_on_targetability_threat_interaction)
		_threat_supported = true
	return true

func _on_targetability_window(team: String, index: int, is_targetable: bool, duration: float, reason: String) -> void:
	var side: String = _source_side(team)
	if side == "":
		return
	var uid: String = _uid_for(side, index)
	if uid == "":
		return
	var rec: Dictionary = {
		"t": _time_s,
		"is_targetable": bool(is_targetable),
		"duration": max(0.0, float(duration)),
		"reason": String(reason)
	}
	_windows_for(side, uid).append(rec)

func _on_targetability_threat_interaction(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, cooldown_s: float, key_threat: bool, dodged: bool) -> void:
	var target_side: String = _source_side(target_team)
	if target_side == "":
		return
	var target_uid: String = _uid_for(target_side, target_index)
	if target_uid == "":
		return
	var source_side: String = _source_side(source_team)
	var source_uid: String = _uid_for(source_side, source_index) if source_side != "" else ""
	var rec: Dictionary = {
		"t": _time_s,
		"source": source_uid,
		"kind": String(kind),
		"cooldown_s": max(0.0, float(cooldown_s)),
		"key_threat": bool(key_threat),
		"dodged": bool(dodged)
	}
	_threats_for(target_side, target_uid).append(rec)

func _summarize_side(side: String) -> Dictionary:
	var out: Dictionary = {}
	var uids: Dictionary = {}
	for window_uid in (_windows.get(side, {}) as Dictionary).keys():
		uids[String(window_uid)] = true
	for threat_uid in (_threats.get(side, {}) as Dictionary).keys():
		uids[String(threat_uid)] = true
	for uid_key in uids.keys():
		var uid: String = String(uid_key)
		out[uid] = _summarize_unit(side, uid)
	return out

func _summarize_unit(side: String, uid: String) -> Dictionary:
	var window_list: Array = (_windows.get(side, {}) as Dictionary).get(uid, [])
	var threat_list: Array = (_threats.get(side, {}) as Dictionary).get(uid, [])
	var untargetable_time: float = 0.0
	var untargetable_windows: int = 0
	var reasons: Dictionary = {}
	for window_value in window_list:
		if not (window_value is Dictionary):
			continue
		var window: Dictionary = window_value
		if bool(window.get("is_targetable", true)):
			continue
		untargetable_windows += 1
		untargetable_time += max(0.0, float(window.get("duration", 0.0)))
		var reason: String = String(window.get("reason", ""))
		if reason != "":
			reasons[reason] = true
	var key_threats_faced: int = 0
	var key_threats_dodged: int = 0
	var threats_faced: int = 0
	var threats_dodged: int = 0
	var cooldown_trade_s: float = 0.0
	for threat_value in threat_list:
		if not (threat_value is Dictionary):
			continue
		var threat: Dictionary = threat_value
		threats_faced += 1
		var is_key: bool = bool(threat.get("key_threat", false))
		var was_dodged: bool = bool(threat.get("dodged", false))
		if is_key:
			key_threats_faced += 1
		if was_dodged:
			threats_dodged += 1
			cooldown_trade_s += max(0.0, float(threat.get("cooldown_s", 0.0)))
			if is_key:
				key_threats_dodged += 1
	var key_dodge_rate: float = 0.0
	if key_threats_faced > 0:
		key_dodge_rate = float(key_threats_dodged) / max(1.0, float(key_threats_faced))
	var threat_dodge_rate: float = 0.0
	if threats_faced > 0:
		threat_dodge_rate = float(threats_dodged) / max(1.0, float(threats_faced))
	var frames_pct: float = untargetable_time / max(0.001, _total_time_s)
	return {
		"untargetable_windows": untargetable_windows,
		"untargetable_time_s": untargetable_time,
		"untargetable_frames_pct": frames_pct,
		"threats_faced": threats_faced,
		"threats_dodged": threats_dodged,
		"threat_dodge_rate": threat_dodge_rate,
		"key_threats_faced": key_threats_faced,
		"key_threats_dodged": key_threats_dodged,
		"key_threat_dodge_rate": key_dodge_rate,
		"cooldown_trade_s": cooldown_trade_s,
		"reasons": reasons.keys()
	}

func _windows_for(side: String, uid: String) -> Array:
	var by_side: Dictionary = _windows.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = []
		_windows[side] = by_side
	return by_side[uid]

func _threats_for(side: String, uid: String) -> Array:
	var by_side: Dictionary = _threats.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = []
		_threats[side] = by_side
	return by_side[uid]

func _uid_for(side: String, index: int) -> String:
	var by_side: Dictionary = _id_map.get(side, {})
	var uid: String = String(by_side.get(int(index), ""))
	if uid == "":
		uid = "%s_%d" % [side, int(index)]
	return uid

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

func _extract_index_map(context_tags: Dictionary) -> Dictionary:
	var out: Dictionary = {SIDE_A: {}, SIDE_B: {}}
	if not (context_tags is Dictionary):
		return out
	var timelines: Dictionary = context_tags.get("unit_timelines", {})
	if not (timelines is Dictionary):
		return out
	for side in [SIDE_A, SIDE_B]:
		var entries: Array = timelines.get(side, [])
		if not (entries is Array):
			continue
		var side_map: Dictionary = {}
		for entry in entries:
			if not (entry is Dictionary):
				continue
			var idx: int = int((entry as Dictionary).get("unit_index", -1))
			if idx < 0:
				continue
			var uid: String = String((entry as Dictionary).get("unit_id", ""))
			if uid != "":
				side_map[idx] = uid
		out[side] = side_map
	return out
