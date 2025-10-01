extends Node

const RoleLibrary := preload("res://scripts/game/units/role_library.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitDef := preload("res://scripts/game/units/unit_def.gd")
const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")

func _ready() -> void:
    RoleLibrary.reload()
    _test_factory_populates_defaults()
    _test_unknown_role_reports_issue()
    _test_goal_role_mismatch_reports_issue()
    _test_unknown_approach_reports_issue()
    queue_free()

func _make_unit_def(id: String, role_id: String, goal_id: String, approaches: Array[String]) -> UnitDef:
    var def := UnitDef.new()
    def.id = id
    def.name = id.capitalize()
    def.primary_role = role_id
    def.primary_goal = goal_id
    def.approaches = approaches.duplicate()
    return def

func _test_factory_populates_defaults() -> void:
    var def := _make_unit_def("defaults_tank", IdentityKeys.ROLE_TANK, "", [])
    var unit := UnitFactory._from_def(def)
    assert(unit.get_primary_role() == IdentityKeys.ROLE_TANK)
    assert(unit.get_primary_goal() != "")
    var approaches := unit.get_approaches()
    assert(approaches.size() > 0)
    var issues := UnitFactory.validate_role_invariants(unit)
    assert(issues.is_empty())

func _test_unknown_role_reports_issue() -> void:
    var def := _make_unit_def("invalid_role", "cosmic", IdentityKeys.GOAL_TANK_FRONTLINE_ABSORB, [IdentityKeys.APPROACH_ENGAGE])
    var unit := UnitFactory._from_def(def)
    var issues := UnitFactory.validate_role_invariants(unit)
    assert(issues.size() > 0)
    var found := false
    for issue in issues:
        if issue.contains("Unknown primary role"):
            found = true
            break
    assert(found)

func _test_goal_role_mismatch_reports_issue() -> void:
    var def := _make_unit_def("goal_mismatch", IdentityKeys.ROLE_TANK, IdentityKeys.GOAL_MAGE_AREA_DENIAL_ZONE, [IdentityKeys.APPROACH_ENGAGE])
    var unit := UnitFactory._from_def(def)
    var issues := UnitFactory.validate_role_invariants(unit)
    assert(issues.size() > 0)
    var found := false
    for issue in issues:
        if issue.contains("is not allowed for role"):
            found = true
            break
    assert(found)

func _test_unknown_approach_reports_issue() -> void:
    var def := _make_unit_def("unknown_approach", IdentityKeys.ROLE_TANK, IdentityKeys.GOAL_TANK_FRONTLINE_ABSORB, ["nonexistent_tag"])
    var unit := UnitFactory._from_def(def)
    var issues := UnitFactory.validate_role_invariants(unit)
    assert(issues.size() > 0)
    var found := false
    for issue in issues:
        if issue.contains("Unknown approach id"):
            found = true
            break
    assert(found)
