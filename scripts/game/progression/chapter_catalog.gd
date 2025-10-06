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
    1: {
        "name": "Chapter 1",
        # Intentionally omit "stages" to exercise fallback path.
        # "default_rule_id": "",   # example: "NORMAL"
        # "chapter_rules": {},
    },
    2: {
        "name": "Chapter 2",
        # Uses default stages per chapter and default rules
    },
}

static func get_meta_for(ch: int) -> Dictionary:
    var c: int = int(ch)
    if c <= 0:
        c = 1
    var meta: Dictionary = _chapters.get(c, {})
    var out: Dictionary = {}
    out["name"] = String(meta.get("name", "Chapter %d" % c))
    if meta.has("stages"):
        out["stages"] = int(meta["stages"])
    if meta.has("default_rule_id"):
        out["default_rule_id"] = String(meta["default_rule_id"]) 
    if meta.has("chapter_rules"):
        var cr = meta["chapter_rules"]
        out["chapter_rules"] = (cr.duplicate(true) if typeof(cr) == TYPE_DICTIONARY else {})
    return out

static func stages_in(ch: int) -> int:
    var meta := get_meta_for(ch)
    if meta.has("stages"):
        var s: int = int(meta["stages"])
        if s > 0:
            return s
    return int(ProgressionConfig.STAGES_PER_CHAPTER)
