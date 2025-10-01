extends Node

const IdentityValidator := preload("res://scripts/game/identity/identity_validator.gd")
const GoalCatalog := preload("res://scripts/game/identity/goal_catalog.gd")
const ApproachCatalog := preload("res://scripts/game/identity/approach_catalog.gd")
const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")
const RoleLibrary := preload("res://scripts/game/units/role_library.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitDef := preload("res://scripts/game/units/unit_def.gd")
const Unit := preload("res://scripts/unit.gd")

func _ready() -> void:
    _test_empty_identity()
    _test_role_library_profiles()
    _test_unit_factory_defaults()
    _test_identity_catalogs()
    queue_free()

func _test_empty_identity() -> void:
    var errors := IdentityValidator.validate("", "", [])
    assert(errors.size() > 0)

func _test_role_library_profiles() -> void:
    RoleLibrary.reload()
    var stats := RoleLibrary.base_stats("tank")
    assert(not stats.is_empty())
    assert(stats.has("max_hp"))
    var goals := RoleLibrary.default_goals("tank")
    assert(goals.size() > 0)
    var unit := Unit.new()
    unit.max_hp = 600
    unit.armor = 10
    unit.magic_resist = 5
    unit.attack_damage = 120
    var violates := RoleLibrary.validate_unit("tank", unit)
    assert(violates.size() > 0)

func _test_unit_factory_defaults() -> void:
    RoleLibrary.reload()
    var def := UnitDef.new()
    def.id = "unit_factory_test"
    def.name = "Factory Tank"
    def.primary_role = "tank"
    var unit := UnitFactory._from_def(def)
    assert(unit.get_primary_role() == "tank")
    assert(String(unit.get_primary_goal()).strip_edges() != "")
    var approaches := unit.get_approaches()
    assert(approaches.size() > 0)
    var issues := UnitFactory.validate_role_invariants(unit)
    assert(issues.is_empty())

func _test_identity_catalogs() -> void:
    GoalCatalog.reload()
    ApproachCatalog.reload()
    var expected_goals := [
        IdentityKeys.GOAL_TANK_FRONTLINE_ABSORB,
        IdentityKeys.GOAL_TANK_TEAM_FORTIFICATION,
        IdentityKeys.GOAL_TANK_INITIATE_FIGHT,
        IdentityKeys.GOAL_TANK_SINGLE_TARGET_LOCKDOWN,
        IdentityKeys.GOAL_BRAWLER_ATTRITION_DPS,
        IdentityKeys.GOAL_BRAWLER_FRONTLINE_DISRUPTION,
        IdentityKeys.GOAL_BRAWLER_SKIRMISH_DIVE,
        IdentityKeys.GOAL_ASSASSIN_BACKLINE_ELIMINATION,
        IdentityKeys.GOAL_ASSASSIN_CLEANUP_EXECUTION,
        IdentityKeys.GOAL_ASSASSIN_DISRUPT_AND_ESCAPE,
        IdentityKeys.GOAL_MARKSMAN_SUSTAINED_DPS,
        IdentityKeys.GOAL_MARKSMAN_BACKLINE_SIEGE,
        IdentityKeys.GOAL_MARKSMAN_TANK_SHREDDING,
        IdentityKeys.GOAL_MAGE_WOMBO_COMBO_BURST,
        IdentityKeys.GOAL_MAGE_AREA_DENIAL_ZONE,
        IdentityKeys.GOAL_MAGE_PICK_BURST,
        IdentityKeys.GOAL_MAGE_SUSTAINED_DPS,
        IdentityKeys.GOAL_SUPPORT_PEEL_CARRY,
        IdentityKeys.GOAL_SUPPORT_TEAM_AMPLIFICATION,
        IdentityKeys.GOAL_SUPPORT_ENEMY_LOCKDOWN,
        IdentityKeys.GOAL_SUPPORT_INITIATE_FIGHT,
        IdentityKeys.GOAL_SUPPORT_FORMATION_BREAKING,
    ]
    for goal_id in expected_goals:
        assert(GoalCatalog.has(goal_id), "GoalCatalog missing %s" % goal_id)
        assert(GoalCatalog.get_def(goal_id) != null)
    var expected_approaches := [
        IdentityKeys.APPROACH_BURST,
        IdentityKeys.APPROACH_AOE,
        IdentityKeys.APPROACH_DOT,
        IdentityKeys.APPROACH_EXECUTE,
        IdentityKeys.APPROACH_RESET_MECHANIC,
        IdentityKeys.APPROACH_ON_HIT_EFFECT,
        IdentityKeys.APPROACH_RAMP,
        IdentityKeys.APPROACH_SUSTAIN,
        IdentityKeys.APPROACH_DAMAGE_REDUCTION,
        IdentityKeys.APPROACH_REDIRECT,
        IdentityKeys.APPROACH_CC_IMMUNITY,
        IdentityKeys.APPROACH_UNTARGETABLE,
        IdentityKeys.APPROACH_ACCESS_BACKLINE,
        IdentityKeys.APPROACH_REPOSITION,
        IdentityKeys.APPROACH_ENGAGE,
        IdentityKeys.APPROACH_DISRUPT,
        IdentityKeys.APPROACH_LOCKDOWN,
        IdentityKeys.APPROACH_PEEL,
        IdentityKeys.APPROACH_AMP,
        IdentityKeys.APPROACH_DEBUFF,
        IdentityKeys.APPROACH_LONG_RANGE,
        IdentityKeys.APPROACH_ZONE,
    ]
    for approach_id in expected_approaches:
        assert(ApproachCatalog.has(approach_id), "ApproachCatalog missing %s" % approach_id)
        assert(ApproachCatalog.get_def(approach_id) != null)
