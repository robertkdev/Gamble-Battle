extends Object
class_name LogSchema

# Shared formatters for stage/chapter labels in UI and logs.

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")

static func format_stage(ch: int, sic: int, total: int) -> String:
    var stage_label: String = ChapterCatalog.display_name_for(ch)
    var round_num: int = max(1, int(sic))
    var total_rounds: int = int(total)
    if total_rounds > 0:
        return "%s - Round %d/%d" % [stage_label, round_num, total_rounds]
    return "%s - Round %d" % [stage_label, round_num]

static func format_boss_badge() -> String:
    return "BOSS"
