extends Object
class_name RosterCatalog

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const RosterUtils := preload("res://scripts/game/progression/roster_utils.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const RgaStageChallengeDirector := preload("res://scripts/game/progression/rga_stage_challenge_director.gd")
const EndlessChapterGenerator := preload("res://scripts/game/progression/endless_chapter_generator.gd")

# Single source of truth for enemy stage composition.
# Current pattern for authored chapters:
# 1 CREEPS, 2 NORMAL RGA puzzle, 3 NORMAL RGA puzzle, 4 BOSS, 5 MIRROR.
# Chapters 1-10 are authored; normal rounds are selected from bounded RGA puzzle
# pools at runtime and cached so preview and battle match. Chapters after the
# authored campaign are generated and cached here so preview and battle use the
# same procedural board.

static var _endless_seed: int = 0
static var _endless_state: Dictionary = {}
static var _endless_spec_cache: Dictionary = {}

static var _entries: Dictionary = {
	1: {
		1: {StageTypes.KEY_IDS: [{"id": "beegle", "level": 1}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {
			"stat_overrides": {"index": {0: {"max_hp": 120, "attack_damage": 50.0, "attack_range": 1}}},
		}},
		4: {StageTypes.KEY_IDS: [{"id": "morrak", "level": 2}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	2: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 1}, {"id": "drueling", "level": 1}, {"id": "beegle", "level": 1}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "korath", "level": 2}, {"id": "morrak", "level": 2}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["guard"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	3: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 2}, {"id": "drueling", "level": 1}, {"id": "beegle", "level": 1}, {"id": "faeling", "level": 1}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "hexeon", "level": 2}, {"id": "totem", "level": 1}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	4: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 2}, {"id": "drueling", "level": 2}, {"id": "beegle", "level": 2}, {"id": "faeling", "level": 1}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "morrak", "level": 3}, {"id": "repo", "level": 2}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["hyperstone"], 1: ["anchor"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	5: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 3}, {"id": "drueling", "level": 2}, {"id": "beegle", "level": 2}, {"id": "faeling", "level": 2}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "morrak", "level": 4}, {"id": "korath", "level": 3}, {"id": "paisley", "level": 3}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["blood_engine"], 1: ["sanctum"], 2: ["mageheart"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	6: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 3}, {"id": "drueling", "level": 3}, {"id": "beegle", "level": 2}, {"id": "faeling", "level": 2}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "bastionne", "level": 2}, {"id": "gable", "level": 2}, {"id": "saffron", "level": 2}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["guard"], 1: ["shiv"], 2: ["wardheart"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	7: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 4}, {"id": "drueling", "level": 3}, {"id": "beegle", "level": 3}, {"id": "faeling", "level": 2}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "hexeon", "level": 3}, {"id": "nullora", "level": 2}, {"id": "quorra", "level": 3}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["blood_engine"], 1: ["shiv"], 2: ["anchor"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	8: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 4}, {"id": "drueling", "level": 4}, {"id": "beegle", "level": 3}, {"id": "faeling", "level": 3}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "malachor", "level": 2}, {"id": "quillith", "level": 2}, {"id": "orielle", "level": 3}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["sanctum"], 1: ["codex"], 2: ["mageheart"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	9: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 5}, {"id": "drueling", "level": 4}, {"id": "beegle", "level": 4}, {"id": "faeling", "level": 3}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "meridian", "level": 2}, {"id": "nullora", "level": 2}, {"id": "ravel", "level": 3}, {"id": "prisma", "level": 3}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["mageheart"], 1: ["blood_engine"], 2: ["wardheart"], 3: ["codex"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
	10: {
		1: {StageTypes.KEY_IDS: [{"id": "drubble", "level": 5}, {"id": "drueling", "level": 5}, {"id": "beegle", "level": 4}, {"id": "faeling", "level": 4}], StageTypes.KEY_KIND: StageTypes.KIND_CREEPS, StageTypes.KEY_RULES: {}},
		4: {StageTypes.KEY_IDS: [{"id": "malachor", "level": 3}, {"id": "meridian", "level": 3}, {"id": "nullora", "level": 3}, {"id": "quillith", "level": 3}], StageTypes.KEY_KIND: StageTypes.KIND_BOSS, StageTypes.KEY_RULES: {"items": {0: ["sanctum"], 1: ["mageheart"], 2: ["blood_engine"], 3: ["codex"]}}},
		5: {StageTypes.KEY_IDS: [], StageTypes.KEY_KIND: StageTypes.KIND_MIRROR, StageTypes.KEY_RULES: {}},
	},
}

const DEFAULT_CREEP_REWARDS: Dictionary = {
	"pool_path": "res://data/creeps/reward_pools/default.tres",
	"rolls_per_kill": 1,
	"only_creeps": true,
	"source_team": "player",
}

static func clear_runtime() -> void:
	RgaStageChallengeDirector.clear_runtime(true)
	_reset_endless_runtime(true)

static func set_endless_seed(seed: int) -> void:
	_endless_seed = int(seed)
	_reset_endless_runtime(false)

static func get_spec(ch: int, sic: int) -> Dictionary:
	var c: int = max(1, int(ch))
	var s: int = clampi(max(1, int(sic)), 1, int(ChapterCatalog.stages_in(c)))
	if ChapterCatalog.is_endless_chapter(c):
		return _get_endless_spec(c, s)
	var stage_map: Dictionary = _entries.get(c, {})
	if stage_map.has(s):
		var raw_value: Variant = stage_map[s]
		if typeof(raw_value) == TYPE_DICTIONARY:
			var raw: Dictionary = raw_value
			return _spec_from_raw(raw)
	if s == int(ProgressionConfig.FIRST_RGA_STAGE) or s == int(ProgressionConfig.SECOND_RGA_STAGE):
		return RgaStageChallengeDirector.get_normal_spec(c, s)

	var def_kind: String = _default_kind_for(c, s)
	var def_ids: Array[String] = RosterUtils.sanitize_ids(_default_ids_for(c, s, def_kind))
	var def_rules: Dictionary = {}
	_attach_default_creep_rewards(def_rules, def_kind)
	return StageTypes.make_spec(def_ids, def_kind, def_rules)

static func _spec_from_raw(raw: Dictionary) -> Dictionary:
	var raw_ids_value: Variant = raw.get(StageTypes.KEY_IDS, []) if raw.has(StageTypes.KEY_IDS) else []
	var raw_ids: Array = raw_ids_value if raw_ids_value is Array else []
	var ids: Array[String] = []
	var levels_from_inline: Dictionary = {}
	var idx: int = 0
	for value: Variant in raw_ids:
		if typeof(value) == TYPE_DICTIONARY:
			var entry: Dictionary = value
			var entry_id: String = String(entry.get("id", "")).strip_edges()
			if entry_id != "":
				ids.append(entry_id)
				var level_value: int = int(entry.get("level", 0))
				if level_value > 0:
					levels_from_inline[idx] = level_value
					levels_from_inline[entry_id] = level_value
				idx += 1
		else:
			var sid: String = String(value).strip_edges()
			if sid != "":
				ids.append(sid)
				idx += 1

	ids = RosterUtils.sanitize_ids(ids)
	var kind: String = String(raw.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
	var rules: Variant = raw.get(StageTypes.KEY_RULES, {})
	var rules_dict: Dictionary = (rules.duplicate(true) if typeof(rules) == TYPE_DICTIONARY else {})
	if not levels_from_inline.is_empty():
		if rules_dict.has("levels") and typeof(rules_dict["levels"]) == TYPE_DICTIONARY:
			var existing: Dictionary = rules_dict["levels"]
			for key: Variant in levels_from_inline.keys():
				existing[key] = levels_from_inline[key]
			rules_dict["levels"] = existing
		else:
			rules_dict["levels"] = levels_from_inline
	_attach_default_creep_rewards(rules_dict, kind)
	return StageTypes.make_spec(ids, kind, rules_dict)

static func _attach_default_creep_rewards(rules: Dictionary, kind: String) -> void:
	if String(kind).strip_edges().to_upper() != StageTypes.KIND_CREEPS:
		return
	if rules.has("rewards"):
		return
	rules["rewards"] = DEFAULT_CREEP_REWARDS.duplicate(true)

static func _default_kind_for(_ch: int, sic: int) -> String:
	var s: int = int(sic)
	if s == int(ProgressionConfig.CREEP_STAGE):
		return StageTypes.KIND_CREEPS
	if s == int(ProgressionConfig.BOSS_STAGE):
		return StageTypes.KIND_BOSS
	if s == int(ProgressionConfig.MIRROR_STAGE):
		return StageTypes.KIND_MIRROR
	return StageTypes.KIND_NORMAL

static func _default_ids_for(_ch: int, _sic: int, kind: String) -> Array[String]:
	var normalized_kind: String = String(kind).strip_edges().to_upper()
	if normalized_kind == StageTypes.KIND_BOSS:
		return ["morrak"]
	if normalized_kind == StageTypes.KIND_CREEPS:
		return ["drubble"]
	if normalized_kind == StageTypes.KIND_MIRROR:
		return []
	return ["bonko"]

static func _get_endless_spec(chapter: int, stage_index: int) -> Dictionary:
	_ensure_endless_seed()
	_ensure_endless_generated_through(chapter)
	var key: String = _endless_key(chapter, stage_index)
	if _endless_spec_cache.has(key) and typeof(_endless_spec_cache[key]) == TYPE_DICTIONARY:
		var cached: Dictionary = _endless_spec_cache[key]
		return cached.duplicate(true)
	var generated: Dictionary = EndlessChapterGenerator.get_spec(chapter, stage_index, _endless_seed, _endless_state)
	_endless_spec_cache[key] = generated.duplicate(true)
	return generated.duplicate(true)

static func _ensure_endless_generated_through(target_chapter: int) -> void:
	_ensure_endless_state()
	var next_chapter: int = int(_endless_state.get("next_chapter", int(ProgressionConfig.ENDLESS_START_CHAPTER)))
	var target: int = max(int(ProgressionConfig.ENDLESS_START_CHAPTER), int(target_chapter))
	while next_chapter <= target:
		for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
			var spec: Dictionary = EndlessChapterGenerator.get_spec(next_chapter, stage_index, _endless_seed, _endless_state)
			_endless_spec_cache[_endless_key(next_chapter, stage_index)] = spec.duplicate(true)
		next_chapter += 1
		_endless_state["next_chapter"] = next_chapter

static func _reset_endless_runtime(randomize_seed: bool) -> void:
	_endless_spec_cache.clear()
	_endless_state = {
		"recent_signatures": [],
		"next_chapter": int(ProgressionConfig.ENDLESS_START_CHAPTER),
	}
	if randomize_seed or _endless_seed == 0:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		_endless_seed = int(rng.randi())
	EndlessChapterGenerator.clear_cache()

static func _ensure_endless_seed() -> void:
	if _endless_seed != 0:
		return
	_endless_seed = int(ProgressionConfig.ENDLESS_DEFAULT_SEED)

static func _ensure_endless_state() -> void:
	if _endless_state.is_empty():
		_reset_endless_runtime(false)
	if not _endless_state.has("recent_signatures") or not (_endless_state["recent_signatures"] is Array):
		_endless_state["recent_signatures"] = []
	if not _endless_state.has("next_chapter"):
		_endless_state["next_chapter"] = int(ProgressionConfig.ENDLESS_START_CHAPTER)

static func _endless_key(chapter: int, stage_index: int) -> String:
	return "%d:%d" % [int(chapter), int(stage_index)]
