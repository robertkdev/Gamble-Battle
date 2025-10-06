extends Object
class_name LogSchema

# Shared formatters for stage/chapter labels in UI and logs.

static func format_stage(ch: int, sic: int, total: int) -> String:
    var stage_num: int = max(1, int(ch))
    var round_num: int = max(1, int(sic))
    var total_rounds: int = int(total)
    if total_rounds > 0:
        return "Stage %d - Round %d/%d" % [stage_num, round_num, total_rounds]
    return "Stage %d - Round %d" % [stage_num, round_num]

static func format_boss_badge() -> String:
    return "BOSS"
