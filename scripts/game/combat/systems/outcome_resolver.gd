extends RefCounted
class_name OutcomeResolver

var state: BattleState
var rng: RandomNumberGenerator
var outcome_sent: bool = false

func configure(_state: BattleState, _rng: RandomNumberGenerator) -> void:
    state = _state
    rng = _rng
    outcome_sent = false

func reset() -> void:
    outcome_sent = false

func evaluate_idle(simultaneous_pairs: bool, totals: Dictionary) -> String:
    if outcome_sent:
        return ""
    var outcome: String = _outcome_from_board(
        BattleState.all_dead(state.player_team),
        BattleState.all_dead(state.enemy_team),
        simultaneous_pairs,
        totals
    )
    if outcome != "":
        outcome_sent = true
    return outcome

func evaluate_board(simultaneous_pairs: bool, totals: Dictionary) -> String:
    if outcome_sent:
        return ""
    var outcome: String = _outcome_from_board(
        BattleState.all_dead(state.player_team),
        BattleState.all_dead(state.enemy_team),
        simultaneous_pairs,
        totals
    )
    if outcome != "":
        outcome_sent = true
    return outcome

func evaluate_frame(simultaneous_pairs: bool, frame_flags: Dictionary) -> String:
    if outcome_sent:
        return ""
    if BattleState.all_dead(state.player_team) and BattleState.all_dead(state.enemy_team):
        outcome_sent = true
        return "draw"
    var double_ko: bool = bool(frame_flags.get("double_ko", false))
    if double_ko:
        outcome_sent = true
        return "draw"
    var player_dead: bool = bool(frame_flags.get("player_dead", false))
    var enemy_dead: bool = bool(frame_flags.get("enemy_dead", false))
    if player_dead and enemy_dead:
        outcome_sent = true
        return "draw"
    if enemy_dead:
        outcome_sent = true
        return "victory"
    if player_dead:
        outcome_sent = true
        return "defeat"
    return ""

func mark_emitted() -> void:
    outcome_sent = true

func _outcome_from_board(player_dead: bool, enemy_dead: bool, simultaneous_pairs: bool, totals: Dictionary) -> String:
    if player_dead and enemy_dead:
        if simultaneous_pairs:
            return "draw"
        var p_dmg: int = int(totals.get("player", 0))
        var e_dmg: int = int(totals.get("enemy", 0))
        if p_dmg > e_dmg:
            return "victory"
        elif e_dmg > p_dmg:
            return "defeat"
        var p_cd: float = _first_cd(state.player_cds)
        var e_cd: float = _first_cd(state.enemy_cds)
        if p_cd < e_cd:
            return "victory"
        elif e_cd < p_cd:
            return "defeat"
        if rng and rng.randf() < 0.5:
            return "victory"
        return "defeat"
    elif player_dead:
        return "defeat"
    elif enemy_dead:
        return "victory"
    return ""

func _first_cd(cds: Array) -> float:
    if cds.is_empty():
        return 9999.0
    return float(cds[0])

