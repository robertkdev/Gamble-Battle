extends Node

const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const EnemySpawner := preload("res://scripts/game/combat/enemy_spawner.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var ch: int = 1
    var sic: int = -1
    # Auto-detect a CREEPS round for this chapter using the roster catalog
    var total: int = int(ChapterCatalog.stages_in(ch))
    var spawner := EnemySpawner.new()
    var chosen_units: Array = []
    for i in range(1, total + 1):
        var s = RosterCatalog.get_spec(ch, i)
        var k: String = String(s.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
        if k != StageTypes.KIND_CREEPS:
            continue
        # Prefer a CREEPS stage with >=4 units to validate richer waves
        var u: Array = spawner.build_for_spec(s, ch, i)
        if u.size() >= 4:
            sic = i
            chosen_units = u
            break
        # If not enough, remember the first CREEPS stage as fallback
        if sic <= 0:
            sic = i
            chosen_units = u
    if sic <= 0:
        printerr("CreepsProbe: no CREEPS stages found in chapter ", ch)
        get_tree().quit(1)
        return
    var spec: Dictionary = RosterCatalog.get_spec(ch, sic)
    var kind: String = String(spec.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
    if kind != StageTypes.KIND_CREEPS:
        printerr("CreepsProbe: expected CREEPS kind at ch=", ch, " sic=", sic, ", got ", kind)
        get_tree().quit(1)
        return
    var units: Array = chosen_units if chosen_units.size() > 0 else spawner.build_for_spec(spec, ch, sic)
    if units.size() < 4:
        printerr("CreepsProbe: expected >=4 creeps, got ", units.size())
        get_tree().quit(1)
        return
    var all_cost_zero := true
    for u in units:
        if u == null:
            continue
        if int(u.cost) != 0:
            all_cost_zero = false
            break
    if not all_cost_zero:
        printerr("CreepsProbe: some creeps had nonzero cost")
        get_tree().quit(1)
        return
    print("CreepsProbe: PASS (spawned ", units.size(), ")")
    get_tree().quit(0)
