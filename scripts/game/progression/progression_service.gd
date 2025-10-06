extends Object
class_name ProgressionService

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")

# Stateless chapter/stage mapping utilities.

static func from_global_stage(global: int) -> Dictionary:
    var g: int = int(global)
    assert(g >= 1, "ProgressionService.from_global_stage: global must be >= 1")
    if g < 1:
        g = 1
    var remaining: int = g
    var ch: int = 1
    while true:
        var per_ch: int = int(ChapterCatalog.stages_in(ch))
        if remaining <= per_ch:
            return { "chapter": ch, "stage_in_chapter": remaining }
        remaining -= per_ch
        ch += 1
    # Fallback (should be unreachable) to satisfy analyzer
    return { "chapter": ch, "stage_in_chapter": 1 }

static func to_global_stage(ch: int, sic: int) -> int:
    var c: int = int(ch)
    var s: int = int(sic)
    assert(c >= 1, "ProgressionService.to_global_stage: chapter must be >= 1")
    if c < 1:
        c = 1
    var per_ch: int = int(ChapterCatalog.stages_in(c))
    assert(s >= 1 and s <= per_ch, "ProgressionService.to_global_stage: stage_in_chapter out of bounds")
    if s < 1:
        s = 1
    if s > per_ch:
        s = per_ch
    var total: int = s
    var i: int = 1
    while i < c:
        total += int(ChapterCatalog.stages_in(i))
        i += 1
    return total

static func advance(ch: int, sic: int, win: bool) -> Dictionary:
    var c: int = int(ch)
    var s: int = int(sic)
    assert(c >= 1, "ProgressionService.advance: chapter must be >= 1")
    if c < 1:
        c = 1
    var per_ch: int = int(ChapterCatalog.stages_in(c))
    assert(s >= 1 and s <= per_ch, "ProgressionService.advance: stage_in_chapter out of bounds")
    if s < 1:
        s = 1
    if s > per_ch:
        s = per_ch

    var next_ch: int = c
    var next_sic: int = s
    var chapter_cleared: bool = false

    if win:
        if s >= per_ch:
            # rollover
            next_ch = c + 1
            next_sic = 1
            chapter_cleared = true
        else:
            next_sic = s + 1
    else:
        # stay on current stage
        chapter_cleared = false

    var next_per_ch: int = int(ChapterCatalog.stages_in(next_ch))
    var is_boss_next: bool = (next_sic == next_per_ch)

    return {
        "chapter": next_ch,
        "stage_in_chapter": next_sic,
        "chapter_cleared": chapter_cleared,
        "is_boss_next": is_boss_next,
    }
