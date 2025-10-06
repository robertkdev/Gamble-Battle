extends Node

# MovementTest
# Verifies key movement behaviors:
# 1) If a unit is within attack range of its target, it should not step.
# 2) If a unit is out of range, it should move closer toward the target.

const BattleState := preload("res://scripts/game/combat/battle_state.gd")
const Unit := preload("res://scripts/unit.gd")
const MovementService := preload("res://scripts/game/combat/movement/movement_service.gd")

var _passes: int = 0
var _fails: int = 0

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    _test_stops_when_in_range()
    _test_moves_when_out_of_range()
    var total := _passes + _fails
    if _fails == 0:
        print("MovementTest: PASS (", _passes, "/", total, ")")
        if get_tree():
            get_tree().quit(0)
    else:
        printerr("MovementTest: FAIL (", _fails, " of ", total, ")")
        if get_tree():
            get_tree().quit(1)

func _resolve_target(team: String, idx: int) -> int:
    # Single-opponent test: always target index 0 on the opposing team
    return 0

func _build_basic_state(attacker_range_tiles: int, attacker_speed: float, defender_speed: float) -> Dictionary:
    var state := BattleState.new()
    var attacker := Unit.new()
    attacker.max_hp = 100
    attacker.hp = 100
    attacker.attack_range = attacker_range_tiles
    attacker.move_speed = attacker_speed
    var defender := Unit.new()
    defender.max_hp = 100
    defender.hp = 100
    defender.attack_range = attacker_range_tiles
    defender.move_speed = defender_speed
    state.player_team = [attacker]
    state.enemy_team = [defender]
    state.player_cds = BattleState.fill_cds_for(state.player_team)
    state.enemy_cds = BattleState.fill_cds_for(state.enemy_team)
    state.player_targets = [0]
    state.enemy_targets = [0]
    return {
        "state": state,
        "attacker": attacker,
        "defender": defender
    }

func _new_arena(ts: float, ppos: Vector2, epos: Vector2, w: float = 1000.0, h: float = 1000.0):
    var arena = MovementService.new()
    var bounds := Rect2(Vector2.ZERO, Vector2(w, h))
    arena.configure(ts, [ppos], [epos], bounds)
    return arena

func _test_stops_when_in_range() -> void:
    # Setup: distance inside attack range but outside collision radius.
    var ts := 96.0
    var data := _build_basic_state(1, 120.0, 0.0) # defender immobile
    var state: BattleState = data.state
    var start_p := Vector2(200, 200)
    var start_e := Vector2(280, 200) # 80px apart; range ~ 96 * band(1.05) = ~100.8
    var arena = _new_arena(ts, start_p, start_e)
    var resolver := Callable(self, "_resolve_target")
    arena.update_movement(state, 0.05, resolver)
    var p_after: Vector2 = arena.get_player_position(0)
    var moved_dist := p_after.distance_to(start_p)
    # Expect essentially no movement (<= 0.1 px tolerance)
    if moved_dist <= 0.1:
        _passes += 1
        print("Test 1 (stop in range): PASS  Δ=", moved_dist)
    else:
        _fails += 1
        printerr("Test 1 (stop in range): FAIL  Δ=", moved_dist)

func _test_moves_when_out_of_range() -> void:
    # Setup: distance larger than attack range; expect to close distance.
    var ts := 96.0
    var data := _build_basic_state(1, 120.0, 0.0) # defender immobile
    var state: BattleState = data.state
    var start_p := Vector2(200, 200)
    var start_e := Vector2(420, 200) # 220px apart (> range)
    var arena = _new_arena(ts, start_p, start_e)
    var resolver := Callable(self, "_resolve_target")
    var dist_before := start_p.distance_to(start_e)
    arena.update_movement(state, 0.1, resolver)
    var p_after: Vector2 = arena.get_player_position(0)
    var new_dist := p_after.distance_to(start_e)
    if new_dist < dist_before:
        _passes += 1
        print("Test 2 (approach out of range): PASS  ", dist_before, " -> ", new_dist)
    else:
        _fails += 1
        printerr("Test 2 (approach out of range): FAIL  ", dist_before, " -> ", new_dist)

