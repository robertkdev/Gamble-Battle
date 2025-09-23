extends RefCounted
class_name AbilitySystem

signal ability_cast(team: String, index: int, ability_id: String)

const AbilityCatalog = preload("res://scripts/game/abilities/ability_catalog.gd")
const AbilityContext = preload("res://scripts/game/abilities/ability_context.gd")

var engine: CombatEngine
var state: BattleState
var rng: RandomNumberGenerator
var buff_system: BuffSystem = null

# Per-unit cooldowns (seconds remaining)
var _cooldowns: Dictionary = {} # Unit -> float

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
