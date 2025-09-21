extends RefCounted
class_name RegenSystem

# Expect a map of event_key -> Callable
func apply_ticks(state: BattleState, ticks: int, player_ref: Unit, emitters: Dictionary[String, Callable]) -> void:
	if ticks <= 0 or state == null:
		return
	for _i in range(ticks):
		_apply_single_tick(state, player_ref, emitters)

func _apply_single_tick(state: BattleState, player_ref: Unit, emitters: Dictionary[String, Callable]) -> void:
	for u in state.player_team:
		if u:
			u.end_of_turn()
	for e in state.enemy_team:
		if e:
			e.end_of_turn()
	_emit(emitters, "stats_updated", [player_ref, BattleState.first_alive(state.enemy_team)])
	_emit(emitters, "team_stats_updated", [state.player_team, state.enemy_team])

func _emit(emitters: Dictionary[String, Callable], key: String, args: Array) -> void:
	var cb_variant: Callable = emitters.get(key, Callable())
	var cb: Callable = (cb_variant as Callable)
	if cb.is_valid():
		cb.callv(args)
