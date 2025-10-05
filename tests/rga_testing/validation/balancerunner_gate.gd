extends Node

# Validation gate: compare the new RGA pipeline 1v1 aggregates against BalanceRunner CSV.
# Usage example:
# godot --headless -s tests/rga_testing/validation/balancerunner_gate.gd -- --repeats=10 --timeout=120 --abilities=false --ids=sari:paisley,nyxa:volt --br_csv=user://balance_matrix.csv

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const BRReader := preload("res://tests/rga_testing/io/br_csv_reader.gd")

@export var use_editor_params: bool = false

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var exit_code := 0
    var args := OS.get_cmdline_args()
    var settings: RGASettings = RGASettings.parse_cli(args)
    var extras := _parse_kv(args)
    var br_csv := String(extras.get("br_csv", ""))
    if settings.ids.is_empty():
        # Fallback fixed sample pairs found in repo tests
        settings.ids = [
            {"a":"sari","b":"paisley"},
            {"a":"nyxa","b":"volt"}
        ]
    var repeats: int = max(1, int(settings.repeats))
    var timeout_s: float = float(settings.timeout_s)
    var abilities: bool = bool(settings.abilities)
    var tol_win := float(extras.get("tol_win_pct", 0.02))     # absolute
    var tol_time := float(extras.get("tol_time_s", 0.10))     # absolute seconds
    var tol_dmg_rel := float(extras.get("tol_damage_rel", 0.03)) # relative (3%)

    if br_csv.strip_edges() == "":
        printerr("Balancerunner Gate: --br_csv=<path> required")
        exit_code = 2
        _quit(exit_code)
        return

    var br_rows: Array[Dictionary] = BRReader.read_rows(br_csv)
    if br_rows.is_empty():
        printerr("Balancerunner Gate: no rows parsed from br_csv=", br_csv)
        exit_code = 2
        _quit(exit_code)
        return

    var all_ok := true
    for pair in settings.ids:
        var a_id := String(pair.get("a",""))
        var b_id := String(pair.get("b",""))
        if a_id == "" or b_id == "":
            continue
        var ours := _run_pair(a_id, b_id, repeats, timeout_s, abilities, int(settings.sim_seed_start))
        var br := _find_br_row(br_rows, a_id, b_id)
        if br.is_empty():
            printerr("Gate: missing BalanceRunner row for ", a_id, " vs ", b_id)
            all_ok = false
            continue
        var ok := _compare_and_print(a_id, b_id, ours, br, tol_win, tol_time, tol_dmg_rel)
        all_ok = all_ok and ok
    exit_code = (0 if all_ok else 1)
    _quit(exit_code)

func _run_pair(a_id: String, b_id: String, repeats: int, timeout_s: float, abilities: bool, seed0: int) -> Dictionary:
    # Aggregate stats in "attacker/defender" orientation
    var stats := {
        "matches_total": 0,
        "a_wins": 0, "b_wins": 0, "draws": 0,
        "a_time_sum": 0.0, "b_time_sum": 0.0,
        "a_damage_sum": 0.0, "b_damage_sum": 0.0
    }
    var idx := 0
    for r in range(repeats):
        # a (attacker) vs b (defender)
        var job1 := DataModels.SimJob.new()
        job1.run_id = "gate"
        job1.sim_index = idx; idx += 1
        job1.seed = seed0 + job1.sim_index
        job1.team_a_ids = [a_id]; job1.team_b_ids = [b_id]
        job1.team_size = 1
        job1.timeout_s = timeout_s
        job1.abilities = abilities
        var sim1 := LockstepSimulator.new()
        var col1 := CombatStatsCollector.new()
        var out1: Dictionary = sim1.run(job1, false, col1)
        _accumulate(stats, out1, true)

        # b (attacker) vs a (defender) - swap sides
        var job2 := DataModels.SimJob.new()
        job2.run_id = "gate"
        job2.sim_index = idx; idx += 1
        job2.seed = seed0 + job2.sim_index
        job2.team_a_ids = [b_id]; job2.team_b_ids = [a_id]
        job2.team_size = 1
        job2.timeout_s = timeout_s
        job2.abilities = abilities
        var sim2 := LockstepSimulator.new()
        var col2 := CombatStatsCollector.new()
        var out2: Dictionary = sim2.run(job2, false, col2)
        _accumulate(stats, out2, false) # false => attacker is team_b in this sim
    return _summarize(stats)

func _accumulate(acc: Dictionary, sim_out: Dictionary, attacker_is_team_a: bool) -> void:
    var outcome = sim_out.get("engine_outcome", null)
    var aggregates: Dictionary = sim_out.get("aggregates", {})
    var teams: Dictionary = aggregates.get("teams", {})
    var a: Dictionary = (teams.get("a", {}) as Dictionary)
    var b: Dictionary = (teams.get("b", {}) as Dictionary)
    acc.matches_total += 1
    var win_side := ""
    if outcome != null:
        win_side = String(outcome.result)
    if win_side == "team_a":
        if attacker_is_team_a:
            acc.a_wins += 1
            acc.a_time_sum += float(outcome.time_s)
        else:
            acc.b_wins += 1
            acc.b_time_sum += float(outcome.time_s)
    elif win_side == "team_b":
        if attacker_is_team_a:
            acc.b_wins += 1
            acc.b_time_sum += float(outcome.time_s)
        else:
            acc.a_wins += 1
            acc.a_time_sum += float(outcome.time_s)
    else:
        acc.draws += 1
    # Damage per match (sum both sides separately)
    var dmg_a := int(a.get("damage", 0))
    var dmg_b := int(b.get("damage", 0))
    if attacker_is_team_a:
        acc.a_damage_sum += dmg_a
        acc.b_damage_sum += dmg_b
    else:
        acc.a_damage_sum += dmg_b
        acc.b_damage_sum += dmg_a

func _summarize(acc: Dictionary) -> Dictionary:
    var total := max(1, int(acc.matches_total))
    var a_wins := int(acc.a_wins)
    var b_wins := int(acc.b_wins)
    return {
        "attacker_win_pct": float(a_wins) / float(total),
        "defender_win_pct": float(b_wins) / float(total),
        "draw_pct": float(int(acc.draws)) / float(total),
        "attacker_avg_time_to_win_s": (float(acc.a_time_sum) / max(1.0, float(a_wins))),
        "defender_avg_time_to_win_s": (float(acc.b_time_sum) / max(1.0, float(b_wins))),
        "attacker_avg_damage_dealt_per_match": (float(acc.a_damage_sum) / float(total)),
        "defender_avg_damage_dealt_per_match": (float(acc.b_damage_sum) / float(total))
    }

func _find_br_row(rows: Array[Dictionary], attacker: String, defender: String) -> Dictionary:
    for r in rows:
        if String(r.get("attacker_id","")) == attacker and String(r.get("defender_id","")) == defender:
            return r
    return {}

func _compare_and_print(attacker: String, defender: String, ours: Dictionary, br: Dictionary, tol_win_abs: float, tol_time_abs: float, tol_dmg_rel: float) -> bool:
    var ok := true
    print("Gate: ", attacker, " vs ", defender)
    ok = _cmp_scalar("attacker_win_pct", ours, br, tol_win_abs, 0.0) and ok
    ok = _cmp_scalar("defender_win_pct", ours, br, tol_win_abs, 0.0) and ok
    ok = _cmp_scalar("attacker_avg_time_to_win_s", ours, br, tol_time_abs, 0.0) and ok
    ok = _cmp_scalar("defender_avg_time_to_win_s", ours, br, tol_time_abs, 0.0) and ok
    ok = _cmp_scalar("attacker_avg_damage_dealt_per_match", ours, br, INF, tol_dmg_rel) and ok
    ok = _cmp_scalar("defender_avg_damage_dealt_per_match", ours, br, INF, tol_dmg_rel) and ok
    if ok:
        print("  PASS")
    return ok

func _cmp_scalar(key: String, ours: Dictionary, br: Dictionary, tol_abs: float, tol_rel: float) -> bool:
    var a := float(ours.get(key, 0.0))
    var b := float(br.get(key, 0.0))
    var diff := abs(a - b)
    var rel := (diff / max(1e-6, abs(b)))
    var pass := (diff <= tol_abs) or (rel <= tol_rel)
    if not pass:
        printerr("  ", key, ": ours=", a, " br=", b, " diff=", diff)
    else:
        print("  ", key, ": ours=", a, " br=", b)
    return pass

func _parse_kv(argv: PackedStringArray) -> Dictionary:
    var out := {}
    var seen_sep := false
    for a in argv:
        if a == "--":
            seen_sep = true
            continue
        var s := String(a)
        if (not seen_sep) and (not s.contains("=")):
            continue
        var parts := s.split("=", false, 2)
        if parts.size() == 2:
            out[parts[0].lstrip("-")] = parts[1]
    return out

func _quit(code: int) -> void:
    if get_tree():
        get_tree().quit(code)

