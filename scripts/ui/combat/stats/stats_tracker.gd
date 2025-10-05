extends Node
class_name StatsTracker

# UI-side stats tracker. No engine changes.
# Listens to CombatEngine.hit_applied (via CombatManager.get_engine()),
# AbilitySystem.ability_cast, and battle start/end to maintain per-unit stats
# and rolling DPS windows.

const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

const WINDOW_ALL := "ALL"
const WINDOW_1S := "1S"
const WINDOW_3S := "3S"

const METRIC_DAMAGE := "damage"
const METRIC_TAKEN := "taken"
const METRIC_CASTS := "casts"
const METRIC_DPS := "dps"
const METRIC_HEALING := "healing"
const METRIC_OVERHEAL := "overheal"
const METRIC_ABSORB := "absorbed"
const METRIC_MITIGATED := "mitigated"
const METRIC_HPS := "hps"
const METRIC_CC_INF := "cc_inflicted"
const METRIC_CC_REC := "cc_received"
const METRIC_KILLS := "kills"
const METRIC_DEATHS := "deaths"
const METRIC_TIME := "time"
const METRIC_FOCUS := "focus"
const METRIC_OVERKILL := "overkill"

var manager: CombatManager = null
var engine: CombatEngine = null
var ability_system: AbilitySystem = null

# Sampling for rolling DPS
var sampling_hz: float = 10.0
var _sample_accum: float = 0.0
var _w1_count: int = 10   # 1s at 10 Hz
var _w3_count: int = 30   # 3s at 10 Hz
var _active: bool = false

# Bounded event buffers for optional UI/tooltips (avoid unbounded growth)
var _max_events: int = 256
var _hit_events: Array = []      # Array[Dictionary]
var _cast_events: Array = []     # Array[Dictionary]

# Per team arrays of UnitStats (index aligned to team arrays)
var _player_stats: Array = []
var _enemy_stats: Array = []
var _focus_maps_player: Array = []   # Array[Dictionary[target_key -> damage]]
var _focus_maps_enemy: Array = []

func _ready() -> void:
	set_process(true)

func configure(_manager: CombatManager, _sampling_hz: float = 10.0) -> void:
	manager = _manager
	sampling_hz = max(1.0, _sampling_hz)
	_w1_count = int(round(1.0 * sampling_hz))
	_w3_count = int(round(3.0 * sampling_hz))
	_wire_manager_signals()
	_reset_all()
	set_process(true)

func _wire_manager_signals() -> void:
	if manager == null:
		return
	if not manager.is_connected("battle_started", Callable(self, "_on_battle_started")):
		manager.battle_started.connect(_on_battle_started)
	if not manager.is_connected("victory", Callable(self, "_on_battle_end")):
		manager.victory.connect(_on_battle_end)
	if not manager.is_connected("defeat", Callable(self, "_on_battle_end")):
		manager.defeat.connect(_on_battle_end)

func _on_battle_started(_stage: int, _enemy) -> void:
	_reset_for_new_battle()
	engine = (manager.get_engine() if manager and manager.has_method("get_engine") else null)
	if engine != null:
		_connect_engine_signals()
		_connect_ability_signals()
	else:
		call_deferred("_late_bind_engine")
	_active = true

func _late_bind_engine() -> void:
	if not _active:
		return
	engine = (manager.get_engine() if manager and manager.has_method("get_engine") else null)
	if engine == null:
		call_deferred("_late_bind_engine")
		return
	_connect_engine_signals()
	_connect_ability_signals()

func _on_battle_end(_stage: int) -> void:
	_active = false

func _connect_engine_signals() -> void:
	if engine == null:
		return
	if not engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
		engine.hit_applied.connect(_on_hit_applied)
	if engine.has_signal("heal_applied") and not engine.is_connected("heal_applied", Callable(self, "_on_heal_applied")):
		engine.heal_applied.connect(_on_heal_applied)
	if engine.has_signal("shield_absorbed") and not engine.is_connected("shield_absorbed", Callable(self, "_on_shield_absorbed")):
		engine.shield_absorbed.connect(_on_shield_absorbed)
	if engine.has_signal("hit_mitigated") and not engine.is_connected("hit_mitigated", Callable(self, "_on_hit_mitigated")):
		engine.hit_mitigated.connect(_on_hit_mitigated)
	if engine.has_signal("hit_components") and not engine.is_connected("hit_components", Callable(self, "_on_engine_hit_components")):
		engine.hit_components.connect(_on_engine_hit_components)
	if engine.has_signal("hit_overkill") and not engine.is_connected("hit_overkill", Callable(self, "_on_engine_hit_overkill")):
		engine.hit_overkill.connect(_on_engine_hit_overkill)
	if engine.has_signal("cc_applied") and not engine.is_connected("cc_applied", Callable(self, "_on_engine_cc_applied")):
		engine.cc_applied.connect(_on_engine_cc_applied)

func _connect_ability_signals() -> void:
	ability_system = (engine.ability_system if engine != null else null)
	if ability_system != null and not ability_system.is_connected("ability_cast", Callable(self, "_on_ability_cast")):
		ability_system.ability_cast.connect(_on_ability_cast)

func _reset_all() -> void:
	_player_stats.clear()
	_enemy_stats.clear()
	_sample_accum = 0.0
	_active = false
	_hit_events.clear()
	_cast_events.clear()

func _reset_for_new_battle() -> void:
	_player_stats = _make_array_for_team(manager.player_team)
	_enemy_stats = _make_array_for_team(manager.enemy_team)
	_focus_maps_player = []
	_focus_maps_enemy = []
	_focus_maps_player.resize(_player_stats.size())
	_focus_maps_enemy.resize(_enemy_stats.size())
	_sample_accum = 0.0

func _make_array_for_team(team: Array) -> Array:
	var arr: Array = []
	if team == null:
		return arr
	for _i in range(team.size()):
		arr.append(_new_stats())
	return arr

func _ensure_capacity(team: String, size_needed: int) -> void:
	var arr: Array = ( _player_stats if team == TEAM_PLAYER else _enemy_stats )
	while arr.size() < size_needed:
		arr.append(_new_stats())
	if team == TEAM_PLAYER:
		_player_stats = arr
	else:
		_enemy_stats = arr

func _new_stats() -> Dictionary:
	var samples: Array[float] = []
	samples.resize(_w3_count)
	for i in range(_w3_count):
		samples[i] = 0.0
	return {
		"damage_dealt_total": 0,
		"damage_taken_total": 0,
		"casts": 0,
		"time_alive": 0.0,
		"kills": 0,
		"deaths": 0,
		"healing_done_total": 0,
		"healing_received_total": 0,
		"overheal_total": 0,
		"shields_absorbed_total": 0,
		"mitigated_total": 0, # pre - post_pre_shield summed for target
		"cc_inflicted_s": 0.0,
		"cc_received_s": 0.0,
		# rolling window ring buffer
		"samples": samples,    # last _w3_count samples of dealt damage
		"cursor": 0,
		"pending_dealt": 0.0,
		"pending_healed": 0.0,
		"pending_shield": 0.0,
	}

func _on_hit_applied(team: String, source_index: int, target_index: int, _rolled: int, dealt: int, _crit: bool, _bhp: int, _ahp: int, _pcd: float, _ecd: float) -> void:
	var src_team := (TEAM_PLAYER if String(team) == TEAM_PLAYER else TEAM_ENEMY)
	var tgt_team := (TEAM_ENEMY if src_team == TEAM_PLAYER else TEAM_PLAYER)
	_ensure_capacity(src_team, source_index + 1)
	_ensure_capacity(tgt_team, target_index + 1)
	var src_arr: Array = (_player_stats if src_team == TEAM_PLAYER else _enemy_stats)
	var tgt_arr: Array = (_enemy_stats if src_team == TEAM_PLAYER else _player_stats)
	var amt: int = max(0, int(dealt))
	# Dealt
	var s: Dictionary = src_arr[source_index]
	s.damage_dealt_total = int(s.damage_dealt_total) + amt
	s.pending_dealt = float(s.pending_dealt) + float(amt)
	src_arr[source_index] = s
	# Focus tracking (damage to specific targets)
	var fmap_arr: Array = (_focus_maps_player if src_team == TEAM_PLAYER else _focus_maps_enemy)
	while fmap_arr.size() <= source_index:
		fmap_arr.append({})
	if fmap_arr[source_index] == null or not (fmap_arr[source_index] is Dictionary):
		fmap_arr[source_index] = {}
	var fmap: Dictionary = fmap_arr[source_index]
	var key := "%s#%d" % [tgt_team, target_index]
	fmap[key] = int(fmap.get(key, 0)) + amt
	fmap_arr[source_index] = fmap
	# Taken
	var t: Dictionary = tgt_arr[target_index]
	t.damage_taken_total = int(t.damage_taken_total) + amt
	# Deaths/kills from hit_applied
	if amt > 0 and int(_ahp) <= 0 and int(_bhp) > 0:
		t.deaths = int(t.get("deaths", 0)) + 1
		# Attribute kill to source
		s.kills = int(s.get("kills", 0)) + 1
		src_arr[source_index] = s
	tgt_arr[target_index] = t
	# Record in bounded buffer
	_push_event(_hit_events, {
		"team": String(team),
		"source_index": int(source_index),
		"target_index": int(target_index),
		"dealt": amt,
		"t": Time.get_ticks_msec()
	})

func _on_ability_cast(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	var tm := (TEAM_PLAYER if String(team) == TEAM_PLAYER else TEAM_ENEMY)
	_ensure_capacity(tm, int(index) + 1)
	var arr: Array = (_player_stats if tm == TEAM_PLAYER else _enemy_stats)
	var st: Dictionary = arr[int(index)]
	st.casts = int(st.casts) + 1
	arr[int(index)] = st
	_push_event(_cast_events, {
		"team": String(team),
		"index": int(index),
		"id": String(ability_id),
		"target_team": String(target_team),
		"target_index": int(target_index),
		"point": target_point,
		"t": Time.get_ticks_msec()
	})

func _process(delta: float) -> void:
	if not _active:
		return
	var d: float = max(0.0, float(delta))
	# Time alive accumulation
	var pteam: Array = (manager.player_team if manager != null else [])
	var eteam: Array = (manager.enemy_team if manager != null else [])
	for i in range(_player_stats.size()):
		var u: Unit = (pteam[i] if i < pteam.size() else null)
		if u != null and u.is_alive():
			var s: Dictionary = _player_stats[i]
			s.time_alive = float(s.time_alive) + d
			_player_stats[i] = s
	for j in range(_enemy_stats.size()):
		var e: Unit = (eteam[j] if j < eteam.size() else null)
		if e != null and e.is_alive():
			var s2: Dictionary = _enemy_stats[j]
			s2.time_alive = float(s2.time_alive) + d
			_enemy_stats[j] = s2
	# Sampling for rolling DPS
	_sample_accum += d
	var period: float = 1.0 / sampling_hz
	while _sample_accum >= period:
		_sample_accum -= period
		_push_sample_for_all()

func _push_sample_for_all() -> void:
	for i in range(_player_stats.size()):
		_push_sample(_player_stats[i])
	for j in range(_enemy_stats.size()):
		_push_sample(_enemy_stats[j])

func _push_sample(s: Dictionary) -> void:
	var samples: Array = s.samples
	var cur: int = int(s.cursor)
	samples[cur] = float(s.pending_dealt)
	s.pending_dealt = 0.0
	# We can accumulate separate windows similarly if needed
	# For now we only expose DPS/HPS/Shielded via sums of last N samples
	if not s.has("samples_heal"):
		# Lazy allocate heal/shield samples matching _w3_count
		var hs: Array[float] = []
		hs.resize(_w3_count)
		for i in range(_w3_count): hs[i] = 0.0
		s["samples_heal"] = hs
		var ss: Array[float] = []
		ss.resize(_w3_count)
		for i in range(_w3_count): ss[i] = 0.0
		s["samples_shield"] = ss
	var heal_samples: Array = s.samples_heal
	var shield_samples: Array = s.samples_shield
	heal_samples[cur] = float(s.pending_healed)
	shield_samples[cur] = float(s.pending_shield)
	s.pending_healed = 0.0
	s.pending_shield = 0.0
	s.cursor = (cur + 1) % _w3_count

func _push_event(buf: Array, evt: Dictionary) -> void:
	if buf.size() >= _max_events:
		# Remove oldest ~10% to amortize shift cost
		var drop: float = max(1, int(round(float(_max_events) * 0.1)))
		buf.remove_at(0)
		for _i in range(drop - 1):
			if buf.is_empty():
				break
			buf.remove_at(0)
	buf.append(evt)

func _sum_last_n(s: Dictionary, n: int) -> float:
	var samples: Array = s.samples
	var cur: int = int(s.cursor)
	var total: float = 0.0
	var cnt: int = min(n, samples.size())
	for i in range(cnt):
		var idx: int = (cur - 1 - i)
		while idx < 0:
			idx += samples.size()
		total += float(samples[idx])
	return total

# Damage component breakdown (all-time totals) for hover
func damage_breakdown(team: String, index: int) -> Dictionary:
	var tm := (TEAM_PLAYER if String(team) == TEAM_PLAYER else TEAM_ENEMY)
	_ensure_capacity(tm, index + 1)
	var s: Dictionary = (( _player_stats if tm == TEAM_PLAYER else _enemy_stats)[index])
	return s.get("comp", {})

func get_focus_share(team: String, index: int) -> float:
	var tm := (TEAM_PLAYER if String(team) == TEAM_PLAYER else TEAM_ENEMY)
	var arr: Array = (_focus_maps_player if tm == TEAM_PLAYER else _focus_maps_enemy)
	if index < 0 or index >= arr.size():
		return 0.0
	var entry = arr[index]
	if entry == null or not (entry is Dictionary):
		arr[index] = {}
		return 0.0
	var fmap: Dictionary = entry
	if fmap.is_empty():
		return 0.0
	var maxv: float = 0.0
	var total: float = 0.0
	for v in fmap.values():
		var x: float = float(v)
		total += x
		if x > maxv:
			maxv = x
	if total <= 0.0:
		return 0.0
	return maxv / total

func _on_engine_hit_components(st: String, si: int, _tt: String, _ti: int, phys: int, mag: int, tru: int) -> void:
	var tm := (TEAM_PLAYER if String(st) == TEAM_PLAYER else TEAM_ENEMY)
	_ensure_capacity(tm, si + 1)
	var arr: Array = (_player_stats if tm == TEAM_PLAYER else _enemy_stats)
	var s: Dictionary = arr[si]
	var comp: Dictionary = s.get("comp", {"physical": 0.0, "magic": 0.0, "true": 0.0})
	comp["physical"] = float(comp.get("physical", 0.0)) + max(0.0, float(phys))
	comp["magic"] = float(comp.get("magic", 0.0)) + max(0.0, float(mag))
	comp["true"] = float(comp.get("true", 0.0)) + max(0.0, float(tru))
	s["comp"] = comp
	arr[si] = s

func _on_engine_hit_overkill(st: String, si: int, _tt: String, _ti: int, overkill: int) -> void:
	var tm := (TEAM_PLAYER if String(st) == TEAM_PLAYER else TEAM_ENEMY)
	_ensure_capacity(tm, si + 1)
	var arr: Array = (_player_stats if tm == TEAM_PLAYER else _enemy_stats)
	var s: Dictionary = arr[si]
	s.overkill_total = int(s.get("overkill_total", 0)) + max(0, int(overkill))
	arr[si] = s

func _on_engine_cc_applied(st: String, si: int, tt: String, ti: int, _kind: String, dur: float) -> void:
	var duration: float = max(0.0, float(dur))
	# Received on target
	var tgt_tm := (TEAM_PLAYER if String(tt) == TEAM_PLAYER else TEAM_ENEMY)
	_ensure_capacity(tgt_tm, ti + 1)
	var tarr: Array = (_player_stats if tgt_tm == TEAM_PLAYER else _enemy_stats)
	var ts: Dictionary = tarr[ti]
	ts.cc_received_s = float(ts.cc_received_s) + duration
	tarr[ti] = ts
	# Inflicted on source when provided
	if String(st) != "" and int(si) >= 0:
		var src_tm := (TEAM_PLAYER if String(st) == TEAM_PLAYER else TEAM_ENEMY)
		_ensure_capacity(src_tm, si + 1)
		var sarr: Array = (_player_stats if src_tm == TEAM_PLAYER else _enemy_stats)
		var ss: Dictionary = sarr[si]
		ss.cc_inflicted_s = float(ss.cc_inflicted_s) + duration
		sarr[si] = ss

func _sum_last_n_heal(s: Dictionary, n: int) -> float:
	if not s.has("samples_heal"):
		return 0.0
	var samples: Array = s.samples_heal
	var cur: int = int(s.cursor)
	var total: float = 0.0
	var cnt: int = min(n, samples.size())
	for i in range(cnt):
		var idx: int = (cur - 1 - i)
		while idx < 0:
			idx += samples.size()
		total += float(samples[idx])
	return total

func _sum_last_n_shield(s: Dictionary, n: int) -> float:
	if not s.has("samples_shield"):
		return 0.0
	var samples: Array = s.samples_shield
	var cur: int = int(s.cursor)
	var total: float = 0.0
	var cnt: int = min(n, samples.size())
	for i in range(cnt):
		var idx: int = (cur - 1 - i)
		while idx < 0:
			idx += samples.size()
		total += float(samples[idx])
	return total

func _on_heal_applied(st: String, si: int, tt: String, ti: int, healed: int, overheal: int, _bhp: int, _ahp: int) -> void:
	var src_tm := (TEAM_PLAYER if String(st) == TEAM_PLAYER else TEAM_ENEMY)
	var tgt_tm := (TEAM_PLAYER if String(tt) == TEAM_PLAYER else TEAM_ENEMY)
	if ti >= 0:
		_ensure_capacity(tgt_tm, ti + 1)
		var arr_tgt: Array = (_player_stats if tgt_tm == TEAM_PLAYER else _enemy_stats)
		var ts: Dictionary = arr_tgt[ti]
		ts.healing_received_total = int(ts.healing_received_total) + max(0, int(healed))
		ts.overheal_total = int(ts.overheal_total) + max(0, int(overheal))
		ts.pending_healed = float(ts.pending_healed) + float(max(0, int(healed)))
		arr_tgt[ti] = ts
	if si >= 0 and st != "":
		_ensure_capacity(src_tm, si + 1)
		var arr_src: Array = (_player_stats if src_tm == TEAM_PLAYER else _enemy_stats)
		var ss: Dictionary = arr_src[si]
		ss.healing_done_total = int(ss.healing_done_total) + max(0, int(healed))
		arr_src[si] = ss

func _on_shield_absorbed(tt: String, ti: int, absorbed: int) -> void:
	var tgt_tm := (TEAM_PLAYER if String(tt) == TEAM_PLAYER else TEAM_ENEMY)
	_ensure_capacity(tgt_tm, ti + 1)
	var arr: Array = (_player_stats if tgt_tm == TEAM_PLAYER else _enemy_stats)
	var s: Dictionary = arr[ti]
	var amt: int = max(0, int(absorbed))
	s.shields_absorbed_total = int(s.shields_absorbed_total) + amt
	s.pending_shield = float(s.pending_shield) + float(amt)
	arr[ti] = s

func _on_hit_mitigated(_st: String, _si: int, tt: String, ti: int, pre_mit: int, post_pre_shield: int) -> void:
	# Attribute mitigation to the target (their defenses prevented this much)
	var tgt_tm := (TEAM_PLAYER if String(tt) == TEAM_PLAYER else TEAM_ENEMY)
	_ensure_capacity(tgt_tm, ti + 1)
	var arr: Array = (_player_stats if tgt_tm == TEAM_PLAYER else _enemy_stats)
	var s: Dictionary = arr[ti]
	var prevented: int = max(0, int(pre_mit) - max(0, int(post_pre_shield)))
	s.mitigated_total = int(s.mitigated_total) + prevented
	arr[ti] = s

# --- Public getters ---

func is_active() -> bool:
	return _active

func get_value(team: String, index: int, metric: String, window: String = WINDOW_ALL) -> float:
	var tm := (TEAM_PLAYER if String(team) == TEAM_PLAYER else TEAM_ENEMY)
	var arr: Array = (_player_stats if tm == TEAM_PLAYER else _enemy_stats)
	if index < 0 or index >= arr.size():
		return 0.0
	var s: Dictionary = arr[index]
	match String(metric):
		METRIC_DAMAGE:
			return float(s.damage_dealt_total)
		METRIC_TAKEN:
			return float(s.damage_taken_total)
		METRIC_CASTS:
			return float(s.casts)
		METRIC_DPS:
			if String(window) == WINDOW_1S:
				return _sum_last_n(s, _w1_count) / 1.0
			elif String(window) == WINDOW_3S:
				return _sum_last_n(s, _w3_count) / 3.0
			else:
				var t: float = max(0.0, float(s.time_alive))
				return (float(s.damage_dealt_total) / t) if t > 0.0 else 0.0
		METRIC_HEALING:
			return float(s.healing_done_total)
		METRIC_OVERHEAL:
			return float(s.overheal_total)
		METRIC_ABSORB:
			return float(s.shields_absorbed_total)
		METRIC_MITIGATED:
			return float(s.mitigated_total)
		METRIC_HPS:
			if String(window) == WINDOW_1S:
				return _sum_last_n_heal(s, _w1_count) / 1.0
			else:
				return _sum_last_n_heal(s, _w3_count) / 3.0
		METRIC_CC_INF:
			return float(s.cc_inflicted_s)
		METRIC_CC_REC:
			return float(s.cc_received_s)
		METRIC_KILLS:
			return float(s.get("kills", 0))
		METRIC_DEATHS:
			return float(s.get("deaths", 0))
		METRIC_TIME:
			return float(s.time_alive)
		METRIC_FOCUS:
			return get_focus_share(team, index) * 100.0
		METRIC_OVERKILL:
			return float(s.get("overkill_total", 0))
		_:
			return 0.0

func get_rows(team: String, metric: String, window: String = WINDOW_ALL) -> Array:
	var tm := (TEAM_PLAYER if String(team) == TEAM_PLAYER else TEAM_ENEMY)
	var arr: Array = (_player_stats if tm == TEAM_PLAYER else _enemy_stats)
	var units: Array = (manager.player_team if tm == TEAM_PLAYER else manager.enemy_team)
	var rows: Array = []
	for i in range(max(arr.size(), units.size())):
		var unit: Unit = (units[i] if i < units.size() else null)
		var value: float = get_value(tm, i, metric, window)
		rows.append({
			"team": tm,
			"index": i,
			"unit": unit,
			"value": value,
		})
	return rows

func get_team_total(team: String, metric: String, window: String = WINDOW_ALL) -> float:
	var total: float = 0.0
	var rows: Array = get_rows(team, metric, window)
	for r in rows:
		total += float(r.get("value", 0.0))
	return total

# Optional: recent event accessors
func recent_hits(limit: int = 20) -> Array:
	var n: int = clamp(int(limit), 0, _hit_events.size())
	if n <= 0:
		return []
	return _hit_events.slice(_hit_events.size() - n, _hit_events.size())

func recent_casts(limit: int = 20) -> Array:
	var n: int = clamp(int(limit), 0, _cast_events.size())
	if n <= 0:
		return []
	return _cast_events.slice(_cast_events.size() - n, _cast_events.size())
