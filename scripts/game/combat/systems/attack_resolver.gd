extends RefCounted
class_name AttackResolver

var state: BattleState
var target_controller: TargetController
var rng: RandomNumberGenerator
var player_ref: Unit
var deterministic_rolls: bool = true

var total_damage_player: int = 0
var total_damage_enemy: int = 0

var frame_damage_player: int = 0
var frame_damage_enemy: int = 0
var frame_player_dead: bool = false
var frame_enemy_dead: bool = false
var frame_double_ko: bool = false

var emitters: Dictionary = {}

var debug_pairs: int = 0
var debug_shots: int = 0
var debug_double_lethals: int = 0

func configure(_state: BattleState, _target_controller: TargetController, _rng: RandomNumberGenerator, _player_ref: Unit, _emitters: Dictionary) -> void:
	state = _state
	target_controller = _target_controller
	rng = _rng
	player_ref = _player_ref
	emitters = _emitters.duplicate()

func set_deterministic_rolls(flag: bool) -> void:
	deterministic_rolls = flag

func reset_totals() -> void:
	total_damage_player = 0
	total_damage_enemy = 0

func begin_frame() -> void:
	frame_damage_player = 0
	frame_damage_enemy = 0
	frame_player_dead = false
	frame_enemy_dead = false
	frame_double_ko = false

func resolve_pairs(pairs: Array) -> void:
	for pair in pairs:
		if typeof(pair) != TYPE_ARRAY or pair.size() < 2:
			continue
		var result: Dictionary = _resolve_pair(pair[0], pair[1])
		if result.get("double_ko", false):
			frame_double_ko = true

func resolve_ordered(events: Array[AttackEvent]) -> void:
	for event in events:
		if typeof(event) != TYPE_OBJECT:
			continue
		_resolve_single_event(event)

func apply_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool, respect_block: bool = true) -> Dictionary:
	var response: Dictionary = {"processed": false}
	if not state or not state.battle_active:
		return response
	var src: Unit = _unit_at(source_team, source_index)
	var tgt_team: String = _other_team(source_team)
	var tgt: Unit = _unit_at(tgt_team, target_index)
	if not src or not tgt:
		return response
	response["processed"] = true
	var before_hp: int = int(tgt.hp)
	response["before_hp"] = before_hp
	response["after_hp"] = before_hp
	response["dealt"] = 0
	response["heal"] = 0
	response["blocked"] = false
	if respect_block and rng and rng.randf() < tgt.block_chance:
		response["blocked"] = true
		if source_team == "enemy":
			_emit_log("You blocked the enemy attack.")
		else:
			_emit_log("%s blocked your attack." % tgt.name)
		return response
	var dealt: int = int(tgt.take_damage(damage))
	response["dealt"] = dealt
	response["after_hp"] = int(tgt.hp)
	if source_team == "player":
		total_damage_player += dealt
		frame_damage_player += dealt
	else:
		total_damage_enemy += dealt
		frame_damage_enemy += dealt
	var heal: int = int(float(dealt) * src.lifesteal)
	response["heal"] = heal
	if heal > 0:
		src.hp = min(src.max_hp, src.hp + heal)
	if source_team == "player":
		_emit_log("You hit %s for %d%s. Lifesteal +%d." % [tgt.name, dealt, (" (CRIT)" if crit else ""), heal])
	else:
		_emit_log("%s hits you for %d%s." % [src.name, dealt, (" (CRIT)" if crit else "")])
	_after_attack_mana_gain(source_team, source_index, src)
	_emit_unit_stat(source_team, source_index, {"hp": src.hp, "mana": src.mana})
	_emit_unit_stat(tgt_team, target_index, {"hp": tgt.hp})
	_emit_stats()
	_update_frame_deaths(source_team)
	return response

func totals() -> Dictionary:
	return {"player": total_damage_player, "enemy": total_damage_enemy}

func frame_status() -> Dictionary:
	return {
		"player_dead": frame_player_dead,
		"enemy_dead": frame_enemy_dead,
		"double_ko": frame_double_ko
	}

func frame_damage_summary() -> Dictionary:
	return {"player": frame_damage_player, "enemy": frame_damage_enemy}

func _resolve_pair(player_event: AttackEvent, enemy_event: AttackEvent) -> Dictionary:
	var summary: Dictionary = {"double_ko": false}
	if not state:
		return summary
	var p_idx: int = player_event.shooter_index
	var e_idx: int = enemy_event.shooter_index
	var player_unit: Unit = BattleState.unit_at(state.player_team, p_idx)
	var enemy_unit: Unit = BattleState.unit_at(state.enemy_team, e_idx)
	if not player_unit or not player_unit.is_alive():
		return summary
	if not enemy_unit or not enemy_unit.is_alive():
		return summary
	var p_target_idx: int = target_controller.current_target("player", p_idx)
	player_event.target_index = p_target_idx
	var e_target_idx: int = target_controller.current_target("enemy", e_idx)
	enemy_event.target_index = e_target_idx
	if not BattleState.is_target_alive(state.enemy_team, p_target_idx):
		return summary
	if not BattleState.is_target_alive(state.player_team, e_target_idx):
		return summary
	var ptgt: Unit = state.enemy_team[p_target_idx]
	var etgt: Unit = state.player_team[e_target_idx]
	var p_roll: Dictionary = _attack_roll(player_unit)
	var e_roll: Dictionary = _attack_roll(enemy_unit)
	player_event.rolled_damage = int(p_roll["damage"])
	player_event.crit = bool(p_roll["crit"])
	enemy_event.rolled_damage = int(e_roll["damage"])
	enemy_event.crit = bool(e_roll["crit"])
	_emit_projectile("player", p_idx, p_target_idx, player_event.rolled_damage, player_event.crit)
	_emit_projectile("enemy", e_idx, e_target_idx, enemy_event.rolled_damage, enemy_event.crit)
	debug_shots += 2
	var p_before: int = int(ptgt.hp)
	var e_before: int = int(etgt.hp)
	var p_dealt: int = min(player_event.rolled_damage, p_before)
	var e_dealt: int = min(enemy_event.rolled_damage, e_before)
	ptgt.hp = max(0, p_before - p_dealt)
	etgt.hp = max(0, e_before - e_dealt)
	debug_pairs += 1
	if p_dealt > 0 and player_unit.lifesteal > 0.0:
		player_unit.hp = min(player_unit.max_hp, player_unit.hp + int(float(p_dealt) * player_unit.lifesteal))
	if e_dealt > 0 and enemy_unit.lifesteal > 0.0:
		enemy_unit.hp = min(enemy_unit.max_hp, enemy_unit.hp + int(float(e_dealt) * enemy_unit.lifesteal))
	if p_dealt >= p_before and e_dealt >= e_before:
		frame_double_ko = true
		summary["double_ko"] = true
		debug_double_lethals += 1
	total_damage_player += p_dealt
	total_damage_enemy += e_dealt
	frame_damage_player += p_dealt
	frame_damage_enemy += e_dealt
	_after_attack_mana_gain("player", p_idx, player_unit)
	_after_attack_mana_gain("enemy", e_idx, enemy_unit)
	var player_lifesteal: int = int(float(p_dealt) * player_unit.lifesteal)
	var enemy_lifesteal: int = int(float(e_dealt) * enemy_unit.lifesteal)
	_emit_log("You hit %s for %d%s. Lifesteal +%d." % [ptgt.name, p_dealt, (" (CRIT)" if player_event.crit else ""), player_lifesteal])
	_emit_log("%s hits you for %d%s." % [enemy_unit.name, e_dealt, (" (CRIT)" if enemy_event.crit else "")])
	_emit_unit_stat("enemy", p_idx, {"hp": player_unit.hp, "mana": player_unit.mana})
	_emit_unit_stat("player", e_idx, {"hp": enemy_unit.hp, "mana": enemy_unit.mana})
	_emit_unit_stat("enemy", p_target_idx, {"hp": ptgt.hp})
	_emit_unit_stat("player", e_target_idx, {"hp": etgt.hp})
	_emit_stats()
	var player_cd_now: float = _cd_safe("player", p_idx)
	var enemy_cd_now: float = _cd_safe("enemy", e_idx)
	_emit_hit("player", p_idx, p_target_idx, player_event.rolled_damage, p_dealt, player_event.crit, p_before, int(ptgt.hp), player_cd_now, enemy_cd_now)
	_emit_hit("enemy", e_idx, e_target_idx, enemy_event.rolled_damage, e_dealt, enemy_event.crit, e_before, int(etgt.hp), player_cd_now, enemy_cd_now)
	var player_all_dead: bool = BattleState.all_dead(state.player_team)
	var enemy_all_dead: bool = BattleState.all_dead(state.enemy_team)
	if player_all_dead:
		frame_player_dead = true
	if enemy_all_dead:
		frame_enemy_dead = true
	return summary

func _resolve_single_event(event: AttackEvent) -> void:
	if not state:
		return
	var team: String = event.team
	var shooter_index: int = event.shooter_index
	var shooter: Unit = _unit_at(team, shooter_index)
	if not shooter or not shooter.is_alive():
		return
	var target_idx: int = target_controller.current_target(team, shooter_index)
	event.target_index = target_idx
	var target_team: String = _other_team(team)
	var target: Unit = _unit_at(target_team, target_idx)
	if not target or not target.is_alive():
		return
	var roll: Dictionary = _attack_roll(shooter)
	event.rolled_damage = int(roll["damage"])
	event.crit = bool(roll["crit"])
	_emit_projectile(team, shooter_index, target_idx, event.rolled_damage, event.crit)
	debug_shots += 1
	var outcome: Dictionary = apply_projectile_hit(team, shooter_index, target_idx, event.rolled_damage, event.crit, true)
	if not outcome.get("processed", false):
		return
	var before_hp: int = int(outcome.get("before_hp", int(target.hp)))
	var after_hp: int = int(outcome.get("after_hp", int(target.hp)))
	var dealt: int = int(outcome.get("dealt", 0))
	var player_cd: float = _cd_safe("player", shooter_index) if team == "player" else _cd_safe("player", 0)
	var enemy_cd: float = _cd_safe("enemy", shooter_index) if team == "enemy" else _cd_safe("enemy", 0)

	_emit_hit(team, shooter_index, target_idx, event.rolled_damage, dealt, event.crit, before_hp, after_hp, player_cd, enemy_cd)

func _attack_roll(u: Unit) -> Dictionary:
	if not u:
		return {"damage": 0, "crit": false}
	if deterministic_rolls:
		var dmg_f: float = float(u.attack_damage) + float(u.true_damage)
		return {"damage": int(round(dmg_f)), "crit": false}
	return u.attack_roll(rng)

func _after_attack_mana_gain(team: String, index: int, src: Unit) -> void:
	if not src:
		return
	var gain: int = int(max(0, int(src.mana_gain_per_attack)))
	if gain > 0 and src.mana_max > 0:
		src.mana = min(src.mana_max, src.mana + gain)
		if src.mana >= src.mana_max:
			var ability_name: String = _ability_name_for(src)
			var readable_name: String = src.name if src.name != "" else "Unit"
			_emit_log("%s used %s!" % [readable_name, ability_name])
			src.mana = 0
	_emit_unit_stat(team, index, {"mana": src.mana})
	_emit_stats()

func _ability_name_for(u: Unit) -> String:
	if not u or u.ability_id == "":
		return "Ability"
	var path: String = "res://data/abilities/%s.tres" % u.ability_id
	if ResourceLoader.exists(path):
		var def: AbilityDef = load(path)
		if def and def.name != "":
			return def.name
	return "Ability"

func _update_frame_deaths(source_team: String) -> void:
	var target_team: String = _other_team(source_team)
	if not BattleState.all_dead(_unit_array(target_team)):
		return
	var min_cd: float = _min_cd(_other_cds(source_team))
	if min_cd <= 0.0001:
		frame_enemy_dead = true
		frame_player_dead = true
	elif source_team == "player":
		frame_enemy_dead = true
	else:
		frame_player_dead = true

func _emit_projectile(team: String, shooter_index: int, target_index: int, damage: int, crit: bool) -> void:
	_emit("projectile_fired", [team, shooter_index, target_index, damage, crit])

func _emit_hit(team: String, shooter_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	_emit("hit_applied", [team, shooter_index, target_index, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd])

func _emit_unit_stat(team: String, index: int, fields: Dictionary) -> void:
	_emit("unit_stat_changed", [team, index, fields])

func _emit_log(text: String) -> void:
	if text == "":
		return
	_emit("log_line", [text])

func _emit_stats() -> void:
	if not state:
		return
	_emit("stats_updated", [player_ref, BattleState.first_alive(state.enemy_team)])
	_emit("team_stats_updated", [state.player_team, state.enemy_team])

func _emit(key: String, args: Array) -> void:
	var callable: Callable = emitters.get(key, Callable())
	if callable.is_valid():
		callable.callv(args)

func _unit_array(team: String) -> Array[Unit]:
	return state.player_team if team == "player" else state.enemy_team

func _unit_at(team: String, index: int) -> Unit:
	var arr: Array[Unit] = _unit_array(team)
	if index < 0 or index >= arr.size():
		return null
	return arr[index]

func _other_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func _other_cds(team: String) -> Array[float]:
	return state.enemy_cds if team == "player" else state.player_cds

func _cd_safe(team: String, index: int) -> float:
	var cds: Array[float] = state.player_cds if team == "player" else state.enemy_cds
	if index < 0 or index >= cds.size():
		return 0.0
	return float(cds[index])

func _min_cd(cds: Array) -> float:
	if cds.is_empty():
		return 9999.0
	var min_val: float = 9999.0
	for v in cds:
		var f: float = float(v)
		if f < min_val:
			min_val = f
	return min_val
