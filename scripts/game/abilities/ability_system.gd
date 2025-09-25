extends RefCounted
class_name AbilitySystem

signal ability_cast(team: String, index: int, ability_id: String)

const AbilityCatalog = preload("res://scripts/game/abilities/ability_catalog.gd")
const AbilityContext = preload("res://scripts/game/abilities/ability_context.gd")
const AbilityEffects = preload("res://scripts/game/abilities/effects.gd")
const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")

var engine: CombatEngine
var state: BattleState
var rng: RandomNumberGenerator
var buff_system: BuffSystem = null

# Per-unit cooldowns (seconds remaining)
var _cooldowns: Dictionary = {} # Unit -> float
var _events: Array = [] # Array[Dictionary]: { name, team, index, t, data }

func configure(_engine: CombatEngine, _state: BattleState, _rng: RandomNumberGenerator, _buffs: BuffSystem = null) -> void:
	engine = _engine
	state = _state
	rng = _rng
	buff_system = _buffs
	_cooldowns.clear()

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var to_erase: Array = []
	for u in _cooldowns.keys():
		var left: float = float(_cooldowns[u]) - delta
		if left <= 0.0:
			to_erase.append(u)
		else:
			_cooldowns[u] = left
	for u2 in to_erase:
		_cooldowns.erase(u2)
	# Timed ability events (e.g., Korath release)
	var remaining: Array = []
	for e in _events:
		var tleft: float = float(e.get("t", 0.0)) - delta
		if tleft <= 0.0:
			_handle_event(e)
		else:
			e["t"] = tleft
			remaining.append(e)
	_events = remaining

func schedule_event(name: String, team: String, index: int, delay_s: float, data: Dictionary = {}) -> void:
	if String(name) == "":
		return
	_events.append({
		"name": name,
		"team": team,
		"index": index,
		"t": max(0.0, float(delay_s)),
		"data": (data if data != null else {})
	})

func _handle_event(evt: Dictionary) -> void:
	var name: String = String(evt.get("name", ""))
	match name:
		"korath_release":
			_handle_korath_release(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"veyra_harden_end":
			_handle_veyra_harden_end(String(evt.get("team", "player")), int(evt.get("index", -1)))
		"kythera_siphon_tick":
			_handle_kythera_siphon_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"kythera_siphon_end":
			_handle_kythera_siphon_end(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		_:
			pass

func _handle_korath_release(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	# Extract meta reference captured at cast time
	var meta: Dictionary = {}
	if data != null:
		meta = data.get("meta", {})
	var pool: int = int(0)
	var stacks_at_cast: int = int(0)
	if meta != null and typeof(meta) == TYPE_DICTIONARY:
		pool = int(meta.get("pool", 0))
		stacks_at_cast = int(meta.get("stacks_at_cast", 0))
		# Clear remaining time on tag if still present (not required, but tidy)
		if buff_system != null and buff_system.has_tag(state, team, index, BuffTags.TAG_KORATH):
			var tag = buff_system.get_tag(state, team, index, BuffTags.TAG_KORATH)
			if not tag.is_empty():
				tag["remaining"] = 0.0
	# Find ally with greatest missing HP (include self)
	var allies: Array[Unit] = (state.player_team if team == "player" else state.enemy_team)
	var best_idx: int = -1
	var best_missing: int = -1
	for i in range(allies.size()):
		var u: Unit = allies[i]
		if u == null or not u.is_alive():
			continue
		var missing: int = int(u.max_hp) - int(u.hp)
		if missing > best_missing:
			best_missing = missing
			best_idx = i
	if best_idx < 0:
		return
	var tgt_team: String = team
	var heal_base: int = int(floor(0.20 * float(caster.max_hp)))
	var heal_amt: int = max(0, int(pool) + heal_base + 4 * int(stacks_at_cast))
	AbilityEffects.heal_single(engine, state, tgt_team, best_idx, heal_amt)
	engine._resolver_emit_log("Absorb & Release: healed %d (pool=%d, base=%d, stacks=%d)" % [heal_amt, pool, heal_base, stacks_at_cast])

func _handle_veyra_harden_end(team: String, index: int) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var stacks: int = 0
	if buff_system != null and buff_system.has_method("get_stack"):
		stacks = int(buff_system.get_stack(state, team, index, "aegis_stacks"))
	stacks = max(0, stacks)
	if stacks <= 0:
		engine._resolver_emit_log("Harden ended: no Aegis stacks; no max HP gained.")
		return
	var hp_gain: int = int(floor(float(caster.max_hp) * (float(stacks) * 0.01)))
	if hp_gain <= 0:
		engine._resolver_emit_log("Harden ended: stacks=%d, no effective max HP gain." % stacks)
		return
	# Apply a match-long stack that adds max_hp by hp_gain
	if buff_system != null and buff_system.has_method("add_stack"):
		buff_system.add_stack(state, team, index, "veyra_harden_hp", 1, {"max_hp": hp_gain})
	engine._resolver_emit_log("Harden: +%d Max HP (stacks=%d)" % [hp_gain, stacks])

func _handle_kythera_siphon_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var tgt_idx: int = int(data.get("target_index", -1))
	if tgt_idx < 0:
		return
	var tgt_team: String = ("enemy" if team == "player" else "player")
	var tgt: Unit = _unit_at(tgt_team, tgt_idx)
	if tgt == null or not tgt.is_alive():
		return
	var dmg: int = int(max(0, int(data.get("damage", 0))))
	if dmg > 0:
		AbilityEffects.damage_single(engine, state, team, index, tgt_idx, dmg, "magic")
	# Apply incremental MR drain this tick and accumulate drained_total on caster tag
	if buff_system != null:
		var BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")
		if buff_system.has_tag(state, team, index, BuffTags.TAG_KYTHERA):
			var tag := buff_system.get_tag(state, team, index, BuffTags.TAG_KYTHERA)
			var meta: Dictionary = tag.get("data", {})
			var per_sec: float = float(meta.get("per_sec", 0.0))
			var drained_total: float = float(meta.get("drained_total", 0.0))
			var remain: float = float(data.get("remain", 0.0))
			# Effective drain cannot exceed current MR
			var cur_mr: float = float(tgt.magic_resist)
			var eff: float = min(per_sec, max(0.0, cur_mr))
			if eff > 0.0 and remain > 0.0:
				buff_system.apply_stats_buff(state, tgt_team, tgt_idx, {"magic_resist": -eff}, remain)
			drained_total += eff
			meta["drained_total"] = drained_total
			tag["data"] = meta

func _handle_kythera_siphon_end(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var gain_total: int = 0
	if buff_system != null:
		var BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")
		if buff_system.has_tag(state, team, index, BuffTags.TAG_KYTHERA):
			var tag := buff_system.get_tag(state, team, index, BuffTags.TAG_KYTHERA)
			var meta: Dictionary = tag.get("data", {})
			var drained_total: float = float(meta.get("drained_total", 0.0))
			gain_total = int(max(0, round(drained_total)))
			# Clear remaining time on tag
			tag["remaining"] = 0.0
	if gain_total <= 0:
		engine._resolver_emit_log("Siphon ended: no MR gained.")
		return
	if buff_system != null and buff_system.has_method("add_stack"):
		buff_system.add_stack(state, team, index, "kythera_siphon_mr", 1, {"magic_resist": float(gain_total)})
	engine._resolver_emit_log("Siphon: +%d Magic Resist (permanent)" % gain_total)

func try_cast(team: String, index: int) -> Dictionary:
	var result := {"cast": false, "reason": ""}
	if state == null or engine == null:
		result.reason = "no_state_or_engine"
		return result
	var unit: Unit = _unit_at(team, index)
	if unit == null:
		result.reason = "no_unit"
		return result
	var ability_id: String = String(unit.ability_id)
	if ability_id == "":
		result.reason = "no_ability"
		return result
	# Cooldown check
	if _cooldowns.get(unit, 0.0) > 0.0:
		result.reason = "on_cooldown"
		return result
	# Resolve def and cost
	var def = AbilityCatalog.get_def(ability_id)
	var cost: int = int(unit.mana_max)
	if def != null:
		var bcost: int = int(def.base_cost)
		if bcost > 0:
			cost = bcost
	if unit.mana < cost:
		result.reason = "not_enough_mana"
		return result
	# Resolve implementation
	var impl = AbilityCatalog.new_instance(ability_id)
	if impl == null or not impl.has_method("cast"):
		result.reason = "no_impl"
		return result
	# Build context
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	# Call ability implementation
	var ok: bool = false
	# Guard against exceptions in ability scripts
	
	ok = bool(impl.cast(ctx))
	
	if not ok:
		result.reason = "cast_failed"
		return result
	# Success: reset mana and start cooldown (if present)
	unit.mana = 0
	var cd_s: float = 0.0
	if cd_s > 0.0:
		_cooldowns[unit] = cd_s
	# Emit updates
	engine._resolver_emit_unit_stat(team, index, {"mana": unit.mana})
	engine._resolver_emit_stats(unit, BattleState.first_alive(state.enemy_team))
	if def != null and String(def.name) != "":
		engine._resolver_emit_log("%s used %s!" % [unit.name if unit.name != "" else "Unit", String(def.name)])
	else:
		engine._resolver_emit_log("%s used ability." % (unit.name if unit.name != "" else "Unit"))
	emit_signal("ability_cast", team, index, ability_id)
	result.cast = true
	return result

func is_on_cooldown(unit: Unit) -> bool:
	return _cooldowns.get(unit, 0.0) > 0.0

func cooldown_remaining(unit: Unit) -> float:
	return float(_cooldowns.get(unit, 0.0))

func _unit_at(team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]
