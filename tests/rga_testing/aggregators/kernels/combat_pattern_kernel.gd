extends RefCounted

# Combat Pattern Kernel
# Emits per-unit combat-pattern KPIs for doc-level approaches:
# burst, execute, aoe, ramp, and windowed sustained throughput.

const BattleState := preload("res://scripts/game/combat/battle_state.gd")

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"
const BURST_WINDOW_S: float = 1.0
const EARLY_WINDOW_END_S: float = 3.0
const SUSTAINED_WINDOW_END_S: float = 10.0
const TIME_BUCKETS_PER_SECOND: float = 20.0

var _engine: Variant = null
var _state: BattleState = null
var _player_is_team_a: bool = true
var _time_s: float = 0.0
var _total_time_s: float = 0.0
var _id_map: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _hits: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _groups: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _overkill: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _kills: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _resets: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _execute_bonus: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _ramp_state: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _first_cast_s: Dictionary = { SIDE_A: {}, SIDE_B: {} }
var _connected: bool = false
var _reset_supported: bool = false
var _execute_bonus_supported: bool = false
var _ramp_state_supported: bool = false

func attach(engine, _team_sizes: Dictionary = {}, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_state = null
	if engine != null and engine.has_method("get"):
		var maybe_state: Variant = engine.get("state")
		if maybe_state is BattleState:
			_state = maybe_state
	_player_is_team_a = player_is_team_a
	_time_s = 0.0
	_total_time_s = 0.0
	_id_map = _extract_index_map(context_tags)
	_hits = { SIDE_A: {}, SIDE_B: {} }
	_groups = { SIDE_A: {}, SIDE_B: {} }
	_overkill = { SIDE_A: {}, SIDE_B: {} }
	_kills = { SIDE_A: {}, SIDE_B: {} }
	_resets = { SIDE_A: {}, SIDE_B: {} }
	_execute_bonus = { SIDE_A: {}, SIDE_B: {} }
	_ramp_state = { SIDE_A: {}, SIDE_B: {} }
	_first_cast_s = { SIDE_A: {}, SIDE_B: {} }
	_reset_supported = false
	_execute_bonus_supported = false
	_ramp_state_supported = false
	_connected = _connect()

func detach() -> void:
	if _engine != null:
		if _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
			_engine.hit_applied.disconnect(_on_hit_applied)
		if _engine.has_signal("hit_overkill") and _engine.is_connected("hit_overkill", Callable(self, "_on_hit_overkill")):
			_engine.hit_overkill.disconnect(_on_hit_overkill)
		if _engine.has_signal("ability_cast") and _engine.is_connected("ability_cast", Callable(self, "_on_ability_cast")):
			_engine.ability_cast.disconnect(_on_ability_cast)
		if _engine.has_signal("reset_triggered") and _engine.is_connected("reset_triggered", Callable(self, "_on_reset_triggered")):
			_engine.reset_triggered.disconnect(_on_reset_triggered)
		if _engine.has_signal("execute_bonus_applied") and _engine.is_connected("execute_bonus_applied", Callable(self, "_on_execute_bonus_applied")):
			_engine.execute_bonus_applied.disconnect(_on_execute_bonus_applied)
		if _engine.has_signal("ramp_state_changed") and _engine.is_connected("ramp_state_changed", Callable(self, "_on_ramp_state_changed")):
			_engine.ramp_state_changed.disconnect(_on_ramp_state_changed)
	_engine = null
	_state = null
	_connected = false
	_reset_supported = false
	_execute_bonus_supported = false
	_ramp_state_supported = false

func tick(delta_s: float) -> void:
	_time_s += max(0.0, float(delta_s))

func finalize(total_time_s: float) -> void:
	_total_time_s = max(_time_s, float(total_time_s))

func result() -> Dictionary:
	return {
		"combat_patterns": {
			"supported": true,
			"reset_supported": _reset_supported,
			"execute_bonus_supported": _execute_bonus_supported,
			"ramp_state_supported": _ramp_state_supported,
			"window_s": BURST_WINDOW_S,
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
	if _engine.has_signal("hit_applied"):
		_engine.hit_applied.connect(_on_hit_applied)
	if _engine.has_signal("hit_overkill"):
		_engine.hit_overkill.connect(_on_hit_overkill)
	if _engine.has_signal("ability_cast"):
		_engine.ability_cast.connect(_on_ability_cast)
	if _engine.has_signal("reset_triggered"):
		_engine.reset_triggered.connect(_on_reset_triggered)
		_reset_supported = true
	if _engine.has_signal("execute_bonus_applied"):
		_engine.execute_bonus_applied.connect(_on_execute_bonus_applied)
		_execute_bonus_supported = true
	if _engine.has_signal("ramp_state_changed"):
		_engine.ramp_state_changed.connect(_on_ramp_state_changed)
		_ramp_state_supported = true
	return true

func _on_hit_applied(team: String, source_index: int, target_index: int, _rolled: int, dealt: int, _crit: bool, before_hp: int, after_hp: int, _player_cd: float, _enemy_cd: float) -> void:
	var source_side: String = _source_side(team)
	var target_side: String = _opponent_side(source_side)
	if source_side == "" or target_side == "":
		return
	var source_uid: String = _uid_for(source_side, source_index)
	if source_uid == "":
		return
	var damage: int = max(0, int(dealt))
	var target_uid: String = _uid_for(target_side, target_index)
	if target_uid == "":
		target_uid = "%s_%d" % [target_side, int(target_index)]
	var target_max_hp: int = _target_max_hp(target_side, target_index)
	var before_pct: float = float(before_hp) / max(1.0, float(target_max_hp))
	var rec: Dictionary = {
		"t": _time_s,
		"damage": damage,
		"target": target_uid,
		"before_hp_pct": before_pct,
		"after_hp": int(after_hp)
	}
	_hits_for(source_side, source_uid).append(rec)
	_record_group(source_side, source_uid, target_uid, damage)
	if int(after_hp) <= 0:
		var kill_rec: Dictionary = {
			"t": _time_s,
			"target": target_uid,
			"before_hp_pct": before_pct
		}
		_kills_for(source_side, source_uid).append(kill_rec)

func _on_hit_overkill(source_team: String, source_index: int, _target_team: String, _target_index: int, overkill: int) -> void:
	var source_side: String = _source_side(source_team)
	if source_side == "":
		return
	var source_uid: String = _uid_for(source_side, source_index)
	if source_uid == "":
		return
	var by_side: Dictionary = _overkill.get(source_side, {})
	by_side[source_uid] = float(by_side.get(source_uid, 0.0)) + max(0.0, float(overkill))
	_overkill[source_side] = by_side

func _on_ability_cast(source_team: String, source_index: int, _target_team: String, _target_index: int, _position: Vector2) -> void:
	var source_side: String = _source_side(source_team)
	if source_side == "":
		return
	var source_uid: String = _uid_for(source_side, source_index)
	if source_uid == "":
		return
	var by_side: Dictionary = _first_cast_s.get(source_side, {})
	if not by_side.has(source_uid):
		by_side[source_uid] = _time_s
	_first_cast_s[source_side] = by_side

func _on_reset_triggered(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, chain_index: int, time_since_previous_s: float, power_scale: float) -> void:
	var source_side: String = _source_side(source_team)
	var target_side: String = _source_side(target_team)
	if source_side == "":
		return
	var source_uid: String = _uid_for(source_side, source_index)
	if source_uid == "":
		return
	var target_uid: String = _uid_for(target_side, target_index) if target_side != "" else ""
	if target_uid == "":
		target_uid = "%s_%d" % [String(target_team), int(target_index)]
	var rec: Dictionary = {
		"t": _time_s,
		"target": target_uid,
		"kind": String(kind),
		"chain_index": max(0, int(chain_index)),
		"time_since_previous_s": max(0.0, float(time_since_previous_s)),
		"power_scale": max(0.0, float(power_scale))
	}
	_resets_for(source_side, source_uid).append(rec)

func _on_execute_bonus_applied(source_team: String, source_index: int, target_team: String, target_index: int, base_damage: int, bonus_damage: int, threshold_pct: float, target_hp_pct: float, kind: String) -> void:
	var source_side: String = _source_side(source_team)
	var target_side: String = _source_side(target_team)
	if source_side == "":
		return
	if target_side == "":
		target_side = _opponent_side(source_side)
	var source_uid: String = _uid_for(source_side, source_index)
	if source_uid == "":
		return
	var target_uid: String = _uid_for(target_side, target_index) if target_side != "" else ""
	if target_uid == "":
		target_uid = "%s_%d" % [String(target_team), int(target_index)]
	var threshold: float = clamp(float(threshold_pct), 0.0, 1.0)
	var target_pct: float = clamp(float(target_hp_pct), 0.0, 1.0)
	var rec: Dictionary = {
		"t": _time_s,
		"target": target_uid,
		"base_damage": max(0, int(base_damage)),
		"bonus_damage": max(0, int(bonus_damage)),
		"threshold_pct": threshold,
		"target_hp_pct": target_pct,
		"kind": String(kind),
		"outside_threshold": target_pct > threshold + 0.001
	}
	_execute_bonus_for(source_side, source_uid).append(rec)

func _on_ramp_state_changed(source_team: String, source_index: int, kind: String, stacks: int, value: float, peak_stacks: int, duration_s: float, reason: String) -> void:
	var source_side: String = _source_side(source_team)
	if source_side == "":
		return
	var source_uid: String = _uid_for(source_side, source_index)
	if source_uid == "":
		return
	var rec: Dictionary = {
		"t": _time_s,
		"kind": String(kind),
		"stacks": max(0, int(stacks)),
		"value": max(0.0, float(value)),
		"peak_stacks": max(0, int(peak_stacks)),
		"duration_s": max(0.0, float(duration_s)),
		"reason": String(reason)
	}
	_ramp_state_for(source_side, source_uid).append(rec)

func _summarize_side(side: String) -> Dictionary:
	var out: Dictionary = {}
	var uids: Dictionary = {}
	for hit_uid in (_hits.get(side, {}) as Dictionary).keys():
		uids[String(hit_uid)] = true
	for reset_uid in (_resets.get(side, {}) as Dictionary).keys():
		uids[String(reset_uid)] = true
	for execute_uid in (_execute_bonus.get(side, {}) as Dictionary).keys():
		uids[String(execute_uid)] = true
	for ramp_uid in (_ramp_state.get(side, {}) as Dictionary).keys():
		uids[String(ramp_uid)] = true
	var early_side_damage: float = 0.0
	var sustained_side_damage: float = 0.0
	for uid_key in uids.keys():
		var uid: String = String(uid_key)
		var hit_list: Array = (_hits.get(side, {}) as Dictionary).get(uid, [])
		var unit_summary: Dictionary = _summarize_unit(side, uid, hit_list)
		early_side_damage += float(unit_summary.get("early_0_3s_damage", 0.0))
		sustained_side_damage += float(unit_summary.get("sustained_3_10s_damage", 0.0))
		out[uid] = unit_summary
	for summary_uid in out.keys():
		var summary: Dictionary = out.get(summary_uid, {})
		summary["early_0_3s_team_share"] = float(summary.get("early_0_3s_damage", 0.0)) / max(1.0, early_side_damage)
		summary["sustained_3_10s_team_share"] = float(summary.get("sustained_3_10s_damage", 0.0)) / max(1.0, sustained_side_damage)
		out[summary_uid] = summary
	return out

func _summarize_unit(side: String, uid: String, hit_list: Array) -> Dictionary:
	var total_damage: float = 0.0
	for hit in hit_list:
		if hit is Dictionary:
			total_damage += float((hit as Dictionary).get("damage", 0.0))
	var burst: Dictionary = _burst_summary(hit_list, total_damage)
	var group_summary: Dictionary = _group_summary(side, uid)
	var kill_summary: Dictionary = _kill_summary(side, uid)
	var overkill_damage: float = float((_overkill.get(side, {}) as Dictionary).get(uid, 0.0))
	var first_cast: float = float((_first_cast_s.get(side, {}) as Dictionary).get(uid, -1.0))
	var peak_start: float = float(burst.get("peak_start_s", -1.0))
	var counterplay_ms: float = -1.0
	if first_cast >= 0.0 and peak_start >= first_cast:
		counterplay_ms = (peak_start - first_cast) * 1000.0
	var ramp: Dictionary = _ramp_summary(hit_list, burst)
	var sustained: Dictionary = _sustained_window_summary(hit_list, total_damage)
	var ramp_state: Dictionary = _ramp_state_summary(side, uid)
	var resets: Dictionary = _reset_summary(side, uid, hit_list)
	var execute_bonus: Dictionary = _execute_bonus_summary(side, uid, total_damage)
	return {
		"total_damage": total_damage,
		"hit_count": hit_list.size(),
		"peak_1s_damage": float(burst.get("peak_damage", 0.0)),
		"peak_1s_damage_share": float(burst.get("peak_share", 0.0)),
		"peak_1s_dps": float(burst.get("peak_dps", 0.0)),
		"peak_start_s": peak_start,
		"counterplay_window_ms": counterplay_ms,
		"overkill_damage": overkill_damage,
		"overkill_rate": overkill_damage / max(1.0, total_damage + overkill_damage),
		"kill_count": int(kill_summary.get("kill_count", 0)),
		"low_hp_kill_count": int(kill_summary.get("low_hp_kill_count", 0)),
		"low_hp_kill_share": float(kill_summary.get("low_hp_kill_share", 0.0)),
		"execute_bonus_events": int(execute_bonus.get("execute_bonus_events", 0)),
		"execute_bonus_damage": float(execute_bonus.get("execute_bonus_damage", 0.0)),
		"execute_base_damage": float(execute_bonus.get("execute_base_damage", 0.0)),
		"execute_bonus_damage_share": float(execute_bonus.get("execute_bonus_damage_share", 0.0)),
		"execute_bonus_fight_damage_share": float(execute_bonus.get("execute_bonus_fight_damage_share", 0.0)),
		"execute_bonus_targets": int(execute_bonus.get("execute_bonus_targets", 0)),
		"execute_bonus_outside_threshold_events": int(execute_bonus.get("execute_bonus_outside_threshold_events", 0)),
		"execute_bonus_target_hp_pct_avg": float(execute_bonus.get("execute_bonus_target_hp_pct_avg", 0.0)),
		"execute_bonus_threshold_pct_max": float(execute_bonus.get("execute_bonus_threshold_pct_max", 0.0)),
		"targets_hit_median": float(group_summary.get("targets_hit_median", 0.0)),
		"max_targets_hit": int(group_summary.get("max_targets_hit", 0)),
		"multi_target_groups": int(group_summary.get("multi_target_groups", 0)),
		"aoe_damage": float(group_summary.get("aoe_damage", 0.0)),
		"aoe_dps": float(group_summary.get("aoe_damage", 0.0)) / max(1.0, _total_time_s),
		"aoe_hit_group_share": float(group_summary.get("aoe_hit_group_share", 0.0)),
		"time_to_peak_s": float(ramp.get("time_to_peak_s", 0.0)),
		"late_early_dps_ratio": float(ramp.get("late_early_dps_ratio", 0.0)),
		"falloff_after_peak": float(ramp.get("falloff_after_peak", 0.0)),
		"early_damage": float(ramp.get("early_damage", 0.0)),
		"late_damage": float(ramp.get("late_damage", 0.0)),
		"early_0_3s_damage": float(sustained.get("early_0_3s_damage", 0.0)),
		"early_0_3s_share": float(sustained.get("early_0_3s_share", 0.0)),
		"sustained_3_10s_damage": float(sustained.get("sustained_3_10s_damage", 0.0)),
		"sustained_3_10s_share": float(sustained.get("sustained_3_10s_share", 0.0)),
		"sustained_3_10s_rate": float(sustained.get("sustained_3_10s_rate", 0.0)),
		"sustained_3_10s_window_s": float(sustained.get("sustained_3_10s_window_s", 0.0)),
		"ramp_state_supported": _ramp_state_supported,
		"ramp_state_events": int(ramp_state.get("ramp_state_events", 0)),
		"ramp_stack_max": int(ramp_state.get("ramp_stack_max", 0)),
		"ramp_time_to_peak_s": float(ramp_state.get("ramp_time_to_peak_s", 0.0)),
		"ramp_peak_duration_s": float(ramp_state.get("ramp_peak_duration_s", 0.0)),
		"ramp_window_duration_s": float(ramp_state.get("ramp_window_duration_s", 0.0)),
		"ramp_value_peak": float(ramp_state.get("ramp_value_peak", 0.0)),
		"ramp_peak_reached": bool(ramp_state.get("ramp_peak_reached", false)),
		"ramp_window_events": int(ramp_state.get("ramp_window_events", 0)),
		"reset_events": int(resets.get("reset_events", 0)),
		"reset_chain_length": int(resets.get("reset_chain_length", 0)),
		"reset_time_between_min_s": float(resets.get("reset_time_between_min_s", 0.0)),
		"reset_time_between_avg_s": float(resets.get("reset_time_between_avg_s", 0.0)),
		"reset_first_s": float(resets.get("reset_first_s", -1.0)),
		"reset_power_scale_avg": float(resets.get("reset_power_scale_avg", 0.0)),
		"reset_targets": int(resets.get("reset_targets", 0)),
		"reset_post_first_damage": float(resets.get("reset_post_first_damage", 0.0)),
		"reset_post_first_damage_share": float(resets.get("reset_post_first_damage_share", 0.0)),
		"reset_post_first_kills": int(resets.get("reset_post_first_kills", 0)),
		"reset_post_first_targets": int(resets.get("reset_post_first_targets", 0)),
		"reset_first_followup_s": float(resets.get("reset_first_followup_s", -1.0))
	}

func _burst_summary(hit_list: Array, total_damage: float) -> Dictionary:
	if hit_list.is_empty():
		return {"peak_damage": 0.0, "peak_share": 0.0, "peak_dps": 0.0, "peak_start_s": -1.0}
	var max_sum: float = 0.0
	var peak_start: float = -1.0
	var current_sum: float = 0.0
	var j: int = 0
	for i in range(hit_list.size()):
		var start_t: float = float((hit_list[i] as Dictionary).get("t", 0.0))
		while j < hit_list.size() and float((hit_list[j] as Dictionary).get("t", 0.0)) - start_t <= BURST_WINDOW_S:
			current_sum += float((hit_list[j] as Dictionary).get("damage", 0.0))
			j += 1
		if current_sum > max_sum:
			max_sum = current_sum
			peak_start = start_t
		current_sum -= float((hit_list[i] as Dictionary).get("damage", 0.0))
	return {
		"peak_damage": max_sum,
		"peak_share": max_sum / max(1.0, total_damage),
		"peak_dps": max_sum / BURST_WINDOW_S,
		"peak_start_s": peak_start
	}

func _ramp_summary(hit_list: Array, burst: Dictionary) -> Dictionary:
	var total_time: float = max(1.0, _total_time_s)
	var third: float = total_time / 3.0
	var early_damage: float = 0.0
	var late_damage: float = 0.0
	var peak_start: float = float(burst.get("peak_start_s", -1.0))
	var peak_dps: float = float(burst.get("peak_dps", 0.0))
	var post_peak_damage: float = 0.0
	for hit in hit_list:
		if not (hit is Dictionary):
			continue
		var t: float = float((hit as Dictionary).get("t", 0.0))
		var damage: float = float((hit as Dictionary).get("damage", 0.0))
		if t <= third:
			early_damage += damage
		if t >= third * 2.0:
			late_damage += damage
		if peak_start >= 0.0 and t > peak_start + BURST_WINDOW_S:
			post_peak_damage += damage
	var early_dps: float = early_damage / max(0.001, third)
	var late_dps: float = late_damage / max(0.001, third)
	var late_early_ratio: float = 0.0
	if early_dps <= 0.001:
		late_early_ratio = 99.0 if late_dps > 0.0 else 0.0
	else:
		late_early_ratio = late_dps / early_dps
	var post_window: float = max(0.001, total_time - max(0.0, peak_start + BURST_WINDOW_S))
	var post_peak_dps: float = post_peak_damage / post_window
	var falloff_after_peak: float = post_peak_dps / max(0.001, peak_dps)
	return {
		"time_to_peak_s": max(0.0, peak_start),
		"late_early_dps_ratio": late_early_ratio,
		"falloff_after_peak": falloff_after_peak,
		"early_damage": early_damage,
		"late_damage": late_damage
	}

func _sustained_window_summary(hit_list: Array, total_damage: float) -> Dictionary:
	var early_damage: float = 0.0
	var sustained_damage: float = 0.0
	var sustained_window_end: float = min(SUSTAINED_WINDOW_END_S, max(0.0, _total_time_s))
	var sustained_window_s: float = max(0.0, sustained_window_end - EARLY_WINDOW_END_S)
	for hit in hit_list:
		if not (hit is Dictionary):
			continue
		var rec: Dictionary = hit
		var t: float = float(rec.get("t", 0.0))
		var damage: float = max(0.0, float(rec.get("damage", 0.0)))
		if t < EARLY_WINDOW_END_S:
			early_damage += damage
		elif t <= sustained_window_end:
			sustained_damage += damage
	return {
		"early_0_3s_damage": early_damage,
		"early_0_3s_share": early_damage / max(1.0, total_damage),
		"sustained_3_10s_damage": sustained_damage,
		"sustained_3_10s_share": sustained_damage / max(1.0, total_damage),
		"sustained_3_10s_rate": sustained_damage / max(0.001, sustained_window_s),
		"sustained_3_10s_window_s": sustained_window_s
	}

func _group_summary(side: String, uid: String) -> Dictionary:
	var side_groups: Dictionary = _groups.get(side, {})
	var uid_groups: Dictionary = side_groups.get(uid, {})
	var counts: Array[float] = []
	var max_targets: int = 0
	var multi_groups: int = 0
	var aoe_damage: float = 0.0
	for group_key in uid_groups.keys():
		var group: Dictionary = uid_groups.get(group_key, {})
		var targets: Dictionary = group.get("targets", {})
		var count: int = targets.size() if targets is Dictionary else 0
		counts.append(float(count))
		max_targets = max(max_targets, count)
		if count >= 2:
			multi_groups += 1
			aoe_damage += float(group.get("damage", 0.0))
	var group_count: int = uid_groups.size()
	return {
		"targets_hit_median": _median(counts),
		"max_targets_hit": max_targets,
		"multi_target_groups": multi_groups,
		"aoe_damage": aoe_damage,
		"aoe_hit_group_share": float(multi_groups) / max(1.0, float(group_count))
	}

func _kill_summary(side: String, uid: String) -> Dictionary:
	var kill_list: Array = (_kills.get(side, {}) as Dictionary).get(uid, [])
	var low_hp: int = 0
	for kill in kill_list:
		if kill is Dictionary and float((kill as Dictionary).get("before_hp_pct", 1.0)) <= 0.30:
			low_hp += 1
	var kills_total: int = kill_list.size()
	return {
		"kill_count": kills_total,
		"low_hp_kill_count": low_hp,
		"low_hp_kill_share": float(low_hp) / max(1.0, float(kills_total))
	}

func _execute_bonus_summary(side: String, uid: String, total_damage: float) -> Dictionary:
	var execute_list: Array = (_execute_bonus.get(side, {}) as Dictionary).get(uid, [])
	if execute_list.is_empty():
		return {
			"execute_bonus_events": 0,
			"execute_bonus_damage": 0.0,
			"execute_base_damage": 0.0,
			"execute_bonus_damage_share": 0.0,
			"execute_bonus_fight_damage_share": 0.0,
			"execute_bonus_targets": 0,
			"execute_bonus_outside_threshold_events": 0,
			"execute_bonus_target_hp_pct_avg": 0.0,
			"execute_bonus_threshold_pct_max": 0.0
		}
	var total_base: float = 0.0
	var total_bonus: float = 0.0
	var target_pct_sum: float = 0.0
	var threshold_max: float = 0.0
	var outside_threshold: int = 0
	var targets: Dictionary = {}
	for execute_value in execute_list:
		if not (execute_value is Dictionary):
			continue
		var rec: Dictionary = execute_value
		var base_damage: float = max(0.0, float(rec.get("base_damage", 0.0)))
		var bonus_damage: float = max(0.0, float(rec.get("bonus_damage", 0.0)))
		total_base += base_damage
		total_bonus += bonus_damage
		target_pct_sum += clamp(float(rec.get("target_hp_pct", 0.0)), 0.0, 1.0)
		threshold_max = max(threshold_max, clamp(float(rec.get("threshold_pct", 0.0)), 0.0, 1.0))
		if bool(rec.get("outside_threshold", false)):
			outside_threshold += 1
		var target_uid: String = String(rec.get("target", ""))
		if target_uid != "":
			targets[target_uid] = true
	var event_count: int = execute_list.size()
	var execute_window_damage: float = total_base + total_bonus
	return {
		"execute_bonus_events": event_count,
		"execute_bonus_damage": total_bonus,
		"execute_base_damage": total_base,
		"execute_bonus_damage_share": total_bonus / max(1.0, execute_window_damage),
		"execute_bonus_fight_damage_share": total_bonus / max(1.0, float(total_damage)),
		"execute_bonus_targets": targets.size(),
		"execute_bonus_outside_threshold_events": outside_threshold,
		"execute_bonus_target_hp_pct_avg": target_pct_sum / max(1.0, float(event_count)),
		"execute_bonus_threshold_pct_max": threshold_max
	}

func _ramp_state_summary(side: String, uid: String) -> Dictionary:
	var ramp_list: Array = (_ramp_state.get(side, {}) as Dictionary).get(uid, [])
	if ramp_list.is_empty():
		return {
			"ramp_state_events": 0,
			"ramp_stack_max": 0,
			"ramp_time_to_peak_s": 0.0,
			"ramp_peak_duration_s": 0.0,
			"ramp_window_duration_s": 0.0,
			"ramp_value_peak": 0.0,
			"ramp_peak_reached": false,
			"ramp_window_events": 0
		}
	var max_stacks: int = 0
	var peak_duration: float = 0.0
	var window_duration: float = 0.0
	var value_peak: float = 0.0
	var time_to_peak: float = 0.0
	var has_time_to_peak: bool = false
	var peak_reached: bool = false
	var window_events: int = 0
	for ramp_value in ramp_list:
		if not (ramp_value is Dictionary):
			continue
		var rec: Dictionary = ramp_value
		var stacks: int = max(0, int(rec.get("stacks", 0)))
		var value: float = max(0.0, float(rec.get("value", 0.0)))
		var duration_s: float = max(0.0, float(rec.get("duration_s", 0.0)))
		var peak_stacks: int = max(0, int(rec.get("peak_stacks", 0)))
		var at_peak: bool = peak_stacks > 0 and stacks >= peak_stacks
		var is_window: bool = duration_s > 0.0 or String(rec.get("kind", "")).find("window") >= 0
		if stacks > max_stacks or value > value_peak:
			time_to_peak = max(0.0, float(rec.get("t", 0.0)))
			has_time_to_peak = true
		max_stacks = max(max_stacks, stacks)
		value_peak = max(value_peak, value)
		if is_window:
			window_events += 1
			window_duration = max(window_duration, duration_s)
		if at_peak:
			peak_reached = true
			peak_duration = max(peak_duration, duration_s)
			if not has_time_to_peak:
				time_to_peak = max(0.0, float(rec.get("t", 0.0)))
				has_time_to_peak = true
	if not peak_reached:
		peak_duration = window_duration
	return {
		"ramp_state_events": ramp_list.size(),
		"ramp_stack_max": max_stacks,
		"ramp_time_to_peak_s": time_to_peak if has_time_to_peak else 0.0,
		"ramp_peak_duration_s": peak_duration,
		"ramp_window_duration_s": window_duration,
		"ramp_value_peak": value_peak,
		"ramp_peak_reached": peak_reached,
		"ramp_window_events": window_events
	}

func _reset_summary(side: String, uid: String, hit_list: Array) -> Dictionary:
	var reset_list: Array = (_resets.get(side, {}) as Dictionary).get(uid, [])
	if reset_list.is_empty():
		return {
			"reset_events": 0,
			"reset_chain_length": 0,
			"reset_time_between_min_s": 0.0,
			"reset_time_between_avg_s": 0.0,
			"reset_first_s": -1.0,
			"reset_power_scale_avg": 0.0,
			"reset_targets": 0,
			"reset_post_first_damage": 0.0,
			"reset_post_first_damage_share": 0.0,
			"reset_post_first_kills": 0,
			"reset_post_first_targets": 0,
			"reset_first_followup_s": -1.0
		}
	var targets: Dictionary = {}
	var intervals: Array[float] = []
	var first_s: float = INF
	var previous_s: float = -1.0
	var max_chain_length: int = 1
	var power_sum: float = 0.0
	for reset in reset_list:
		if not (reset is Dictionary):
			continue
		var rec: Dictionary = reset
		var reset_t: float = float(rec.get("t", 0.0))
		first_s = min(first_s, reset_t)
		var chain_index: int = max(0, int(rec.get("chain_index", 0)))
		if chain_index > 0:
			max_chain_length = max(max_chain_length, chain_index + 1)
		var provided_interval: float = float(rec.get("time_since_previous_s", 0.0))
		if provided_interval > 0.0:
			intervals.append(provided_interval)
		elif previous_s >= 0.0 and reset_t >= previous_s:
			intervals.append(reset_t - previous_s)
		previous_s = reset_t
		var target_uid: String = String(rec.get("target", ""))
		if target_uid != "":
			targets[target_uid] = true
		power_sum += max(0.0, float(rec.get("power_scale", 0.0)))
	var event_count: int = reset_list.size()
	if max_chain_length <= 1 and event_count > 0:
		max_chain_length = event_count + 1
	var post_first: Dictionary = _post_first_reset_summary(side, uid, hit_list, first_s)
	return {
		"reset_events": event_count,
		"reset_chain_length": max_chain_length,
		"reset_time_between_min_s": _min_float(intervals),
		"reset_time_between_avg_s": _mean_float(intervals),
		"reset_first_s": first_s if first_s < INF else -1.0,
		"reset_power_scale_avg": power_sum / max(1.0, float(event_count)),
		"reset_targets": targets.size(),
		"reset_post_first_damage": float(post_first.get("damage", 0.0)),
		"reset_post_first_damage_share": float(post_first.get("damage_share", 0.0)),
		"reset_post_first_kills": int(post_first.get("kills", 0)),
		"reset_post_first_targets": int(post_first.get("targets", 0)),
		"reset_first_followup_s": float(post_first.get("followup_s", -1.0))
	}

func _post_first_reset_summary(side: String, uid: String, hit_list: Array, first_reset_s: float) -> Dictionary:
	if first_reset_s < 0.0 or first_reset_s >= INF:
		return {
			"damage": 0.0,
			"damage_share": 0.0,
			"kills": 0,
			"targets": 0,
			"followup_s": -1.0
		}
	var total_damage: float = 0.0
	var post_damage: float = 0.0
	var first_followup_s: float = INF
	var targets: Dictionary = {}
	for hit_value in hit_list:
		if not (hit_value is Dictionary):
			continue
		var hit: Dictionary = hit_value
		var hit_t: float = float(hit.get("t", 0.0))
		var damage: float = max(0.0, float(hit.get("damage", 0.0)))
		total_damage += damage
		if hit_t < first_reset_s:
			continue
		post_damage += damage
		first_followup_s = min(first_followup_s, hit_t - first_reset_s)
		var target_uid: String = String(hit.get("target", ""))
		if target_uid != "":
			targets[target_uid] = true
	var post_kills: int = 0
	var kill_list: Array = (_kills.get(side, {}) as Dictionary).get(uid, [])
	for kill_value in kill_list:
		if not (kill_value is Dictionary):
			continue
		var kill: Dictionary = kill_value
		if float(kill.get("t", 0.0)) >= first_reset_s:
			post_kills += 1
	return {
		"damage": post_damage,
		"damage_share": post_damage / max(1.0, total_damage),
		"kills": post_kills,
		"targets": targets.size(),
		"followup_s": first_followup_s if first_followup_s < INF else -1.0
	}

func _record_group(side: String, uid: String, target_uid: String, damage: int) -> void:
	var side_groups: Dictionary = _groups.get(side, {})
	var uid_groups: Dictionary = side_groups.get(uid, {})
	var bucket: int = int(round(_time_s * TIME_BUCKETS_PER_SECOND))
	var group_key: String = str(bucket)
	var group: Dictionary = uid_groups.get(group_key, {"targets": {}, "damage": 0.0, "hits": 0})
	var targets: Dictionary = group.get("targets", {})
	targets[target_uid] = true
	group["targets"] = targets
	group["damage"] = float(group.get("damage", 0.0)) + max(0.0, float(damage))
	group["hits"] = int(group.get("hits", 0)) + 1
	uid_groups[group_key] = group
	side_groups[uid] = uid_groups
	_groups[side] = side_groups

func _hits_for(side: String, uid: String) -> Array:
	var by_side: Dictionary = _hits.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = []
		_hits[side] = by_side
	return by_side[uid]

func _kills_for(side: String, uid: String) -> Array:
	var by_side: Dictionary = _kills.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = []
		_kills[side] = by_side
	return by_side[uid]

func _resets_for(side: String, uid: String) -> Array:
	var by_side: Dictionary = _resets.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = []
		_resets[side] = by_side
	return by_side[uid]

func _execute_bonus_for(side: String, uid: String) -> Array:
	var by_side: Dictionary = _execute_bonus.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = []
		_execute_bonus[side] = by_side
	return by_side[uid]

func _ramp_state_for(side: String, uid: String) -> Array:
	var by_side: Dictionary = _ramp_state.get(side, {})
	if not by_side.has(uid):
		by_side[uid] = []
		_ramp_state[side] = by_side
	return by_side[uid]

func _target_max_hp(side: String, index: int) -> int:
	var team: Array = _state_array_for_side(side)
	if index < 0 or index >= team.size():
		return 1
	var unit: Variant = team[index]
	if unit == null:
		return 1
	return max(1, int(unit.max_hp))

func _state_array_for_side(side: String) -> Array:
	if _state == null:
		return []
	if side == SIDE_A:
		return _state.player_team if _player_is_team_a else _state.enemy_team
	return _state.enemy_team if _player_is_team_a else _state.player_team

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

func _opponent_side(side: String) -> String:
	if side == SIDE_A:
		return SIDE_B
	if side == SIDE_B:
		return SIDE_A
	return ""

func _extract_index_map(context_tags: Dictionary) -> Dictionary:
	var out: Dictionary = { SIDE_A: {}, SIDE_B: {} }
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

func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = []
	for value in values:
		sorted_values.append(float(value))
	sorted_values.sort()
	var count: int = sorted_values.size()
	var mid: int = int(float(count) / 2.0)
	if (count % 2) == 1:
		return float(sorted_values[mid])
	return 0.5 * (float(sorted_values[mid - 1]) + float(sorted_values[mid]))

func _mean_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value in values:
		total += float(value)
	return total / max(1.0, float(values.size()))

func _min_float(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var best: float = INF
	for value in values:
		best = min(best, float(value))
	return best if best < INF else 0.0
