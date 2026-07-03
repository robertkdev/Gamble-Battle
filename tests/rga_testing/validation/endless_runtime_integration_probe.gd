extends Node

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const EnemySpawner := preload("res://scripts/game/combat/enemy_spawner.gd")
const LogSchema := preload("res://scripts/util/log_schema.gd")
const MirrorBoardStore := preload("res://scripts/game/progression/mirror_board_store.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const ProgressionService := preload("res://scripts/game/progression/progression_service.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const TEST_SEED: int = 730711
const FIRST_ENDLESS_CHAPTER: int = ProgressionConfig.ENDLESS_START_CHAPTER

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var previous_suppress_validation_warnings: bool = bool(UnitFactory.suppress_validation_warnings)
	UnitFactory.suppress_validation_warnings = true
	StageRuleRunner.clear_runtime()
	MirrorBoardStore.clear_runtime()
	RosterCatalog.set_endless_seed(TEST_SEED)

	_validate_progression_rollover(failures)
	_validate_display_names(failures)
	_validate_endless_catalog_specs(failures)
	_validate_spawner_and_rules(failures)
	_validate_mirror_runtime(failures)

	UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
	if failures.is_empty():
		print("EndlessRuntimeIntegrationProbe: PASS first_endless=%d seed=%d" % [FIRST_ENDLESS_CHAPTER, TEST_SEED])
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("EndlessRuntimeIntegrationProbe: %s" % failure)
		get_tree().quit(1)

func _validate_progression_rollover(failures: Array[String]) -> void:
	var advance: Dictionary = ProgressionService.advance(ProgressionConfig.AUTHORED_CHAPTER_COUNT, ProgressionConfig.MIRROR_STAGE, true)
	_expect(int(advance.get("chapter", 0)) == FIRST_ENDLESS_CHAPTER, "chapter 10 mirror win should advance to first endless chapter, got %s" % JSON.stringify(advance), failures)
	_expect(int(advance.get("stage_in_chapter", 0)) == ProgressionConfig.CREEP_STAGE, "chapter 10 mirror win should advance to endless round 1, got %s" % JSON.stringify(advance), failures)
	var global_stage: int = ProgressionService.to_global_stage(FIRST_ENDLESS_CHAPTER, ProgressionConfig.CREEP_STAGE)
	var mapping: Dictionary = ProgressionService.from_global_stage(global_stage)
	_expect(int(mapping.get("chapter", 0)) == FIRST_ENDLESS_CHAPTER, "global stage should map back to first endless chapter, got %s" % JSON.stringify(mapping), failures)
	_expect(int(mapping.get("stage_in_chapter", 0)) == ProgressionConfig.CREEP_STAGE, "global stage should map back to first endless round, got %s" % JSON.stringify(mapping), failures)

func _validate_display_names(failures: Array[String]) -> void:
	_expect(ChapterCatalog.display_name_for(FIRST_ENDLESS_CHAPTER) == "Endless 1", "first endless display name mismatch", failures)
	_expect(LogSchema.format_stage(FIRST_ENDLESS_CHAPTER, 1, 5).begins_with("Endless 1"), "log schema should display Endless 1 after authored chapters", failures)

func _validate_endless_catalog_specs(failures: Array[String]) -> void:
	for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
		var first_spec: Dictionary = RosterCatalog.get_spec(FIRST_ENDLESS_CHAPTER, stage_index)
		var second_spec: Dictionary = RosterCatalog.get_spec(FIRST_ENDLESS_CHAPTER, stage_index)
		_expect(_specs_equivalent(first_spec, second_spec), "endless spec should be stable for repeated catalog calls chapter=%d stage=%d" % [FIRST_ENDLESS_CHAPTER, stage_index], failures)
		_validate_generated_spec(FIRST_ENDLESS_CHAPTER, stage_index, first_spec, failures)
	_validate_generated_spec(FIRST_ENDLESS_CHAPTER + 1, ProgressionConfig.SECOND_RGA_STAGE, RosterCatalog.get_spec(FIRST_ENDLESS_CHAPTER + 1, ProgressionConfig.SECOND_RGA_STAGE), failures)

func _validate_generated_spec(chapter: int, stage_index: int, spec: Dictionary, failures: Array[String]) -> void:
	_expect(StageTypes.validate_spec(spec), "generated spec invalid chapter=%d stage=%d" % [chapter, stage_index], failures)
	var expected_kind: String = _expected_kind_for(stage_index)
	var kind: String = String(spec.get(StageTypes.KEY_KIND, ""))
	_expect(kind == expected_kind, "generated spec kind mismatch chapter=%d stage=%d expected=%s got=%s" % [chapter, stage_index, expected_kind, kind], failures)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(bool(rules.get("endless", false)), "generated spec missing endless marker chapter=%d stage=%d" % [chapter, stage_index], failures)
	_expect(rules.has("target_rating"), "generated spec missing target rating chapter=%d stage=%d" % [chapter, stage_index], failures)
	_expect(rules.has("difficulty_rating"), "generated spec missing difficulty rating chapter=%d stage=%d" % [chapter, stage_index], failures)
	if kind == StageTypes.KIND_NORMAL:
		_expect(rules.has("rga_challenge"), "generated normal spec missing RGA challenge chapter=%d stage=%d" % [chapter, stage_index], failures)
	if kind == StageTypes.KIND_MIRROR:
		var ids: Array = spec.get(StageTypes.KEY_IDS, [])
		_expect(ids.is_empty(), "generated mirror spec should stay id-empty before mirror rule chapter=%d" % chapter, failures)
		_expect(int(rules.get("mirror_source_stage", 0)) == ProgressionConfig.BOSS_STAGE, "generated mirror source should be boss stage chapter=%d" % chapter, failures)
	else:
		var ids2: Array = spec.get(StageTypes.KEY_IDS, [])
		_expect(not ids2.is_empty(), "generated non-mirror spec should include enemies chapter=%d stage=%d" % [chapter, stage_index], failures)

func _validate_spawner_and_rules(failures: Array[String]) -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	for stage_index: int in [ProgressionConfig.CREEP_STAGE, ProgressionConfig.FIRST_RGA_STAGE, ProgressionConfig.SECOND_RGA_STAGE, ProgressionConfig.BOSS_STAGE]:
		var spec: Dictionary = RosterCatalog.get_spec(FIRST_ENDLESS_CHAPTER, stage_index)
		StageRuleRunner.pre_spawn(spec, FIRST_ENDLESS_CHAPTER, stage_index)
		var units: Array[Unit] = spawner.build_for_spec(spec, FIRST_ENDLESS_CHAPTER, stage_index)
		StageRuleRunner.post_spawn(units, spec, FIRST_ENDLESS_CHAPTER, stage_index)
		_expect(not units.is_empty(), "spawner should build generated units for endless stage %d" % stage_index, failures)
		for unit: Unit in units:
			_expect(unit != null, "spawner returned null unit for endless stage %d" % stage_index, failures)

func _validate_mirror_runtime(failures: Array[String]) -> void:
	var source_units: Array[Unit] = []
	var first: Unit = UnitFactory.spawn("sari")
	var second: Unit = UnitFactory.spawn("paisley")
	_expect(first != null, "failed to spawn source sari for endless mirror", failures)
	_expect(second != null, "failed to spawn source paisley for endless mirror", failures)
	if first != null:
		first.level = 4
		first.max_hp = 777
		first.hp = first.max_hp
		source_units.append(first)
	if second != null:
		second.level = 3
		second.max_hp = 555
		second.hp = second.max_hp
		source_units.append(second)
	MirrorBoardStore.capture_boss_board(FIRST_ENDLESS_CHAPTER, source_units)
	var mirror_spec: Dictionary = RosterCatalog.get_spec(FIRST_ENDLESS_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	StageRuleRunner.pre_spawn(mirror_spec, FIRST_ENDLESS_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	_expect(_same_strings(_spec_ids(mirror_spec), ["sari", "paisley"]), "endless mirror pre-spawn should use boss-entry snapshot ids", failures)
	var spawner: EnemySpawner = EnemySpawner.new()
	var enemies: Array[Unit] = spawner.build_for_spec(mirror_spec, FIRST_ENDLESS_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	StageRuleRunner.post_spawn(enemies, mirror_spec, FIRST_ENDLESS_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	_expect(enemies.size() == 2, "endless mirror should spawn snapshot enemy count", failures)
	if enemies.size() >= 2:
		_expect(String(enemies[0].id) == "sari" and int(enemies[0].level) == 4 and int(enemies[0].max_hp) == 777, "endless mirror first unit did not copy snapshot stats", failures)
		_expect(String(enemies[1].id) == "paisley" and int(enemies[1].level) == 3 and int(enemies[1].max_hp) == 555, "endless mirror second unit did not copy snapshot stats", failures)

func _expected_kind_for(stage_index: int) -> String:
	if stage_index == int(ProgressionConfig.CREEP_STAGE):
		return StageTypes.KIND_CREEPS
	if stage_index == int(ProgressionConfig.BOSS_STAGE):
		return StageTypes.KIND_BOSS
	if stage_index == int(ProgressionConfig.MIRROR_STAGE):
		return StageTypes.KIND_MIRROR
	return StageTypes.KIND_NORMAL

func _specs_equivalent(left: Dictionary, right: Dictionary) -> bool:
	var same_kind: bool = String(left.get(StageTypes.KEY_KIND, "")) == String(right.get(StageTypes.KEY_KIND, ""))
	var same_ids: bool = _same_strings(_spec_ids(left), _spec_ids(right))
	var same_rules: bool = _rules_signature(left) == _rules_signature(right)
	return same_kind and same_ids and same_rules

func _rules_signature(spec: Dictionary) -> String:
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	var challenge: Dictionary = rules.get("rga_challenge", {}) if typeof(rules.get("rga_challenge", {})) == TYPE_DICTIONARY else {}
	return "%s:%s:%s:%s:%s" % [
		str(bool(rules.get("endless", false))),
		String(rules.get("theme", "")),
		String(challenge.get("id", "")),
		str(int(rules.get("target_rating", -1))),
		str(int(rules.get("difficulty_rating", -1))),
	]

func _spec_ids(spec: Dictionary) -> Array[String]:
	var output: Array[String] = []
	var raw: Variant = spec.get(StageTypes.KEY_IDS, [])
	if raw is Array:
		for unit_id: Variant in raw:
			var clean: String = String(unit_id).strip_edges()
			if clean != "":
				output.append(clean)
	return output

func _same_strings(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for i: int in range(left.size()):
		if String(left[i]) != String(right[i]):
			return false
	return true

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
