extends RefCounted
class_name AttackEvent

const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var team: String = ""
var shooter_index: int = -1
var target_index: int = -1
var rolled_damage: int = 0
var crit: bool = false
var pending_cooldown: float = 0.0

func _init(
	_team: String = "",
	_shooter_index: int = -1,
	_target_index: int = -1,
	_rolled_damage: int = 0,
	_crit: bool = false,
	_pending_cooldown: float = 0.0
) -> void:
	team = _team
	shooter_index = _shooter_index
	target_index = _target_index
	rolled_damage = _rolled_damage
	crit = _crit
	pending_cooldown = _pending_cooldown

func is_valid() -> bool:
	return team != "" and shooter_index >= 0

func copy() -> AttackEvent:
	return AttackEvent.new(team, shooter_index, target_index, rolled_damage, crit, pending_cooldown)
