extends RefCounted

# Cooldown Pressure Kernel
# Records committed enemy ability responses targeted at each subject. This gives
# direct evidence for doc metrics such as cooldowns forced, threat draw, and
# counter-cooldown trade.

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"
const KEY_COOLDOWN_S: float = 1.0

var _engine: Object = null
var _player_is_team_a: bool = true
var _id_map: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _per_unit: Dictionary = {SIDE_A: {}, SIDE_B: {}}
var _supported: bool = false

func attach(engine: Object, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_player_is_team_a = player_is_team_a
	_id_map = _extract_index_map(context_tags)
	_per_unit = {SIDE_A: {}, SIDE_B: {}}
	_supported = _connect()

func detach() -> void:
	if _engine != null and _engine.has_signal("ability_committed"):
		if _engine.is_connected("ability_committed", Callable(self, "_on_ability_committed")):
			_engine.ability_committed.disconnect(_on_ability_committed)
	_engine = null
	_supported = false

func tick(_delta_s: float) -> void:
	pass

func finalize(_total_time_s: float) -> void:
	pass

func result() -> Dictionary:
	return {
		"cooldown_pressure": {
			"supported": _supported,
			"key_cooldown_s": KEY_COOLDOWN_S,
			"per_unit": {
				SIDE_A: _per_unit.get(SIDE_A, {}),
				SIDE_B: _per_unit.get(SIDE_B, {})
			}
		}
	}

func register(_aggregator: Variant) -> RefCounted:
	return self

func _connect() -> bool:
	if _engine == null or not _engine.has_signal("ability_committed"):
		return false
	if not _engine.is_connected("ability_committed", Callable(self, "_on_ability_committed")):
		_engine.ability_committed.connect(_on_ability_committed)
	return true

func _on_ability_committed(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, _position: Vector2, cooldown_s: float, commitment_kind: String) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	var safe_cooldown_s: float = max(0.0, float(cooldown_s))
	var safe_ability_id: String = _safe_id(ability_id, "unknown")
	var safe_kind: String = _safe_id(commitment_kind, "ability")
	if source_side != "":
		_bump_unit(source_side, int(source_index), {
			"self_cooldowns_spent": 1,
			"self_cooldown_s": safe_cooldown_s
		})
		_bump_unit_map(source_side, int(source_index), "abilities_spent", safe_ability_id)
		_bump_unit_map(source_side, int(source_index), "commitment_kinds", safe_kind)
	if target_side != "" and source_side != "" and target_side != source_side:
		_bump_unit(target_side, int(target_index), {
			"cooldowns_forced": 1,
			"cooldowns_forced_s": safe_cooldown_s,
			"key_cooldowns_forced": (1 if safe_cooldown_s >= KEY_COOLDOWN_S else 0)
		})
		_bump_unit_map(target_side, int(target_index), "enemy_abilities_forced", safe_ability_id)
		_bump_unit_map(target_side, int(target_index), "enemy_commitment_kinds", safe_kind)
		_bump_unit_map(target_side, int(target_index), "enemy_casters", "%s:%d" % [source_side, int(source_index)])

func _empty_unit_counts() -> Dictionary:
	return {
		"cooldowns_forced": 0,
		"cooldowns_forced_s": 0.0,
		"key_cooldowns_forced": 0,
		"cooldown_threat_draw_events": 0,
		"cooldown_threat_draw_s": 0.0,
		"cooldown_threat_draw_casters": 0,
		"cooldown_threat_draw_abilities": 0,
		"cooldown_key_threat_share": 0.0,
		"cooldown_trade_efficiency": 0.0,
		"cooldown_trade_efficiency_denominator_s": 0.5,
		"self_cooldowns_spent": 0,
		"self_cooldown_s": 0.0,
		"enemy_abilities_forced": {},
		"enemy_commitment_kinds": {},
		"enemy_casters": {},
		"abilities_spent": {},
		"commitment_kinds": {}
	}

func _bump_unit(side: String, index: int, deltas: Dictionary) -> void:
	var uid: String = _uid_for(side, index)
	if uid == "":
		return
	var side_map: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = side_map.get(uid, _empty_unit_counts())
	for key_value in deltas.keys():
		var key: String = String(key_value)
		var delta_value: Variant = deltas.get(key_value)
		if typeof(rec.get(key, 0)) == TYPE_FLOAT or typeof(delta_value) == TYPE_FLOAT:
			rec[key] = float(rec.get(key, 0.0)) + float(delta_value)
		else:
			rec[key] = int(rec.get(key, 0)) + int(delta_value)
	_recompute_quality(rec)
	side_map[uid] = rec
	_per_unit[side] = side_map

func _bump_unit_map(side: String, index: int, field: String, key: String) -> void:
	var uid: String = _uid_for(side, index)
	if uid == "" or key == "":
		return
	var side_map: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = side_map.get(uid, _empty_unit_counts())
	var map_value: Dictionary = rec.get(field, {})
	map_value[key] = int(map_value.get(key, 0)) + 1
	rec[field] = map_value
	_recompute_quality(rec)
	side_map[uid] = rec
	_per_unit[side] = side_map

func _recompute_quality(rec: Dictionary) -> void:
	var forced_count: int = int(rec.get("cooldowns_forced", 0))
	var forced_s: float = float(rec.get("cooldowns_forced_s", 0.0))
	var key_forced: int = int(rec.get("key_cooldowns_forced", 0))
	var self_cooldown_s: float = float(rec.get("self_cooldown_s", 0.0))
	var caster_value: Variant = rec.get("enemy_casters", {})
	var ability_value: Variant = rec.get("enemy_abilities_forced", {})
	var casters: Dictionary = caster_value if (caster_value is Dictionary) else {}
	var abilities: Dictionary = ability_value if (ability_value is Dictionary) else {}
	var efficiency_denominator_s: float = max(0.5, self_cooldown_s)
	rec["cooldown_threat_draw_events"] = forced_count
	rec["cooldown_threat_draw_s"] = forced_s
	rec["cooldown_threat_draw_casters"] = casters.size()
	rec["cooldown_threat_draw_abilities"] = abilities.size()
	rec["cooldown_key_threat_share"] = float(key_forced) / max(1.0, float(forced_count))
	rec["cooldown_trade_efficiency_denominator_s"] = efficiency_denominator_s
	rec["cooldown_trade_efficiency"] = forced_s / efficiency_denominator_s if forced_s > 0.0 else 0.0

func _team_to_side(team_str: String) -> String:
	var team: String = String(team_str)
	if team == "":
		return ""
	if _player_is_team_a:
		return SIDE_A if team == TEAM_PLAYER else SIDE_B
	return SIDE_A if team == TEAM_ENEMY else SIDE_B

func _uid_for(side: String, index: int) -> String:
	if side == "":
		return ""
	var side_map: Dictionary = _id_map.get(side, {})
	return String(side_map.get(int(index), ""))

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

func _safe_id(value: String, fallback: String) -> String:
	var out: String = String(value).strip_edges().to_lower()
	if out == "":
		return String(fallback)
	return out
