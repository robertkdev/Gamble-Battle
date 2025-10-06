extends Object
class_name RosterUtils

const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")

# Pure helpers shared by catalog/spawner. No engine dependencies.

static func is_boss_stage(sic: int) -> bool:
    return int(sic) == int(ProgressionConfig.BOSS_STAGE)

static func sanitize_ids(ids: Array) -> Array[String]:
    var out: Array[String] = []
    if ids == null:
        return out
    for v in ids:
        var s := String(v).strip_edges()
        if s != "":
            out.append(s)
    return out

