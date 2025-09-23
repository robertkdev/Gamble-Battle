extends Node

# Test 2: Long-term average assessment — run identical combat many times and report win rates.

var runs: int = 2300
var tick: float = 0.05
var max_frames: int = 200

func _ready() -> void:
    var a_wins: int = 0
    var b_wins: int = 0
    for i in range(runs):
        var outcome := _run_one()
        if outcome == "A":
            a_wins += 1
        elif outcome == "B":
            b_wins += 1
    var total: int = max(1, a_wins + b_wins)
    var a_pct: float = (float(a_wins) * 100.0) / float(total)
    var b_pct: float = (float(b_wins) * 100.0) / float(total)
    print("Longrun 1v1 sari vs sari runs=", runs, ": A=", String.num(a_pct, 1), "% B=", String.num(b_pct, 1), "%")
    get_tree().quit(0)

func _run_one() -> String:
    var state: BattleState = load("res://scripts/game/combat/battle_state.gd").new()
    state.reset()
    state.stage = 1
    var uf = load("res://scripts/unit_factory.gd")
    var a: Unit = uf.spawn("sari")
    var b: Unit = uf.spawn("sari")
    if not a or not b:
        return ""
    a.heal_to_full(); b.heal_to_full()
    a.mana = a.mana_start; b.mana = b.mana_start
    state.player_team = [a]
    state.enemy_team = [b]
    var engine: CombatEngine = load("res://scripts/game/combat/combat_engine.gd").new()
    var outcome := ""
    engine.alternate_order = true
    engine.simultaneous_pairs = false
    engine.deterministic_rolls = true
    engine.victory.connect(func(_s): if outcome == "": outcome = "A")
    engine.defeat.connect(func(_s): if outcome == "": outcome = "B")
    engine.configure(state, a, 1)
    engine.start()
    var frames := 0
    while outcome == "" and frames < max_frames:
        engine.process(tick)
        frames += 1
    if outcome != "":
        return outcome
    # Fallback: decide by survivor/HP if no signal yet (keeps test self-contained)
    var a_alive := a.is_alive()
    var b_alive := b.is_alive()
    if a_alive and not b_alive:
        return "A"
    elif b_alive and not a_alive:
        return "B"
    elif not a_alive and not b_alive:
        # Tie-break by first cooldowns
        var p_cd: float = (state.player_cds[0] if state.player_cds.size() > 0 else 9999.0)
        var e_cd: float = (state.enemy_cds[0] if state.enemy_cds.size() > 0 else 9999.0)
        return ("A" if p_cd <= e_cd else "B")
    # Both alive: higher HP wins
    return ("A" if int(a.hp) >= int(b.hp) else "B")

