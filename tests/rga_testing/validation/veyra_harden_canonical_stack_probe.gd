extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: BattleState = _make_state()
	var engine: CombatEngine = CombatEngineScript.new()
	engine.configure(state, state.player_team[0], 1, Callable())

	var failed: bool = false
	if engine.buff_system == null:
		printerr("VeyraHardenCanonicalStackProbe: FAIL missing BuffSystem")
		failed = true
	if engine.ability_system == null:
		printerr("VeyraHardenCanonicalStackProbe: FAIL missing AbilitySystem")
		failed = true
	if failed:
		_finish(engine, 1)
		return

	var veyra: Unit = state.player_team[0]
	var before_max_hp: int = int(veyra.max_hp)
	var expected_stacks: int = 4
	var expected_gain: int = int(floor(float(before_max_hp) * (float(expected_stacks) * 0.01)))

	var stack_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.AEGIS, expected_stacks)
	if not bool(stack_res.get("processed", false)):
		printerr("VeyraHardenCanonicalStackProbe: FAIL could not add canonical Aegis stacks")
		_finish(engine, 1)
		return

	engine.ability_system.schedule_event("veyra_harden_end", "player", 0, 0.0, {})
	engine.ability_system.tick(0.1)

	var canonical_stacks: int = int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.AEGIS))
	var legacy_stacks: int = int(engine.buff_system.get_stack(state, "player", 0, "aegis_stacks"))
	var harden_stack: int = int(engine.buff_system.get_stack(state, "player", 0, "veyra_harden_hp"))
	var after_max_hp: int = int(veyra.max_hp)

	print("VeyraHardenCanonicalStackProbe: canonical_stacks=", canonical_stacks,
		" legacy_stacks=", legacy_stacks,
		" harden_stack=", harden_stack,
		" before_max_hp=", before_max_hp,
		" after_max_hp=", after_max_hp,
		" expected_gain=", expected_gain)

	if canonical_stacks != expected_stacks:
		printerr("VeyraHardenCanonicalStackProbe: FAIL canonical Aegis stack count changed")
		failed = true
	if legacy_stacks != 0:
		printerr("VeyraHardenCanonicalStackProbe: FAIL probe unexpectedly used legacy Aegis stacks")
		failed = true
	if harden_stack != 1:
		printerr("VeyraHardenCanonicalStackProbe: FAIL Harden end did not apply permanent max-HP stack")
		failed = true
	if after_max_hp != before_max_hp + expected_gain:
		printerr("VeyraHardenCanonicalStackProbe: FAIL Harden end did not consume canonical Aegis stacks")
		failed = true

	if failed:
		_finish(engine, 1)
		return
	print("VeyraHardenCanonicalStackProbe: PASS")
	_finish(engine, 0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var veyra: Unit = _make_unit("veyra", 1000)
	var target: Unit = _make_unit("target_dummy", 1000)
	state.player_team = [veyra]
	state.enemy_team = [target]
	state.player_cds = [0.0]
	state.enemy_cds = [0.0]
	state.player_targets = [0]
	state.enemy_targets = [0]
	return state

func _make_unit(unit_id: String, max_hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = unit_id
	unit.name = unit_id
	unit.max_hp = max_hp
	unit.hp = max_hp
	return unit

func _finish(engine: CombatEngine, code: int) -> void:
	if engine != null:
		engine.teardown()
	_quit(code)

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
