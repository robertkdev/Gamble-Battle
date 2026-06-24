extends RefCounted
class_name RegenSystem

const Mana := preload("res://scripts/game/stats/mana.gd")

var buff_system: BuffSystem = null
var ability_system: AbilitySystem = null

const TICK_SECONDS: float = 1.0
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

# Expect a map of event_key -> Callable
func apply_ticks(state: BattleState, ticks: int, player_ref: Unit, emitters: Dictionary[String, Callable]) -> void:
	# Drive multiple regen steps when the caller accumulates fractional seconds elsewhere.
	if ticks <= 0 or state == null:
		return
	for _i in range(ticks):
		_apply_single_tick(state, player_ref, emitters)

func _apply_single_tick(state: BattleState, player_ref: Unit, emitters: Dictionary[String, Callable]) -> void:
	# Mana regen (and autocast) respects block tags; health is intentionally unaffected.
	for i in range(state.player_team.size()):
		var u: Unit = state.player_team[i]
		if u:
			var before_mana_p: int = int(u.mana)
			Mana.regen_tick(u, TICK_SECONDS)
			if buff_system != null and buff_system.has_method("is_mana_gain_blocked"):
				if buff_system.is_mana_gain_blocked(state, TEAM_PLAYER, i):
					u.mana = before_mana_p
			# Autocast on regen reaching full mana (for casters who don't attack)
			if ability_system != null and int(u.mana_max) > 0 and int(u.mana) >= int(u.mana_max):
				ability_system.try_cast(TEAM_PLAYER, i)
	# Enemy team regen
	for j in range(state.enemy_team.size()):
		var e: Unit = state.enemy_team[j]
		if e:
			var before_mana_e: int = int(e.mana)
			Mana.regen_tick(e, TICK_SECONDS)
			if buff_system != null and buff_system.has_method("is_mana_gain_blocked"):
				if buff_system.is_mana_gain_blocked(state, TEAM_ENEMY, j):
					e.mana = before_mana_e
			if ability_system != null and int(e.mana_max) > 0 and int(e.mana) >= int(e.mana_max):
				ability_system.try_cast(TEAM_ENEMY, j)
	_emit(emitters, "stats_updated", [player_ref, BattleState.first_alive(state.enemy_team)])
	_emit(emitters, "team_stats_updated", [state.player_team, state.enemy_team])

func _emit(emitters: Dictionary[String, Callable], key: String, args: Array) -> void:
	var cb_variant: Callable = emitters.get(key, Callable())
	var cb: Callable = (cb_variant as Callable)
	if cb.is_valid():
		cb.callv(args)
