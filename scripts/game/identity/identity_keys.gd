extends Object
class_name IdentityKeys

const PrimaryRole := preload("res://scripts/game/identity/primary_role.gd")

const ROLE_TANK := PrimaryRole.TANK
const ROLE_BRAWLER := PrimaryRole.BRAWLER
const ROLE_ASSASSIN := PrimaryRole.ASSASSIN
const ROLE_MARKSMAN := PrimaryRole.MARKSMAN
const ROLE_MAGE := PrimaryRole.MAGE
const ROLE_SUPPORT := PrimaryRole.SUPPORT

static var ROLES: PackedStringArray = PackedStringArray(PrimaryRole.ALL)

const GOAL_TANK_FRONTLINE_ABSORB := "tank.frontline_absorb"
const GOAL_TANK_TEAM_FORTIFICATION := "tank.team_fortification"
const GOAL_TANK_INITIATE_FIGHT := "tank.initiate_fight"
const GOAL_TANK_SINGLE_TARGET_LOCKDOWN := "tank.single_target_lockdown"

const GOAL_BRAWLER_ATTRITION_DPS := "brawler.attrition_dps"
const GOAL_BRAWLER_FRONTLINE_DISRUPTION := "brawler.frontline_disruption"
const GOAL_BRAWLER_SKIRMISH_DIVE := "brawler.skirmish_dive"

const GOAL_ASSASSIN_BACKLINE_ELIMINATION := "assassin.backline_elimination"
const GOAL_ASSASSIN_CLEANUP_EXECUTION := "assassin.cleanup_execution"
const GOAL_ASSASSIN_DISRUPT_AND_ESCAPE := "assassin.disrupt_and_escape"

const GOAL_MARKSMAN_SUSTAINED_DPS := "marksman.sustained_dps"
const GOAL_MARKSMAN_BACKLINE_SIEGE := "marksman.backline_siege"
const GOAL_MARKSMAN_TANK_SHREDDING := "marksman.tank_shredding"

const GOAL_MAGE_WOMBO_COMBO_BURST := "mage.wombo_combo_burst"
const GOAL_MAGE_AREA_DENIAL_ZONE := "mage.area_denial_zone"
const GOAL_MAGE_PICK_BURST := "mage.pick_burst"
const GOAL_MAGE_SUSTAINED_DPS := "mage.sustained_dps"

const GOAL_SUPPORT_PEEL_CARRY := "support.peel_carry"
const GOAL_SUPPORT_TEAM_AMPLIFICATION := "support.team_amplification"
const GOAL_SUPPORT_ENEMY_LOCKDOWN := "support.enemy_lockdown"
const GOAL_SUPPORT_INITIATE_FIGHT := "support.initiate_fight"
const GOAL_SUPPORT_FORMATION_BREAKING := "support.formation_breaking"

const APPROACH_BURST := "burst"
const APPROACH_AOE := "aoe"
const APPROACH_DOT := "dot"
const APPROACH_EXECUTE := "execute"
const APPROACH_RESET_MECHANIC := "reset_mechanic"
const APPROACH_ON_HIT_EFFECT := "on_hit_effect"
const APPROACH_RAMP := "ramp"
const APPROACH_SUSTAIN := "sustain"
const APPROACH_DAMAGE_REDUCTION := "damage_reduction"
const APPROACH_REDIRECT := "redirect"
const APPROACH_CC_IMMUNITY := "cc_immunity"
const APPROACH_UNTARGETABLE := "untargetable"
const APPROACH_ACCESS_BACKLINE := "access_backline"
const APPROACH_REPOSITION := "reposition"
const APPROACH_ENGAGE := "engage"
const APPROACH_DISRUPT := "disrupt"
const APPROACH_LOCKDOWN := "lockdown"
const APPROACH_PEEL := "peel"
const APPROACH_AMP := "amp"
const APPROACH_DEBUFF := "debuff"
const APPROACH_LONG_RANGE := "long_range"
const APPROACH_ZONE := "zone"

static var APPROACHES: PackedStringArray = PackedStringArray([
	APPROACH_BURST,
	APPROACH_AOE,
	APPROACH_DOT,
	APPROACH_EXECUTE,
	APPROACH_RESET_MECHANIC,
	APPROACH_ON_HIT_EFFECT,
	APPROACH_RAMP,
	APPROACH_SUSTAIN,
	APPROACH_DAMAGE_REDUCTION,
	APPROACH_REDIRECT,
	APPROACH_CC_IMMUNITY,
	APPROACH_UNTARGETABLE,
	APPROACH_ACCESS_BACKLINE,
	APPROACH_REPOSITION,
	APPROACH_ENGAGE,
	APPROACH_DISRUPT,
	APPROACH_LOCKDOWN,
	APPROACH_PEEL,
	APPROACH_AMP,
	APPROACH_DEBUFF,
	APPROACH_LONG_RANGE,
	APPROACH_ZONE,
])
