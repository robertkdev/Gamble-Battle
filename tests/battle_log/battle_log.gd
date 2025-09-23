extends Node

# Test 1: What went wrong — single battle log with minimal prints.
# Logs only:
# - attack: t, unit (id), damage rolled, target (id)
# - damage: t, unit (id) taking damage, amount dealt, from (id)
# - winner: "win player" or "win enemy"

var tick: float = 0.05
var max_frames: int = 2000

func _ready() -> void:
    _run_battle()
    get_tree().quit(0)

func _run_battle() -> void:
    var state: BattleState = load("res://scripts/game/combat/battle_state.gd").new()
    state.reset()
    state.stage = 1

    # Build teams using UnitFactory (actual game logic)
    var uf = load("res://scripts/unit_factory.gd")
    var p1: Unit = uf.spawn("sari")
    var p2: Unit = uf.spawn("paisley")
    var e1: Unit = uf.spawn("nyxa")
    var e2: Unit = uf.spawn("volt")
    state.player_team = [p1, p2]
    state.enemy_team = [e1, e2]
    for u in state.player_team:
        if u: u.heal_to_full(); u.mana = u.mana_start
    for u in state.enemy_team:
        if u: u.heal_to_full(); u.mana = u.mana_start

    var engine: CombatEngine = load("res://scripts/game/combat/combat_engine.gd").new()
    var outcome := ""
    # Use engine randomness for starting side; alternate order on to enable coin flip
    engine.alternate_order = true
    engine.simultaneous_pairs = false
    engine.deterministic_rolls = true
    engine.configure(state, state.player_team[0], 1)

    var sim_time := 0.0
    engine.hit_applied.connect(func(team: String, si: int, ti: int, rolled: int, dealt: int, _crit: bool, _bhp: int, _ahp: int, _pcd: float, _ecd: float):
        var src: Unit = (state.player_team[si] if team == "player" else state.enemy_team[si])
        var tgt: Unit = (state.enemy_team[ti] if team == "player" else state.player_team[ti])
        var sid := (src.id if src else "?")
        var tid := (tgt.id if tgt else "?")
        print("attack t=", String.num(sim_time, 2), " unit=", sid, " dmg=", rolled, " target=", tid)
        print("damage t=", String.num(sim_time, 2), " unit=", tid, " amt=", dealt, " from=", sid)
    )
    engine.victory.connect(func(_s): if outcome == "": outcome = "player"; print("win player"))
    engine.defeat.connect(func(_s): if outcome == "": outcome = "enemy"; print("win enemy"))

    engine.start()
    var frames := 0
    while outcome == "" and frames < max_frames:
        engine.process(tick)
        sim_time += tick
        frames += 1

