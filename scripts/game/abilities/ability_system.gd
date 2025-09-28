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
var cost_adapter = null

# Per-unit cooldowns (seconds remaining)
var _cooldowns: Dictionary = {} # Unit -> float
var _events: Array = [] # Array[Dictionary]: { name, team, index, t, data }

func configure(_engine: CombatEngine, _state: BattleState, _rng: RandomNumberGenerator, _buffs: BuffSystem = null) -> void:
	engine = _engine
	state = _state
	rng = _rng
	buff_system = _buffs
	cost_adapter = null
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

	# Passive ability watchers (e.g., Totem Exile auto-cleanse)
	_autocast_watchers()

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

func _autocast_watchers() -> void:
	# Totem Exile upgrade: auto-cast Cleanse when any ally is debuffed
	if state == null:
		return
	for i in range(state.player_team.size()):
		var u: Unit = state.player_team[i]
		if u == null or not u.is_alive():
			continue
		if String(u.ability_id) == "totem_cleanse":
			_autocast_totem_if_needed("player", i)
	for j in range(state.enemy_team.size()):
		var e: Unit = state.enemy_team[j]
		if e == null or not e.is_alive():
			continue
		if String(e.ability_id) == "totem_cleanse":
			_autocast_totem_if_needed("enemy", j)

func _team_has_debuff(team: String) -> bool:
	if buff_system == null:
		return false
	var arr: Array[Unit] = (state.player_team if team == "player" else state.enemy_team)
	for idx in range(arr.size()):
		var u: Unit = arr[idx]
		if u != null and u.is_alive():
			if buff_system.is_debuffed(state, team, idx):
				return true
	return false

func _autocast_totem_if_needed(team: String, index: int) -> void:
	# Require Exile trait active on team (count > 0)
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	var exile_count: int = 0
	if ctx.has_method("trait_count"):
		exile_count = ctx.trait_count(team, "Exile")
	if exile_count <= 0:
		return
	# Check if any ally is currently debuffed
	if not _team_has_debuff(team):
		return
	# Gate: simple per-unit cooldown to avoid spamming
	if _cooldowns.get(state.player_team[index] if team == "player" else state.enemy_team[index], 0.0) > 0.0:
		return
	# Attempt to cast immediately, ignoring mana threshold; consume mana on success
	var impl = AbilityCatalog.new_instance("totem_cleanse")
	if impl == null or not impl.has_method("cast"):
		return
	var ok: bool = bool(impl.cast(ctx))
	if not ok:
		return
	# Consume mana and start a brief cooldown
	var unit: Unit = _unit_at(team, index)
	if unit != null:
		unit.mana = 0
		engine._resolver_emit_unit_stat(team, index, {"mana": unit.mana})
		engine._resolver_emit_stats(unit, BattleState.first_alive(state.enemy_team))
		emit_signal("ability_cast", team, index, "totem_cleanse")
		_cooldowns[unit] = 0.5

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
		"creep_eaves_tick":
			_handle_creep_eaves_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"bo_wos_dash_tick":
			_handle_bo_wos_dash_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"bo_wos_land":
			_handle_bo_wos_land(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		_:
			pass

func _handle_creep_eaves_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	# Pull ticking meta
	var ticks_left: int = int(data.get("ticks_left", 0))
	var interval: float = float(data.get("interval", 0.2))
	var dmg: int = int(max(0, int(data.get("damage", 0))))
	var radius: float = float(data.get("radius", 1.3))
	var center: Vector2 = data.get("center", Vector2.ZERO)
	var allow_chase: bool = bool(data.get("allow_chase", false))
	var chase_used: bool = bool(data.get("chase_used", false))
	var exiled: bool = bool(data.get("exiled", false))
	var shred_pct: float = float(data.get("shred_pct", 0.0))
	var shred_dur: float = float(data.get("shred_dur", 0.0))
	if ticks_left <= 0:
		return
	# Build a context for geometric helpers
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	# Gather victims within radius around center
	var victims: Array[int] = ctx.enemies_in_radius_at(team, center, radius)
	var tgt_team: String = ("enemy" if team == "player" else "player")
	var any_kill: bool = false
	for vi in victims:
		if vi < 0:
			continue
		var res: Dictionary = AbilityEffects.damage_single(engine, state, team, index, int(vi), dmg, "physical")
		var after_hp: int = int(res.get("after_hp", 1))
		if after_hp <= 0:
			any_kill = true
		# Exiled shred: reduce Armor by 10% for 3s
		if exiled and shred_pct > 0.0 and shred_dur > 0.0 and buff_system != null:
			var tgt: Unit = _unit_at(tgt_team, int(vi))
			if tgt != null and tgt.is_alive():
				var eff: float = float(tgt.armor) * shred_pct
				if eff > 0.0:
					buff_system.apply_stats_buff(state, tgt_team, int(vi), {"armor": -eff}, shred_dur)
	# Chase logic (once)
	if allow_chase and (not chase_used) and any_kill:
		var next_idx: int = ctx.lowest_hp_enemy(team)
		if next_idx >= 0:
			center = ctx.position_of(tgt_team, next_idx)
			data["center"] = center
			data["chase_used"] = true
			engine._resolver_emit_log("Eavesdropping: chase")
	# Reschedule next tick if any
	ticks_left -= 1
	if ticks_left > 0:
		data["ticks_left"] = ticks_left
		schedule_event("creep_eaves_tick", team, index, max(0.0, interval), data)

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
	# Use context helper so healing includes source metadata
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	ctx.heal_single(tgt_team, best_idx, heal_amt)
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

func _handle_bo_wos_dash_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	if data == null:
		return
	var remain: float = float(data.get("remain", 0.0))
	var tick: float = float(data.get("tick", 0.06))
	if remain <= 0.0 or tick <= 0.0:
		return
	var width_tiles: float = float(data.get("width_tiles", 0.6))
	var dmg: int = int(max(0, int(data.get("damage", 0))))
	var kdur: float = float(data.get("knock", 0.75))
	var end_pos: Vector2 = data.get("end_pos", Vector2.ZERO)
	var last_pos: Vector2 = data.get("last_pos", Vector2.ZERO)
	var hit: Dictionary = data.get("hit", {})

	# Compute new position along the dash path and write to arena for visible movement
	var dur: float = float(data.get("dur", remain))
	var start_pos: Vector2 = data.get("start_pos", (engine.get_player_position(index) if team == "player" else engine.get_enemy_position(index)))
	var next_remain: float = max(0.0, remain - tick)
	var t2: float = 0.0 if dur <= 0.0 else clamp(1.0 - (next_remain / dur), 0.0, 1.0)
	var cur_pos: Vector2 = start_pos.lerp(end_pos, t2)
	if engine.arena_state != null:
		if team == "player":
			if index >= 0 and index < engine.arena_state.data.player_positions.size():
				engine.arena_state.data.player_positions[index] = cur_pos
		else:
			if index >= 0 and index < engine.arena_state.data.enemy_positions.size():
				engine.arena_state.data.enemy_positions[index] = cur_pos
	# Build sweep corridor from last_pos -> cur_pos
	var seg: Vector2 = cur_pos - last_pos
	var seg_len: float = seg.length()
	var ts: float = 1.0
	var eps: float = 0.5
	if engine.arena_state != null:
		ts = engine.arena_state.tile_size()
		if engine.arena_state.tuning != null:
			eps = float(engine.arena_state.tuning.range_epsilon)
	var half_w: float = max(0.0, width_tiles) * ts * 0.5 + eps
	var fwd: Vector2 = (seg / seg_len) if seg_len > 0.0 else Vector2.ZERO
	# Damage/CC enemies intersecting this sweep and not hit yet
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	var tgt_team: String = ("enemy" if team == "player" else "player")
	for vi in range((state.enemy_team.size() if team == "player" else state.player_team.size())):
		var opp: Unit = _unit_at(tgt_team, vi)
		if opp == null or not opp.is_alive():
			continue
		if hit.has(vi) and bool(hit[vi]):
			continue
		var p: Vector2 = (engine.get_enemy_position(vi) if team == "player" else engine.get_player_position(vi))
		# Skip if outside bounding box quickly
		if seg_len <= 0.0:
			continue
		var rel: Vector2 = p - last_pos
		var proj: float = rel.dot(fwd)
		if proj < 0.0 or proj > seg_len:
			continue
		var perp: float = abs(rel.cross(fwd))
		if perp <= half_w:
			# Hit once per dash
			AbilityEffects.stun(buff_system, engine, state, tgt_team, vi, kdur)
			if engine and engine.has_method("_resolver_emit_vfx_knockup"):
				engine._resolver_emit_vfx_knockup(tgt_team, vi, kdur)
			AbilityEffects.damage_single(engine, state, team, index, vi, dmg, "physical")
			hit[vi] = true

	# Reschedule next tick until remaining time elapses
	remain = next_remain
	data["remain"] = remain
	data["last_pos"] = cur_pos
	data["hit"] = hit
	if remain > 0.0:
		schedule_event("bo_wos_dash_tick", team, index, max(0.0, tick), data)
	else:
		# Ensure we schedule landing (handler snaps and retargets)
		schedule_event("bo_wos_land", team, index, 0.0, {"end_pos": end_pos})

func _handle_bo_wos_land(team: String, index: int, data: Dictionary) -> void:
	if engine == null or state == null:
		return
	# Snap to landing position if provided to ensure visible reposition
	if data != null and data.has("end_pos") and engine.arena_state != null:
		var p: Variant = data.get("end_pos")
		if typeof(p) == TYPE_VECTOR2:
			var dest: Vector2 = p
			if team == "player":
				if index >= 0 and index < engine.arena_state.data.player_positions.size():
					engine.arena_state.data.player_positions[index] = dest
			else:
				if index >= 0 and index < engine.arena_state.data.enemy_positions.size():
					engine.arena_state.data.enemy_positions[index] = dest
	# After dash, retarget to nearest via refresh; relies on configured selector
	if engine.target_controller != null and engine.target_controller.has_method("refresh_target"):
		var new_idx: int = engine.target_controller.refresh_target(team, index)
		engine._resolver_emit_log("Writ of Severance: retargeted -> %d" % new_idx)

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
	# Cost adapter (traits like Overload)
	if cost_adapter != null and cost_adapter.has_method("effective_cost"):
		cost = int(max(0, int(cost_adapter.effective_cost(unit, cost))))
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

func set_cost_resolver(resolver) -> void:
	# Back-compat name; stores adapter implementing effective_cost(unit, base_cost)
	cost_adapter = resolver

func set_cost_adapter(adapter) -> void:
	# Alias for clarity
	set_cost_resolver(adapter)

func is_on_cooldown(unit: Unit) -> bool:
	return _cooldowns.get(unit, 0.0) > 0.0

func cooldown_remaining(unit: Unit) -> float:
	return float(_cooldowns.get(unit, 0.0))

func _unit_at(team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]
