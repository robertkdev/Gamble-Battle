extends Object
class_name IdentityRegistry

const PrimaryRole := preload("res://scripts/game/identity/primary_role.gd")
const GoalCatalog := preload("res://scripts/game/identity/goal_catalog.gd")
const ApproachCatalog := preload("res://scripts/game/identity/approach_catalog.gd")
const IdentityValidator := preload("res://scripts/game/identity/identity_validator.gd")

static func reload() -> void:
    GoalCatalog.reload()
    ApproachCatalog.reload()

static func valid_roles() -> PackedStringArray:
    return PackedStringArray(PrimaryRole.ALL)

static func role_display_name(role_id: String) -> String:
    return PrimaryRole.display_name(role_id)

static func default_role_profile_path(role_id: String) -> String:
    return PrimaryRole.default_profile_path(role_id)

static func goals_for_role(role_id: String) -> Array[String]:
    return GoalCatalog.goals_for_role(role_id)

static func goal_def(goal_id: String):
    return GoalCatalog.get_def(goal_id)

static func approach_def(approach_id: String):
    return ApproachCatalog.get_def(approach_id)

static func all_goal_ids() -> PackedStringArray:
    return GoalCatalog.all_goal_ids()

static func all_approach_ids() -> PackedStringArray:
    return ApproachCatalog.all_ids()

static func validate_identity(primary_role: String, primary_goal: String, approaches: Array[String]) -> Array[String]:
    return IdentityValidator.validate(primary_role, primary_goal, approaches)

static func ensure_identity(primary_role: String, primary_goal: String, approaches: Array[String]) -> void:
    IdentityValidator.ensure_valid(primary_role, primary_goal, approaches)