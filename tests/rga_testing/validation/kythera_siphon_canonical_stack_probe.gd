extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const KytheraSiphon := preload("res://scripts/game/abilities/impls/kythera_siphon.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
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
		printerr("KytheraSiphonCanonicalStackProbe: FAIL missing BuffSystem")
		failed = true
	if engine.ability_system == null:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL missing AbilitySystem")
		failed = true
	if failed:
		_finish(engine, 1)
		return

	var kythera: Unit = state.player_team[0]
	var target: Unit = state.enemy_team[0]
	var expected_stacks: int = 6
	var expected_per_sec: int = 3
	var expected_total_gain: int = expected_per_sec * 3
	var before_mr: float = float(kythera.magic_resist)

	var stack_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.AEGIS, expected_stacks)
	if not bool(stack_res.get("processed", false)):
		printerr("KytheraSiphonCanonicalStackProbe: FAIL could not add canonical Aegis stacks")
		_finish(engine, 1)
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31415
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = KytheraSiphon.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))
	var tag: Dictionary = engine.buff_system.get_tag(state, "player", 0, BuffTags.TAG_KYTHERA)
	var meta: Dictionary = tag.get("data", {}) if tag is Dictionary else {}
	var per_sec: int = int(meta.get("per_sec", 0))

	engine.ability_system.tick(3.1)

	var canonical_stacks: int = int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.AEGIS))
	var legacy_stacks: int = int(engine.buff_system.get_stack(state, "player", 0, "aegis_stacks"))
	var siphon_stack: int = int(engine.buff_system.get_stack(state, "player", 0, "kythera_siphon_mr"))
	var after_mr: float = float(kythera.magic_resist)
	var target_after_mr: float = float(target.magic_resist)
	var mr_gain: int = int(round(after_mr - before_mr))

	print("KytheraSiphonCanonicalStackProbe: cast_ok=", cast_ok,
		" canonical_stacks=", canonical_stacks,
		" legacy_stacks=", legacy_stacks,
		" per_sec=", per_sec,
		" siphon_stack=", siphon_stack,
		" mr_gain=", mr_gain,
		" target_after_mr=", target_after_mr)

	if not cast_ok:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL Siphon did not cast")
		failed = true
	if canonical_stacks != expected_stacks:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL canonical Aegis stack count changed")
		failed = true
	if legacy_stacks != 0:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL probe unexpectedly used legacy Aegis stacks")
		failed = true
	if per_sec != expected_per_sec:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL Siphon did not consume canonical Aegis stacks")
		failed = true
	if siphon_stack != 1:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL Siphon end did not apply permanent MR stack")
		failed = true
	if mr_gain != expected_total_gain:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL Siphon permanent MR gain was wrong")
		failed = true
	if target_after_mr >= 50.0:
		printerr("KytheraSiphonCanonicalStackProbe: FAIL Siphon ticks did not drain target MR")
		failed = true

	if failed:
		_finish(engine, 1)
		return
	print("KytheraSiphonCanonicalStackProbe: PASS")
	_finish(engine, 0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var kythera: Unit = _make_unit("kythera", 1000)
	kythera.magic_resist = 20.0
	kythera.spell_power = 0.0
	var target: Unit = _make_unit("target_dummy", 1000)
	target.magic_resist = 50.0
	state.player_team = [kythera]
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
