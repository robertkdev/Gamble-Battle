extends Object
class_name PrimaryRole

const TANK := "tank"
const BRAWLER := "brawler"
const ASSASSIN := "assassin"
const MARKSMAN := "marksman"
const MAGE := "mage"
const SUPPORT := "support"

const _DISPLAY_NAMES := {
    TANK: "Tank",
    BRAWLER: "Brawler",
    ASSASSIN: "Assassin",
    MARKSMAN: "Marksman",
    MAGE: "Mage",
    SUPPORT: "Support",
}

const _DEFAULT_PROFILE_PATHS := {
    TANK: "res://data/identity/primary_role_profiles/tank.tres",
    BRAWLER: "res://data/identity/primary_role_profiles/brawler.tres",
    ASSASSIN: "res://data/identity/primary_role_profiles/assassin.tres",
    MARKSMAN: "res://data/identity/primary_role_profiles/marksman.tres",
    MAGE: "res://data/identity/primary_role_profiles/mage.tres",
    SUPPORT: "res://data/identity/primary_role_profiles/support.tres",
}

const ALL := [TANK, BRAWLER, ASSASSIN, MARKSMAN, MAGE, SUPPORT]
const _ROLE_SET := {
    TANK: true,
    BRAWLER: true,
    ASSASSIN: true,
    MARKSMAN: true,
    MAGE: true,
    SUPPORT: true,
}

static func is_valid(role_id: String) -> bool:
    return _ROLE_SET.has(role_id)

static func require_valid(role_id: String) -> void:
    if not is_valid(role_id):
        push_error("PrimaryRole: invalid role id '%s'" % role_id)
        assert(false)

static func display_name(role_id: String) -> String:
    return String(_DISPLAY_NAMES.get(role_id, role_id.capitalize()))

static func default_profile_path(role_id: String) -> String:
    return String(_DEFAULT_PROFILE_PATHS.get(role_id, ""))