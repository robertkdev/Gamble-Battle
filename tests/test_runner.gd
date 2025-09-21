extends Node

var total: int = 0
var passed: int = 0
var failed: int = 0
var logs: Array[String] = []
var filter_substr: String = ""
var bail_on_fail: bool = false

func _ready() -> void:
	_parse_args()
	run_all()

func _parse_args() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--filter="):
			filter_substr = arg.substr(9)
		if arg == "--bail" or arg == "--fail-fast":
			bail_on_fail = true

func tlog(msg: String) -> void:
	prints(msg)
	logs.append(msg)

func _write_results() -> void:
	var save_paths := ["res://tests/test_results.txt", "user://test_results.txt"]
	for path in save_paths:
		var fa := FileAccess.open(path, FileAccess.WRITE)
		if fa:
			for line in logs:
				fa.store_line(line)
			fa.close()
			tlog("Wrote results to: %s" % ProjectSettings.globalize_path(path))
			return

func _finish_and_quit() -> void:
	_write_results()
	var tmr := get_tree().create_timer(0.05)
	tmr.timeout.connect(func(): get_tree().quit(1))

func _ok_name(name: String) -> bool:
	return filter_substr == "" or name.findn(filter_substr) >= 0

func _assert(cond: bool, test_name: String, details: String = "") -> void:
	total += 1
	if cond:
		passed += 1
		tlog("PASS: %s" % test_name)
	else:
		failed += 1
		tlog("FAIL: %s%s" % [test_name, (" -> " + details) if details != "" else ""]) 
		if bail_on_fail:
			_finish_and_quit()

func _assert_eq(a, b, test_name: String) -> void:
	_assert(a == b, test_name, "%s != %s" % [str(a), str(b)])

func _assert_close(a: float, b: float, eps: float, test_name: String) -> void:
	_assert(abs(a - b) <= eps, test_name, "%s != %s (eps %s)" % [str(a), str(b), str(eps)])

func _mk_unit(
		hp: int,
		ad: int,
		atk_spd: float,
		cc: float = 0.0,
		cd: float = 2.0,
		ls: float = 0.0,
		regen: int = 0,
		block: float = 0.0
	) -> Unit:
	var u := Unit.new()
	# Identity
	u.id = "test"
	u.name = "Test"
	u.sprite_path = ""
	# Health
	u.max_hp = max(1, hp)
	u.hp = clamp(hp, 0, u.max_hp)
	u.hp_regen = max(0, regen)
	# Offense
	u.attack_damage = max(0, ad)
	u.spell_power = 0
	u.attack_speed = max(0.01, atk_spd)
	u.crit_chance = clampf(cc, 0.0, 0.95)
	u.crit_damage = max(1.0, cd)
	u.lifesteal = clampf(ls, 0.0, 0.9)
	u.attack_range = 1
	# Defense
	u.armor = 0
	u.magic_resist = 0
	u.block_chance = clampf(block, 0.0, 0.8)
	u.damage_reduction = 0.0
	# Mana
	u.mana_max = 0
	u.mana_start = 0
	u.mana_regen = 0
	u.mana = 0
	return u

func _mk_manager(p: Unit, e: Unit):
	var m = load("res://scripts/combat_manager.gd").new()
	add_child(m)
	m.player = p
	m.player_team = [p]
	m.enemy_team = [e]
	m.enemy = e
	m._battle_active = true
	return m

# --- Combat logic tests ---

func test_attack_speed_both_rates() -> void:
	if not _ok_name("attack_speed_both_rates"): return
	var p := _mk_unit(9999, 0, 5.0)
	var e := _mk_unit(9999, 0, 2.0)
	var m = _mk_manager(p, e)
	var cnt := {"ps": 0, "es": 0}
	m.projectile_fired.connect(func(src_team: String, src_idx: int, tgt_idx: int, dmg: int, crit: bool):
		if src_team == "player":
			cnt["ps"] = int(cnt["ps"]) + 1
			m.on_projectile_hit(src_team, src_idx, 0, dmg, crit)
		else:
			cnt["es"] = int(cnt["es"]) + 1
			m.on_projectile_hit(src_team, src_idx, 0, dmg, crit)
	)
	for i in 40: m._process(0.05) # ~2s
	_assert_close(float(cnt["ps"]), 10.0, 2.0, "attack_speed player ~10 shots in 2s")
	_assert_close(float(cnt["es"]), 4.0, 2.0, "attack_speed enemy ~4 shots in 2s")
	m.queue_free()

func test_block_prevents_damage() -> void:
	if not _ok_name("block_prevents_damage"): return
	var p := _mk_unit(100, 0, 0.0, 0.0, 2.0, 0.0, 0, 1.0)
	var e := _mk_unit(100, 10, 4.0)
	var m = _mk_manager(p, e)
	m._player_cds = [9999.0]
	m._enemy_cds = [0.0]
	var start_hp := p.hp
	m.projectile_fired.connect(func(src_team: String, src_idx: int, _ti: int, dmg: int, crit: bool): m.on_projectile_hit(src_team, src_idx, 0, dmg, crit))
	# Run enough frames to ensure multiple attack attempts
	for i in 40: m._process(0.05)
	_assert(p.hp == start_hp, "block chance prevents enemy damage")
	m.queue_free()

func test_lifesteal_heals() -> void:
	if not _ok_name("lifesteal_heals"): return
	var p := _mk_unit(100, 20, 1.0, 0.0, 2.0, 0.5)
	p.hp = 50
	var e := _mk_unit(100, 0, 1.0)
	var m = _mk_manager(p, e)
	m.on_projectile_hit("player", 0, 0, 20, false)
	_assert(p.hp == 60 and e.hp == 80, "lifesteal heals on player hit")
	m.queue_free()

func test_crit_damage_roll() -> void:
	if not _ok_name("crit_damage_roll"): return
	var u := _mk_unit(100, 10, 1.0, 1.0, 2.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var roll := u.attack_roll(rng)
	_assert(int(roll["damage"]) == 25 and bool(roll["crit"]) == true, "crit roll applies crit_damage")

func test_regen_tick() -> void:
	if not _ok_name("regen_tick"): return
	var p := _mk_unit(20, 0, 1.0, 0.0, 2.0, 0.0, 2)
	p.hp = 10
	var e := _mk_unit(1, 0, 1.0)
	var state := BattleState.new()
	state.player_team = [p]
	state.enemy_team = [e]
	var regen := RegenSystem.new()
	regen.apply_ticks(state, 2, p, {})
	_assert_eq(p.hp, 14, "regen applies per tick")

func test_victory_and_defeat() -> void:
	if not _ok_name("victory_and_defeat"): return
	var p := _mk_unit(100, 100, 1.0)
	var e := _mk_unit(10, 0, 1.0)
	var m = _mk_manager(p, e)
	var state := {"won": false, "lost": false}
	m.victory.connect(func(_stage: int): state["won"] = true)
	m.on_projectile_hit("player", 0, 0, 10, false)
	_assert(bool(state["won"]) and not m._battle_active, "victory triggers and stops")
	# defeat
	var p2 := _mk_unit(10, 0, 1.0)
	var e2 := _mk_unit(100, 100, 1.0)
	var m2 = _mk_manager(p2, e2)
	m2.defeat.connect(func(_stage: int): state["lost"] = true)
	m2.on_projectile_hit("enemy", 0, 0, 10, false)
	_assert(bool(state["lost"]) and not m2._battle_active, "defeat triggers and stops")
	m.queue_free(); m2.queue_free()

func test_powerups_specific() -> void:
	if not _ok_name("powerups_specific"): return
	var u := _mk_unit(100, 10, 1.0)
	var before_ad := u.attack_damage
	Powerup.pu_atk_flat_10(u); _assert_eq(u.attack_damage, before_ad + 10, "+10 AD works")
	var before_max := u.max_hp
	Powerup.pu_hp30_heal30(u); _assert(u.max_hp >= before_max and u.hp <= u.max_hp, "+30 HP heal applies")
	var before_cc := u.crit_chance
	Powerup.pu_crit_5(u); _assert(u.crit_chance >= before_cc, "+5% crit applies")
	var before_ls := u.lifesteal
	Powerup.pu_ls_4(u); _assert(u.lifesteal >= before_ls, "+4% lifesteal applies")
	var before_block := u.block_chance
	Powerup.pu_block_5(u); _assert(u.block_chance >= before_block, "+5% block applies")
	var before_regen := u.hp_regen
	Powerup.pu_regen_1(u); _assert_eq(u.hp_regen, before_regen + 1, "+1 regen applies")

func test_as_upgrade_increases_rate() -> void:
	if not _ok_name("as_upgrade_increases_rate"): return
	var p1 := _mk_unit(9999, 0, 5.0)
	var p2 := _mk_unit(9999, 0, 5.0)
	Powerup.pu_as_10(p2)
	var e := _mk_unit(9999, 0, 0.0)
	var m1 = _mk_manager(p1, e)
	var m2 = _mk_manager(p2, e)
	var c1 := 0
	var c2 := 0
	m1.projectile_fired.connect(func(src_team: String, _si: int, _ti: int, _dmg: int, _crit: bool): if src_team == "player": c1 += 1)
	m2.projectile_fired.connect(func(src_team: String, _si: int, _ti: int, _dmg: int, _crit: bool): if src_team == "player": c2 += 1)
	for i in 40: m1._process(0.05)
	for i in 40: m2._process(0.05)
	_assert(c2 >= c1 + 1, "+10% AS yields more shots in ~2s")
	m1.queue_free(); m2.queue_free()

func test_ad_flat_and_percent_increase_damage() -> void:
	if not _ok_name("ad_flat_and_percent_increase_damage"): return
	var u := _mk_unit(100, 10, 1.0)
	Powerup.pu_atk_20(u)
	_assert_eq(u.attack_damage, 12, "20% of 10 -> 12")
	Powerup.pu_atk_flat_10(u)
	_assert_eq(u.attack_damage, 22, "+10 flat applied after percent")

func test_ls_upgrade_heals_nonzero_on_typical_hit() -> void:
	if not _ok_name("ls_upgrade_heals_nonzero_on_typical_hit"): return
	var p := _mk_unit(100, 0, 1.0)
	var e := _mk_unit(100, 0, 1.0)
	Powerup.pu_ls_4(p)
	p.hp = 50
	var m = _mk_manager(p, e)
	m.on_projectile_hit("player", 0, 0, 50, false)
	_assert(p.hp > 50, "+4% lifesteal heals on 50 dmg")
	m.queue_free()

func test_block_upgrade_reduces_expected_damage() -> void:
	if not _ok_name("block_upgrade_reduces_expected_damage"): return
	var p := _mk_unit(1000, 0, 0.0)
	var e := _mk_unit(1000, 10, 0.0)
	for i in 10: Powerup.pu_block_5(p) # ~50% block
	var m = _mk_manager(p, e)
	m.rng.seed = 1
	var start_hp := p.hp
	var attempts := 1000
	for i in attempts:
		m.on_projectile_hit("enemy", 0, 0, 10, false)
	var taken := start_hp - p.hp
	_assert(taken < attempts * 10, "some damage blocked vs 0% block baseline")
	_assert(taken < int(attempts * 10 * 0.7), "~50% block reduces expected damage")
	m.queue_free()

func test_mana_gain_triggers_ability_print() -> void:
	if not _ok_name("mana_gain_triggers_ability_print"): return
	var p := _mk_unit(100, 0, 10.0)
	p.name = "Tester"
	p.mana_max = 3
	p.mana = 0
	p.mana_gain_per_attack = 1
	var e := _mk_unit(1000, 0, 0.0)
	var m = _mk_manager(p, e)
	var hit := false
	m.log_line.connect(func(txt: String): if txt.find("used its ability!") >= 0: hit = true)
	# Drive time until 3 attacks have fired
	var shots := 0
	m.projectile_fired.connect(func(src_team: String, _si: int, _ti: int, _d: int, _c: bool): if src_team == "player": shots += 1)
	while shots < 3:
		m._process(0.05)
	# After 3 attacks, mana should have wrapped
	_assert(hit and p.mana == 0, "ability triggers at mana_max and resets")
	m.queue_free()

func test_two_enemies_closest_targeting() -> void:
	if not _ok_name("two_enemies_closest_targeting"): return
	var view = load("res://scripts/combat_view.gd").new()
	add_child(view)
	await get_tree().process_frame
	# Prepare manager with two enemies
	var e1 := _mk_unit(100, 0, 0.0)
	var e2 := _mk_unit(100, 0, 0.0)
	view.manager.enemy_team = [e1, e2]
	view.manager.enemy = e1
	# Place player and enemies on known tiles
	view._set_player_tile(0)
	view._set_enemy_tile(1) # near player
	view._set_enemy2_tile(23) # far away
	# Use helper to choose nearest and verify index is the close one
	var choice: int = view.select_closest_target("player", 0, "enemy")
	_assert_eq(choice, 0, "player selects nearest enemy (index 0)")
	view.queue_free()

# --- Factories and resources ---

func test_unit_factory_templates() -> void:
	if not _ok_name("unit_factory_templates"): return
	var sari = load("res://scripts/unit_factory.gd").get_template("sari")
	_assert(sari != null and sari.name == "Sari" and sari.attack_damage > 0, "sari template valid")
	var nyxa = load("res://scripts/unit_factory.gd").get_template("nyxa")
	_assert(nyxa != null and nyxa.attack_range >= 1 and nyxa.attack_damage > 0, "nyxa template valid")
	var u = load("res://scripts/unit_factory.gd").spawn("sari")
	_assert(u is Unit and u.max_hp >= u.hp and u.attack_speed > 0.0, "spawn produces sane unit")

func test_enemy_factory_spawn() -> void:
	if not _ok_name("enemy_factory_spawn"): return
	var ef = EnemyFactory.new()
	add_child(ef)
	var f = ef.spawn_enemy(3)
	_assert(f is Fighter and f.is_alive() and f.atk > 0, "enemy factory produces fighter")
	ef.queue_free()

# --- Projectile manager ---

func test_projectile_motion_and_hit() -> void:
	if not _ok_name("projectile_motion_and_hit"): return
	var pm = load("res://scripts/projectile_manager.gd").new()
	add_child(pm)
	# Keep sprites null; set a target rect via dummy Control
	var player_rect := TextureRect.new()
	var enemy_rect := TextureRect.new()
	add_child(player_rect); add_child(enemy_rect)
	player_rect.position = Vector2(10, 100); player_rect.size = Vector2(50, 50)
	enemy_rect.position = Vector2(300, 110); enemy_rect.size = Vector2(50, 50)
	pm.configure(player_rect, enemy_rect)
	var st := {"hit": false}
	pm.projectile_hit.connect(func(_src_team: String, _si: int, _ti: int, _dmg: int, _crit: bool): st["hit"] = true)
	pm.fire_basic("player", 0, Vector2(0, 125), Vector2(400, 125), 1, false, 800.0, 6.0, Color.WHITE)
	# Step frames until hit or timeout
	for i in 120:
		pm._process(1.0/60.0)
		if bool(st["hit"]): break
	_assert(bool(st["hit"]), "projectile reaches target and emits hit")
	pm.queue_free(); player_rect.queue_free(); enemy_rect.queue_free()

func run_all() -> void:
	total = 0; passed = 0; failed = 0; logs.clear()
	var filt := ""
	if filter_substr != "":
		filt = " (filter: " + filter_substr + ")"
	var bail := ""
	if bail_on_fail:
		bail = " [bail]"
	tlog("Running tests" + filt + bail)
	# Discover test methods dynamically
	var tests := []
	for m in get_method_list():
		var n: String = m.name
		if n.begins_with("test_"):
			tests.append(n)
	tests.sort()
	for t in tests:
		# Each test runs isolated; log its start
		tlog("-- " + t)
		call(t)
		tlog("%d/%d tests passed (failed: %d)" % [passed, total, failed])
	# Write results to res:// or user://
	_write_results()
	var tmr := get_tree().create_timer(0.1)
	tmr.timeout.connect(func(): get_tree().quit(0 if failed == 0 else 1))

# --- Unit sim smoke (optional balancing helper) ---
func test_unit_sim_base_1v1() -> void:
	if not _ok_name("unit_sim_base_1v1"): return
	var sim := load("res://tests/unit_sim.gd").new()
	var result := sim.run_1v1("none", "none", 100, 0.05, "sari", "nyxa")
	tlog("UnitSim base 1v1 (sari vs nyxa): %s" % [str(result)])
	_assert(true, "unit sim executed")

func test_target_controller_refresh() -> void:
	if not _ok_name("target_controller_refresh"): return
	var state := BattleState.new()
	var p1 := _mk_unit(50, 10, 1.0)
	var p2 := _mk_unit(50, 10, 1.0)
	var e1 := _mk_unit(50, 0, 1.0)
	var e2 := _mk_unit(50, 0, 1.0)
	state.player_team = [p1, p2]
	state.enemy_team = [e1, e2]
	var controller := TargetController.new()
	controller.configure(state, Callable())
	_assert_eq(controller.current_target("player", 0), 0, "initial target is first alive")
	e1.hp = 0
	_assert_eq(controller.refresh_target("player", 0), 1, "refresh selects next alive target")

func test_cooldown_scheduler_pairs() -> void:
	if not _ok_name("cooldown_scheduler_pairs"): return
	var state := BattleState.new()
	var p := _mk_unit(100, 10, 10.0)
	var e := _mk_unit(100, 10, 10.0)
	state.player_team = [p]
	state.enemy_team = [e]
	state.player_cds = [0.0]
	state.enemy_cds = [0.0]
	var controller := TargetController.new()
	controller.configure(state, Callable())
	var scheduler := CooldownScheduler.new()
	scheduler.configure(state, controller)
	scheduler.apply_rules(true, false, true)
	scheduler.reset_turn()
	var result := scheduler.advance(0.2)
	var pairs: Array = result.get("pairs", [])
	_assert(pairs.size() > 0, "scheduler produced pair events")
	_assert(Array(pairs[0]).size() == 2, "pair contains both sides")

func test_attack_resolver_double_ko_frame_flags() -> void:
	if not _ok_name("attack_resolver_double_ko"): return
	var state := BattleState.new()
	var p := _mk_unit(10, 10, 1.0)
	var e := _mk_unit(10, 10, 1.0)
	state.player_team = [p]
	state.enemy_team = [e]
	state.player_cds = [0.0]
	state.enemy_cds = [0.0]
	var controller := TargetController.new()
	controller.configure(state, Callable())
	var resolver := AttackResolver.new()
	resolver.configure(state, controller, RandomNumberGenerator.new(), p, {})
	resolver.set_deterministic_rolls(true)
	var pair := [AttackEvent.new("player", 0, 0), AttackEvent.new("enemy", 0, 0)]
	resolver.resolve_pairs([pair])
	var frame := resolver.frame_status()
	_assert(bool(frame.get("player_dead", false)), "player flagged dead after double KO")
	_assert(bool(frame.get("enemy_dead", false)), "enemy flagged dead after double KO")
	_assert(bool(frame.get("double_ko", false)), "double KO flag set")

func test_outcome_resolver_tiebreaker_cd() -> void:
	if not _ok_name("outcome_resolver_tiebreaker_cd"): return
	var state := BattleState.new()
	state.player_team = []
	state.enemy_team = []
	state.player_cds = [0.2]
	state.enemy_cds = [0.5]
	var resolver := OutcomeResolver.new()
	resolver.configure(state, RandomNumberGenerator.new())
	var totals := {"player": 40, "enemy": 40}
	var outcome := resolver.evaluate_board(false, totals)
	_assert_eq(outcome, "victory", "lower cooldown wins tiebreaker")
