extends RefCounted
class_name CombatEvents

var _emitters: Dictionary[String, Callable] = {}

func configure(emitters: Dictionary) -> void:
    _emitters = (emitters.duplicate() if emitters != null else {})

func projectile_fired(team: String, shooter_index: int, target_index: int, damage: int, crit: bool) -> void:
    _emit("projectile_fired", [team, shooter_index, target_index, damage, crit])

func hit_applied(team: String, shooter_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
    _emit("hit_applied", [team, shooter_index, target_index, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd])

func unit_stat_changed(team: String, index: int, fields: Dictionary) -> void:
    _emit("unit_stat_changed", [team, index, fields])

func log_line(text: String) -> void:
    if text == "":
        return
    _emit("log_line", [text])

func stats_snapshot(player_ref, state) -> void:
    if state == null:
        return
    _emit("stats_updated", [player_ref, BattleState.first_alive(state.enemy_team)])

func team_stats(state) -> void:
    if state == null:
        return
    _emit("team_stats_updated", [state.player_team, state.enemy_team])

func _emit(key: String, args: Array) -> void:
    var callable: Callable = _emitters.get(key, Callable())
    if callable.is_valid():
        callable.callv(args)

