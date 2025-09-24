extends RefCounted
class_name RegenSystem

const Health := preload("res://scripts/game/stats/health.gd")
const Mana := preload("res://scripts/game/stats/mana.gd")

var buff_system: BuffSystem = null

# Expect a map of event_key -> Callable
func apply_ticks(state: BattleState, ticks: int, player_ref: Unit, emitters: Dictionary[String, Callable]) -> void:
	if ticks <= 0 or state == null:
		return
	for _i in range(ticks):
		_apply_single_tick(state, player_ref, emitters)

func _apply_single_tick(state: BattleState, player_ref: Unit, emitters: Dictionary[String, Callable]) -> void:
	# Player team regen
	for i in range(state.player_team.size()):
		var u: Unit = state.player_team[i]
		if u:
			Health.regen_tick(u, 1.0)
			var before_mana_p: int = int(u.mana)
			Mana.regen_tick(u, 1.0)
			if buff_system != null and buff_system.has_method("is_mana_gain_blocked"):
				if buff_system.is_mana_gain_blocked(state, "player", i):
					u.mana = before_mana_p
	# Enemy team regen
	for j in range(state.enemy_team.size()):
		var e: Unit = state.enemy_team[j]
		if e:
			Health.regen_tick(e, 1.0)
			var before_mana_e: int = int(e.mana)
			Mana.regen_tick(e, 1.0)
			if buff_system != null and buff_system.has_method("is_mana_gain_blocked"):
				if buff_system.is_mana_gain_blocked(state, "enemy", j):
					e.mana = before_mana_e
	_emit(emitters, "stats_updated", [player_ref, BattleState.first_alive(state.enemy_team)])
	_emit(emitters, "team_stats_updated", [state.player_team, state.enemy_team])

func _emit(emitters: Dictionary[String, Callable], key: String, args: Array) -> void:
	var cb_variant: Callable = emitters.get(key, Callable())
	var cb: Callable = (cb_variant as Callable)
	if cb.is_valid():
		cb.callv(args)
