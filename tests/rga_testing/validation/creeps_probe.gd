extends Node

const RosterCatalog = preload("res://scripts/game/progression/roster_catalog.gd")
const EnemySpawner = preload("res://scripts/game/combat/enemy_spawner.gd")
const StageTypes = preload("res://scripts/game/progression/stage_types.gd")
const ChapterCatalog = preload("res://scripts/game/progression/chapter_catalog.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var previous_suppress_validation_warnings: bool = UnitFactory.suppress_validation_warnings
    UnitFactory.suppress_validation_warnings = true
    var ch: int = 1
    var sic: int = -1
    # Auto-detect a CREEPS round for this chapter using the roster catalog
    var total: int = int(ChapterCatalog.stages_in(ch))
    var spawner: EnemySpawner = EnemySpawner.new()
    var chosen_units: Array = []
    for i in range(1, total + 1):
        var s: Dictionary = RosterCatalog.get_spec(ch, i)
        var k: String = String(s.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
        if k != StageTypes.KIND_CREEPS:
            continue
        var u: Array = spawner.build_for_spec(s, ch, i)
        sic = i
        chosen_units = u
        break
    if sic <= 0:
        printerr("CreepsProbe: no CREEPS stages found in chapter ", ch)
        _quit(1, previous_suppress_validation_warnings)
        return
    var spec: Dictionary = RosterCatalog.get_spec(ch, sic)
    var kind: String = String(spec.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
    if kind != StageTypes.KIND_CREEPS:
        printerr("CreepsProbe: expected CREEPS kind at ch=", ch, " sic=", sic, ", got ", kind)
        _quit(1, previous_suppress_validation_warnings)
        return
    var units: Array = chosen_units if chosen_units.size() > 0 else spawner.build_for_spec(spec, ch, sic)
    if units.is_empty():
        printerr("CreepsProbe: expected at least one creep")
        _quit(1, previous_suppress_validation_warnings)
        return
    var all_cost_zero: bool = true
    for unit: Unit in units:
        if unit == null:
            continue
        if int(unit.cost) != 0:
            all_cost_zero = false
            break
    if not all_cost_zero:
        printerr("CreepsProbe: some creeps had nonzero cost")
        _quit(1, previous_suppress_validation_warnings)
        return
    print("CreepsProbe: PASS (spawned ", units.size(), ")")
    _quit(0, previous_suppress_validation_warnings)

func _quit(exit_code: int, previous_suppress_validation_warnings: bool) -> void:
    UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
    get_tree().quit(exit_code)
