extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")

const SMOKE_TITLE: String = "EndlessEntryMainFlowSmoke"
const TEST_SEED: int = 730711
const STARTER_ID: String = "bonko"
const ENDLESS_CHAPTER: int = ProgressionConfig.ENDLESS_START_CHAPTER
const ENDLESS_ROUND: int = ProgressionConfig.CREEP_STAGE
const WATCHDOG_SECONDS: float = 80.0
const PLAYER_IDS: Array[String] = ["malachor", "meridian", "nullora", "quillith", "bastionne", "saffron"]

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 8.0
	RosterCatalog.set_endless_seed(TEST_SEED)

	_start_main_scene()
	await _settle_frames(4)
	await _ensure_unit_select()
	await _select_starter(STARTER_ID)
	await _settle_frames(4)
	_force_endless_entry_state()
	await _settle_frames(6)
	_validate_endless_preview()
	if _technical_failures().is_empty():
		await _play_first_endless_round()
	_finish_endless_entry()

func _force_endless_entry_state() -> void:
	GameState.set_chapter_and_stage(ENDLESS_CHAPTER, ENDLESS_ROUND)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	if Economy != null:
		Economy.reset_run()
		Economy.gold = 60
		Economy.current_bet = 1
		Economy.preferred_bet = 1
		Economy.combat_active = false
		Economy.gold_changed.emit(Economy.gold)
		Economy.bet_changed.emit(Economy.current_bet)
	if Shop != null:
		Shop.reset_run()
	if Roster != null:
		Roster.reset(true)
		Roster.set_max_team_size(PLAYER_IDS.size())
	var controller: Variant = _combat_controller()
	_expect(controller != null, "endless entry combat controller missing")
	if controller == null:
		return
	var manager: Variant = controller.get("manager")
	_expect(manager != null, "endless entry combat manager missing")
	if manager == null:
		return
	manager.player_team.clear()
	for unit_id: String in PLAYER_IDS:
		var unit: Unit = UnitFactory.spawn(unit_id)
		_expect(unit != null, "endless entry failed to spawn player unit %s" % unit_id)
		if unit != null:
			_make_player_unit_durable(unit)
			manager.player_team.append(unit)
	if manager.has_method("setup_stage_preview"):
		manager.setup_stage_preview()
	if controller.has_method("refresh_all_views"):
		controller.refresh_all_views()
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	if button != null:
		button.text = "Start Battle"
		button.disabled = false
		button.visible = true

func _make_player_unit_durable(unit: Unit) -> void:
	unit.level = 8
	unit.max_hp = max(int(unit.max_hp), 5000)
	unit.hp = unit.max_hp
	unit.attack_damage = max(float(unit.attack_damage), 500.0)
	unit.spell_power = max(float(unit.spell_power), 200.0)
	unit.armor = max(float(unit.armor), 80.0)
	unit.magic_resist = max(float(unit.magic_resist), 80.0)

func _validate_endless_preview() -> void:
	_expect(ChapterCatalog.display_name_for(ENDLESS_CHAPTER) == "Endless 1", "chapter catalog should label first generated chapter Endless 1")
	var chapter_label: Label = _main.find_child("ChapterLabel", true, false) as Label
	_expect(chapter_label != null, "endless entry chapter label missing")
	if chapter_label != null:
		_expect(String(chapter_label.text) == "Endless 1", "endless entry chapter label expected Endless 1 got %s" % chapter_label.text)
	var spec: Dictionary = RosterCatalog.get_spec(ENDLESS_CHAPTER, ENDLESS_ROUND)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(String(spec.get(StageTypes.KEY_KIND, "")) == StageTypes.KIND_CREEPS, "first endless round should be generated creeps")
	_expect(bool(rules.get("endless", false)), "first endless preview spec should carry endless marker")
	var controller: Variant = _combat_controller()
	var manager: Variant = controller.get("manager") if controller != null else null
	_expect(manager != null, "endless entry manager missing for preview validation")
	if manager != null:
		var preview_enemy_ids: Array[String] = _enemy_ids(manager)
		_expect(not preview_enemy_ids.is_empty(), "endless entry preview should show generated enemies")
		print("%s: preview chapter=%d round=%d enemy=%s spec=%s" % [SMOKE_TITLE, ENDLESS_CHAPTER, ENDLESS_ROUND, JSON.stringify(preview_enemy_ids), JSON.stringify(_spec_summary(spec))])

func _play_first_endless_round() -> void:
	_set_planning_timer_safe()
	await _press_continue(false, "endless entry generated creep")
	var combat_seen: bool = await _wait_for_combat_active(3.0)
	if not combat_seen and int(GameState.chapter) == ENDLESS_CHAPTER and int(GameState.stage_in_chapter) >= ProgressionConfig.FIRST_RGA_STAGE:
		print("%s: first endless combat resolved before combat-active poll" % SMOKE_TITLE)
		return
	_expect(combat_seen, "endless entry did not enter combat")
	if not combat_seen:
		return
	var resolved: bool = await _wait_for_preview_or_loss(WATCHDOG_SECONDS)
	var fight_result: String = _second_fight_result(resolved)
	_expect(resolved, "endless entry round did not resolve")
	_expect(fight_result == "shop", "endless entry should return to shop after generated creep win, got %s" % fight_result)
	_expect(int(GameState.chapter) == ENDLESS_CHAPTER, "endless entry should remain in first endless chapter after round 1")
	_expect(int(GameState.stage_in_chapter) >= ProgressionConfig.FIRST_RGA_STAGE, "endless entry should advance to first RGA round, got round %d" % int(GameState.stage_in_chapter))
	var next_spec: Dictionary = RosterCatalog.get_spec(ENDLESS_CHAPTER, ProgressionConfig.FIRST_RGA_STAGE)
	var next_rules: Dictionary = next_spec.get(StageTypes.KEY_RULES, {})
	_expect(String(next_spec.get(StageTypes.KEY_KIND, "")) == StageTypes.KIND_NORMAL, "endless entry next round should be generated normal RGA")
	_expect(next_rules.has("rga_challenge"), "endless entry next normal round should expose RGA metadata")
	print("%s: first_round_result=%s chapter=%d round=%d next_spec=%s" % [SMOKE_TITLE, fight_result, int(GameState.chapter), int(GameState.stage_in_chapter), JSON.stringify(_spec_summary(next_spec))])

func _spec_summary(spec: Dictionary) -> Dictionary:
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	return {
		"ids": spec.get(StageTypes.KEY_IDS, []),
		"kind": String(spec.get(StageTypes.KEY_KIND, "")),
		"endless": bool(rules.get("endless", false)),
		"target_rating": int(rules.get("target_rating", 0)),
		"difficulty_rating": int(rules.get("difficulty_rating", 0)),
		"theme": String(rules.get("theme", "")),
		"challenge": rules.get("rga_challenge", {}),
	}

func _enemy_ids(manager: Variant) -> Array[String]:
	var output: Array[String] = []
	if manager == null:
		return output
	for unit_value: Variant in manager.enemy_team:
		var unit: Unit = unit_value as Unit
		if unit != null:
			output.append(String(unit.id))
	return output

func _finish_endless_entry() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		print("%s: OK state=%s" % [SMOKE_TITLE, JSON.stringify({
			"chapter": int(GameState.chapter),
			"round": int(GameState.stage_in_chapter),
			"board": _board_ids(),
			"bench": _bench_ids(),
		})])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [SMOKE_TITLE, failure])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
