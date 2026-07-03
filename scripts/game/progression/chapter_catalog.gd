extends Object
class_name ChapterCatalog

const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")

# Per-chapter metadata registry.
# Keys:
#  - name: String (required)
#  - stages: int? (optional override, defaults to ProgressionConfig.STAGES_PER_CHAPTER)
#  - default_rule_id: String? (optional)
#  - chapter_rules: Dictionary? (optional)

static var _chapters: Dictionary = {
	1: {"name": "Chapter 1"},
	2: {"name": "Chapter 2"},
	3: {"name": "Chapter 3"},
	4: {"name": "Chapter 4"},
	5: {"name": "Chapter 5"},
	6: {"name": "Chapter 6"},
	7: {"name": "Chapter 7"},
	8: {"name": "Chapter 8"},
	9: {"name": "Chapter 9"},
	10: {"name": "Chapter 10"},
}

static func get_meta_for(ch: int) -> Dictionary:
	var c: int = int(ch)
	if c <= 0:
		c = 1
	var meta: Dictionary = _chapters.get(c, {})
	var out: Dictionary = {}
	out["name"] = String(meta.get("name", display_name_for(c)))
	if meta.has("stages"):
		out["stages"] = int(meta["stages"])
	if meta.has("default_rule_id"):
		out["default_rule_id"] = String(meta["default_rule_id"])
	if meta.has("chapter_rules"):
		var cr: Variant = meta["chapter_rules"]
		if typeof(cr) == TYPE_DICTIONARY:
			var cr_dict: Dictionary = cr
			out["chapter_rules"] = cr_dict.duplicate(true)
		else:
			out["chapter_rules"] = {}
	return out

static func stages_in(ch: int) -> int:
	var meta: Dictionary = get_meta_for(ch)
	if meta.has("stages"):
		var s: int = int(meta["stages"])
		if s > 0:
			return s
	return int(ProgressionConfig.STAGES_PER_CHAPTER)

static func chapter_count() -> int:
	return int(ProgressionConfig.CHAPTER_COUNT)

static func authored_chapter_count() -> int:
	return int(ProgressionConfig.AUTHORED_CHAPTER_COUNT)

static func is_authored_chapter(ch: int) -> bool:
	return int(ch) >= 1 and int(ch) <= authored_chapter_count()

static func is_endless_chapter(ch: int) -> bool:
	return is_procedural_chapter(ch)

static func endless_chapter_index(ch: int) -> int:
	return procedural_chapter_index(ch)

static func is_procedural_chapter(ch: int) -> bool:
	return int(ch) >= int(ProgressionConfig.PROCEDURAL_START_CHAPTER)

static func procedural_chapter_index(ch: int) -> int:
	return max(1, int(ch) - int(ProgressionConfig.PROCEDURAL_START_CHAPTER) + 1)

static func display_name_for(ch: int) -> String:
	var c: int = max(1, int(ch))
	return "Chapter %d" % c
