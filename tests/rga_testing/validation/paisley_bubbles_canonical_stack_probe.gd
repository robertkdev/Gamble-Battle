extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const PaisleyBubbles := preload("res://scripts/game/abilities/impls/paisley_bubbles.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

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
	engine.set_arena(
		72.0,
		[Vector2(100.0, 140.0), Vector2(90.0, 90.0), Vector2(90.0, 190.0)],
		[Vector2(260.0, 120.0), Vector2(280.0, 190.0)],
		Rect2(0.0, 0.0, 900.0, 360.0)
	)
	engine.start()

	var failed: bool = false
	if engine.buff_system == null:
		printerr("PaisleyBubblesCanonicalStackProbe: FAIL missing BuffSystem")
		failed = true
	if failed:
		_finish(engine, 1)
		return

	var expected_kalei: int = 3
	var expected_arca: int = 2
	var expected_shield: int = 80 + (10 * expected_kalei) + (8 * expected_arca)
	var expected_total_damage: int = 110 + (12 * expected_kalei) + (8 * expected_arca)
	var expected_split_damage: int = int(floor(float(expected_total_damage) * 0.5))
	var enemy0_before_hp: int = int(state.enemy_team[0].hp)
	var enemy1_before_hp: int = int(state.enemy_team[1].hp)

	var kalei_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.KALEIDOSCOPE, expected_kalei)
	var arca_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.ARCANIST, expected_arca)
	if not bool(kalei_res.get("processed", false)) or not bool(arca_res.get("processed", false)):
		printerr("PaisleyBubblesCanonicalStackProbe: FAIL could not add canonical stacks")
		_finish(engine, 1)
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 16180
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = PaisleyBubbles.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))

	var canonical_kalei: int = int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.KALEIDOSCOPE))
	var canonical_arca: int = int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.ARCANIST))
	var legacy_kalei: int = int(engine.buff_system.get_stack(state, "player", 0, "kaleidoscope_stacks"))
	var legacy_arca: int = int(engine.buff_system.get_stack(state, "player", 0, "arcanist_stacks"))
	var caster_shield: int = int(state.player_team[0].ui_shield)
	var ally1_shield: int = int(state.player_team[1].ui_shield)
	var ally2_shield: int = int(state.player_team[2].ui_shield)
	var enemy0_damage: int = enemy0_before_hp - int(state.enemy_team[0].hp)
	var enemy1_damage: int = enemy1_before_hp - int(state.enemy_team[1].hp)

	print("PaisleyBubblesCanonicalStackProbe: cast_ok=", cast_ok,
		" canonical_kalei=", canonical_kalei,
		" canonical_arca=", canonical_arca,
		" legacy_kalei=", legacy_kalei,
		" legacy_arca=", legacy_arca,
		" caster_shield=", caster_shield,
		" ally1_shield=", ally1_shield,
		" ally2_shield=", ally2_shield,
		" enemy0_damage=", enemy0_damage,
		" enemy1_damage=", enemy1_damage,
		" expected_shield=", expected_shield,
		" expected_split_damage=", expected_split_damage)

	if not cast_ok:
		printerr("PaisleyBubblesCanonicalStackProbe: FAIL Bubbles did not cast")
		failed = true
	if canonical_kalei != expected_kalei or canonical_arca != expected_arca:
		printerr("PaisleyBubblesCanonicalStackProbe: FAIL canonical stack count changed")
		failed = true
	if legacy_kalei != 0 or legacy_arca != 0:
		printerr("PaisleyBubblesCanonicalStackProbe: FAIL probe unexpectedly used legacy stacks")
		failed = true
	if caster_shield != 0 or ally1_shield != expected_shield or ally2_shield != expected_shield:
		printerr("PaisleyBubblesCanonicalStackProbe: FAIL Bubbles did not consume canonical stacks for shields")
		failed = true
	if enemy0_damage != expected_split_damage or enemy1_damage != expected_total_damage - expected_split_damage:
		printerr("PaisleyBubblesCanonicalStackProbe: FAIL Bubbles did not consume canonical stacks for damage")
		failed = true

	if failed:
		_finish(engine, 1)
		return
	print("PaisleyBubblesCanonicalStackProbe: PASS")
	_finish(engine, 0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var paisley: Unit = _make_unit("paisley", 1000)
	paisley.level = 1
	paisley.spell_power = 0.0
	var ally1: Unit = _make_unit("ally_low", 1000)
	ally1.hp = 400
	var ally2: Unit = _make_unit("ally_mid", 1000)
	ally2.hp = 500
	var enemy0: Unit = _make_unit("enemy_front", 1000)
	var enemy1: Unit = _make_unit("enemy_back", 1000)
	state.player_team = [paisley, ally1, ally2]
	state.enemy_team = [enemy0, enemy1]
	state.player_cds = [0.0, 0.0, 0.0]
	state.enemy_cds = [0.0, 0.0]
	state.player_targets = [0, 0, 0]
	state.enemy_targets = [0, 0]
	state.player_damage_this_round = [0, 0, 0]
	state.enemy_damage_this_round = [0, 0]
	state.player_pupil_map = [-1, -1, -1]
	state.enemy_pupil_map = [-1, -1]
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
