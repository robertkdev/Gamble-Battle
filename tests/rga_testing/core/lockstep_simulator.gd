extends RefCounted
class_name LockstepSimulator

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const OpenFieldScenario = preload("res://tests/rga_testing/scenarios/open_field_scenario.gd")
const BattleState = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngine = preload("res://scripts/game/combat/combat_engine.gd")

# Runs a single SimJob through the CombatEngine in deterministic lockstep.
# Optionally accepts a base stats collector that will be attached and ticked during the run.
# Returns: { context, engine_outcome, aggregates?, events? }
func run(job: DataModels.SimJob, collect_events: bool = false, collector = null) -> Dictionary:
    var result: Dictionary = {"context": null, "engine_outcome": null, "events": []}
    if job == null:
        return result

    # Scenario setup
    var state: BattleState = BattleState.new()
    state.reset()
    state.stage = 1
    var scen: OpenFieldScenario = OpenFieldScenario.new()
    var info: Dictionary = scen.make(state, job.team_a_ids, job.team_b_ids, job.map_params)

    # Engine setup
    var engine: CombatEngine = CombatEngine.new()
    engine.abilities_enabled = bool(job.abilities)
    engine.deterministic_rolls = true
    engine.alternate_order = bool(job.alternate_order)
    engine.configure(state, BattleState.first_alive(state.player_team), 1, Callable())

    # Apply arena
    var tile_size: float = float(info.get("tile_size", 1.0))
    var ppos: Array = info.get("player_positions", [])
    var epos: Array = info.get("enemy_positions", [])
    var bounds: Rect2 = info.get("bounds", Rect2())
    engine.set_arena(tile_size, ppos, epos, bounds)

    # Optional projectile->hit bridging for tests that ignore projectile flight
    if bool(job.bridge_projectile_to_hit):
        engine.projectile_fired.connect(func(team: String, sidx: int, tidx: int, dmg: int, crit: bool):
            engine.on_projectile_hit(team, sidx, tidx, dmg, crit)
        )

    # Seed the engine RNG after configure to override any randomize()
    if engine.rng != null and int(job.seed) != 0:
        engine.rng.seed = int(job.seed)

    # Outcome capture
    var outcome_str := ""
    engine.victory.connect(func(_stage: int): if outcome_str == "": outcome_str = "team_a")
    engine.defeat.connect(func(_stage: int): if outcome_str == "": outcome_str = "team_b")

    # Optional event capture
    var events: Array = []
    var sim_time := 0.0
    if collect_events:
        var add_evt = func(kind: String, data: Dictionary, t: float):
            events.append({"t_s": t, "kind": kind, "data": data})
        engine.hit_applied.connect(func(team: String, sidx: int, tidx: int, rolled: int, dealt: int, crit: bool, bhp: int, ahp: int, _pcd: float, _ecd: float):
            add_evt.call("hit_applied", {"team": team, "sidx": sidx, "tidx": tidx, "rolled": rolled, "dealt": dealt, "crit": crit, "before_hp": bhp, "after_hp": ahp}, sim_time)
        )
        if engine.has_signal("heal_applied"):
            engine.heal_applied.connect(func(st: String, si: int, tt: String, ti: int, healed: int, overheal: int, bhp: int, ahp: int):
                add_evt.call("heal_applied", {"st": st, "si": si, "tt": tt, "ti": ti, "healed": healed, "overheal": overheal, "before_hp": bhp, "after_hp": ahp}, sim_time)
            )
        if engine.has_signal("shield_absorbed"):
            engine.shield_absorbed.connect(func(tt: String, ti: int, absorbed: int):
                add_evt.call("shield_absorbed", {"tt": tt, "ti": ti, "absorbed": absorbed}, sim_time)
            )
        if engine.has_signal("hit_mitigated"):
            engine.hit_mitigated.connect(func(st: String, si: int, tt: String, ti: int, pre_mit: int, post_pre_shield: int):
                add_evt.call("hit_mitigated", {"st": st, "si": si, "tt": tt, "ti": ti, "pre_mit": pre_mit, "post_pre_shield": post_pre_shield}, sim_time)
            )
        if engine.has_signal("hit_overkill"):
            engine.hit_overkill.connect(func(st: String, si: int, tt: String, ti: int, overkill: int):
                add_evt.call("hit_overkill", {"st": st, "si": si, "tt": tt, "ti": ti, "overkill": overkill}, sim_time)
            )
        if engine.has_signal("hit_components"):
            engine.hit_components.connect(func(st: String, si: int, tt: String, ti: int, phys: int, mag: int, tru: int):
                add_evt.call("hit_components", {"st": st, "si": si, "tt": tt, "ti": ti, "phys": phys, "mag": mag, "tru": tru}, sim_time)
            )
        if engine.has_signal("cc_applied"):
            engine.cc_applied.connect(func(st: String, si: int, tt: String, ti: int, kind: String, dur: float):
                add_evt.call("cc_applied", {"st": st, "si": si, "tt": tt, "ti": ti, "kind": kind, "dur": dur}, sim_time)
            )

    # Run loop
    var delta_s: float = max(0.001, float(job.delta_s))
    # Attach collector if provided (player side corresponds to team A in this simulator)
    if collector != null and collector.has_method("attach"):
        collector.attach(engine, state, true)
    engine.start()
    while outcome_str == "" and sim_time < float(job.timeout_s):
        engine.process(delta_s)
        if collector != null and collector.has_method("tick"):
            collector.tick(delta_s)
        sim_time += delta_s
        var a_alive := _alive_count(state.player_team)
        var b_alive := _alive_count(state.enemy_team)
        if a_alive <= 0:
            outcome_str = "team_b"
            break
        if b_alive <= 0:
            outcome_str = "team_a"
            break

    # Outcome and survivors
    var outcome := DataModels.EngineOutcome.new()
    if outcome_str == "":
        outcome.result = "timeout"
    else:
        outcome.result = outcome_str
    outcome.time_s = sim_time
    outcome.frames = int(round(sim_time / delta_s))
    outcome.team_a_alive = _alive_count(state.player_team)
    outcome.team_b_alive = _alive_count(state.enemy_team)

    # Context
    var ctx := DataModels.MatchContext.new()
    ctx.run_id = String(job.run_id)
    ctx.sim_index = int(job.sim_index)
    ctx.sim_seed = int(job.seed)
    ctx.engine_version = ""  # optional (filled by provenance later)
    ctx.asset_hash = ""
    ctx.scenario_id = String(job.scenario_id)
    ctx.map_id = String(info.get("map_id", "open_field_basic"))
    ctx.map_params = job.map_params.duplicate()
    ctx.team_a_ids = job.team_a_ids.duplicate()
    ctx.team_b_ids = job.team_b_ids.duplicate()
    ctx.team_size = int(job.team_size)
    ctx.tile_size = tile_size
    ctx.arena_bounds = bounds
    ctx.spawn_a = ppos.duplicate()
    ctx.spawn_b = epos.duplicate()
    ctx.capabilities = job.capabilities.duplicate()

    # Aggregates from collector (if any)
    if collector != null and collector.has_method("finalize") and collector.has_method("result"):
        collector.finalize(sim_time)
        result["aggregates"] = collector.result()
    if collector != null and collector.has_method("detach"):
        collector.detach()

    result["context"] = ctx
    result["engine_outcome"] = outcome
    result["events"] = (events if collect_events else [])
    return result

func _alive_count(team: Array) -> int:
    var n := 0
    for u in team:
        if u and u.is_alive():
            n += 1
    return n

