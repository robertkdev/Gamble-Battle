extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const BonkoBonk := preload("res://scripts/game/abilities/impls/bonko_bonk.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: BattleState = _make_state()
	var engine: CombatEngine = CombatEngineScript.new()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.configure(state, state.player_team[0], 1, Callable())
	engine.start()

	var failed: bool = false
	if engine.buff_system == null:
		printerr("BonkoEmpowerContractProbe: FAIL missing BuffSystem")
		failed = true
	if failed:
		_finish(engine, 1)
		return

	var ramp_events: Array[Dictionary] = []
	engine.ramp_state_changed.connect(_on_ramp_state_changed.bind(ramp_events))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 24680
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = BonkoBonk.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))
	var has_empower: bool = engine.buff_system.has_tag(state, "player", 0, BuffTags.TAG_BONKO_EMPOWER)
	var meta: Dictionary = engine.buff_system.get_tag_data(state, "player", 0, BuffTags.TAG_BONKO_EMPOWER)
	var hits_left: int = int(meta.get("hits_left", 0))
	var extra_ad_ratio: float = float(meta.get("extra_ad_ratio", 0.0))
	var heal_missing_pct: float = float(meta.get("heal_missing_pct", 0.0))
	var block_mana_gain: bool = bool(meta.get("block_mana_gain", false))
	var ramp: Dictionary = ramp_events[0] if not ramp_events.is_empty() else {}

	print("BonkoEmpowerContractProbe: cast_ok=", cast_ok,
		" has_empower=", has_empower,
		" hits_left=", hits_left,
		" extra_ad_ratio=", extra_ad_ratio,
		" heal_missing_pct=", heal_missing_pct,
		" block_mana_gain=", block_mana_gain,
		" ramp_events=", ramp_events.size(),
		" ramp_kind=", String(ramp.get("kind", "")),
		" ramp_stacks=", int(ramp.get("stacks", 0)),
		" ramp_reason=", String(ramp.get("reason", "")))

	if not cast_ok:
		printerr("BonkoEmpowerContractProbe: FAIL Bonk did not cast")
		failed = true
	if not has_empower:
		printerr("BonkoEmpowerContractProbe: FAIL empower tag was not applied")
		failed = true
	if hits_left != 3 or not is_equal_approx(extra_ad_ratio, 1.0):
		printerr("BonkoEmpowerContractProbe: FAIL empower damage metadata is wrong")
		failed = true
	if not is_equal_approx(heal_missing_pct, 0.20) or not block_mana_gain:
		printerr("BonkoEmpowerContractProbe: FAIL empower heal/mana metadata is wrong")
		failed = true
	if ramp_events.size() != 1:
		printerr("BonkoEmpowerContractProbe: FAIL ramp-state telemetry was not emitted once")
		failed = true
	elif String(ramp.get("kind", "")) != "timed_window" or int(ramp.get("stacks", 0)) != 3 or String(ramp.get("reason", "")) != "bonko_empowered_hits":
		printerr("BonkoEmpowerContractProbe: FAIL ramp-state telemetry payload is wrong")
		failed = true

	if failed:
		_finish(engine, 1)
		return
	print("BonkoEmpowerContractProbe: PASS")
	_finish(engine, 0)

func _on_ramp_state_changed(source_team: String, source_index: int, kind: String, stacks: int, value: float, peak_stacks: int, duration_s: float, reason: String, ramp_events: Array[Dictionary]) -> void:
	ramp_events.append({
		"source_team": source_team,
		"source_index": source_index,
		"kind": kind,
		"stacks": stacks,
		"value": value,
		"peak_stacks": peak_stacks,
		"duration_s": duration_s,
		"reason": reason
	})

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var bonko: Unit = _make_unit("bonko", 1000)
	var target: Unit = _make_unit("target_dummy", 1000)
	state.player_team = [bonko]
	state.enemy_team = [target]
	state.player_cds = [0.0]
	state.enemy_cds = [0.0]
	state.player_targets = [0]
	state.enemy_targets = [0]
	state.player_damage_this_round = [0]
	state.enemy_damage_this_round = [0]
	state.player_pupil_map = [-1]
	state.enemy_pupil_map = [-1]
	return state

func _make_unit(unit_id: String, max_hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = String(unit_id)
	unit.name = String(unit_id)
	unit.max_hp = int(max_hp)
	unit.hp = int(max_hp)
	unit.armor = 0.0
	unit.magic_resist = 0.0
	unit.damage_reduction = 0.0
	unit.damage_reduction_flat = 0.0
	return unit

func _finish(engine: CombatEngine, code: int) -> void:
	if engine != null:
		engine.stop()
		engine.teardown()
	_quit(code)

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
