extends RefCounted
class_name DPSDummyCollector

const CombatStatsCollector := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")

var make_dummies: bool = true
var dummy_hp: int = 1000000

var _base: CombatStatsCollector
var _engine: Variant = null
var _state: Variant = null

func _init() -> void:
	_base = CombatStatsCollector.new()

func attach(engine: Variant, state: Variant, player_is_team_a: bool = true) -> void:
	_engine = engine
	_state = state
	if _base != null and _base.has_method("attach"):
		_base.attach(engine, state, player_is_team_a)
	if make_dummies:
		_setup_dummies()

func detach() -> void:
	if _base != null and _base.has_method("detach"):
		_base.detach()
	_engine = null
	_state = null

func tick(delta_s: float) -> void:
	if _base != null and _base.has_method("tick"):
		_base.tick(delta_s)

func finalize(total_time_s: float) -> void:
	if _base != null and _base.has_method("finalize"):
		_base.finalize(total_time_s)

func result() -> Dictionary:
	if _base != null and _base.has_method("result"):
		return _base.result()
	return {}

func _setup_dummies() -> void:
	if _engine == null or _state == null:
		return
	var bs: Variant = null
	if _engine != null:
		bs = _engine.buff_system
	if bs == null:
		return
	# Configure every enemy as an inert sponge with no mitigation.
	for idx in range(_state.enemy_team.size()):
		var u: Variant = _state.enemy_team[idx]
		if u == null:
			continue
		var fields: Dictionary = {}
		fields["attack_damage"] = -float(u.attack_damage)
		fields["armor"] = -float(u.armor)
		fields["magic_resist"] = -float(u.magic_resist)
		fields["damage_reduction"] = -float(u.damage_reduction)
		fields["damage_reduction_flat"] = -float(u.damage_reduction_flat)
		fields["max_hp"] = float(max(0, int(dummy_hp) - int(u.max_hp)))
		bs.apply_stats_buff(_state, "enemy", idx, fields, 1000.0)
		u.max_hp = max(int(u.max_hp), int(dummy_hp))
		u.hp = u.max_hp
